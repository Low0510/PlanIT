class HourlyForecast {
  final DateTime time;
  final double temperature;
  final String weather;
  final String description;
  final double precipitationProbability;
  final double uv;
  final double dewPoint;

  HourlyForecast({
    required this.time,
    required this.temperature,
    required this.weather,
    required this.description,
    required this.precipitationProbability,
    required this.uv,
    required this.dewPoint,
  });
}