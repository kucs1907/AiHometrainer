// lib/screens/live_feedback_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:io' show WebSocket;
import 'dart:math';

import 'session_result_screen.dart';
import '../config/env.dart';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';

// ML Kit
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

// 화면 꺼짐 방지
import 'package:wakelock_plus/wakelock_plus.dart';

// 오버레이
import '../widgets/pose_painter.dart';

// ✅ TTS
import 'package:flutter_tts/flutter_tts.dart';

/// 네트워크 환경에 맞춰 변경
const String WS_URL = Env.wsUrl;

/// 운동명 매핑 (한글 ⇄ 영문)
const Map<String, String> ko2en = {
  '딥스': 'dips',
  '플랭크': 'plank',
  '턱걸이': 'pullup',
  '팔굽혀펴기': 'pushup',
  '스쿼트': 'squat',
};
const Map<String, String> en2ko = {
  'dips': '딥스',
  'plank': '플랭크',
  'pullup': '턱걸이',
  'pushup': '팔굽혀펴기',
  'squat': '스쿼트',
};

/// ===== 로컬 카운트 쿨다운 설정 =====
const int REP_COOLDOWN_SECONDS = 1;

/// ===== 모델 게이팅 임계치 =====
const double MODEL_PROBA_THRESH = 0.60;

/// ===== 코칭 문구 스로틀/데바운스 =====
const int TIP_CONFIRM_FRAMES = 6;   // 6프레임 연속(약 0.7초 @8~10fps)
const int TIP_MIN_SHOW_MS    = 1200;

class LiveFeedbackScreen extends StatefulWidget {
  final List<String> selectedExercises;
  const LiveFeedbackScreen({super.key, required this.selectedExercises});

  @override
  State<LiveFeedbackScreen> createState() => _LiveFeedbackScreenState();
}

class _LiveFeedbackScreenState extends State<LiveFeedbackScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  CameraController? _camera;
  late final PoseDetector _poseDetector;

  WebSocketChannel? _ws;
  bool _wsOpen = false;
  bool _wsAvailable = false;

  // 화면 상태
  String feedbackMessage = "서버로부터 피드백 대기 중..."; // 시스템 상태/에러/연결
  String coachTip = "준비가 끝나면 자세를 잡아주세요"; // 실시간 코칭 메시지
  String _label = '-';
  double _proba = 0.0;

  /// ====== 로컬 카운트(각도 기반) ======
  int count = 0;
  int _lastCount = 0;
  String _phase = 'init';

  bool _ending = false;

  // 결과 네비/캐시
  bool _awaitingFinish = false;
  bool _navigatedToResult = false;
  double _lastServerAccuracy = 0.0;
  double _finalServerAvgAcc = 0.0;
  int _lastSessionId = 0;

  bool _localIsCorrect = false;

  // plank
  int _plankGoodMsAcc = 0;
  int _plankLastTickMs = 0;

  // 쿨다운
  DateTime? _lastRepAcceptedAt;

  // (선택) 애니메이션 컨트롤러 — 지금은 REPS에 적용 안 함
  late final AnimationController _anim;

  // 현재 선택 운동
  late String _exerciseKo;
  late String _exerciseEn;

  // 스트림 제어
  bool _processing = false;
  int _sendIntervalMs = 120; // ~8fps
  int _lastSentMs = 0;

  // 오버레이
  List<PoseLandmark> _overlayLandmarks = const [];
  ui.Size _overlayImageSize = ui.Size.zero;
  bool _mirrorOverlay = false;

  // 타이머
  Timer? _timer;
  int _elapsedSec = 0;
  String get _mmss {
    final m = (_elapsedSec ~/ 60).toString().padLeft(2, '0');
    final s = (_elapsedSec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// 모델 게이트 상태
  bool _haveModelSignal = false;
  bool _modelOk = false;

  /// ✅ finish 중복 전송 방지
  bool _finishSent = false;

  /// ✅ 'finished' ack 대기용
  Completer<Map<String, dynamic>>? _finishAck;

  /// ===== 실수 패턴 카운터(요약 피드백용) =====
  int _badDepth = 0;         // 깊이 부족(스쿼트/푸쉬업/딥스)
  int _noLockout = 0;        // 완전 펴지지 않음
  int _roundedTorso = 0;     // 몸통/허리 각도 불량
  int _hipsHigh = 0;         // 플랭크 엉덩이 높음
  int _hipsLow = 0;          // 플랭크 엉덩이 처짐
  int _pullupNotHigh = 0;    // 턱이 충분히 안 올라감

  /// ===== 코칭 문구 후보 상태 =====
  String _tipCandidate = "";
  int _tipCandidateStreak = 0;
  bool _tipCandidateIsBad = false;     // ✅ 후보가 교정성 문구인지
  DateTime _lastTipChange = DateTime.fromMillisecondsSinceEpoch(0);

  /// ===== TTS =====
  final FlutterTts _tts = FlutterTts();
  bool _ttsEnabled = true;                      // 추후 설정에서 끄고 켜기 가능
  int _lastTtsMs = 0;
  static const int TTS_MIN_GAP_MS = 900;        // 두 발화 최소 간격

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable();

    _exerciseKo = widget.selectedExercises.isNotEmpty
        ? widget.selectedExercises.first
        : '스쿼트';
    _exerciseEn = ko2en[_exerciseKo] ?? _exerciseKo;

    _poseDetector = PoseDetector(
      options: PoseDetectorOptions(
        mode: PoseDetectionMode.stream,
        model: PoseDetectionModel.base,
      ),
    );

    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _initTts(); // ✅ TTS 초기화

    _startTimer();
    _initCamera().then((_) => _connectWsAndStart());
  }

  Future<void> _initTts() async {
    try {
      await _tts.setLanguage('ko-KR');
      await _tts.setSpeechRate(0.48);
      await _tts.setPitch(1.0);
      await _tts.awaitSpeakCompletion(true);
    } catch (_) {
      // 엔진/언어 미설치 등은 조용히 무시
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _timer?.cancel();

    _stopImageStream();
    _camera?.dispose();
    _camera = null;

    _poseDetector.close();
    _anim.dispose();

    _tts.stop(); // ✅ TTS 정리
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      WakelockPlus.enable();
    }
  }

  /// ===== 타이머 시작 =====
  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _ending) return;
      setState(() {
        _elapsedSec += 1;
      });
    });
  }

  // ===== 카메라 =====
  Future<void> _initCamera() async {
    try {
      final cams = await availableCameras();

      final front = cams.isNotEmpty
          ? (cams.firstWhere(
              (c) => c.lensDirection == CameraLensDirection.front,
              orElse: () => cams.first,
            ))
          : throw StateError('사용 가능한 카메라가 없습니다.');

      _mirrorOverlay = front.lensDirection == CameraLensDirection.front;

      final controller = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );

      _camera = controller;
      await controller.initialize();

      if (!mounted) return;

      await controller.startImageStream(_onCameraImage);
      setState(() {}); // 프리뷰 갱신
    } catch (e) {
      setState(() => feedbackMessage = "카메라 초기화 실패: $e");
    }
  }

  void _stopImageStream() {
    final cam = _camera;
    if (cam != null && cam.value.isStreamingImages) {
      try {
        cam.stopImageStream();
      } catch (_) {}
    }
  }

  // ===== WebSocket (정확도/세션만) =====
  Future<void> _connectWsAndStart() async {
    try {
      final socket = await WebSocket.connect(WS_URL)
          .timeout(const Duration(milliseconds: 800));
      _ws = IOWebSocketChannel(socket);
      _wsAvailable = true;

      _ws!.sink.add(jsonEncode({
        "type": "start",
        "user_id": "u-1",
        "exercise": _exerciseEn,
      }));
      _wsOpen = true;

      _ws!.stream.listen((message) {
        try {
          final data = message is String ? jsonDecode(message) : message;
          switch (data["type"]) {
            case "started":
              _safeSet(() => feedbackMessage = "세션 시작됨. 프레임 전송 중…");
              break;

            case "inference":
              final lbl = data["label"];
              final ratio = (data["proba"] as num?)?.toDouble() ?? 0.0;

              _lastServerAccuracy = ratio;

              bool labelCorrect = false;
              if (lbl is String) {
                final l = lbl.toLowerCase();
                if (l.contains('correct') || l.contains('good') || l == 'ok') {
                  labelCorrect = true;
                }
              }
              _modelOk = labelCorrect || (ratio >= MODEL_PROBA_THRESH);
              _haveModelSignal = true;

              _safeSet(() {
                feedbackMessage = "피드백 수신 중";
                _label = lbl is String ? (en2ko[lbl] ?? lbl) : '-';
                _proba = ratio;
              });
              break;

            case "finished":
              final sid   = (data["session_id"] as num?)?.toInt() ?? 0;
              final ratio = (data["correct_ratio"] as num?)?.toDouble() ?? 0.0;

              _lastSessionId = sid;
              _finalServerAvgAcc = ratio;
              _safeSet(() => feedbackMessage = "세션 종료");

              // ✅ 서버 ack 완료 신호
              _finishAck?.complete(data);

              if (_navigatedToResult) break;

              if (_awaitingFinish && mounted) {
                _navigatedToResult = true;
                Navigator.of(context).pushReplacementNamed(
                  '/session_result',
                  arguments: SessionResultArgs(
                    exerciseKo: _exerciseKo,
                    exerciseEn: _exerciseEn,
                    reps: count,
                    accuracy: _finalAccForResult(),
                    sessionId: sid,
                    feedback: _finalFeedbackSummary(),
                  ),
                );
              }
              break;

            case "error":
              _safeSet(() => feedbackMessage = "에러: ${data["message"]}");
              break;
          }
        } catch (e) {
          _safeSet(() => feedbackMessage = "수신 파싱 오류: $e");
        }
      }, onDone: () {
        _wsOpen = false;
        _safeSet(() => feedbackMessage = "연결 종료");

        if (_navigatedToResult) return;

        if (_awaitingFinish && mounted) {
          _navigatedToResult = true;
          Navigator.of(context).pushReplacementNamed(
            '/session_result',
            arguments: SessionResultArgs(
              exerciseKo: _exerciseKo,
              exerciseEn: _exerciseEn,
              reps: count,
              accuracy: _finalAccForResult(),
              sessionId: _lastSessionId,
              feedback: _finalFeedbackSummary(),
            ),
          );
        }
      }, onError: (e) {
        _wsOpen = false;
        _safeSet(() => feedbackMessage = "연결 에러: $e");

        if (_navigatedToResult) return;

        if (_awaitingFinish && mounted) {
          _navigatedToResult = true;
          Navigator.of(context).pushReplacementNamed(
            '/session_result',
            arguments: SessionResultArgs(
              exerciseKo: _exerciseKo,
              exerciseEn: _exerciseEn,
              reps: count,
              accuracy: _finalAccForResult(),
              sessionId: _lastSessionId,
              feedback: _finalFeedbackSummary(),
            ),
          );
        }
      });

      _safeSet(() {}); // 상태 갱신
    } catch (_) {
      _wsAvailable = false;
      _wsOpen = false;
      _ws = null;
      _safeSet(() => feedbackMessage = "오프라인(서버 미연결)");
    }
  }

  double _finalAccForResult() {
    return (_finalServerAvgAcc != 0.0)
        ? _finalServerAvgAcc
        : (_lastServerAccuracy != 0.0
            ? _lastServerAccuracy
            : (_localIsCorrect ? 1.0 : 0.0));
  }

  /// ✅ 서버에 finish 전송 → finished ack 대기 → 채널 close → 끝.
  ///    ack이 타임아웃이면 false 반환(폴백 네비로 처리)
  Future<bool> _finishSession({
    int? reps,
    Duration ackTimeout = const Duration(milliseconds: 1500),
  }) async {
    if (_finishSent) return false; // 중복 방지
    _finishSent = true;

    final ch = _ws;
    if (ch == null) return false;

    try {
      // 1) ack 대기 준비
      _finishAck = Completer<Map<String, dynamic>>();

      // 2) finish 전송 (client_reps 함께)
      ch.sink.add(jsonEncode({
        "type": "finish",
        "client_reps": reps ?? count,
      }));

      // 3) ack 대기
      final res = await _finishAck!.future
          .timeout(ackTimeout, onTimeout: () => {"ok": false, "timeout": true});

      // 4) 반드시 채널 close를 await (flush 보장)
      try {
        await ch.sink.close();
      } catch (_) {}

      _ws = null;
      _wsOpen = false;

      if (res["timeout"] == true) return false;
      return true;
    } catch (_) {
      // 예외 시에도 닫기 시도
      try { await ch.sink.close(); } catch (_) {}
      _ws = null;
      _wsOpen = false;
      return false;
    }
  }

  bool _cooldownPassed() {
    if (_lastRepAcceptedAt == null) return true;
    final diff = DateTime.now().difference(_lastRepAcceptedAt!);
    return diff.inSeconds >= REP_COOLDOWN_SECONDS;
  }

  bool _shouldGateByModel() => _haveModelSignal;

  // ===== 코칭 문구 업데이트(데바운스/확정 프레임)
  // speakOnConfirm=true 인 경우에만 확정 시 TTS 발화 (rep 강제 교체는 무음)
  void _updateCoachTip(String next, {bool force = false, bool speakOnConfirm = false}) {
    final now = DateTime.now();

    if (force) {
      // ✅ rep +1 등 즉시 교체이지만, 요구사항상 이때는 TTS 꺼둔다.
      coachTip = next;
      _lastTipChange = now;
      _tipCandidate = "";
      _tipCandidateStreak = 0;
      _tipCandidateIsBad = false;
      if (mounted) setState(() {});
      return;
    }

    if (next == coachTip) {
      _tipCandidate = "";
      _tipCandidateStreak = 0;
      _tipCandidateIsBad = false;
      return;
    }

    if (next == _tipCandidate) {
      _tipCandidateStreak++;
    } else {
      _tipCandidate = next;
      _tipCandidateStreak = 1;
      // 현재 후보가 교정성인지 전달받은 speakOnConfirm 기준으로 표시
      _tipCandidateIsBad = speakOnConfirm;
    }

    final minShown =
        now.difference(_lastTipChange).inMilliseconds >= TIP_MIN_SHOW_MS;

    if (_tipCandidateStreak >= TIP_CONFIRM_FRAMES && minShown) {
      coachTip = _tipCandidate;
      _lastTipChange = now;
      final shouldSpeak = _tipCandidateIsBad; // 확정된 후보가 교정성일 때만 발화
      _tipCandidate = "";
      _tipCandidateStreak = 0;
      _tipCandidateIsBad = false;
      if (mounted) setState(() {});
      if (shouldSpeak) {
        _speakTip(coachTip); // ✅ 자세가 안좋아 교정할 때만 말함
      }
    }
  }

  // ===== 카메라 프레임 처리 =====
  Future<void> _onCameraImage(CameraImage image) async {
    if (!mounted || _processing || _ending) return;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs - _lastSentMs < _sendIntervalMs) return;
    _lastSentMs = nowMs;

    _processing = true;
    try {
      final cam = _camera;
      if (cam == null || !cam.value.isInitialized) return;

      final input = _toInputImage(image, cam.description);

      final poses = await _poseDetector.processImage(input);
      if (poses.isEmpty) {
        _overlayLandmarks = const [];
        // 사람 미검출 안내는 음성 제외
        _updateCoachTip("사람이 보이지 않아요. 프레임에 몸 전체가 들어오게 위치해 주세요",
            speakOnConfirm: false);
        if (mounted) setState(() {});
        return;
      }

      final pose = poses.first;

      final rotation = cam.description.sensorOrientation;
      final isRotated = rotation == 90 || rotation == 270;
      _overlayImageSize = isRotated
          ? ui.Size(image.height.toDouble(), image.width.toDouble())
          : ui.Size(image.width.toDouble(), image.height.toDouble());
      _overlayLandmarks = pose.landmarks.values.toList(growable: false);

      _updateLocalByExercise(pose); // 여기서 coachTip은 _updateCoachTip()으로만 갱신

      // 서버로 키포인트 전송
      final keypoints = _mapToCoco17(
        pose,
        _overlayImageSize,
        isFrontCamera:
            cam.description.lensDirection == CameraLensDirection.front,
      );
      if (_wsAvailable && _ws != null && _wsOpen && keypoints.length == 17) {
        final payload = {"type": "frame", "keypoints": keypoints};
        try {
          _ws!.sink.add(jsonEncode(payload));
        } catch (_) {}
      }

      if (mounted) setState(() {});
    } catch (e) {
      _safeSet(() => feedbackMessage = "추론 오류: $e");
    } finally {
      _processing = false;
    }
  }

  // === 포맷: NV21 고정 + YUV420 → NV21
  Uint8List _bytesForMlkit(CameraImage image) {
    if (image.format.group == ImageFormatGroup.nv21) {
      return image.planes[0].bytes;
    }
    if (image.format.group == ImageFormatGroup.yuv420) {
      return _yuv420ToNv21(image);
    }
    throw UnsupportedError('Unsupported camera image format: ${image.format.group}');
  }

  Uint8List _yuv420ToNv21(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final ySize = width * height;
    final uvSize = width * height ~/ 2;
    final out = Uint8List(ySize + uvSize);

    final yPlane = image.planes[0];
    int o = 0;
    for (int r = 0; r < height; r++) {
      final start = r * yPlane.bytesPerRow;
      out.setRange(o, o + width, yPlane.bytes.sublist(start, start + width));
      o += width;
    }

    final u = image.planes[1];
    final v = image.planes[2];
    final uRowStride = u.bytesPerRow;
    final vRowStride = v.bytesPerRow;
    final uPixelStride = u.bytesPerPixel ?? 1;
    final vPixelStride = v.bytesPerPixel ?? 1;

    for (int r = 0; r < height ~/ 2; r++) {
      int uRow = r * uRowStride;
      int vRow = r * vRowStride;
      for (int c = 0; c < width; c += 2) {
        final uIdx = uRow + (c ~/ 2) * uPixelStride;
        final vIdx = vRow + (c ~/ 2) * vPixelStride;
        out[o++] = v.bytes[vIdx];
        out[o++] = u.bytes[uIdx];
      }
    }
    return out;
  }

  InputImage _toInputImage(CameraImage image, CameraDescription desc) {
    final bytes = _bytesForMlkit(image);

    final rotation =
        InputImageRotationValue.fromRawValue(desc.sensorOrientation) ??
            InputImageRotation.rotation0deg;

    final metadata = InputImageMetadata(
      size: ui.Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,
      format: InputImageFormat.nv21,
      bytesPerRow: image.planes[0].bytesPerRow,
    );

    return InputImage.fromBytes(bytes: bytes, metadata: metadata);
  }

  /// ======== 각도/코칭 헬퍼 ========

  double _angle(List<double> a, List<double> b, List<double> c) {
    final ab = [a[0]-b[0], a[1]-b[1]];
    final cb = [c[0]-b[0], c[1]-b[1]];
    final ang = (atan2(cb[1], cb[0]) - atan2(ab[1], ab[0])) * 180.0 / pi;
    final x = ang.abs();
    return x > 180.0 ? 360.0 - x : x;
  }

  PoseLandmark? _lm(Pose pose, PoseLandmarkType t) => pose.landmarks[t];

  String _fmtPct(double v) => "${(v*100).toStringAsFixed(0)}%";

  void _updateLocalByExercise(Pose pose) {
    bool isCorrect = false;
    bool repInc = false;
    bool forceTip = false;           // 카운트 성공 등 즉시 교체 플래그
    bool badTip = false;             // ✅ 교정성 문구 여부
    String tip = "좋아요! 리듬 유지해요";

    final ls = _lm(pose, PoseLandmarkType.leftShoulder);
    final rs = _lm(pose, PoseLandmarkType.rightShoulder);
    final le = _lm(pose, PoseLandmarkType.leftElbow);
    final re = _lm(pose, PoseLandmarkType.rightElbow);
    final lw = _lm(pose, PoseLandmarkType.leftWrist);
    final rw = _lm(pose, PoseLandmarkType.rightWrist);
    final lh = _lm(pose, PoseLandmarkType.leftHip);
    final rh = _lm(pose, PoseLandmarkType.rightHip);
    final lk = _lm(pose, PoseLandmarkType.leftKnee);
    final rk = _lm(pose, PoseLandmarkType.rightKnee);
    final la = _lm(pose, PoseLandmarkType.leftAnkle);
    final ra = _lm(pose, PoseLandmarkType.rightAnkle);

    double torsoAngleAvg() {
      if (ls == null || lh == null || la == null || rs == null || rh == null || ra == null) return 180;
      final bodyL = _angle([ls.x, ls.y], [lh.x, lh.y], [la.x, la.y]);
      final bodyR = _angle([rs.x, rs.y], [rh.x, rh.y], [ra.x, ra.y]);
      return (bodyL + bodyR) / 2.0;
    }

    switch (_exerciseEn) {
      case 'squat': {
        if (lh == null || lk == null || la == null) break;
        final kneeL = _angle([lh.x, lh.y], [lk.x, lk.y], [la.x, la.y]);
        double kneeR = 180;
        if (rh != null && rk != null && ra != null) {
          kneeR = _angle([rh.x, rh.y], [rk.x, rk.y], [ra.x, ra.y]);
        }
        final knee = min(kneeL, kneeR);

        if (knee >= 160) {
          tip = "완전히 일어났어요. 무릎을 곧게 펴 유지!";
        } else if (knee >= 120) {
          tip = "조금 더 내려가보세요(무릎 각도 더 작게)!";
          _badDepth++; badTip = true;
        } else if (knee <= 90) {
          tip = "좋은 깊이입니다. 가슴은 세우고 무릎 흔들림 주의!";
        }

        final torso = torsoAngleAvg();
        if (torso < 155) {
          tip = "허리를 세워요(가슴 업)!";
          _roundedTorso++; badTip = true;
        }

        if (knee < 90) _phase = 'down';
        if (knee > 160 && _phase == 'down' && _cooldownPassed()) {
          repInc = true; _phase = 'up';
        }

        isCorrect = (knee > 150) || (knee < 95);
        break;
      }

      case 'pushup': {
        if (ls == null || le == null || lw == null || rs == null || re == null || rw == null) break;
        final elbowL = _angle([ls.x, ls.y], [le.x, le.y], [lw.x, lw.y]);
        final elbowR = _angle([rs.x, rs.y], [re.x, re.y], [rw.x, rw.y]);
        final elbow = min(elbowL, elbowR);

        if (elbow >= 160) {
          tip = "팔을 완전히 펴고 코어 힘 유지!";
          _noLockout++; // 칭찬성
        } else if (elbow >= 100) {
          tip = "조금 더 내려가요(가슴 바닥 가까이)!";
          _badDepth++; badTip = true;
        } else {
          tip = "좋아요, 이제 위로 밀어 올려요!";
        }

        final torso = torsoAngleAvg();
        if (torso < 165) {
          tip = "몸을 일직선으로! 엉덩이 처짐 주의";
          _roundedTorso++; badTip = true;
        }

        if (elbow < 90) _phase = 'down';
        if (elbow > 160 && _phase == 'down' && _cooldownPassed()) {
          repInc = true; _phase = 'up';
        }

        isCorrect = (elbow > 155) || (elbow < 85);
        break;
      }

      case 'dips': {
        if (ls == null || le == null || lw == null || rs == null || re == null || rw == null) break;
        final elbowL = _angle([ls.x, ls.y], [le.x, le.y], [lw.x, lw.y]);
        final elbowR = _angle([rs.x, rs.y], [re.x, re.y], [rw.x, rw.y]);
        final elbow = min(elbowL, elbowR);

        if (elbow >= 165) {
          tip = "완전 펴기 좋습니다. 어깨는 내리고 가슴 열기!";
          _noLockout++;
        } else if (elbow >= 90) {
          tip = "조금 더 깊게 내려가요(어깨 말림 주의)!";
          _badDepth++; badTip = true;
        } else {
          tip = "좋아요, 부드럽게 위로 밀어올려요!";
        }

        final torso = torsoAngleAvg();
        if (torso < 165) {
          tip = "상체를 너무 숙이지 말고 가슴을 펴요";
          _roundedTorso++; badTip = true;
        }

        if (elbow < 80) _phase = 'down';
        if (elbow > 160 && _phase == 'down' && _cooldownPassed()) {
          repInc = true; _phase = 'up';
        }
        isCorrect = (elbow > 155) || (elbow < 75);
        break;
      }

      case 'pullup': {
        if (ls == null || rs == null || lw == null || rw == null) break;
        final shoulderY = (ls.y + rs.y) / 2.0;
        final wristY = (lw.y + rw.y) / 2.0;
        const upThresh = -40.0;
        const downThresh = 40.0;
        final diff = wristY - shoulderY;

        if (diff < upThresh) {
          tip = "좋아요! 턱을 바 위로 유지해보세요";
        } else if (diff < 0) {
          tip = "조금만 더! 등으로 당겨 턱을 바 위로";
          badTip = true;
        } else {
          tip = "완전한 매달림 후 당기기 시작!";
          _pullupNotHigh++; badTip = true;
        }

        if (diff < upThresh) _phase = 'up';
        if (diff > downThresh && _phase == 'up' && _cooldownPassed()) {
          repInc = true; _phase = 'down';
        }
        isCorrect = (diff < upThresh) || (diff > downThresh/2);
        break;
      }

      case 'plank': {
        if (ls == null || lh == null || la == null || rs == null || rh == null || ra == null) break;
        final bodyL = _angle([ls.x, ls.y], [lh.x, lh.y], [la.x, la.y]);
        final bodyR = _angle([rs.x, rs.y], [rh.x, rh.y], [ra.x, ra.y]);
        final body = (bodyL + bodyR) / 2.0; // 180에 가까울수록 일직선

        if (body >= 175) {
          tip = "좋아요! 몸 일직선 유지";
        } else if (body >= 165) {
          tip = "복부에 힘, 허리를 조금 더 펴요";
          badTip = true;
        } else {
          tip = "엉덩이를 살짝 올려 몸을 일직선으로!";
          _hipsLow++; badTip = true;
        }

        // 플랭크는 1초 유지 = 1rep
        final now = DateTime.now().millisecondsSinceEpoch;
        if (_plankLastTickMs == 0) _plankLastTickMs = now;
        if (body >= 165) {
          _plankGoodMsAcc += (now - _plankLastTickMs);
          while (_plankGoodMsAcc >= 1000) {
            repInc = true;
            _plankGoodMsAcc -= 1000;
          }
        }
        _plankLastTickMs = now;

        isCorrect = (body > 165);
        break;
      }
    }

    // 모델 게이팅(모델 신호가 있을 때만) — 불확실 메시지는 교정성으로 취급
    if (repInc && _shouldGateByModel()) {
      if (!_modelOk) {
        repInc = false;
        tip = "AI가 아직 불확실해요(신호 ${_fmtPct(_proba)}). 자세를 더 분명히!";
        badTip = true;
      }
    }

    // 카운트 수용
    if (repInc) {
      if (_cooldownPassed() || _exerciseEn == 'plank') {
        count += 1;
        _lastRepAcceptedAt = DateTime.now();
        if (count > _lastCount) {
          _lastCount = count;
          _anim.forward(from: 0.0);
        }
        // ✅ rep 직후 칭찬은 강제 교체하지만 '무음'으로
        tip = "좋아요! +1 ✅  (총 $count)";
        forceTip = true;
        badTip = false; // 칭찬은 교정 아님
      }
    }

    _localIsCorrect = isCorrect;

    // 코칭 문구 갱신 — 교정성일 때만 speakOnConfirm=true
    _updateCoachTip(tip, force: forceTip, speakOnConfirm: badTip && !forceTip);
  }

  /// ML Kit landmark → COCO 17
  List<Map<String, double>> _mapToCoco17(
    Pose pose,
    ui.Size imageSize, {
    required bool isFrontCamera,
  }) {
    double w = imageSize.width;
    double h = imageSize.height;

    PoseLandmark? g(PoseLandmarkType t) => pose.landmarks[t];

    Map<String, double> n(PoseLandmark? lm) {
      if (lm == null) return {"x": 0.0, "y": 0.0, "score": 0.0};
      double x = (lm.x / w).clamp(0.0, 1.0);
      double y = (lm.y / h).clamp(0.0, 1.0);

      // if (isFrontCamera) x = 1.0 - x;

      final score = (lm.likelihood ?? 0.9).clamp(0.0, 1.0);
      return {"x": x, "y": y, "score": score};
    }

    final leftEye  = g(PoseLandmarkType.leftEye)  ?? g(PoseLandmarkType.leftEyeOuter) ?? g(PoseLandmarkType.leftEyeInner);
    final rightEye = g(PoseLandmarkType.rightEye) ?? g(PoseLandmarkType.rightEyeOuter) ?? g(PoseLandmarkType.rightEyeInner);

    final list = <Map<String, double>>[
      n(g(PoseLandmarkType.nose)),
      n(leftEye),
      n(rightEye),
      n(g(PoseLandmarkType.leftEar)),
      n(g(PoseLandmarkType.rightEar)),
      n(g(PoseLandmarkType.leftShoulder)),
      n(g(PoseLandmarkType.rightShoulder)),
      n(g(PoseLandmarkType.leftElbow)),
      n(g(PoseLandmarkType.rightElbow)),
      n(g(PoseLandmarkType.leftWrist)),
      n(g(PoseLandmarkType.rightWrist)),
      n(g(PoseLandmarkType.leftHip)),
      n(g(PoseLandmarkType.rightHip)),
      n(g(PoseLandmarkType.leftKnee)),
      n(g(PoseLandmarkType.rightKnee)),
      n(g(PoseLandmarkType.leftAnkle)),
      n(g(PoseLandmarkType.rightAnkle)),
    ];

    final avgScore =
        list.map((m) => m["score"] ?? 0.0).fold<double>(0.0, (a, b) => a + b) / list.length;
    if (avgScore < 0.2) return const [];

    return list;
  }

  // ===== 요약 피드백 생성 =====
  String _finalFeedbackSummary() {
    final b = StringBuffer();
    b.writeln("운동 총평");

    switch (_exerciseEn) {
      case 'squat':
        if (_badDepth >= 3) b.writeln("• 스쿼트 깊이가 부족했어요. 무릎 각도를 더 줄여 충분히 앉았다가 올라오세요.");
        if (_roundedTorso >= 3) b.writeln("• 상체가 숙여졌습니다. 가슴을 열고 코어에 힘을 주세요.");
        if (_noLockout >= 3) b.writeln("• 완전히 일어선 뒤 1초 정지(락아웃)로 마무리해보세요.");
        break;
      case 'pushup':
        if (_badDepth >= 3) b.writeln("• 바닥에 더 가까이 내려갔다가 밀어올리면 더 좋아요.");
        if (_roundedTorso >= 3) b.writeln("• 몸을 일직선으로 유지(엉덩이 처짐 주의)하세요.");
        if (_noLockout >= 3) b.writeln("• 팔을 완전히 펴고 0.5~1초 정지해보세요.");
        break;
      case 'dips':
        if (_badDepth >= 3) b.writeln("• 하강 깊이가 조금 아쉬웠어요. 어깨 말림 없이 가슴을 열고 더 깊게 내려가보세요.");
        if (_roundedTorso >= 3) b.writeln("• 상체가 과도하게 숙여졌어요. 중립자세를 유지해요.");
        break;
      case 'pullup':
        if (_pullupNotHigh >= 3) b.writeln("• 턱이 바 위로 오도록 끝까지 당겨보세요. 반동 대신 등으로 끌어올리기!");
        break;
      case 'plank':
        if (_hipsLow >= 3) b.writeln("• 허리가 꺼졌어요. 배꼽을 등 쪽으로 끌어당겨 코어를 조이세요.");
        if (_hipsHigh >= 3) b.writeln("• 엉덩이가 높습니다. 어깨-엉덩이-발목이 한 선상에 있도록 조정하세요.");
        break;
    }

    if (b.toString().trim() == "운동 총평") {
      b.writeln("• 전반적으로 안정적인 자세였어요. 지금 리듬을 유지해봅시다!");
    }
    return b.toString().trim();
  }

  // ===== 유틸 =====
  void _safeSet(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  Future<void> markTodayAsExercised() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await prefs.setString('last_exercise_date', today);
  }

  // ===== TTS 유틸 =====
  Future<void> _speak(String text, {bool interrupt = false}) async {
    if (!_ttsEnabled || text.trim().isEmpty) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    if (!interrupt && now - _lastTtsMs < TTS_MIN_GAP_MS) return;

    try {
      if (interrupt) {
        await _tts.stop();
      }
      _lastTtsMs = now;
      await _tts.speak(text);
    } catch (_) {
      // 무시
    }
  }

  Future<void> _speakTip(String text, {bool interrupt = false}) async {
    // 시스템/에러 상태는 음성 제외
    if (text.contains("AI") || text.contains("에러") || text.contains("오프라인")) return;
    final msg = text.length > 60 ? text.substring(0, 60) : text;
    await _speak(msg, interrupt: interrupt);
  }

  @override
  Widget build(BuildContext context) {
    final camReady = !_ending && _camera != null && _camera!.value.isInitialized;
    final insets = MediaQuery.of(context).padding;

    return WillPopScope(
      onWillPop: () async {
        if (_ending) return false;
        _awaitingFinish = true;
        setState(() => _ending = true);
        _timer?.cancel();
        _stopImageStream();
        await _camera?.dispose();
        _camera = null;
        await _finishSession(reps: count);
        if (!_navigatedToResult && mounted) {
          _navigatedToResult = true;
          Navigator.of(context).pushReplacementNamed(
            '/session_result',
            arguments: SessionResultArgs(
              exerciseKo: _exerciseKo,
              exerciseEn: _exerciseEn,
              reps: count,
              accuracy: _finalAccForResult(),
              sessionId: _lastSessionId,
              feedback: _finalFeedbackSummary(),
            ),
          );
        }
        return false;
      },
      child: Scaffold(
        body: Stack(
          children: [
            // ① 카메라 프리뷰 + 스켈레톤
            Positioned.fill(
              child: camReady
                  ? LayoutBuilder(
                      builder: (context, constraints) {
                        final pv = _camera!.value.previewSize!;
                        final rotation = _camera!.description.sensorOrientation;
                        final isRotated = rotation == 90 || rotation == 270;

                        final baseW = isRotated ? pv.height : pv.width;
                        final baseH = isRotated ? pv.width  : pv.height;

                        return FittedBox(
                          fit: BoxFit.cover,
                          clipBehavior: Clip.hardEdge,
                          child: SizedBox(
                            width: baseW,
                            height: baseH,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                CameraPreview(_camera!),
                                IgnorePointer(
                                  child: CustomPaint(
                                    painter: PosePainter(
                                      landmarks: _overlayLandmarks,
                                      imageSize: Size(
                                        _overlayImageSize.width,
                                        _overlayImageSize.height,
                                      ),
                                      statusText: '',
                                      mirror: _mirrorOverlay,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    )
                  : const Center(child: CircularProgressIndicator()),
            ),

            // ② 좌상단 패널
            Positioned(
              top: insets.top + 10,
              left: 10,
              child: _SimplePanel(
                exercise: _exerciseKo,
                reps: count,
                isCorrect: _localIsCorrect,
              ),
            ),

            // ②-1 타이머
            Positioned(
              top: insets.top + 10,
              right: 10,
              child: _TimerPill(text: _mmss),
            ),

            // ③ 실시간 코칭 + 시스템 상태(난잡함 방지된 코칭 문구)
            Positioned(
              bottom: insets.bottom + 120,
              left: 16,
              right: 16,
              child: Column(
                children: [
                  // 코칭(운동 피드백)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.80),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      coachTip,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 시스템 상태(서버/오류 등)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.65),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _ending ? "종료 중..." : feedbackMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14, color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),

            // ④ 연결 종료(현재 카운트로 저장) → 종료와 동일 순서로 처리
            Positioned(
              bottom: insets.bottom + 96,
              left: 0,
              right: 0,
              child: Center(
                child: TextButton(
                  onPressed: () async {
                    _awaitingFinish = true;
                    setState(() => _ending = true);
                    _timer?.cancel();
                    _stopImageStream();
                    await _camera?.dispose();
                    _camera = null;

                    final _ = await _finishSession(reps: count);
                    if (!_navigatedToResult && mounted) {
                      _navigatedToResult = true;
                      Navigator.of(context).pushReplacementNamed(
                        '/session_result',
                        arguments: SessionResultArgs(
                          exerciseKo: _exerciseKo,
                          exerciseEn: _exerciseEn,
                          reps: count,
                          accuracy: _finalAccForResult(),
                          sessionId: _lastSessionId,
                          feedback: _finalFeedbackSummary(),
                        ),
                      );
                    }
                  },
                  child: const Text("연결 종료", style: TextStyle(color: Colors.white)),
                ),
              ),
            ),

            // ⑤ 운동 종료 (ack 대기 → close await → 네비)
            Positioned(
              bottom: insets.bottom + 40,
              left: 0,
              right: 0,
              child: Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  ),
                  onPressed: () async {
                    _awaitingFinish = true;

                    setState(() => _ending = true);
                    _timer?.cancel();
                    _stopImageStream();
                    await _camera?.dispose();
                    _camera = null;

                    await markTodayAsExercised();

                    // ✅ ack 대기 + close 대기
                    final ok = await _finishSession(
                      reps: count,
                      ackTimeout: const Duration(milliseconds: 1500),
                    );

                    if (_navigatedToResult) return;

                    _navigatedToResult = true;

                    if (!mounted) return;
                    Navigator.of(context).pushReplacementNamed(
                      '/session_result',
                      arguments: SessionResultArgs(
                        exerciseKo: _exerciseKo,
                        exerciseEn: _exerciseEn,
                        reps: count,
                        accuracy: _finalAccForResult(),
                        sessionId: _lastSessionId,
                        feedback: _finalFeedbackSummary(),
                      ),
                    );
                  },
                  child: const Text("운동 종료", style: TextStyle(fontSize: 16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================== 위젯들 ==================

class _SimplePanel extends StatelessWidget {
  final String exercise;
  final int reps;
  final bool isCorrect;

  const _SimplePanel({
    required this.exercise,
    required this.reps,
    required this.isCorrect,
  });

  @override
  Widget build(BuildContext context) {
    final statusText = isCorrect ? "CORRECT" : "INCORRECT";
    final statusColor = isCorrect ? Colors.greenAccent : Colors.redAccent;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("EXERCISE: $exercise",
              style: const TextStyle(
                  color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          // ✅ REPS 크기 적당히(애니메이션 제거)
          Text(
            "REPS: $reps${exercise == '플랭크' ? 's' : ''}",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Text("AI STATUS: ",
                  style: TextStyle(color: Colors.white, fontSize: 14)),
              Text(statusText,
                  style: TextStyle(
                      color: statusColor, fontSize: 16, fontWeight: FontWeight.w900)),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimerPill extends StatelessWidget {
  final String text;
  const _TimerPill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.70),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          // 원래 코드 스타일을 유지 (tabular figures)
          fontFeatures: [ui.FontFeature.tabularFigures()],
          fontWeight: FontWeight.w800,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}
