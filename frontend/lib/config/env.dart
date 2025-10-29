// lib/config/env.dart
class Env {
  /// REST API 베이스 URL
  /// http://3.36.181.144 
  static const restBase = String.fromEnvironment(
    'REST_BASE',
    defaultValue: 'http://3.36.181.144',
  );

  /// WebSocket URL (풀 URL)
  /// 예) ws://3.36.181.144/sessions/ws 
  static const wsUrl = String.fromEnvironment(
    'WS_URL',
    defaultValue: 'ws://3.36.181.144/sessions/ws',
  );
}
