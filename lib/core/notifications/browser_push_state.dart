/// Public browser capability only. Tokens and account identifiers never belong
/// in presentation state or diagnostic messages.
class BrowserPushEnvironment {
  const BrowserPushEnvironment({
    required this.supported,
    required this.configured,
    required this.permission,
    required this.message,
  });

  final bool supported;
  final bool configured;
  final String permission;
  final String message;
  bool get canEnable => supported && configured && permission != 'denied';
}

class BrowserPushState {
  const BrowserPushState({
    required this.environment,
    required this.enabled,
    required this.registered,
  });

  final BrowserPushEnvironment environment;
  final bool enabled;
  final bool registered;
  bool get active => enabled && registered && environment.permission == 'granted';
}
