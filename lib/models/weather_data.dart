
import 'package:planit_schedule_manager/models/hourly_forecast.dart';

class WeatherData {
  final String locationName;
  final double temperature;
  final String weather;
  final String description;
  final DateTime? sunrise;
  final DateTime? sunset;
  final int humidity;
  final double windSpeed;
  final double dewPoint; 
  final double uvi;     
  final List<HourlyForecast> hourlyForecast;

  WeatherData({
    required this.locationName,
    required this.temperature,
    required this.weather,
    required this.description,
    this.sunrise,
    this.sunset,
    required this.humidity,
    required this.windSpeed,
    required this.dewPoint,
    required this.uvi,
    required this.hourlyForecast,
  });
}