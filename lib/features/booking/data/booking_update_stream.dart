import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

class BookingUpdateStream {
  BookingUpdateStream._();

  static final BookingUpdateStream instance = BookingUpdateStream._();

  final StreamController<Map<String, dynamic>> _controller =
      StreamController<Map<String, dynamic>>.broadcast();

  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  bool _isConnecting = false;
  bool _isStarted = false;

  Stream<Map<String, dynamic>> get stream => _controller.stream;

  void start() {
    if (_isStarted) return;
    _isStarted = true;
    _connect();
  }

  void _connect() {
    if (_isConnecting || _channel != null) return;

    _isConnecting = true;
    try {
      final channel = WebSocketChannel.connect(
        Uri.parse('ws://localhost:3000/ws'),
      );
      _channel = channel;
      _isConnecting = false;

      channel.stream.listen(
        _handleMessage,
        onDone: _scheduleReconnect,
        onError: (_) => _scheduleReconnect(),
        cancelOnError: true,
      );
    } catch (_) {
      _isConnecting = false;
      _scheduleReconnect();
    }
  }

  void _handleMessage(dynamic message) {
    if (message is! String) return;

    try {
      final decoded = jsonDecode(message);
      if (decoded is Map<String, dynamic>) {
        _controller.add(decoded);
      }
    } catch (_) {
      // Ignore malformed socket messages from development servers.
    }
  }

  void _scheduleReconnect() {
    _channel = null;
    if (!_isStarted || _reconnectTimer?.isActive == true) return;

    _reconnectTimer = Timer(const Duration(seconds: 3), _connect);
  }
}
