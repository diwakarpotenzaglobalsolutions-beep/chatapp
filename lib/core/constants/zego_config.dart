
class ZegoConfig {
  ZegoConfig._();

  static const int appId = 1520177485;

  static const String appSign =
      '1653e97cdd60956005e7f593f3f10d9ff2a6e57484230e1d09097dd483e5eacd';

  static const int callTimeoutSeconds = 60;
  static const String resourceId = 'zegouikit_call';

  static bool get isConfigured => appId != 0 && appSign.isNotEmpty;
}
