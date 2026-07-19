import 'dart:async';

class SessionInvalidationNotifier {
  final StreamController<void> _controller = StreamController<void>.broadcast();

  Stream<void> get events => _controller.stream;

  void notifySessionInvalidated() {
    if (!_controller.isClosed) {
      _controller.add(null);
    }
  }

  Future<void> dispose() {
    return _controller.close();
  }
}
