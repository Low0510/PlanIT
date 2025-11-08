import 'dart:ui';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:planit_schedule_manager/models/hourly_forecast.dart';
import 'package:planit_schedule_manager/models/task.dart';
import 'package:planit_schedule_manager/models/weather_data.dart';

// Enums for weather and task classifications
enum WeatherSeverity {
  severe,
  moderate,
  mild,
  good
}

enum WeatherImpact {
  none,
  low,
  medium,
  high,
}

enum TaskCategory {
  outdoor,
  indoor,
  sports,
  travel,
  work,
  leisure
}

class WeatherUtils {
  // Constants for weather thresholds
  static const double _extremeHotTemp = 40.0;
  static const double _veryHotTemp = 35.0; 
  static const double _hotTemp = 32.0;
  static const double _coldTemp = 5.0;
  static const double _veryColdTemp = 0.0; 
  static const double _freezingTemp = -5.0;    
  
  // Precipitation thresholds 
  static const double _heavyPrecipitation = 90.0;
  static const double _highPrecipitation = 75.0;  
  static const double _moderatePrecipitation = 50.0;
  static const double _lightPrecipitation = 25.0; 
  
  static const double _extremeUV = 9.0;
  static const double _highUV = 6.0;
  static const double _moderateUV = 3.0;
  
  static const double _veryHumidDewPoint = 26.0;
  static const double _humidDewPoint = 22.0;      
  static const double _moderateHumidDewPoint = 18.0; 

  /// Returns the appropriate weather icon path based on weather type and time of day
  static String getWeatherIcon(String weatherType, {
    DateTime? sunrise,
    DateTime? sunset,
    DateTime? currentTime,
  }) {
    final now = currentTime ?? DateTime.now();
    bool isDay = _isDayTime(now, sunrise, sunset);

    switch (weatherType.toLowerCase().trim()) {
      case 'clear':
      case 'sunny':
        return isDay ? 'assets/weather_icons/day.svg' : 'assets/weather_icons/night.svg';
      case 'clouds':
      case 'cloudy':
      case 'overcast':
        return isDay ? 'assets/weather_icons/cloud_day.svg' : 'assets/weather_icons/cloud_night.svg';
      case 'rain':
      case 'light rain':
      case 'moderate rain':
      case 'heavy rain':
      case 'drizzle':
        return 'assets/weather_icons/rain.svg';
      case 'thunderstorm':
      case 'storm':
        return 'assets/weather_icons/thunderstorm.svg';
      case 'snow':
      case 'light snow':
      case 'heavy snow':
        return 'assets/weather_icons/snow.svg';
      case 'fog':
      case 'mist':
        return 'assets/weather_icons/ .svg';
      default:
        return 'assets/weather_icons/cloud.svg';
    }
  }

  /// Helper method to determine if it's day time
  static bool _isDayTime(DateTime time, DateTime? sunrise, DateTime? sunset) {
    if (sunrise != null && sunset != null) {
      return time.isAfter(sunrise) && time.isBefore(sunset);
    }
    // Fallback to general day hours
    return time.hour >= 6 && time.hour < 18;
  }

  /// Gets the forecast for a specific task time with improved matching
  static HourlyForecast? getTaskTimeWeather(Task task, WeatherData weatherData) {
    if (weatherData.hourlyForecast.isEmpty) {
      print('Warning: No hourly forecast data available for task: ${task.title}');
      return null;
    }
    
    // Find forecasts within a reasonable time window (±2 hours)
    final taskTime = task.time;
    final maxTimeDifference = Duration(hours: 2);
    
    final candidateForecasts = weatherData.hourlyForecast.where((forecast) {
      final timeDiff = (forecast.time.difference(taskTime)).abs();
      return timeDiff <= maxTimeDifference;
    }).toList();
    
    if (candidateForecasts.isEmpty) {
      // If no close matches, find the closest available forecast
      final closestForecast = weatherData.hourlyForecast.reduce((a, b) {
        final aDiff = (a.time.difference(taskTime)).abs();
        final bDiff = (b.time.difference(taskTime)).abs();
        return aDiff < bDiff ? a : b;
      });
      
      print('Using closest available forecast for ${task.title}: ${closestForecast.time} (${(closestForecast.time.difference(taskTime)).inHours}h difference)');
      return closestForecast;
    }
    
    // Return the closest forecast from candidates
    final bestMatch = candidateForecasts.reduce((a, b) {
      final aDiff = (a.time.difference(taskTime)).abs();
      final bDiff = (b.time.difference(taskTime)).abs();
      return aDiff < bDiff ? a : b;
    });
    
    print('Found weather forecast for ${task.title} at ${bestMatch.time}');
    print('Conditions: ${bestMatch.weather}, ${bestMatch.temperature}°C, ${bestMatch.precipitationProbability}% rain chance');
    
    return bestMatch;
  }

  /// Detects the category of a task based on its title with improved patterns
  static TaskCategory detectTaskCategory(Task task) {
    
   final title = task.title.toLowerCase().trim();
    
    // Include subtask titles for more comprehensive categorization
    final subtaskTitles = task.subtasks?.map((subtask) => subtask.title.toLowerCase().trim()).join(' ') ?? '';
    final searchText = subtaskTitles.isNotEmpty 
        ? '$title $subtaskTitles'
        : title;

    final patterns = {
      TaskCategory.sports: RegExp(
          r'\b(badminton|tennis|basketball|soccer|football|rugby|cricket|volleyball|sports?|game|match|training|practice|workout|gym|fitness|exercise|running|jogging|cycling|swimming|yoga|pilates)\b'),
      TaskCategory.outdoor: RegExp(
          r'\b(walk|hike|hiking|trekking|outdoor|garden|gardening|yard|park|picnic|adventure|camping|nature|fishing|hunting|safari|beach|mountain|forest)\b'),
      TaskCategory.travel: RegExp(
          r'\b(drive|driving|commute|commuting|travel|traveling|flight|fly|train|bus|trip|roadtrip|vacation|holiday|journey|visit|tour|cruise|airport|station)\b'),
      TaskCategory.work: RegExp(
          r'\b(meet|meeting|presentation|interview|work|job|client|office|conference|deadline|task|project|business|professional|corporate|workshop|seminar)\b'),
      TaskCategory.leisure: RegExp(
          r'\b(party|celebration|gathering|barbecue|bbq|festival|concert|event|entertainment|fun|movie|cinema|theater|restaurant|dinner|lunch|date|social)\b'),
    };

    // Check patterns in order of specificity
    for (var entry in patterns.entries) {
      if (entry.value.hasMatch(searchText)) {
        return entry.key;
      }
    }

    // Default to indoor for unmatched tasks
    return TaskCategory.indoor;
  }

  /// Determines the weather impact on a task with improved logic
  static WeatherImpact getWeatherImpact(Task task, WeatherData weatherData) {
    final forecast = getTaskTimeWeather(task, weatherData);
    if (forecast == null) {
      return WeatherImpact.none;
    }
    
    final category = detectTaskCategory(task);
    final severity = getWeatherSeverity(forecast);

    // Improved impact matrix with more nuanced relationships
    final impactMatrix = {
      TaskCategory.outdoor: {
        WeatherSeverity.severe: WeatherImpact.high,
        WeatherSeverity.moderate: WeatherImpact.high,
        WeatherSeverity.mild: WeatherImpact.medium,
        WeatherSeverity.good: WeatherImpact.none,
      },
      TaskCategory.sports: {
        WeatherSeverity.severe: WeatherImpact.high,
        WeatherSeverity.moderate: WeatherImpact.high,
        WeatherSeverity.mild: WeatherImpact.medium,
        WeatherSeverity.good: WeatherImpact.low, // Even good weather has slight impact on sports
      },
      TaskCategory.travel: {
        WeatherSeverity.severe: WeatherImpact.high,
        WeatherSeverity.moderate: WeatherImpact.medium,
        WeatherSeverity.mild: WeatherImpact.low,
        WeatherSeverity.good: WeatherImpact.none,
      },
      TaskCategory.work: {
        WeatherSeverity.severe: WeatherImpact.low, // Most work is indoors
        WeatherSeverity.moderate: WeatherImpact.none,
        WeatherSeverity.mild: WeatherImpact.none,
        WeatherSeverity.good: WeatherImpact.none,
      },
      TaskCategory.leisure: {
        WeatherSeverity.severe: WeatherImpact.medium, // Can adapt leisure activities
        WeatherSeverity.moderate: WeatherImpact.low,
        WeatherSeverity.mild: WeatherImpact.none,
        WeatherSeverity.good: WeatherImpact.none,
      },
      TaskCategory.indoor: {
        WeatherSeverity.severe: WeatherImpact.none,
        WeatherSeverity.moderate: WeatherImpact.none,
        WeatherSeverity.mild: WeatherImpact.none,
        WeatherSeverity.good: WeatherImpact.none,
      },
    };

    return impactMatrix[category]?[severity] ?? WeatherImpact.none;
  }

  /// Gets gradient colors based on weather impact with improved color scheme
  static List<Color> getImpactGradient(WeatherImpact impact) {
    switch (impact) {
      case WeatherImpact.high:
        return [
          Colors.red.shade700.withOpacity(0.8),
          Colors.red.shade800.withOpacity(0.9),
        ];
      case WeatherImpact.medium:
        return [
          Colors.orange.shade600.withOpacity(0.8),
          Colors.orange.shade700.withOpacity(0.9),
        ];
      case WeatherImpact.low:
        return [
          Colors.yellow.shade600.withOpacity(0.7),
          Colors.yellow.shade700.withOpacity(0.8),
        ];
      case WeatherImpact.none:
      default:
        return [
          Colors.green.shade600.withOpacity(0.7),
          Colors.green.shade700.withOpacity(0.8),
        ];
    }
  }

  /// Determines the severity of weather conditions with improved thresholds
  static WeatherSeverity getWeatherSeverity(HourlyForecast forecast) {
    final weather = forecast.weather.toLowerCase().trim();
    final temp = forecast.temperature;
    final precipitation = forecast.precipitationProbability;
    final uvIndex = forecast.uv;
    final dewPoint = forecast.dewPoint;

    int severityScore = 0;
    bool hasCriticalCondition = false; // Flag for immediately severe conditions

    // Weather type scoring with critical condition detection
    if (weather.contains('thunderstorm') || weather.contains('storm')) {
      severityScore += 4;
      hasCriticalCondition = true; // Thunderstorms are inherently severe
    } else if (weather.contains('heavy rain') || weather.contains('heavy snow') || weather.contains('blizzard')) {
      severityScore += 3;
    } else if (weather.contains('snow')) {
      severityScore += 2;
    } else if (weather.contains('rain') || weather.contains('drizzle')) {
      severityScore += 1;
    } else if (weather.contains('fog') && weather.contains('dense')) {
      severityScore += 2; // Dense fog is more problematic
    } else if (weather.contains('clouds') || weather.contains('overcast')) {
      // No penalty for just cloudy weather
    }

    // Temperature scoring with more realistic thresholds
    if (temp > _extremeHotTemp) {
      severityScore += 4;
      hasCriticalCondition = true; // Extreme heat is dangerous
    } else if (temp < _freezingTemp) {
      severityScore += 4;
      hasCriticalCondition = true; // Extreme cold is dangerous
    } else if (temp > _veryHotTemp || temp < _veryColdTemp) {
      severityScore += 3;
    } else if (temp > _hotTemp || temp < _coldTemp) {
      severityScore += 2;
    } else if (temp > 28.0 || temp < 8.0) { // Mild discomfort range
      severityScore += 1;
    }

    // Precipitation scoring with better granularity
    if (precipitation > _heavyPrecipitation) {
      severityScore += 3;
    } else if (precipitation > _highPrecipitation) {
      severityScore += 2;
    } else if (precipitation > _moderatePrecipitation) {
      severityScore += 1;
    } else if (precipitation > _lightPrecipitation) {
      // Only slight concern for light precipitation
    }

    // UV index scoring (only during daytime hours)
    final hour = forecast.time.hour;
    if (hour >= 9 && hour <= 17) { // Only consider UV during peak sun hours
      if (uvIndex >= _extremeUV) {
        severityScore += 2;
      } else if (uvIndex >= _highUV) {
        severityScore += 1;
      }
    }

    // Humidity scoring (more lenient, only extreme humidity counts)
    if (dewPoint > _veryHumidDewPoint) {
      severityScore += 2;
    } else if (dewPoint > _humidDewPoint) {
      severityScore += 1;
    }

    // Adjusted severity thresholds with critical condition override
    if (hasCriticalCondition || severityScore >= 8) {
      return WeatherSeverity.severe;
    } else if (severityScore >= 5) { // Increased from 4
      return WeatherSeverity.moderate;
    } else if (severityScore >= 2) {
      return WeatherSeverity.mild;
    } else {
      return WeatherSeverity.good;
    }
  }

  /// Generates comprehensive weather advice based on task and forecast
  static String getWeatherAdvice(Task task, WeatherData weatherData) {
    final forecast = getTaskTimeWeather(task, weatherData);
    if (forecast == null) {
      return '❓ Weather data unavailable for this time';
    }

    final category = detectTaskCategory(task);
    final severity = getWeatherSeverity(forecast);
    final weather = forecast.weather.toLowerCase();
    final temp = forecast.temperature;
    final precipitation = forecast.precipitationProbability;
    final uvIndex = forecast.uv;
    final dewPoint = forecast.dewPoint;

    List<String> adviceComponents = [];

    // Base advice based on category and severity
    final baseAdvice = _getBaseAdvice(category, severity, weather);
    adviceComponents.add(baseAdvice);

    // Temperature-specific advice
    if (temp > _extremeHotTemp) {
      adviceComponents.add('🌡️ Extreme heat (${temp.round()}°C) - Avoid prolonged outdoor exposure');
    } else if (temp > _veryHotTemp) {
      adviceComponents.add('☀️ Very hot (${temp.round()}°C) - Stay hydrated and seek shade');
    } else if (temp < _freezingTemp) {
      adviceComponents.add('❄️ Freezing conditions (${temp.round()}°C) - Dress warmly and be cautious of ice');
    } else if (temp < _veryColdTemp) {
      adviceComponents.add('🧥 Cold conditions (${temp.round()}°C) - Layer up and protect exposed skin');
    }

    // Precipitation advice
    if (precipitation > _highPrecipitation) {
      adviceComponents.add('☔ Very likely rain (${precipitation.round()}%) - Bring waterproof gear');
    } else if (precipitation > _moderatePrecipitation) {
      adviceComponents.add('🌦️ Possible rain (${precipitation.round()}%) - Consider bringing an umbrella');
    }

    // UV index advice
    if (uvIndex > _extremeUV) {
      adviceComponents.add('☀️ Extreme UV (${uvIndex.toStringAsFixed(1)}) - Use strong sun protection');
    } else if (uvIndex > _highUV) {
      adviceComponents.add('🕶️ High UV (${uvIndex.toStringAsFixed(1)}) - Apply sunscreen and wear a hat');
    }

    // Humidity advice for outdoor activities
    if ((category == TaskCategory.outdoor || category == TaskCategory.sports) && dewPoint > _veryHumidDewPoint) {
      adviceComponents.add('💧 Very humid conditions - Take frequent breaks and stay hydrated');
    }

    return adviceComponents.join('\n');
  }

  /// Helper method for base weather advice
  static String _getBaseAdvice(TaskCategory category, WeatherSeverity severity, String weather) {
    switch (category) {
      case TaskCategory.outdoor:
        switch (severity) {
          case WeatherSeverity.severe:
            return '⚠️ Severe weather - Consider postponing outdoor activities';
          case WeatherSeverity.moderate:
            return '⚡ Challenging conditions for outdoor activities - Take precautions';
          case WeatherSeverity.mild:
            return '🌤️ Fair conditions with minor weather considerations';
          case WeatherSeverity.good:
            return '🌟 Excellent conditions for outdoor activities';
        }
      case TaskCategory.sports:
        switch (severity) {
          case WeatherSeverity.severe:
            return '🚫 Unsafe for outdoor sports - Consider indoor alternatives';
          case WeatherSeverity.moderate:
            return '⚠️ Challenging sports conditions - Monitor weather closely';
          case WeatherSeverity.mild:
            return '🏃 Good for sports with minor adjustments needed';
          case WeatherSeverity.good:
            return '🏆 Perfect sports weather';
        }
      case TaskCategory.travel:
        switch (severity) {
          case WeatherSeverity.severe:
            return '🚗 High-risk travel conditions - Allow extra time and drive carefully';
          case WeatherSeverity.moderate:
            return '🛣️ Moderate travel impact - Plan for delays';
          case WeatherSeverity.mild:
            return '🚙 Minor travel considerations';
          case WeatherSeverity.good:
            return '✈️ Great travel conditions';
        }
      case TaskCategory.work:
        switch (severity) {
          case WeatherSeverity.severe:
            return '💼 Severe weather may affect commute - Consider remote work if possible';
          default:
            return '💼 Weather should not significantly impact work activities';
        }
      case TaskCategory.leisure:
        switch (severity) {
          case WeatherSeverity.severe:
            return '🎭 Consider indoor leisure alternatives';
          case WeatherSeverity.moderate:
            return '🎪 Weather may affect some leisure activities';
          default:
            return '🎉 Weather is suitable for most leisure activities';
        }
      case TaskCategory.indoor:
        return '🏠 Indoor activity - weather impact minimal';
    }
  }

  /// Gets UV index description with more detailed categories
  static String getUVDescription(double uvIndex) {
    if (uvIndex <= 2) return 'Low - Safe to be outside';
    if (uvIndex <= 5) return 'Moderate - Use sunscreen';
    if (uvIndex <= 7) return 'High - Avoid midday sun';
    if (uvIndex <= 10) return 'Very High - Seek shade, use protection';
    return 'Extreme - Stay indoors if possible';
  }

  /// Gets UV value with category
  static String getUVValue(double uvIndex) {
    final category = switch (uvIndex) {
      <= 2 => 'Low',
      <= 5 => 'Moderate',
      <= 7 => 'High',
      <= 10 => 'Very High',
      _ => 'Extreme',
    };
    return '$category (${uvIndex.toStringAsFixed(1)})';
  }

  /// Gets dew point comfort description with temperature consideration
  static String getDewPointDescription(double dewPoint) {
    if (dewPoint < 10) return 'Very dry - may feel crisp';
    if (dewPoint < 15) return 'Comfortable - pleasant humidity';
    if (dewPoint < 20) return 'Slightly humid - noticeable moisture';
    if (dewPoint < 24) return 'Humid - may feel sticky';
    return 'Very humid - uncomfortable conditions';
  }

  /// Finds suitable time slots with configurable criteria
  static List<HourlyForecast> findSuitableTimeSlots(
    WeatherData weatherData, {
    double minTemp = 5.0,
    double maxTemp = 38.0, 
    double maxPrecipitation = 60.0,
    int startHour = 4,
    int endHour = 23,
    List<String> excludeWeatherTypes = const ['thunderstorm', 'storm', 'heavy rain', 'snow'],
  }) {
    if (weatherData.hourlyForecast.isEmpty) {
      return [];
    }

    return weatherData.hourlyForecast.where((forecast) {
      final weather = forecast.weather.toLowerCase().trim();
      final temp = forecast.temperature;
      final hour = forecast.time.hour;
      final precipitation = forecast.precipitationProbability;
      
      // Check weather type exclusions
      final hasExcludedWeather = excludeWeatherTypes.any((excluded) => 
          weather.contains(excluded.toLowerCase()));
      
      return !hasExcludedWeather &&
          temp >= minTemp &&
          temp <= maxTemp &&
          precipitation <= maxPrecipitation &&
          hour >= startHour &&
          hour <= endHour;
    }).toList()
      ..sort((a, b) => getWeatherSeverity(a).index.compareTo(getWeatherSeverity(b).index));
  }


  /// Gets a weather summary for the day
  static String getDayWeatherSummary(WeatherData weatherData) {
    if (weatherData.hourlyForecast.isEmpty) {
      return 'No weather data available';
    }

    final forecasts = weatherData.hourlyForecast;
    final temps = forecasts.map((f) => f.temperature).toList();
    final minTemp = temps.reduce(min);
    final maxTemp = temps.reduce(max);
    
    final mainWeatherTypes = forecasts
        .map((f) => f.weather.toLowerCase().trim())
        .toSet()
        .toList();
    
    final maxPrecipitation = forecasts
        .map((f) => f.precipitationProbability)
        .reduce(max);

    final dominantWeather = mainWeatherTypes.length == 1 
        ? mainWeatherTypes.first 
        : 'mixed conditions';

    return 'Temperature: ${minTemp.round()}°-${maxTemp.round()}°C, '
           '${dominantWeather.capitalize()}, '
           'Rain chance: ${maxPrecipitation.round()}%';
  }
}

extension StringCapitalization on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}