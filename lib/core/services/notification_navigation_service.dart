import 'dart:async';

class NotificationNavigationService {
  NotificationNavigationService._();
  static final NotificationNavigationService instance =
      NotificationNavigationService._();

  final _controller = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onNavigate => _controller.stream;

  void navigate(Map<String, dynamic> data) {
    if (!_controller.isClosed) {
      _controller.add(data);
    }
  }

  void dispose() {
    _controller.close();
  }
}
