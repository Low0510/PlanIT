import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:planit_schedule_manager/services/schedule_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthenticationService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Email and Password Login
  Future<User?> login(String email, String password) async {
    try {
      UserCredential userCredential =
          await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user; // Return the user object
    } catch (e) {
      return null; // Return null if there is an error
    }
  }

  // Email and Password Register
  Future<User?> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String username,
    required String phone,
  }) async {
    try {
      UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;
      if (user != null) {
        // Save user details to Firestore
        await _firestore.collection('users').doc(user.uid).set({
          'firstName': firstName,
          'lastName': lastName,
          'username': username,
          'email': email,
          'phone': phone,
          'geminiApiKey': '',
          'createdAt': FieldValue.serverTimestamp(), // Registration timestamp
        });

        // Call _createDefaultTasks to set up initial tasks
        await _createDefaultTasks(user);

        return user;
      } else {
        throw Exception('Registration failed');
      }
    } catch (e) {
      print(e.toString());
      rethrow;
    }
  }

  // Fetch user data from Firestore
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(uid).get();
      if (userDoc.exists) {
        return userDoc.data() as Map<String, dynamic>;
      }
    } catch (e) {
      print('Error fetching user data: $e');
    }
    return null;
  }

  // Update user data in Firestore
  Future<void> updateUserData(String uid, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('users').doc(uid).update(data);
    } catch (e) {
      print('Error updating user data: $e');
      throw Exception('Failed to update user data');
    }
  }

  Future<bool> checkFirstTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('first_time') ?? true;
  }

  Future<void> setFirstTimeFalse() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('first_time', false);
  }

  Future<bool> checkUserLoginStatus() async {
    final User? user = _firebaseAuth.currentUser;
    return user != null;
  }

  // Google Sign In
  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      final GoogleSignInAuthentication? googleAuth =
          await googleUser?.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth?.accessToken,
        idToken: googleAuth?.idToken,
      );

      UserCredential userCredential =
          await _firebaseAuth.signInWithCredential(credential);
      User? user = userCredential.user;

      if (user != null) {
        // Check if the user already exists in Firestore
        DocumentSnapshot userDoc =
            await _firestore.collection('users').doc(user.uid).get();

        if (!userDoc.exists) {
          // Add the user details to Firestore if they don't already exist
          await _firestore.collection('users').doc(user.uid).set({
            'firstName': user.displayName?.split(' ')?.first ?? '',
            'lastName': user.displayName?.split(' ')?.last ?? '',
            'email': user.email,
            'username': user.displayName,
            'phone': '',
            'createdAt': FieldValue.serverTimestamp(),
          });

          // Create default tasks for new users
          await _createDefaultTasks(user);
        }
      }

      return user;
    } catch (e) {
      print(e.toString());
      return null;
    }
  }

  Future<void> _createDefaultTasks(User user) async {
    final ScheduleService scheduleService = ScheduleService();

    // Welcome and Basic Controls
    await scheduleService.addSchedule(
      title:
          "👋 Welcome to PlanIT - Swipe the Task Left to Complete, Right to Delete",
      category: "Getting Started",
      url: "",
      placeURL: "",
      time: DateTime.now().add(const Duration(minutes: 5)),
      subtasks: [],
      priority: "High",
      isRepeated: false,
      repeatInterval: "",
      repeatedIntervalTime: 0,
      emotion: "🚀",
    );

    // Fun feature
    await scheduleService.addSchedule(
      title: "🎉 Unlock Interactive Features: Shake & Challenge!",
      category: "Getting Started",
      url: "",
      placeURL: "",
      time: DateTime.now().add(const Duration(hours: 2)),
      subtasks: [
        "**Quick Task Access:** Try shaking your phone! It's a fun shortcut to fetch your next or a random important task.",
        "**Personal Growth:** Explore 'Project 50 Challenges' designed to inspire and motivate."
      ],
      priority: "Medium",
      isRepeated: false,
      repeatInterval: "",
      repeatedIntervalTime: 0,
      emotion: "🥳",
    );

    // Weather Integration
    await scheduleService.addSchedule(
      title: "🌤️ Smart Weather Planning - Schedule Based on Weather Forecast",
      category: "Features",
      url: "",
      placeURL: "",
      time: DateTime.now().add(const Duration(hours: 1)),
      subtasks: [],
      priority: "Medium",
      isRepeated: false,
      repeatInterval: "",
      repeatedIntervalTime: 0,
    );

    // Recurring Tasks
    await scheduleService.addSchedule(
      title: "⏰ Set Up Recurring Tasks with Smart Notifications",
      category: "Features",
      url: "",
      placeURL: "",
      time: DateTime.now().add(const Duration(hours: 4)),
      subtasks: [],
      priority: "Low",
      isRepeated: true,
      repeatInterval: "Daily",
      repeatedIntervalTime: 2,
    );
    await scheduleService.addSchedule(
      title: "💫 Double Tap Tasks to Share Your Feelings!",
      category: "Features",
      url: "",
      placeURL: "",
      time: DateTime.now().add(const Duration(hours: 3, minutes: 30)),
      subtasks: [
        "😆 Enjoying the task with a sense of humor",
        "😍 Loving the task and feeling inspired",
        "🥳 Celebrating the completion of milestones",
        "🥴 Mark tasks that feel overwhelming",
        "😡 Express frustration with challenging tasks",
        "😢 Show tasks that feel emotionally difficult",
        "😫 Indicate tasks that feel urgent and pressing",
        "🚀 Share your excitement about progress",
      ],
      priority: "Medium",
      isRepeated: false,
      repeatInterval: "",
      repeatedIntervalTime: 0,
    );

    await scheduleService.addSchedule(
      title: "📝 Help Us Make PlanIT Better - Share Your Feedback",
      category: "Community",
      url: "https://forms.gle/dxXj9CyszKWY4LQo8",
      placeURL: "",
      time: DateTime.now().add(const Duration(hours: 5)),
      subtasks: [
        "Rate your overall experience with PlanIT",
        "Tell us what features you love most",
        "Suggest new features you'd like to see",
        "Report any bugs or issues you've encountered",
        "Share ideas for making task management more fun"
      ],
      priority: "High",
      isRepeated: false,
      repeatInterval: "",
      repeatedIntervalTime: 0,
      emotion: "😍",
    );

// Chatbot Guide
    await scheduleService.addSchedule(
      title: "🤖 Master Your AI Assistant - Learn All the Cool Commands",
      category: "Getting Started",
      url: "",
      placeURL: "",
      time: DateTime.now().add(const Duration(hours: 6)),
      subtasks: [
        "🎤 Try voice commands - just speak naturally!",
        "➕ Say 'Add task' to create new tasks quickly",
        "🗑️ Use 'Delete task' to remove completed items",
        "✏️ Ask to 'Edit my task' to make changes easily",
        "⏰ Ask 'When am I free?' to discover open time slots",
        "📅 Say 'What's my schedule?' for today's overview",
        "💡 Ask 'Help me plan' for smart suggestions",
      ],
      priority: "Medium",
      isRepeated: false,
      repeatInterval: "",
      repeatedIntervalTime: 0,
    );
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  Future<User?> getCurrentUser() async {
    return _firebaseAuth.currentUser;
  }

  Future<String> getCurrentUserUsername() async {
    final userData = await getUserData(_firebaseAuth.currentUser!.uid);

    return userData?['username'] ?? _firebaseAuth.currentUser!.email ?? '';
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth Error: ${e.code} - ${e.message}');
      switch (e.code) {
        case 'user-not-found':
          throw Exception('No user found with this email address.');
        case 'invalid-email':
          throw Exception('Invalid email address format.');
        case 'too-many-requests':
          throw Exception('Too many requests. Please try again later.');
        default:
          throw Exception('Failed to send reset email: ${e.message}');
      }
    } catch (e) {
      print('General Error: $e');
      throw Exception('An unexpected error occurred. Please try again.');
    }
  }

  Future<void> updateUserProfile({
    String? username,
    String? firstName,
    String? lastName,
    String? phone,
  }) async {
    try {
      User? user = _firebaseAuth.currentUser;
      if (user != null) {
        Map<String, dynamic> updateData = {};

        // Only add fields that are provided and not null
        if (username != null) updateData['username'] = username;
        if (firstName != null) updateData['firstName'] = firstName;
        if (lastName != null) updateData['lastName'] = lastName;
        if (phone != null) updateData['phone'] = phone;

        updateData['updatedAt'] = FieldValue.serverTimestamp();

        await _firestore.collection('users').doc(user.uid).update(updateData);
      } else {
        throw Exception('No user logged in');
      }
    } catch (e) {
      print('Error updating profile: $e');
      throw Exception('Failed to update profile');
    }
  }

  // Update user's password
  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      User? user = _firebaseAuth.currentUser;
      if (user != null && user.email != null) {
        // Re-authenticate user before password change
        AuthCredential credential = EmailAuthProvider.credential(
          email: user.email!,
          password: currentPassword,
        );

        await user.reauthenticateWithCredential(credential);
        await user.updatePassword(newPassword);
      } else {
        throw Exception('No user logged in or no email associated');
      }
    } catch (e) {
      print('Error updating password: $e');
      if (e is FirebaseAuthException) {
        switch (e.code) {
          case 'wrong-password':
            throw Exception('Current password is incorrect');
          case 'weak-password':
            throw Exception('New password is too weak');
          default:
            throw Exception('Failed to update password: ${e.message}');
        }
      }
      throw Exception('Failed to update password');
    }
  }

  // Delete user account
  Future<void> deleteAccount() async {
    try {
      User? user = _firebaseAuth.currentUser;
      if (user != null) {
        // Delete user data from Firestore first
        await _firestore.collection('users').doc(user.uid).delete();

        // Delete Chat
        await _firestore.collection('chats').doc(user.uid).delete();

        // Delete the user authentication account
        await user.delete();

        // Sign out after deletion
        await _firebaseAuth.signOut();
      } else {
        throw Exception('No user logged in');
      }
    } catch (e) {
      print('Error deleting account: $e');
      if (e is FirebaseAuthException) {
        if (e.code == 'requires-recent-login') {
          throw Exception('Please log in again before deleting your account');
        }
      }
      throw Exception('Failed to delete account');
    }
  }
}
