import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:planit_schedule_manager/const.dart';
import 'package:planit_schedule_manager/screens/eisenhowerMatrix_screen.dart';
import 'package:planit_schedule_manager/screens/calendar_screen.dart';
import 'package:planit_schedule_manager/screens/chat_screen.dart';
import 'package:planit_schedule_manager/screens/profile_screen.dart';
import 'package:planit_schedule_manager/screens/project50_screen.dart';
import 'package:planit_schedule_manager/screens/weather_task_screen.dart';
import 'package:planit_schedule_manager/services/location_service.dart';
import 'package:planit_schedule_manager/services/weather_service.dart';
import 'package:planit_schedule_manager/widgets/curved_navbar.dart';
import 'package:planit_schedule_manager/screens/home_screen.dart';
import 'package:planit_schedule_manager/utils/dialog_helper.dart';

class MainLayout extends StatefulWidget {
  final User user;

  const MainLayout({Key? key, required this.user}) : super(key: key);

  @override
  _MainLayoutState createState() => _MainLayoutState();
}


class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;
  bool _weatherScreenInitialized = false;
  late final List<Widget> _screens;
  
  @override
  void initState() {
    super.initState();
    _screens = [
      HomeScreen(user: widget.user),
      ChatScreen(),
      CalendarScreen(),
      Container(), // Placeholder for WeatherTaskScreen
      EisenhowerMatrixScreen(),
      // Project50Screen(),
      ProfileScreen(user: widget.user),
    ];
  }
  
  @override
  Widget build(BuildContext context) {
    // Initialize WeatherTaskScreen only when that tab is selected for the first time
    if (_currentIndex == 3 && !_weatherScreenInitialized) {
      _screens[3] = WeatherTaskScreen(
        weatherService: WeatherService.getInstance(OPENWEATHER_API_KEY, cacheDurationInMinutes: 90),
        locationService: LocationService(),
      );
      _weatherScreenInitialized = true;
    }
    
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: WillPopScope(
        onWillPop: () async {
          return await DialogHelper.showExitDialog(context) ?? false;
        },
        child: Scaffold(
          body: IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
          bottomNavigationBar: CurvedNavBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              FocusManager.instance.primaryFocus?.unfocus();
              setState(() {
                _currentIndex = index;
              });
            },
          ),
          extendBody: true,
        ),
      ),
    );
  }
}