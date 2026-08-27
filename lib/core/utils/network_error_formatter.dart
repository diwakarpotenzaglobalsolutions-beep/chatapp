class NetworkErrorFormatter {
  static bool isNetworkError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('socket') ||
        message.contains('network') ||
        message.contains('connection') ||
        message.contains('offline') ||
        message.contains('unavailable') ||
        message.contains('failed host lookup') ||
        message.contains('timed out') ||
        message.contains('timeout') ||
        message.contains('no address associated with hostname') ||
        message.contains('network-request-failed');
  }

  static String format(Object error) {
    if (isNetworkError(error)) {
      return 'No internet connection. Please check your network and try again.';
    }
    return error.toString().replaceAll('Exception: ', '');
  }
}
