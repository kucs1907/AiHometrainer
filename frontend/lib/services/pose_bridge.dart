class PoseBridge {
  /// Convert your detector output to 17 {x,y,score} keypoints.
  static List<Map<String,double>> to17(List<Map<String,double>> landmarks33) {
    final kp = <Map<String,double>>[];
    for (int i=0; i<17 && i<landmarks33.length; i++) {
      kp.add({
        "x": landmarks33[i]["x"] ?? 0.0,
        "y": landmarks33[i]["y"] ?? 0.0,
        "score": landmarks33[i]["score"] ?? 1.0,
      });
    }
    return kp;
  }
}
