class AppSettings {
  final String emergencyMessage;
  final int scrollSpeedMs;
  final int blinkIntervalMs;
  final int brightness;

  const AppSettings({
    required this.emergencyMessage,
    required this.scrollSpeedMs,
    required this.blinkIntervalMs,
    required this.brightness,
  });
}
