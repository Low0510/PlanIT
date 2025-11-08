import 'dart:ui'; // Import for BackdropFilter
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:planit_schedule_manager/models/hourly_forecast.dart';
import 'package:planit_schedule_manager/models/task.dart';
import 'package:planit_schedule_manager/models/weather_data.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:planit_schedule_manager/services/location_service.dart';
import 'package:planit_schedule_manager/services/schedule_service.dart';
import 'package:planit_schedule_manager/services/weather_service.dart';
import 'package:planit_schedule_manager/utils/weather_util.dart';
import 'package:planit_schedule_manager/widgets/toast.dart';

class WeatherTaskScreen extends StatefulWidget {
  final WeatherService weatherService;
  final LocationService locationService;

  const WeatherTaskScreen({
    Key? key,
    required this.weatherService,
    required this.locationService,
  }) : super(key: key);

  @override
  _WeatherTaskScreenState createState() => _WeatherTaskScreenState();
}

class _WeatherTaskScreenState extends State<WeatherTaskScreen> {
  WeatherData? _weatherData;
  final ScheduleService _scheduleService =
      ScheduleService(); // Keep final if not re-assigned

  bool _isLoading = true;
  String? _errorMessage;
  List<Task> _allTasks = []; // Store all fetched tasks
  List<Task> _weatherAffectedTasks = [];
  bool _locationServicesDisabled = false;
  bool _locationPermissionDenied = false; // Track specific permission state

  @override
  void initState() {
    print("Opening Weather Screen");
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _getLocationAndFetchWeather();
    // Fetch tasks only if weather data was successfully loaded
    if (_weatherData != null) {
      await _fetchTasks();
      _updateWeatherAffectedTasks();
    }
    // Ensure loading state is updated even if weather fetch fails
    if (mounted && _isLoading) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshData() async {
    // Reset state variables for refresh
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _locationServicesDisabled = false;
      _locationPermissionDenied = false;
      _weatherData = null; // Clear old data immediately
      _weatherAffectedTasks = [];
    });
    await _initializeData();
  }

  Future<void> _fetchTasks() async {
    // No need for loading indicator here, handled by the main _isLoading
    try {
      final now = DateTime.now();
      // Fetch tasks for the next 48 hours to cover today and tomorrow adequately
      final tomorrow = now.add(Duration(days: 1));

      final todayTasks = await _scheduleService.getSchedulesForDate(now);

      // Fetch tasks for tomorrow
      final tomorrowTasks =
          await _scheduleService.getSchedulesForDate(tomorrow);

      if (mounted) {
        setState(() {
          _allTasks = [...todayTasks, ...tomorrowTasks];
        });
      }
    } catch (e) {
      print('Error fetching tasks: $e');
      if (mounted) {
        // Optionally show a specific error for task fetching
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Could not load tasks.'),
              backgroundColor: Colors.orange),
        );
      }
    }
  }

  Future<void> _getLocationAndFetchWeather() async {
    // Reset specific error states before trying again
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _locationServicesDisabled = false;
      _locationPermissionDenied = false;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() {
          _locationServicesDisabled = true;
          _isLoading = false;
        });
        // Consider showing the dialog immediately if needed
        _showLocationServicesDisabledDialog(); // Be cautious calling dialogs during build/initState
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          setState(() {
            _errorMessage = 'Location permission denied.';
            _locationPermissionDenied = true; // Specific state
            _isLoading = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _errorMessage =
              'Location permissions permanently denied. Please enable in settings.';
          _locationPermissionDenied = true; // Specific state
          _isLoading = false;
        });
        // Consider showing dialog immediately if needed
        _showPermissionDeniedForeverDialog();
        return;
      }

      // Permissions granted, proceed to get location and weather
      final position = await widget.locationService.determinePosition();
      final weatherData = await widget.weatherService.getWeather(
        position.latitude,
        position.longitude,
      );
      if (!mounted) return;
      setState(() {
        _weatherData = weatherData;
        // Keep _isLoading = true until tasks are also fetched in _initializeData
      });
    } on PlatformException catch (e) {
      // Catch specific platform exceptions
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to get location: ${e.message}';
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        // Handle potential WeatherException or other errors
        _errorMessage = e is WeatherException
            ? e.message
            : 'An unexpected error occurred: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _updateWeatherAffectedTasks() {
    if (_weatherData == null || _allTasks.isEmpty) {
      if (mounted) {
        setState(() {
          _weatherAffectedTasks = [];
        });
      }
      return;
    }

    final now = DateTime.now();
    // Consider tasks within the next 24-48 hours based on forecast availability
    final forecastEndTime = _weatherData!.hourlyForecast.isNotEmpty
        ? _weatherData!.hourlyForecast.last.time
        : now.add(Duration(hours: 24)); // Fallback

    final affected = _allTasks.where((task) {
      // Ensure task time is valid and within the forecast range
      final taskTime = task.time;
      return taskTime.isAfter(now) && taskTime.isBefore(forecastEndTime);
    }).toList();

    // Sort affected tasks by time
    affected.sort((a, b) => a.time.compareTo(b.time));

    if (mounted) {
      setState(() {
        _weatherAffectedTasks = affected;
      });
    }
  }

  // --- Dialog Functions (Keep similar, maybe style adjustments) ---

  void _showLocationServicesDisabledDialog() {
    // Use a theme-consistent dialog style
    showDialog(
      context: context,
      barrierDismissible: false, // Important!
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
          title: Row(
            children: [
              Icon(Icons.location_off_rounded, color: Colors.orange.shade700),
              SizedBox(width: 10),
              Text('Location Disabled',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
              'Enable location services in your device settings to get local weather.'),
          actions: <Widget>[
            TextButton(
              child: Text('Exit App'),
              onPressed: () {
                Navigator.of(context).pop();
                SystemNavigator.pop(); // Close app if necessary
              },
            ),
            ElevatedButton.icon(
              icon: Icon(Icons.settings),
              label: Text('Open Settings'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white, // Ensure text is visible
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8))),
              onPressed: () async {
                Navigator.of(context).pop();
                await Geolocator.openLocationSettings();
                // Optionally add a small delay before re-checking
                await Future.delayed(Duration(milliseconds: 500));
                _refreshData(); // Attempt to refresh data after returning
              },
            ),
          ],
        );
      },
    );
  }

  void _showPermissionDeniedForeverDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // Important!
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
          title: Row(
            children: [
              Icon(Icons.error_outline_rounded, color: Colors.red.shade700),
              SizedBox(width: 10),
              Text('Permission Required',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
              'Location permission was permanently denied. Please enable it in the app settings.'),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
                // Decide if the app should close or stay in a limited state
              },
            ),
            ElevatedButton.icon(
              icon: Icon(Icons.settings),
              label: Text('Open App Settings'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8))),
              onPressed: () async {
                Navigator.of(context).pop();
                await Geolocator.openAppSettings();
                await Future.delayed(Duration(milliseconds: 500));
                _refreshData(); // Attempt to refresh data after returning
              },
            ),
          ],
        );
      },
    );
  }

  // --- UI Builder Functions ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // No AppBar here, integrate title/refresh into the body
      extendBodyBehindAppBar: true, // Allows body to draw behind status bar
      body: Container(
        // Background Gradient
        decoration: BoxDecoration(
          gradient: _getWeatherGradient(_weatherData),
        ),
        child: SafeArea(
          // Ensures content avoids notches/system bars
          child: RefreshIndicator(
            onRefresh: _refreshData,
            color: Colors.white, // Indicator color
            backgroundColor:
                Colors.blue.shade600, // Background for the indicator
            child: _buildBodyContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildBodyContent() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: Colors.white));
    }

    if (_locationServicesDisabled) {
      // Use a dedicated widget, potentially centered or placed appropriately
      return _buildLocationServicesPrompt();
    }

    if (_locationPermissionDenied) {
      // Use a dedicated widget for permission issues
      return _buildPermissionDeniedPrompt();
    }

    if (_errorMessage != null) {
      // Use a dedicated error widget
      return _buildErrorWidget(_errorMessage!);
    }

    if (_weatherData == null) {
      // Fallback if data isn't loaded but no specific error/permission issue known
      return _buildErrorWidget(
          "Could not load weather data. Pull down to refresh.");
    }

    // Main content display
    return SingleChildScrollView(
      physics:
          const AlwaysScrollableScrollPhysics(), // Ensure scroll works with RefreshIndicator
      padding: const EdgeInsets.symmetric(
          vertical: 10.0), // Overall vertical padding
      child: Column(
        children: [
          _buildHeader(), // Location, Date, Refresh (moved inside scroll)
          const SizedBox(height: 10),
          _buildCurrentWeatherSummary(_weatherData!),
          const SizedBox(height: 20),
          _buildWeatherReminder(_weatherData!),
          const SizedBox(height: 30),
          _buildAffectedTasksSection(
              _weatherAffectedTasks, _weatherData!), // Combined glance/list
          const SizedBox(height: 30),
          _buildHourlyForecastSection(_weatherData!),
          const SizedBox(height: 30),
          _buildDetailedWeatherInfo(_weatherData!),
          const SizedBox(height: 30), // Bottom padding
        ],
      ),
    );
  }

  // --- Specific UI Section Widgets ---

  Widget _buildHeader() {
    // Place refresh icon subtly if needed, though RefreshIndicator is primary
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        children: [
          Text(
            _weatherData?.locationName ??
                'Loading...', // Handle null case during init
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [
                Shadow(
                    blurRadius: 2, color: Colors.black26, offset: Offset(1, 1))
              ],
            ),
          ),
          SizedBox(height: 4),
          Text(
            DateFormat('EEEE, d MMMM yyyy').format(DateTime.now()),
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentWeatherSummary(WeatherData data) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center, // Center the row content
        children: [
          // Weather Icon
          if (data.weather.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(
                  right: 15.0), // Space between icon and text
              child: SvgPicture.asset(
                WeatherUtils.getWeatherIcon(
                  data.weather,
                  sunrise: data.sunrise,
                  sunset: data.sunset,
                ),
                width: 80, // Slightly smaller icon
                height: 80,
                colorFilter: ColorFilter.mode(Colors.white,
                    BlendMode.srcIn), // Ensure color compatibility
                semanticsLabel: '${data.weather} icon',
              ),
            ),

          // Temperature and Condition
          Column(
            crossAxisAlignment:
                CrossAxisAlignment.center, // Center text below temp
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment:
                    MainAxisAlignment.center, // Center temp and °C
                crossAxisAlignment: CrossAxisAlignment.start, // Align °C top
                children: [
                  Text(
                    data.temperature
                        .toStringAsFixed(0), // No decimal for cleaner look
                    style: TextStyle(
                      fontSize: 72, // Large temperature
                      fontWeight:
                          FontWeight.w300, // Lighter weight for elegance
                      color: Colors.white,
                      height: 1.0, // Reduce line height
                      shadows: [
                        Shadow(
                            blurRadius: 3,
                            color: Colors.black38,
                            offset: Offset(1, 2))
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(
                        top: 10.0), // Adjust position of °C
                    child: Text(
                      '°C',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w400, // Medium weight
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 0), // Reduce space
              Text(
                // Capitalize first letter
                data.weather.isNotEmpty
                    ? '${data.weather[0].toUpperCase()}${data.weather.substring(1)}'
                    : '',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withOpacity(0.95),
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: 4), // Space before description
              Text(
                data.description.isNotEmpty
                    ? '${data.description[0].toUpperCase()}${data.description.substring(1)}'
                    : '',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.white.withOpacity(0.85),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherReminder(WeatherData data) {
    String reminder = widget.weatherService.getWeatherReminder(data);
    IconData icon = Icons.info_outline; // Default icon

    // Choose icon based on reminder content (simple example)
    if (reminder.contains('🌧️') || reminder.contains('umbrella'))
      icon = Icons.beach_access;
    if (reminder.contains('⛈️') || reminder.contains('Stormy'))
      icon = Icons.thunderstorm;
    if (reminder.contains('❄️') || reminder.contains('Snowy'))
      icon = Icons.ac_unit;
    if (reminder.contains('☀️') || reminder.contains('clear'))
      icon = Icons.wb_sunny;
    if (reminder.contains('☁️') || reminder.contains('Cloudy'))
      icon = Icons.cloud_outlined;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20.0),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(15.0),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 0.5),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              reminder,
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
                height: 1.3, // Improve line spacing
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Affected Tasks Section (Combined Glance/List) ---
  Widget _buildAffectedTasksSection(
      List<Task> affectedTasks, WeatherData weatherData) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Text(
            'Upcoming Affected Tasks (Next 24h)',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [
                Shadow(
                    blurRadius: 1, color: Colors.black26, offset: Offset(1, 1))
              ],
            ),
          ),
        ),
        const SizedBox(height: 15),
        if (affectedTasks.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Center(
                  child: Text(
                    'No tasks affected by weather\nin the near future.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                )),
          )
        else
          // Use ListView for vertical scrolling if many tasks, or Column if few
          // Consider a max height and scrollability if it can get very long
          ListView.builder(
            shrinkWrap: true, // Important inside SingleChildScrollView
            physics: NeverScrollableScrollPhysics(), // Disable its own scroll
            itemCount: affectedTasks.length,
            padding:
                EdgeInsets.symmetric(horizontal: 15), // Padding for the cards
            itemBuilder: (context, index) {
              final task = affectedTasks[index];
              // Calculate impact *here* to avoid passing weatherData down unnecessarily
              final forecast =
                  WeatherUtils.getTaskTimeWeather(task, weatherData);
              final impact = forecast != null
                  ? WeatherUtils.getWeatherImpact(task, weatherData)
                  : WeatherImpact.none;
              final advice = forecast != null
                  ? WeatherUtils.getWeatherAdvice(task, weatherData)
                  : "Weather data unavailable for this time.";

              return _buildWeatherAwareTaskCard(task, impact, forecast, advice);
            },
          ),
      ],
    );
  }

  // Redesigned Task Card for the main list
  Widget _buildWeatherAwareTaskCard(Task task, WeatherImpact impact,
      HourlyForecast? forecast, String advice) {
    final category = WeatherUtils.detectTaskCategory(task);
    final colors =
        WeatherUtils.getImpactGradient(impact); // Use the util function

    return Card(
      elevation: 3.0,
      margin: EdgeInsets.symmetric(vertical: 8.0), // Adjust vertical spacing
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
      color: Colors.transparent, // Make card transparent for gradient
      child: Container(
        decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors, // Use impact-based colors
              stops: [0.1, 0.9],
            ),
            borderRadius: BorderRadius.circular(15.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 5,
                offset: Offset(0, 2),
              )
            ]),
        child: Material(
          // For InkWell splash effect
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(15.0),
            onTap: () => _showTaskDetailsDialog(task, forecast, advice),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCategoryIcon(
                          category), // Re-use existing icon widget
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              task.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 5),
                            Text(
                              DateFormat('E, d MMM HH:mm').format(
                                  task.time), // Slightly different format
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 10),
                      _buildCompactImpactIndicator(impact), // Smaller indicator
                    ],
                  ),
                  // Optionally add a divider or space before weather info if forecast exists
                  if (forecast != null) ...[
                    Divider(height: 20, color: Colors.white.withOpacity(0.2)),
                    _buildCompactWeatherInfo(forecast, _weatherData?.sunrise,
                        _weatherData?.sunset), // More compact display
                  ]
                  // Consider showing advice snippet here or only in dialog
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

// Smaller impact indicator for the card
  Widget _buildCompactImpactIndicator(WeatherImpact impact) {
    final IconData icon;
    final Color color;

    switch (impact) {
      case WeatherImpact.high:
        icon = Icons.warning_amber_rounded;
        color = Colors.red.shade300;
        break;
      case WeatherImpact.medium:
        icon = Icons.info_outline_rounded;
        color = Colors.orange.shade300;
        break;
      default: // None
        icon = Icons.check_circle_outline_rounded;
        color = Colors.green.shade300;
    }

    return Icon(icon, color: color, size: 24);
  }

// Compact weather info row for the task card
  Widget _buildCompactWeatherInfo(
      HourlyForecast forecast, DateTime? sunrise, DateTime? sunset) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween, // Spread elements
      children: [
        Row(
          // Temp + Icon
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
                WeatherUtils.getWeatherIcon(forecast.weather,
                    sunrise: sunrise, sunset: sunset),
                width: 20,
                height: 20,
                colorFilter: ColorFilter.mode(Colors.white, BlendMode.srcIn)),
            SizedBox(width: 6),
            Text(
              '${forecast.temperature.toStringAsFixed(0)}°C', // No decimal
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
        Row(
          // Precipitation
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.water_drop_outlined,
                color: Colors.white.withOpacity(0.8), size: 16),
            SizedBox(width: 4),
            Text(
              '${forecast.precipitationProbability.round()}%',
              style:
                  TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14),
            ),
          ],
        ),
        Row(
          // UV Index
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wb_sunny_outlined,
                color: Colors.white.withOpacity(0.8), size: 16),
            SizedBox(width: 4),
            Text(
              'UV ${forecast.uv.toStringAsFixed(0)}', // Simple UV value
              style:
                  TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14),
            ),
          ],
        ),
      ],
    );
  }

  // --- Hourly Forecast Section ---
  Widget _buildHourlyForecastSection(WeatherData data) {
    if (data.hourlyForecast.isEmpty) {
      return SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Text(
            'Hourly Forecast',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [
                Shadow(
                    blurRadius: 1, color: Colors.black26, offset: Offset(1, 1))
              ],
            ),
          ),
        ),
        SizedBox(height: 15),
        Container(
          height: 155, // Adjust height as needed
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: data.hourlyForecast.length,
            // Add padding to the left/right of the list itself
            padding: EdgeInsets.symmetric(horizontal: 15),
            itemBuilder: (context, index) {
              final forecast = data.hourlyForecast[index];
              final isNow = forecast.time.hour ==
                  DateTime.now().hour; // Highlight current hour
              return _buildHourlyForecastCard(
                  forecast, data.sunrise, data.sunset, isNow);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHourlyForecastCard(HourlyForecast forecast, DateTime? sunrise,
      DateTime? sunset, bool isNow) {
    return Container(
      width: 85, // Slightly narrower cards
      margin: EdgeInsets.symmetric(horizontal: 5), // Space between cards
      decoration: BoxDecoration(
        // Frosted glass effect
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white
              .withOpacity(isNow ? 0.5 : 0.2), // Highlight border if 'now'
          width: isNow ? 1.5 : 1,
        ),
        color: Colors.white
            .withOpacity(isNow ? 0.3 : 0.15), // Highlight background if 'now'
      ),
      child: ClipRRect(
        // Clip the backdrop filter
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          // Frosted glass
          filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('HH:mm').format(forecast.time),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: isNow
                        ? FontWeight.bold
                        : FontWeight.w500, // Bold if 'now'
                    color: Colors.white,
                  ),
                ),
                Spacer(flex: 1),
                SvgPicture.asset(
                  WeatherUtils.getWeatherIcon(forecast.weather,
                      sunrise: sunrise, sunset: sunset),
                  width: 35,
                  height: 35,
                  colorFilter: ColorFilter.mode(Colors.white, BlendMode.srcIn),
                  semanticsLabel: forecast.weather,
                ),
                Spacer(flex: 1),
                Text(
                  '${forecast.temperature.toStringAsFixed(0)}°C', // No decimal
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Spacer(flex: 1),
                // Optional: Precipitation Row
                if (forecast.precipitationProbability >
                    10) // Show only if significant chance
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(Icons.water_drop_outlined,
                          color: Colors.lightBlue.shade100, size: 12),
                      SizedBox(width: 3),
                      Text(
                        '${forecast.precipitationProbability.toInt()}%',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  )
                else
                  SizedBox(
                      height:
                          15), // Placeholder height to maintain layout consistency
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Detailed Weather Info Section ---
  Widget _buildDetailedWeatherInfo(WeatherData data) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: ClipRRect(
        // Clip the backdrop filter
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          // Frosted glass effect
          filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: Colors.white.withOpacity(0.2), width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                          blurRadius: 1,
                          color: Colors.black26,
                          offset: Offset(0, 1))
                    ],
                  ),
                ),
                Divider(height: 25, color: Colors.white.withOpacity(0.2)),
                // Use rows for better horizontal spacing on wider screens
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                        child: _buildDetailItem(Icons.water_drop_outlined,
                            'Humidity', '${data.humidity}%')),
                    SizedBox(width: 15), // Spacer between columns
                    Expanded(
                        child: _buildDetailItem(Icons.air, 'Wind',
                            '${data.windSpeed.toStringAsFixed(1)} m/s')),
                  ],
                ),
                SizedBox(height: 15), // Space between rows
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                        child: _buildDetailItem(
                            Icons.wb_sunny_outlined,
                            'Sunrise',
                            data.sunrise != null
                                ? DateFormat('HH:mm').format(data.sunrise!)
                                : '--:--')),
                    SizedBox(width: 15),
                    Expanded(
                        child: _buildDetailItem(
                            Icons.nights_stay_outlined,
                            'Sunset',
                            data.sunset != null
                                ? DateFormat('HH:mm').format(data.sunset!)
                                : '--:--')),
                  ],
                ),
                SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // UV Index with Description (Utilizes the detail item)
                    Expanded(
                      child: _buildDetailItem(
                        Icons.shield_outlined, // Different icon for UV
                        'UV Index',
                        WeatherUtils.getUVValue(data.uvi), // e.g., "High (7.1)"
                        description: WeatherUtils.getUVDescription(
                            data.uvi), // e.g., "Avoid midday sun"
                      ),
                    ),
                    SizedBox(width: 15),
                    // Dew Point with Description
                    Expanded(
                      child: _buildDetailItem(
                        Icons.thermostat_auto_outlined, // Different icon
                        'Dew Point',
                        '${data.dewPoint.toStringAsFixed(1)}°C',
                        description: WeatherUtils.getDewPointDescription(
                            data.dewPoint), // e.g., "Comfortable"
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Reusable widget for each detail item within the Details card
  Widget _buildDetailItem(IconData icon, String label, String value,
      {String? description}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: Colors.white.withOpacity(0.8)),
            SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
              ),
            ),
          ],
        ),
        SizedBox(height: 4),
        Padding(
          // Indent value slightly or keep aligned based on preference
          padding: const EdgeInsets.only(left: 2), // Minimal indent
          child: Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        // Display description if provided
        if (description != null && description.isNotEmpty) ...[
          SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Text(
              description,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ]
      ],
    );
  }

  // --- Error and Prompt Widgets ---

  Widget _buildErrorWidget(String message) {
    return Center(
      child: Container(
        margin: EdgeInsets.all(30),
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 25),
        decoration: BoxDecoration(
          color: Colors.red.shade100.withOpacity(0.8),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.red.shade300),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                color: Colors.red.shade700, size: 48),
            SizedBox(height: 16),
            Text(
              'Oops!',
              style: TextStyle(
                color: Colors.red.shade900,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(color: Colors.red.shade800, fontSize: 15),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _refreshData,
              icon: Icon(Icons.refresh),
              label: Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildLocationServicesPrompt() {
    // Re-use the dialog logic or create a similar inline prompt
    // For consistency, let's call the dialog show function here
    // Note: Calling dialog directly in build might cause issues. Better to trigger it from initState or a button press.
    // Showing an inline prompt is safer within build:
    return Center(
      child: Container(
        margin: EdgeInsets.all(30),
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 25),
        decoration: BoxDecoration(
          color: Colors.orange.shade100.withOpacity(0.9),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.orange.shade300),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_off_rounded,
                color: Colors.orange.shade700, size: 48),
            SizedBox(height: 16),
            Text(
              'Location Disabled',
              style: TextStyle(
                color: Colors.orange.shade900,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Please enable location services in your device settings to get local weather updates.',
              style: TextStyle(color: Colors.orange.shade800, fontSize: 15),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () async {
                await Geolocator.openLocationSettings();
                // Optionally add delay before refresh
                await Future.delayed(Duration(milliseconds: 500));
                _refreshData();
              },
              icon: Icon(Icons.settings),
              label: Text('Open Settings'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade600,
                foregroundColor: Colors.white,
              ),
            ),
            TextButton(
                onPressed: () => SystemNavigator.pop(), // Option to exit
                child: Text('Exit App',
                    style: TextStyle(color: Colors.orange.shade800)))
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionDeniedPrompt() {
    // Similar to the location services prompt, but for permissions
    return Center(
      child: Container(
        margin: EdgeInsets.all(30),
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 25),
        decoration: BoxDecoration(
          color: Colors.red.shade100.withOpacity(0.9),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.red.shade300),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_disabled_rounded,
                color: Colors.red.shade700, size: 48),
            SizedBox(height: 16),
            Text(
              'Permission Denied',
              style: TextStyle(
                color: Colors.red.shade900,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              _errorMessage ??
                  'Location permission is required for weather data. Please grant permission in the app settings.',
              style: TextStyle(color: Colors.red.shade800, fontSize: 15),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () async {
                await Geolocator.openAppSettings();
                await Future.delayed(Duration(milliseconds: 500));
                _refreshData();
              },
              icon: Icon(Icons.settings),
              label: Text('Open App Settings'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
              ),
            ),
            // Optionally add a cancel/exit button
          ],
        ),
      ),
    );
  }

  // --- Task Details Dialog (Enhanced) ---
  void _showTaskDetailsDialog(
      Task task, HourlyForecast? forecast, String weatherAdvice) {
    final impact = forecast != null
        ? WeatherUtils.getWeatherImpact(task, _weatherData!)
        : WeatherImpact.none;
    final impactColors = WeatherUtils.getImpactGradient(impact);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor:
            Colors.transparent, // Make dialog background transparent
        insetPadding: EdgeInsets.all(20), // Padding around the dialog
        child: Container(
          decoration: BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors:
                      impactColors, // Use impact color for dialog background
                  stops: [0.1, 0.9]),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: Colors.black26, blurRadius: 15, spreadRadius: 2)
              ]),
          child: ClipRRect(
            // Clip backdrop
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              // Subtle frost on dialog
              filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
              child: SingleChildScrollView(
                // Allow scrolling if content overflows
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22, // Slightly smaller than card title
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    _buildDetailRow(Icons.calendar_today_outlined, 'Date',
                        DateFormat('EEE, d MMM yyyy').format(task.time)),
                    SizedBox(height: 10),
                    _buildDetailRow(Icons.access_time_rounded, 'Time',
                        DateFormat('HH:mm').format(task.time)),
                    SizedBox(height: 16),

                    if (forecast != null) ...[
                      Divider(color: Colors.white.withOpacity(0.3), height: 20),
                      _buildDetailRow(Icons.thermostat_outlined, 'Est. Temp',
                          '${forecast.temperature.toStringAsFixed(1)}°C'),
                      SizedBox(height: 10),
                      _buildDetailRow(Icons.water_drop_outlined, 'Est. Precip',
                          '${forecast.precipitationProbability.round()}%'),
                      SizedBox(height: 10),
                      _buildDetailRow(Icons.wb_sunny_outlined, 'Est. UV Index',
                          forecast.uv.toStringAsFixed(1)),
                      SizedBox(height: 10),
                      _buildDetailRow(
                          Icons.info_outline_rounded,
                          'Est. Condition',
                          '${forecast.weather} - ${forecast.description}'),
                      Divider(color: Colors.white.withOpacity(0.3), height: 20),
                    ],

                    SizedBox(height: 5),
                    _buildWeatherAdviceSectionInDialog(
                        weatherAdvice), // Reuse styled advice widget
                    SizedBox(height: 24),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('Close',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 15)),
                          style: TextButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 15, vertical: 8)),
                        ),
                        SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context); // Close details dialog
                            if (_weatherData != null) {
                              _showRescheduleDialog(
                                  task); // Open reschedule dialog
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: Text(
                                      'Weather data needed to suggest times.'),
                                  backgroundColor: Colors.orange));
                            }
                          },
                          icon: Icon(Icons.edit_calendar_outlined, size: 18),
                          label: Text('Reschedule'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.9),
                              foregroundColor: impactColors[
                                  1], // Use darker impact color for text
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              padding: EdgeInsets.symmetric(
                                  horizontal: 15, vertical: 10)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Detail row specifically for the Dialog
  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.9), size: 18),
        SizedBox(width: 12),
        Text(
          '$label:',
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          // Allow value to wrap if long
          child: Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600, // Bolder value
            ),
          ),
        ),
      ],
    );
  }

  // Re-use the advice styling but maybe slightly adapted for the dialog
  Widget _buildWeatherAdviceSectionInDialog(String advice) {
    final messages =
        advice.split('\n').where((m) => m.trim().isNotEmpty).toList();
    if (messages.isEmpty) return SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.1), // Subtle background
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Weather Advice',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          ...messages
              .map((message) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Text(
                      message, // Keep emojis if they exist
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.95),
                        fontSize: 14,
                        height: 1.3,
                      ),
                    ),
                  ))
              .toList(),
        ],
      ),
    );
  }

  // --- Reschedule Dialog (Enhanced) ---
  void _showRescheduleDialog(Task task) {
    final suggestions = WeatherUtils.findSuitableTimeSlots(_weatherData!);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900
            .withOpacity(0.9), // Darker, slightly transparent
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Reschedule "${task.title}"',
          style: TextStyle(color: Colors.white, fontSize: 18),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Suggested times with better weather:',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              SizedBox(height: 16),
              if (suggestions.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'No ideal slots found in the forecast.\nConsider rescheduling manually.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white54, fontStyle: FontStyle.italic),
                    ),
                  ),
                )
              else
                _buildSuggestedTimesList(task, suggestions),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          // Optional: Add a button for manual date/time picking
        ],
      ),
    );
  }

  Widget _buildSuggestedTimesList(Task task, List<HourlyForecast> suggestions) {
    // Limit the number of suggestions shown initially?
    final limitedSuggestions = suggestions.toList(); // Show top 5 for brevity

    return Column(
      children: limitedSuggestions.map((suggestion) {
        final format = DateFormat('E, d MMM HH:mm');
        return ListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: 0, vertical: 4),
          title: Text(
            format.format(suggestion.time),
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
          ),
          subtitle: Row(
            // Show weather condition next to time
            children: [
              SvgPicture.asset(
                  WeatherUtils.getWeatherIcon(suggestion.weather,
                      sunrise: _weatherData?.sunrise,
                      sunset: _weatherData?.sunset),
                  width: 16,
                  height: 16,
                  colorFilter:
                      ColorFilter.mode(Colors.white70, BlendMode.srcIn)),
              SizedBox(width: 5),
              Text(
                '${suggestion.weather}, ${suggestion.temperature.toStringAsFixed(0)}°C',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              SizedBox(width: 8),
              Icon(Icons.water_drop_outlined, size: 12, color: Colors.white54),
              SizedBox(width: 2),
              Text('${suggestion.precipitationProbability.round()}%',
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
          trailing:
              Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
          onTap: () => _updateTaskTime(
            task,
            suggestion.time, // Pass the full DateTime
            // TimeOfDay.fromDateTime(suggestion.time), // Not needed if passing DateTime
          ),
        );
      }).toList(),
    );
  }

// --- Data Update Logic (Enhanced) ---
// Update _updateTaskTime to accept DateTime directly
  Future<void> _updateTaskTime(Task task, DateTime newDateTime) async {
    // Close the reschedule dialog first
    Navigator.of(context).pop();

    // Show a loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('Rescheduling task...'),
        duration: Duration(seconds: 1), // Short duration
      ),
    );

    try {
      await _scheduleService.updateTaskTime(
        taskId: task.id,
        newDateTime: newDateTime,
      );

      _refreshData();

      SuccessToast.show(context, 'Task rescheduled successfully!');
    } catch (e) {
      print("Error rescheduling task: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to reschedule task. Please try again.'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }

  // --- Helper Widgets (Keep as is or slightly modify) ---
  Widget _buildCategoryIcon(TaskCategory category) {
    final IconData icon;
    switch (category) {
      case TaskCategory.outdoor:
        icon = Icons.nature_people_outlined;
        break;
      case TaskCategory.sports:
        icon = Icons.sports_basketball_outlined;
        break;
      case TaskCategory.travel:
        icon = Icons.explore_outlined;
        break;
      case TaskCategory.work:
        icon = Icons.work_outline_rounded;
        break;
      case TaskCategory.leisure:
        icon = Icons.celebration_outlined;
        break;
      case TaskCategory.indoor:
        icon = Icons.home_outlined;
        break;
    }

    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.25), // Slightly more opaque
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: Colors.white, size: 24),
    );
  }
}


LinearGradient _getWeatherGradient(WeatherData? data) {
  // --- Default Gradient (used when data is null or condition unknown) ---
  final defaultGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Colors.blue.shade700, // Default blue sky top
      Colors.lightBlue.shade400,
      Colors.cyan.shade300, // Default blue sky bottom
    ],
    stops: const [0.0, 0.5, 1.0],
  );

  if (data == null) {
    return defaultGradient;
  }

  // --- Determine if it's daytime ---
  final now = DateTime.now();
  bool isDay = data.sunrise != null && data.sunset != null
      ? now.isAfter(data.sunrise!) && now.isBefore(data.sunset!)
      : now.hour >= 6 && now.hour < 18; // Fallback based on hour

  String weather = data.weather.toLowerCase();

  // --- Map Weather Conditions to Gradients ---
  switch (weather) {
    case 'clear':
      return isDay
          ? LinearGradient(
              // Sunny Day
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.lightBlue.shade300,
                Colors.blue.shade500,
                Colors.yellow.shade600
              ],
              stops: const [0.0, 0.6, 1.0],
            )
          : LinearGradient(
              // Clear Night
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.indigo.shade900,
                Colors.black87,
                Colors.deepPurple.shade900
              ],
              stops: const [0.0, 0.7, 1.0],
            );

    case 'clouds':
      return isDay
          ? LinearGradient(
              // Cloudy Day
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.blueGrey.shade400,
                Colors.grey.shade500,
                Colors.lightBlue.shade200
              ],
              stops: const [0.0, 0.5, 1.0],
            )
          : LinearGradient(
              // Cloudy Night
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.blueGrey.shade800,
                Colors.grey.shade700,
                Colors.indigo.shade700
              ],
              stops: const [0.0, 0.5, 1.0],
            );

    case 'rain':
    case 'drizzle':
      return LinearGradient(
        // Rainy (Day or Night similar)
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.blueGrey.shade700,
          Colors.grey.shade600,
          Colors.indigo.shade400
        ],
        stops: const [0.0, 0.5, 1.0],
      );

    case 'thunderstorm':
      return LinearGradient(
        // Stormy (Day or Night similar)
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.grey.shade800,
          Colors.deepPurple.shade900,
          Colors.black87
        ],
        stops: const [0.0, 0.6, 1.0],
      );

    case 'snow':
      return LinearGradient(
        // Snowy (Day or Night similar)
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.lightBlue.shade100,
          Colors.white70,
          Colors.blueGrey.shade200
        ],
        stops: const [0.0, 0.5, 1.0],
      );

    case 'mist':
    case 'fog':
    case 'haze':
      return LinearGradient(
        // Foggy/Misty
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.grey.shade500,
          Colors.blueGrey.shade300,
          Colors.grey.shade400
        ],
        stops: const [0.0, 0.5, 1.0],
      );

    default:
      // Fallback for any other unhandled conditions
      return defaultGradient;
  }
}
