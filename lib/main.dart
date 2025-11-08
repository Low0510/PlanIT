import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:planit_schedule_manager/screens/splash_screen.dart';
import 'package:planit_schedule_manager/services/notification_service.dart';
import 'package:toastification/toastification.dart';
import 'package:timezone/data/latest.dart' as tz;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();
  tz.initializeTimeZones();

  await SystemChrome.setPreferredOrientations(
    [
      DeviceOrientation.portraitUp,
    ]
  );

  await Firebase.initializeApp();

  runApp(
    const ToastificationWrapper(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        textTheme: Typography.blackCupertino.copyWith(
          bodyLarge: TextStyle(fontWeight: FontWeight.w600),
          bodyMedium: TextStyle(fontWeight: FontWeight.w600),
          bodySmall: TextStyle(fontWeight: FontWeight.w600),
        ),
        primarySwatch: Colors.indigo,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.blue[800], 
          foregroundColor: Colors.white, 
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.cyan, 
          primary: Colors.blue[400], 
          secondary: Colors.lightBlueAccent, 
        ),
      ),
      home: SplashScreen(),
    );
  }
}
