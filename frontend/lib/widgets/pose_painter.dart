// lib/widgets/pose_painter.dart
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// 카메라 프리뷰 위에 그려지는 스켈레톤 오버레이.
/// - mirror=true면 선/점만 좌우 반전, 텍스트는 정상 방향.
class PosePainter extends CustomPainter {
  final List<PoseLandmark> landmarks; // ML Kit 좌표(원본 이미지 기준)
  final Size imageSize;               // 원본 이미지 해상도 (w,h)
  final String statusText;            // 예: "squat • 3회 • up"
  final bool mirror;                  // 전면 카메라 정렬용

  PosePainter({
    required this.landmarks,
    required this.imageSize,
    this.statusText = '',
    this.mirror = false,
  });

  static const List<(PoseLandmarkType, PoseLandmarkType)> _edges = [
    (PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder),
    (PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip),
    (PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip),
    (PoseLandmarkType.leftHip, PoseLandmarkType.rightHip),
    (PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow),
    (PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist),
    (PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow),
    (PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist),
    (PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee),
    (PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle),
    (PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee),
    (PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (landmarks.isEmpty || imageSize.width == 0 || imageSize.height == 0) {
      return;
    }

    final scale = _coverScale(imageSize, size);
    final dx = (size.width - imageSize.width * scale) / 2;
    final dy = (size.height - imageSize.height * scale) / 2;

    void drawSkeleton() {
      final line = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Colors.white.withOpacity(0.9);
      final dot = Paint()
        ..style = PaintingStyle.fill
        ..color = Colors.lightBlueAccent.withOpacity(0.9);

      final byType = {for (final l in landmarks) l.type: l};
      Offset mapPt(PoseLandmark l) =>
          Offset(l.x.toDouble() * scale + dx, l.y.toDouble() * scale + dy);

      for (final (a, b) in _edges) {
        final la = byType[a], lb = byType[b];
        if (la == null || lb == null) continue;
        canvas.drawLine(mapPt(la), mapPt(lb), line);
      }
      for (final l in landmarks) {
        canvas.drawCircle(mapPt(l), 4, dot);
      }
    }

    // 선/점만 좌우 반전
    if (mirror) {
      canvas.save();
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
      drawSkeleton();
      canvas.restore();
    } else {
      drawSkeleton();
    }

    // 텍스트는 정상 방향
    if (statusText.isNotEmpty) {
      final tp = TextPainter(
        text: TextSpan(
          text: statusText,
          style: const TextStyle(fontSize: 16, color: Colors.white),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width - 24);

      final bg = Paint()..color = Colors.black.withOpacity(0.45);
      final rect = Rect.fromLTWH(10, 10, tp.width + 14, tp.height + 12);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(8)),
        bg,
      );
      tp.paint(canvas, const Offset(17, 15));
    }
  }

  double _coverScale(Size src, Size dst) {
    final sx = dst.width / src.width;
    final sy = dst.height / src.height;
    return sx > sy ? sx : sy;
  }

  @override
  bool shouldRepaint(covariant PosePainter old) =>
      old.landmarks != landmarks ||
      old.imageSize != imageSize ||
      old.statusText != statusText ||
      old.mirror != mirror;
}
