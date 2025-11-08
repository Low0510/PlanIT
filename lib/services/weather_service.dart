import 'dart:math';

import 'package:planit_schedule_manager/models/hourly_forecast.dart';
import 'package:planit_schedule_manager/models/weather_data.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Singleton Weather Service
class WeatherService {
  static WeatherService? _instance;
  
  final String apiKey;
  final String baseUrl = 'https://api.openweathermap.org/data/3.0/onecall';
  final String geoUrl = 'http://api.openweathermap.org/geo/1.0/reverse';
  
  // Cache duration in minutes
  final int cacheDurationInMinutes;
  
  // Counters for API calls and cache usage
  int _apiCallCount = 0;
  int _cacheHitCount = 0;
  int _cacheMissCount = 0;
  
  // Getter methods for the counters
  int get apiCallCount => _apiCallCount;
  int get cacheHitCount => _cacheHitCount;
  int get cacheMissCount => _cacheMissCount;
  
  // Factory constructor to return the singleton instance
  factory WeatherService.getInstance(String apiKey, {int cacheDurationInMinutes = 60}) {
    // If the instance doesn't exist, create it
    _instance ??= WeatherService._internal(apiKey, cacheDurationInMinutes: cacheDurationInMinutes);
    return _instance!;
  }
  
  // Private constructor
  WeatherService._internal(this.apiKey, {this.cacheDurationInMinutes = 60});

  // Print current stats
  void printStats() {
    print('Weather Service Stats:');
    print('API calls: $_apiCallCount');
    print('Cache hits: $_cacheHitCount');
    print('Cache misses: $_cacheMissCount');
  }

  // Reset counters
  void resetStats() {
    _apiCallCount = 0;
    _cacheHitCount = 0;
    _cacheMissCount = 0;
    print('Weather Service stats reset.');
  }

  Future<WeatherData> getWeather(double lat, double lon) async {
    try {
      // Check if we have cached data first
      final cachedData = await _getCachedWeatherData(lat, lon);
      if (cachedData != null) {
        _cacheHitCount++;
        print('WEATHER: Using cached data for $lat, $lon');
        return cachedData;
      }
      
      _cacheMissCount++;
      print('WEATHER: Cache miss for $lat, $lon - fetching from API');
      
      // If no cache or cache expired, fetch new data
      _apiCallCount++;
      final weatherResponse = await _fetchWeatherData(lat, lon);
      final locationResponse = await _fetchLocationData(lat, lon);
      
      final weatherData = _parseWeatherData(weatherResponse, locationResponse);
      
      // Save to cache
      await _cacheWeatherData(lat, lon, weatherData, weatherResponse);
      
      return weatherData;
    } catch (e) {
      print('WEATHER: Error getting weather: $e');
      // Try to return cached data even if expired in case of API failure
      try {
        final cachedData = await _getCachedWeatherData(lat, lon, ignoreExpiry: true);
        if (cachedData != null) {
          print('WEATHER: Using expired cache due to API failure');
          return cachedData;
        }
      } catch (_) {
        // If even getting cached data fails, we'll throw the original exception
        print('WEATHER: Failed to get expired cache data as fallback');
      }
      
      throw WeatherException('Failed to fetch weather data: $e');
    }
  }

  Future<WeatherData?> _getCachedWeatherData(double lat, double lon, {bool ignoreExpiry = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = _getCacheKey(lat, lon);
    
    final cachedDataString = prefs.getString(cacheKey);
    if (cachedDataString == null) {
      print('WEATHER: No cache data found for $lat, $lon');
      return null;
    }
    
    final cachedMap = json.decode(cachedDataString);
    final timestamp = cachedMap['timestamp'] as int?;
    
    // Check if cache is expired
    if (!ignoreExpiry && timestamp != null) {
      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final now = DateTime.now();
      final difference = now.difference(cacheTime).inMinutes;
      
      if (difference > cacheDurationInMinutes) {
        print('WEATHER: Cache expired for $lat, $lon (${difference}m old)');
        return null; // Cache expired
      }
      
      print('WEATHER: Valid cache for $lat, $lon (${difference}m old)');
    }
    
    try {
      final weatherData = cachedMap['weatherData'];
      final locationName = cachedMap['locationName'] as String;
      
      return _parseWeatherData(weatherData, locationName);
    } catch (e) {
      print('WEATHER: Error parsing cached data: $e');
      return null; // Invalid cache data
    }
  }

  Future<void> _cacheWeatherData(double lat, double lon, WeatherData weatherData, Map<String, dynamic> rawData) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = _getCacheKey(lat, lon);
    
    final cacheData = {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'weatherData': rawData,
      'locationName': weatherData.locationName
    };
    
    await prefs.setString(cacheKey, json.encode(cacheData));
    print('WEATHER: Saved new data to cache for $lat, $lon');
  }

  String _getCacheKey(double lat, double lon) {
    // Round to 4 decimal places for reasonable location precision
    return 'weather_cache_${lat.toStringAsFixed(1)}_${lon.toStringAsFixed(1)}';
  }

  Future<Map<String, dynamic>> _fetchWeatherData(double lat, double lon) async {
    final url = '$baseUrl?lat=$lat&lon=$lon&appid=$apiKey';
    print('WEATHER: Fetching data from weather API for $lat, $lon');
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      print('WEATHER: Weather API call successful');
      return json.decode(response.body);
    } else {
      print('WEATHER: API error (${response.statusCode})');
      throw WeatherException('Weather API returned ${response.statusCode}');
    }
  }

  Future<String> _fetchLocationData(double lat, double lon) async {
    final url = '$geoUrl?lat=$lat&lon=$lon&appid=$apiKey';
    print('WEATHER: Fetching location data from API for $lat, $lon');
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      print('WEATHER: Location API call successful');
      final List<dynamic> locations = json.decode(response.body);
      if (locations.isNotEmpty) {
        return locations.first['name'] ?? 'Unknown Location';
      }
      return 'Unknown Location';
    } else {
      print('WEATHER: Location API error (${response.statusCode})');
      throw WeatherException('Geocoding API returned ${response.statusCode}');
    }
  }

  WeatherData _parseWeatherData(Map<String, dynamic> weatherData, String locationName) {
    final current = weatherData['current'];
    final List<dynamic> hourly = weatherData['hourly'] ?? [];

    return WeatherData(
      locationName: locationName,
      temperature: _kelvinToCelsius(current['temp']),
      weather: current['weather']?[0]?['main'] ?? '',
      description: current['weather']?[0]?['description'] ?? '',
      sunrise: _timestampToDateTime(current['sunrise']),
      sunset: _timestampToDateTime(current['sunset']),
      humidity: _parseIntValue(current['humidity']),
      windSpeed: _parseDoubleValue(current['wind_speed']),
      dewPoint: _kelvinToCelsius(current['dew_point']),
      uvi: _parseDoubleValue(current['uvi']),
      hourlyForecast: _parseHourlyForecast(hourly),
    );
  }

  List<HourlyForecast> _parseHourlyForecast(List<dynamic> hourlyData) {
    return hourlyData.take(24).map((hour) {
      return HourlyForecast(
        time: _timestampToDateTime(hour['dt'])!,
        temperature: _kelvinToCelsius(hour['temp']),
        weather: hour['weather']?[0]?['main'] ?? '',
        description: hour['weather']?[0]?['description'] ?? '',
        precipitationProbability: _parseDoubleValue(hour['pop']) * 100,
        uv: _parseDoubleValue(hour['uvi']),
        dewPoint: _kelvinToCelsius(hour['dew_point']),
      );
    }).toList();
  }

  String getWeatherReminder(WeatherData weatherData) {
    final String weatherCondition = weatherData.weather.toLowerCase();
    final random = Random();
    
    if (weatherCondition.contains('rain')) {
      final rainAdvice = [
        '🌧️ Don\'t forget your umbrella today! It looks like rain.',
        '☔ Rainy day ahead! Keep your umbrella handy.',
        '🌦️ Bring an umbrella - rain is coming your way!',
        '💧 Pack your raincoat! Wet weather expected.',
        '☔ Stay dry today - rain is in the forecast!',
        '🌧️ Umbrella weather! Don\'t get caught in the rain.',
      ];
      return rainAdvice[random.nextInt(rainAdvice.length)];
    } 
    
    else if (weatherCondition.contains('thunderstorm')) {
      final stormAdvice = [
        '⛈️ Stormy weather ahead! Stay safe and plan accordingly.',
        '🌩️ Thunder and lightning expected - stay indoors if possible!',
        '⚡ Rough weather coming! Be extra careful out there.',
        '🌪️ Storm alert! Keep safe and avoid outdoor activities.',
        '⛈️ Wild weather ahead - better stay cozy inside!',
        '🌩️ Thunderstorm warning! Plan indoor activities today.',
      ];
      return stormAdvice[random.nextInt(stormAdvice.length)];
    } 
    
    else if (weatherCondition.contains('snow')) {
      final snowAdvice = [
        '❄️ Snowy day! Dress warmly and take extra care when traveling.',
        '🌨️ Snow is falling! Bundle up and drive carefully.',
        '⛄ Winter weather alert! Wear layers and watch your step.',
        '❄️ Snowflakes are coming! Time for warm clothes and hot cocoa.',
        '🌨️ Snowy conditions ahead - take it slow and stay warm!',
        '⛷️ Snow day vibes! Dress warm and enjoy the winter wonderland.',
      ];
      return snowAdvice[random.nextInt(snowAdvice.length)];
    } 
    
    else if (weatherCondition.contains('clear')) {
      final clearAdvice = [
        '☀️ Beautiful clear skies today - perfect for outdoor activities!',
        '🌞 Sunny and bright! Great day to be outside.',
        '☀️ Crystal clear skies! Perfect weather for adventures.',
        '🌤️ Gorgeous day ahead! Don\'t waste it indoors.',
        '☀️ Sunshine all day! Time to soak up some vitamin D.',
        '🌞 Clear and lovely! Perfect day for a walk or picnic.',
      ];
      return clearAdvice[random.nextInt(clearAdvice.length)];
    } 
    
    else if (weatherCondition.contains('cloud')) {
      final cloudyAdvice = [
        '☁️ Cloudy day ahead. Layer up just in case!',
        '🌫️ Overcast skies today - bring a light jacket.',
        '☁️ Gray day ahead! Perfect weather for cozy indoor activities.',
        '🌥️ Cloudy but comfortable! Good day for any activity.',
        '☁️ Clouds rolling in - dress in layers to be ready.',
        '🌫️ Misty day ahead! Great for a peaceful walk.',
      ];
      return cloudyAdvice[random.nextInt(cloudyAdvice.length)];
    }
    
    // Default messages for unclear or mixed weather
    final defaultAdvice = [
      '🌈 Enjoy your day, whatever the weather!',
      '🌤️ Have a great day ahead!',
      '🌟 Make the most of today!',
      '😊 Wishing you a wonderful day!',
      '🌻 Hope you have an amazing day!',
      '✨ Whatever the weather, make it count!',
    ];
    return defaultAdvice[random.nextInt(defaultAdvice.length)];
  }

  // Force refresh weather data, ignoring cache
  Future<WeatherData> refreshWeather(double lat, double lon) async {
    print('WEATHER: Forcing refresh for $lat, $lon');
    _apiCallCount++;
    
    final weatherResponse = await _fetchWeatherData(lat, lon);
    final locationResponse = await _fetchLocationData(lat, lon);
    
    final weatherData = _parseWeatherData(weatherResponse, locationResponse);
    
    // Update cache with fresh data
    await _cacheWeatherData(lat, lon, weatherData, weatherResponse);
    
    return weatherData;
  }

  double _kelvinToCelsius(dynamic kelvin) {
    if (kelvin == null) return 0.0;
    return (kelvin is int ? kelvin.toDouble() : kelvin as double) - 273.15;
  }

  DateTime? _timestampToDateTime(dynamic timestamp) {
    if (timestamp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch((timestamp is double ? timestamp.toInt() : timestamp as int) * 1000);
  }

  int _parseIntValue(dynamic value) {
    if (value == null) return 0;
    return value is double ? value.toInt() : value as int;
  }

  double _parseDoubleValue(dynamic value) {
    if (value == null) return 0.0;
    return value is int ? value.toDouble() : value as double;
  }
}

class WeatherException implements Exception {
  final String message;
  WeatherException(this.message);

  @override
  String toString() => message;
}