import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class ExerciseWsClient {
  final String wsUrl;
  WebSocketChannel? _ch;

  ExerciseWsClient(this.wsUrl);

  void start(String userId, String exercise) {
    _ch = WebSocketChannel.connect(Uri.parse(wsUrl));
    _ch!.sink.add(jsonEncode({"type":"start","user_id":userId,"exercise":exercise}));
  }

  void sendFrame(List<Map<String, double>> keypoints) {
    if (_ch == null) return;
    _ch!.sink.add(jsonEncode({"type":"frame","keypoints": keypoints}));
  }

  Stream<dynamic>? get stream => _ch?.stream;

  Future<void> finish() async {
    if (_ch == null) return;
    _ch!.sink.add(jsonEncode({"type":"finish"}));
    await Future.delayed(Duration(milliseconds: 200));
    await _ch!.sink.close();
  }
}
