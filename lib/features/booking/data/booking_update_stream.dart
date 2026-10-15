import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/network/api_client.dart';

class BookingUpdateStream {
  BookingUpdateStream({WebSocketChannel Function(Uri)? connect})
    : _connectChannel = connect ?? WebSocketChannel.connect;

  static final BookingUpdateStream instance = BookingUpdateStream();
  final WebSocketChannel Function(Uri) _connectChannel;
  final _controller = StreamController<Map<String, dynamic>>.broadcast();
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;
  String? _token;
  bool _isStarted = false;

  Stream<Map<String, dynamic>> get stream => _controller.stream;

  void start() {
    final token = ApiClient.authToken;
    if (token == null || token.isEmpty) {
      stop();
      return;
    }
    if (_isStarted && _token == token) return;
    stop();
    _token = token;
    _isStarted = true;
    _connect();
  }

  void updateSession() {
    if (_isStarted) start();
  }

  void stop() {
    _isStarted = false;
    _token = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    final previous = _channel;
    _channel = null;
    _subscription?.cancel();
    _subscription = null;
    previous?.sink.close();
  }

  void _connect() {
    if (!_isStarted || _channel != null) return;
    final token = _token;
    if (token == null || token != ApiClient.authToken) {
      stop();
      return;
    }
    const socketUrl = String.fromEnvironment(
      'WS_BASE_URL',
      defaultValue: 'wss://api.hothaircc.cn/ws',
    );
    try {
      final channel = _connectChannel(Uri.parse(socketUrl));
      _channel = channel;
      _subscription = channel.stream.listen(
        (message) {
          if (_channel != channel ||
              _token != token ||
              ApiClient.authToken != token ||
              message is! String) {
            return;
          }
          try {
            final decoded = jsonDecode(message);
            if (decoded is! Map<String, dynamic>) return;
            if (decoded['event'] == 'auth.required') {
              channel.sink.add(
                jsonEncode({
                  'event': 'authenticate',
                  'role': 'merchant',
                  'token': token,
                }),
              );
            } else {
              _controller.add(decoded);
            }
          } catch (_) {
            // Ignore malformed server messages.
          }
        },
        onDone: () => _scheduleReconnect(channel),
        onError: (_) => _scheduleReconnect(channel),
        cancelOnError: true,
      );
    } catch (_) {
      _scheduleReconnect(null);
    }
  }

  void _scheduleReconnect(WebSocketChannel? channel) {
    if (channel != _channel) return;
    _channel = null;
    _subscription?.cancel();
    _subscription = null;
    channel?.sink.close();
    if (!_isStarted || _reconnectTimer?.isActive == true) return;
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      _reconnectTimer = null;
      _connect();
    });
  }
}
