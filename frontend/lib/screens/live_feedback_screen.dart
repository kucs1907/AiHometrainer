// lib/screens/live_feedback_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:io' show WebSocket;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';

// ML Kit
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

// 오버레이
import '../widgets/pose_painter.dart';

/// 네트워크 환경에 맞춰 변경
const String WS_URL = 'ws://192.168.219.105:8000/sessions/ws';

/// 운동명 매핑 (한글 ⇄ 영문)
const Map<String, String> ko2en = {
  '딥스': 'dips',
  '플랭크': 'plank',
  '턱걸이': 'pullup',
  '푸쉬업': 'pushup',
  '스쿼트': 'squat',
};
const Map<String, String> en2ko = {
  'dips': '딥스',
  'plank': '플랭크',
  'pullup': '턱걸이',
  'pushup': '푸쉬업',
  'squat': '스쿼트',
};

class LiveFeedbackScreen extends StatefulWidget {
  final List<String> selectedExercises;
  const LiveFeedbackScreen({super.key, required this.selectedExercises});

  @override
  State<LiveFeedbackScreen> createState() => _LiveFeedbackScreenState();
}

class _LiveFeedbackScreenState extends State<LiveFeedbackScreen>
    with SingleTickerProviderStateMixin {
  CameraController? _camera;
  late final PoseDetector _poseDetector;

  WebSocketChannel? _ws;
  bool _wsOpen = false;
  bool _wsAvailable = false;

  // 화면 상태
  String feedbackMessage = "서버로부터 피드백 대기 중...";
  String _label = '-';
  double _proba = 0.0;
  int count = 0;
  int _lastCount = 0;
  bool _ending = false;

  // 애니메이션 (카운트 증가 시)
  late final AnimationController _anim;
  late final Animation<double> _scaleAnim;

  // 현재 선택 운동 (표시는 한글, 서버 전송은 영문)
  late String _exerciseKo; // UI 표기용 (한글)
  late String _exerciseEn; // 서버 전송용 (영문 키)

  // 스트림 처리 제어
  bool _processing = false;
  int _sendIntervalMs = 120; // ~8fps
  int _lastSentMs = 0;

  // 오버레이 데이터
  List<PoseLandmark> _overlayLandmarks = const [];
  ui.Size _overlayImageSize = ui.Size.zero;
  bool _mirrorOverlay = false; // 전면 카메라면 true

  @override
  void initState() {
    super.initState();

    // SelectExerciseScreen에서 넘어온 첫 번째 선택(한글 제목)을 기준으로 표시/전송 분리
    _exerciseKo = widget.selectedExercises.isNotEmpty
        ? widget.selectedExercises.first
        : '스쿼트';
    _exerciseEn = ko2en[_exerciseKo] ?? _exerciseKo; // 매핑 실패시 원문 그대로

    _poseDetector = PoseDetector(
      options: PoseDetectorOptions(
        mode: PoseDetectionMode.stream,
        model: PoseDetectionModel.base,
      ),
    );

    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 1.5).animate(
      CurvedAnimation(parent: _anim, curve: Curves.easeInOut),
    );
    _anim.addStatusListener((s) {
      if (s == AnimationStatus.completed) _anim.reverse();
    });

    _initCamera().then((_) => _connectWsAndStart());
  }

  @override
  void dispose() {
    _stopImageStream();
    _camera?.dispose();
    _camera = null;

    _poseDetector.close();
    _finishSession();
    _anim.dispose();
    super.dispose();
  }

  // ===== 카메라 =====
  Future<void> _initCamera() async {
    try {
      final cams = await availableCameras();

      // 전면 카메라 우선
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
        imageFormatGroup: ImageFormatGroup.nv21, // NV21 고정
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

  // ===== WebSocket =====
  Future<void> _connectWsAndStart() async {
    try {
      final socket = await WebSocket.connect(WS_URL)
          .timeout(const Duration(milliseconds: 800));
      _ws = IOWebSocketChannel(socket);
      _wsAvailable = true;

      // start: 서버 전송은 영문 키 사용
      _ws!.sink.add(jsonEncode({
        "type": "start",
        "user_id": "u-1", // 실제 로그인 사용자 ID로 교체 가능
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
              final newCount = (data["count"] as num).toInt();
              final lbl = data["label"];
              _safeSet(() {
                feedbackMessage = "피드백 수신 중";
                if (lbl is String) {
                  // 서버 라벨이 영문이면 한글로 매핑해서 표시
                  _label = en2ko[lbl] ?? lbl;
                } else {
                  _label = '-';
                }
                _proba = (data["proba"] as num?)?.toDouble() ?? 0.0;
                count = newCount;
              });
              if (newCount > _lastCount) {
                _lastCount = newCount;
                _anim.forward(from: 0.0);
              }
              break;
            case "finished":
              _safeSet(() => feedbackMessage = "세션 종료");
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
      }, onError: (e) {
        _wsOpen = false;
        _safeSet(() => feedbackMessage = "연결 에러: $e");
      });

      _safeSet(() {}); // 상태 갱신
    } catch (_) {
      _wsAvailable = false;
      _wsOpen = false;
      _ws = null;
      _safeSet(() => feedbackMessage = "오프라인(서버 미연결)");
    }
  }

  Future<void> _finishSession({
    Duration timeout = const Duration(milliseconds: 300),
  }) async {
    final ch = _ws;
    _ws = null;
    _wsOpen = false;
    if (ch == null) return;

    try {
      try {
        ch.sink.add(jsonEncode({"type": "finish"}));
      } catch (_) {}
      try {
        await ch.sink.close().timeout(timeout);
      } catch (_) {}
    } finally {}
  }

  // ===== 카메라 프레임 처리 =====
  Future<void> _onCameraImage(CameraImage image) async {
    if (!mounted || _processing || _ending) return;

    // 전송 간격 제한
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs - _lastSentMs < _sendIntervalMs) return;
    _lastSentMs = nowMs;

    _processing = true;
    try {
      final cam = _camera;
      if (cam == null || !cam.value.isInitialized) return;

      final input = _toInputImage(image, cam.description);

      // ML Kit 추론
      final poses = await _poseDetector.processImage(input);
      if (poses.isEmpty) {
        _overlayLandmarks = const [];
        if (mounted) setState(() {});
        return;
      }

      final pose = poses.first;

      // 오버레이용 해상도(회전 보정) + 랜드마크 저장
      final rotation = cam.description.sensorOrientation;
      final isRotated = rotation == 90 || rotation == 270;
      _overlayImageSize = isRotated
          ? ui.Size(image.height.toDouble(), image.width.toDouble())
          : ui.Size(image.width.toDouble(), image.height.toDouble());
      _overlayLandmarks = pose.landmarks.values.toList(growable: false);
      if (mounted) setState(() {}); // 오버레이 갱신

      // 서버 전송용 COCO 17 포맷
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
    } catch (e) {
      _safeSet(() => feedbackMessage = "추론 오류: $e");
    } finally {
      _processing = false;
    }
  }

  // === 포맷 맞추기: NV21 고정 + YUV420 → NV21 폴백 ===
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

    // Y plane copy
    final yPlane = image.planes[0];
    int o = 0;
    for (int r = 0; r < height; r++) {
      final start = r * yPlane.bytesPerRow;
      out.setRange(o, o + width, yPlane.bytes.sublist(start, start + width));
      o += width;
    }

    // interleaved VU (NV21)
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
        out[o++] = v.bytes[vIdx]; // V
        out[o++] = u.bytes[uIdx]; // U
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

      // 오버레이는 mirror 처리했고, 서버엔 원본 정규화 좌표를 보냄
      // 필요 시: if (isFrontCamera) x = 1.0 - x;

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
        list.map((m) => m["score"] ?? 0.0).fold<double>(0.0, (a, b) => a + b) /
            list.length;
    if (avgScore < 0.2) return const [];

    return list;
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

  @override
  Widget build(BuildContext context) {
    final camReady = !_ending && _camera != null && _camera!.value.isInitialized;
    final insets = MediaQuery.of(context).padding; // 안전영역(상/하단)

    return Scaffold(
      body: Stack(
        children: [
          // ====== ① 카메라 프리뷰 + 스켈레톤 (화면 가득 채우기) ======
          Positioned.fill(
            child: camReady
                ? LayoutBuilder(
                    builder: (context, constraints) {
                      final pv = _camera!.value.previewSize!;
                      final rotation = _camera!.description.sensorOrientation;
                      final isRotated = rotation == 90 || rotation == 270;

                      // 베이스 박스(카메라 원본 프리뷰 크기, 회전 보정)
                      final baseW = isRotated ? pv.height : pv.width;
                      final baseH = isRotated ? pv.width  : pv.height;

                      return FittedBox(
                        fit: BoxFit.cover, // ← 화면 가득
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
                                    statusText: '', // ← 오버레이 텍스트 제거(겹침 방지)
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

          // ====== ② 우상단 상태 배지 (운동/카운트/라벨/확률) ======
          Positioned(
            top: insets.top + 10,
            right: 10,
            child: _StatusBadge(
              title: '$_exerciseKo · ${count}회',
              subtitle1: '라벨: $_label',
              subtitle2: '확률: ${_proba.toStringAsFixed(2)}',
            ),
          ),

          // ====== ③ 상태 메시지 ======
          Positioned(
            bottom: insets.bottom + 100,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _ending ? "종료 중..." : feedbackMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
          ),

          // ====== ④ 연결 종료 버튼 (홈 제스처 영역 피해 위로) ======
          Positioned(
            bottom: insets.bottom + 96,
            left: 0,
            right: 0,
            child: Center(
              child: TextButton(
                onPressed: () async {
                  await _finishSession();
                  if (mounted) setState(() => feedbackMessage = "연결 종료");
                },
                child: const Text("연결 종료", style: TextStyle(color: Colors.white)),
              ),
            ),
          ),

          // ====== ⑤ 운동 종료 버튼 ======
          Positioned(
            bottom: insets.bottom + 40,
            left: 0,
            right: 0,
            child: Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
                onPressed: () async {
                  setState(() => _ending = true);
                  _stopImageStream();
                  await _camera?.dispose();
                  _camera = null;
                  await markTodayAsExercised();
                  await _finishSession().timeout(
                    const Duration(milliseconds: 350),
                    onTimeout: () {},
                  );
                  if (!mounted) return;
                  Navigator.pop(context);
                },
                child: const Text("운동 종료", style: TextStyle(fontSize: 16)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================== 위젯들 ==================

class _StatusBadge extends StatelessWidget {
  final String title;
  final String subtitle1;
  final String subtitle2;

  const _StatusBadge({
    required this.title,
    required this.subtitle1,
    required this.subtitle2,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(subtitle1,
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
          Text(subtitle2,
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  const _Badge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white)),
    );
  }
}
