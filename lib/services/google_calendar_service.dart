import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:http/http.dart' as http;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';


class GoogleCalendarService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'https://www.googleapis.com/auth/calendar',
      'https://www.googleapis.com/auth/calendar.events',
    ],
  );

  GoogleSignInAccount? _currentUser;
  calendar.CalendarApi? _calendarApi;
  auth.AuthClient? _authClient;

  GoogleCalendarService() {
    _initialize();
  }

  void _initialize() {
    _googleSignIn.onCurrentUserChanged.listen((GoogleSignInAccount? account) async {
      _currentUser = account;
      if (account != null) {
        await _setupAuthClient();
      } else {
        _authClient = null;
        _calendarApi = null;
      }
    });
    _googleSignIn.signInSilently().then((account) {
      if (account != null) {
        _currentUser = account;
        _setupAuthClient();
      }
    });
  }

  Future<void> _setupAuthClient() async {
    try {
      _authClient = await _googleSignIn.authenticatedClient();
      if (_authClient != null) {
        _calendarApi = calendar.CalendarApi(_authClient!);
        print('Successfully authenticated and initialized Calendar API');
      } else {
        print('Failed to obtain authenticated client');
      }
    } catch (e) {
      print('Error setting up auth client: $e');
      _authClient = null;
      _calendarApi = null;
    }
  }

  Future<bool> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account != null) {
        _currentUser = account;
        await _setupAuthClient();
        return true;
      }
      return false;
    } catch (e) {
      print('Sign-in error: $e');
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      _currentUser = null;
      _authClient = null;
      _calendarApi = null;
      print('Signed out successfully');
    } catch (e) {
      print('Sign-out error: $e');
    }
  }

  bool get isSignedIn => _currentUser != null && _calendarApi != null;

  Future<List<calendar.Event>> getEvents({
    DateTime? startTime,
    DateTime? endTime,
    String calendarId = 'primary',
  }) async {
    if (!isSignedIn) {
      throw Exception('User is not signed in or Calendar API is not initialized');
    }

    try {
      final events = await _calendarApi!.events.list(
        calendarId,
        timeMin: startTime?.toUtc(),
        timeMax: endTime?.toUtc(),
        singleEvents: true,
        orderBy: 'startTime',
      );
      return events.items ?? [];
    } catch (e) {
      print('Error fetching events: $e');
      if (e is calendar.DetailedApiRequestError && e.status == 401) {
        await signOut();
        throw Exception('Authentication failed. Please sign in again.');
      }
      throw Exception('Failed to fetch events: $e');
    }
  }

  Future<calendar.Event?> createEvent({
    required String summary,
    String? description,
    required DateTime startTime,
    required DateTime endTime,
    String calendarId = 'primary',
  }) async {
    if (!isSignedIn) {
      throw Exception('User is not signed in or Calendar API is not initialized');
    }

    final event = calendar.Event()
      ..summary = summary
      ..description = description
      ..start = (calendar.EventDateTime()..dateTime = startTime.toUtc())
      ..end = (calendar.EventDateTime()..dateTime = endTime.toUtc());

    try {
      final createdEvent = await _calendarApi!.events.insert(event, calendarId);
      print('Event created: ${createdEvent.summary}');
      return createdEvent; 
    } catch (e) {
      print('Error creating event: $e');
      throw Exception('Failed to create event: $e');
    }
  }
}
