import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  Future<bool> isMicrophoneGranted() async {
    return Permission.microphone.isGranted;
  }

  Future<bool> isCameraGranted() async {
    return Permission.camera.isGranted;
  }

  Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  /// Request permissions needed for a call. Returns false if denied.
  Future<bool> requestCallPermissions({required bool isVideo}) async {
    final micGranted = await requestMicrophonePermission();
    if (!micGranted) return false;

    if (isVideo) {
      final cameraGranted = await requestCameraPermission();
      if (!cameraGranted) return false;
    }

    return true;
  }

  Future<bool> openSettings() => openAppSettings();
}
