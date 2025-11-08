import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:planit_schedule_manager/screens/project50_screen.dart';
import 'package:planit_schedule_manager/services/ai_analyzer.dart';
import 'package:planit_schedule_manager/utils/task_analytics.dart';
import 'package:planit_schedule_manager/models/task.dart';
import 'package:planit_schedule_manager/screens/login_screen.dart';
import 'package:planit_schedule_manager/services/authentication_service.dart';
import 'package:planit_schedule_manager/services/schedule_service.dart';
import 'package:planit_schedule_manager/widgets/emotion_analystic_card.dart';
import 'package:planit_schedule_manager/widgets/distribution_chart.dart';
import 'package:planit_schedule_manager/widgets/month_heatmp.dart';
import 'package:planit_schedule_manager/widgets/task_countdown_picker.dart';
import 'package:planit_schedule_manager/widgets/toast.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class ProfileScreen extends StatefulWidget {
  final User user;
  const ProfileScreen({Key? key, required this.user}) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final AuthenticationService _authService = AuthenticationService();
  late TabController _tabController;
  bool _isLoading = true;
  // Map<String, dynamic> _analyticsData = {};

  late AnalyticsData _analyticsData;
  final TaskAnalytics _taskAnalytics = TaskAnalytics();
  final ScheduleService _scheduleService = ScheduleService();

  List<Task> tasks = [];

  late Map<String, dynamic> _userData = {};
  final _formKey = GlobalKey<FormState>();
  bool _isLoadingProfile = false;
  bool _isEditing = false;

  final _profileFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();

  // Controllers
  final _usernameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();

  final _statsPageController = PageController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchUserAnalytics();
    _loadUserData();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // -------------------- Load user data --------------------

  Future<void> _loadUserData() async {
    setState(() => _isLoadingProfile = true);
    try {
      final userData = await _authService.getUserData(widget.user.uid);
      print(userData);
      if (userData != null) {
        setState(() {
          _userData = userData;
          _usernameController.text = userData['username'] ?? '';
          _firstNameController.text = userData['firstName'] ?? '';
          _lastNameController.text = userData['lastName'] ?? '';
          _phoneController.text = userData['phone'] ?? '';
        });
      }
    } catch (e) {
      _showSnackBar('Error loading user data: $e');
    } finally {
      setState(() => _isLoadingProfile = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // -------------------- Function Profile Details Update --------------------

  Future<void> _updateProfile() async {
    if (!_profileFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await _authService.updateUserProfile(
        username: _usernameController.text.trim(),
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        phone: _phoneController.text.trim(),
      );
      SuccessToast.show(context, 'Profile updated successfully');
      setState(() => _isEditing = false);
      await _loadUserData();
    } catch (e) {
      ErrorToast.show(context, 'Failed to update profile: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updatePassword() async {
    // Only proceed if both password fields are filled
    if (_currentPasswordController.text.isEmpty ||
        _newPasswordController.text.isEmpty) {
      ErrorToast.show(context, 'Please enter both current and new passwords');
      return;
    }

    if (!_passwordFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await _authService.updatePassword(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );

      // Clear password fields after successful update
      _currentPasswordController.clear();
      _newPasswordController.clear();

      SuccessToast.show(context, 'Password updated successfully');
    } catch (e) {
      ErrorToast.show(context, 'Failed to update password: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }
  

  // -------------------- Function User Analytics --------------------

  List<Task> getTasksFromLast7Days(List<Task> allTasks) {
    // Get the current date without time component
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Calculate date 7 days ago
    final sevenDaysAgo = today.subtract(const Duration(days: 7));

    // Filter tasks that have a date within the last 7 days
    return allTasks.where((task) {
      // Extract just the date component from the task time for accurate comparison
      final taskDate = DateTime(task.time.year, task.time.month, task.time.day);

      // Return true if the task date is between 7 days ago and today (inclusive)
      return taskDate.isAfter(sevenDaysAgo.subtract(const Duration(days: 1))) &&
          taskDate.isBefore(today.add(const Duration(days: 1)));
    }).toList();
  }

  Future<void> _fetchUserAnalytics() async {
    setState(() => _isLoading = true);
    try {
      tasks = await _scheduleService.getSchedules().first;
      _analyticsData = await _taskAnalytics.calculateAnalytics(tasks);
      // AiAnalyzer _aiAnalyzer = AiAnalyzer();
      // final response = await _aiAnalyzer.getEnhancedTaskInsights(_analyticsData, getTasksFromLast7Days(tasks));
      setState(() {
        // print("Ai Analyzer: $response");
      });
    } catch (e) {
      print('Error fetching analytics: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  int _getTodayTasksCount() {
    // Return actual count of today's tasks
    final today = DateTime.now();
    return tasks
        .where((task) =>
            task.time.day == today.day &&
            task.time.month == today.month &&
            task.time.year == today.year)
        .length;
  }

  int _getCompletedTasksCount() {
    // Return completed tasks for today
    final today = DateTime.now();
    return tasks
        .where((task) =>
            task.done &&
            task.time.day == today.day &&
            task.time.month == today.month &&
            task.time.year == today.year)
        .length;
  }

  int _getUpcomingTasksCount() {
    // Return upcoming tasks for today
    final now = DateTime.now();
    return tasks
        .where((task) =>
            !task.done && task.time.isAfter(now) && task.time.day == now.day)
        .length;
  }

  int _getWeeklyCompletionRate() {
    // Calculate weekly completion percentage
    final weekStart =
        DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));
    final weekEnd = weekStart.add(Duration(days: 6));

    final weekTasks = tasks
        .where((task) =>
            task.time.isAfter(weekStart.subtract(Duration(days: 1))) &&
            task.time.isBefore(weekEnd.add(Duration(days: 1))))
        .toList();

    if (weekTasks.isEmpty) return 0;

    final completed = weekTasks.where((task) => task.done).length;
    return ((completed / weekTasks.length) * 100).round();
  }

  int _getOnTimePercentage() {
    // Calculate on-time completion rate
    final completedTasks = tasks.where((task) => task.done).toList();
    if (completedTasks.isEmpty) return 100;

    final onTimeTasks = completedTasks
        .where((task) =>
            task.completedAt != null &&
            task.completedAt!.isBefore(task.time.add(Duration(minutes: 15))))
        .length;

    return ((onTimeTasks / completedTasks.length) * 100).round();
  }

  int _getOverdueCount() {
    // Return count of overdue tasks
    final now = DateTime.now();
    return tasks.where((task) => !task.done && task.time.isBefore(now)).length;
  }

  // -------------------- Helper Functions --------------------

  String _getDominantMood() {
    if (_analyticsData.emotionalTrends.isEmpty) {
      return '😆'; // Default mood when no data
    }
    return _analyticsData.emotionalTrends.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  Color _getMoodColor(String mood) {
    switch (mood) {
      case '😆':
        return Colors.yellow.shade600;
      case '😍':
        return Colors.pink;
      case '🥳':
        return Colors.purple;
      case '🥴':
        return Colors.orange;
      case '😡':
        return Colors.red;
      case '😢':
        return Colors.lightBlue;
      case '😫':
        return Colors.grey;
      case '🚀':
        return Colors.blue;
      default:
        return Colors.blue;
    }
  }

  String _getMoodName(String emoji) {
    switch (emoji) {
      case '😆':
        return 'Laughing';
      case '😍':
        return 'Loving';
      case '🥳':
        return 'Celebrating';
      case '🥴':
        return 'Woozy';
      case '😡':
        return 'Angry';
      case '😢':
        return 'Sad';
      case '😫':
        return 'Exhausted';
      case '🚀':
        return 'Energetic';
      default:
        return '';
    }
  }

  String _getMoodDescription(String emoji) {
    switch (emoji) {
      case '😆':
        return 'You\'re at your best when enjoying yourself with high energy!';
      case '😍':
        return 'You\'re feeling passionate and positive about your tasks!';
      case '🥳':
        return 'Your celebratory mood brings maximum energy and productivity!';
      case '🥴':
        return 'You\'re feeling a bit overwhelmed, which might affect your focus.';
      case '😡':
        return 'Your frustration is giving you energy, but may affect quality of work.';
      case '😢':
        return 'You\'re feeling down, which is lowering your energy levels.';
      case '😫':
        return 'Your exhaustion is affecting both your mood and productivity.';
      case '🚀':
        return 'You\'re making progress with high energy and positivity!';
      default:
        return 'Keep tracking your moods to get personalized insights!';
    }
  }

  // -------------------- Build Profile Screen --------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8FAFC),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/background.png'),
            fit: BoxFit.cover,
            opacity: 0.8,
          ),
        ),
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            overscroll: false, // Disable overscroll
            physics: ClampingScrollPhysics(),
          ),
          child: CustomScrollView(
            // physics: BouncingScrollPhysics(),
            slivers: [
              // Glass Header Section
              SliverToBoxAdapter(
                child: Container(
                  margin: EdgeInsets.fromLTRB(16, 50, 16, 20),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      padding: EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(0.25),
                            Colors.white.withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          // Profile Section with Refresh Button
                          Row(
                            children: [
                              // Avatar with Glass Effect
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.white.withOpacity(0.3),
                                      Colors.white.withOpacity(0.1),
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 20,
                                      offset: Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Stack(
                                  children: [
                                    CircleAvatar(
                                      radius: 32,
                                      backgroundColor: Colors.grey[100],
                                      backgroundImage: widget.user.photoURL !=
                                              null
                                          ? NetworkImage(widget.user.photoURL!)
                                          : null,
                                      child: widget.user.photoURL == null
                                          ? Icon(
                                              Icons.person,
                                              size: 32,
                                              color: Color(0xFF64748B),
                                            )
                                          : null,
                                    ),
                                    Positioned(
                                      bottom: 2,
                                      right: 2,
                                      child: Container(
                                        width: 14,
                                        height: 14,
                                        decoration: BoxDecoration(
                                          color: Color(0xFF10B981),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: 16),
                              // Welcome Text
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Hello, ${_userData['username'] ?? 'Guest'}',
                                      style: TextStyle(
                                        color: Color(0xFF1E293B),
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Ready to conquer today?',
                                      style: TextStyle(
                                        color: Color(0xFF64748B),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Refresh Button
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.9),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.06),
                                      blurRadius: 12,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(20),
                                    onTap: () {
                                      // Add your refresh logic here
                                      _fetchUserAnalytics();
                                    },
                                    child: Padding(
                                      padding: EdgeInsets.all(10),
                                      child: Icon(
                                        Icons.refresh_rounded,
                                        size: 15,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 24),
                          // Enhanced Project 50 Button
                          _buildLiquidProject50Button(context),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            
              // Quick Stats Section
              SliverToBoxAdapter(
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 16),
                  child: buildSwipableStatsCarousel(),
                ),
              ),

              SliverToBoxAdapter(
                  child: TaskCountdownWidget(
                tasks: tasks,
                onUpdateFavourite: (taskId, favourite) async {
                  // Your existing updateFavouriteTask logic
                  await _scheduleService.updateFavouriteTask(taskId, favourite);
                },
                onUpdateLatestTasks: () {
                  _fetchUserAnalytics();
                },
              )),


           
              // Main Content Cards
              SliverToBoxAdapter(
                child: Container(
                  margin: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildMinimalGlassCard(
                        title: 'Analytics',
                        subtitle: 'Performance insights',
                        icon: Icons.analytics_outlined,
                        color: Color(0xFF6366F1),
                        onTap: () => _showBottomSheet(
                            context, 'Analytics', _buildAnalyticsTab()),
                      ),
                      SizedBox(height: 16),
                      _buildMinimalGlassCard(
                        title: 'Profile',
                        subtitle: 'Your information',
                        icon: Icons.person_outline_rounded,
                        color: Color(0xFF10B981),
                        onTap: () => _showBottomSheetForProfile('Profile',),
                      ),
                      SizedBox(height: 16),
                      _buildMinimalGlassCard(
                        title: 'Settings',
                        subtitle: 'LogOut',
                        icon: Icons.tune_rounded,
                        color: Color(0xFF8B5CF6),
                        onTap: () => _showBottomSheet(
                            context, 'Settings', _buildSettingsTab()),
                      ),
                      SizedBox(height: 62),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLiquidProject50Button(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 70,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1E293B).withOpacity(0.9),
                Color(0xFF334155).withOpacity(0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => Project50Screen()),
                );
              },
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    // Gradient Icon
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFFF6B6B), Color(0xFFFFE66D)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0xFFFF6B6B).withOpacity(0.3),
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.fitness_center_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    SizedBox(width: 16),
                    // Text Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Text(
                                'PROJECT 50',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              SizedBox(width: 8),
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Color(0xFFFF6B6B),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'NEW',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'Transform your discipline',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white.withOpacity(0.7),
                      size: 16,
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

  Widget buildTodayScheduleStats() {
    return Row(
      children: [
        Expanded(
            child: _buildStatGlass('Today\'s Tasks', '${_getTodayTasksCount()}',
                Icons.today_outlined, Color(0xFF6366F1))),
        SizedBox(width: 12),
        Expanded(
            child: _buildStatGlass('Completed', '${_getCompletedTasksCount()}',
                Icons.check_circle_outline, Color(0xFF10B981))),
        SizedBox(width: 12),
        Expanded(
            child: _buildStatGlass('Upcoming', '${_getUpcomingTasksCount()}',
                Icons.schedule_outlined, Color(0xFFFF6B6B))),
      ],
    );
  }

  Widget buildWeeklyPerformanceStats() {
    return Row(
      children: [
        Expanded(
            child: _buildStatGlass(
                'This Week',
                '${_getWeeklyCompletionRate()}%',
                Icons.trending_up_rounded,
                Color(0xFF6366F1))),
        SizedBox(width: 12),
        Expanded(
            child: _buildStatGlass('On Time', '${_getOnTimePercentage()}%',
                Icons.access_time_rounded, Color(0xFF10B981))),
        SizedBox(width: 12),
        Expanded(
            child: _buildStatGlass('Overdue', '${_getOverdueCount()}',
                Icons.warning_amber_outlined, Color(0xFFFF6B6B))),
      ],
    );
  }

  Widget buildSwipableStatsCarousel() {
    return Column(
      children: [
        SizedBox(
          height: 130,
          child: PageView(
            controller: _statsPageController,
            children: [
              // Page 1
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: buildTodayScheduleStats(),
              ),
              // Page 2
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: buildWeeklyPerformanceStats(),
              ),
            ],
          ),
        ),
        SizedBox(height: 12),

        // The dot indicator
        SmoothPageIndicator(
          controller: _statsPageController,
          count: 2,
          effect: WormEffect(
            dotHeight: 8,
            dotWidth: 8,
            activeDotColor: Color(0xFF6366F1),
            dotColor: Colors.grey.shade400,
          ),
        ),
      ],
    );
  }

  Widget _buildStatGlass(
      String title, String value, IconData icon, Color color) {
    return GestureDetector(
      onTapDown: (details) {
        _showStatHint(title, value, icon, color, details.globalPosition);
      },
      onTapUp: (details) {
        _hideStatHint();
      },
      onTapCancel: () {
        _hideStatHint();
      },
      onLongPressStart: (details) {
        _showStatHint(title, value, icon, color, details.globalPosition);
      },
      onLongPressEnd: (details) {
        _hideStatHint();
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.25),
                Colors.white.withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  OverlayEntry? _hintOverlay;

  void _showStatHint(
      String title, String value, IconData icon, Color color, Offset position) {
    _hideStatHint(); // Remove any existing overlay

    String hintText = _getHintText(title);

    // Get screen dimensions
    final screenSize = MediaQuery.of(context).size;
    final tooltipWidth = 200.0;
    final tooltipHeight = 80.0;

    // Calculate position with boundary checks
    double left = position.dx - (tooltipWidth / 2);
    double top = position.dy - tooltipHeight - 20;

    // Adjust horizontal position if it goes outside screen
    if (left < 16) {
      left = 16;
    } else if (left + tooltipWidth > screenSize.width - 16) {
      left = screenSize.width - tooltipWidth - 16;
    }

    // Adjust vertical position if it goes above screen
    if (top < 50) {
      top = position.dy + 30; // Show below finger instead
    }

    _hintOverlay = OverlayEntry(
      builder: (context) => Positioned(
        left: left,
        top: top,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: tooltipWidth,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.5),
                      Colors.white.withOpacity(0.4),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.6),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Simple content
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(icon, color: color, size: 16),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A202C),
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 8),

                    // Short hint text
                    Text(
                      hintText,
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF4A5568),
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_hintOverlay!);
  }

  void _hideStatHint() {
    _hintOverlay?.remove();
    _hintOverlay = null;
  }

  String _getHintText(String title) {
    switch (title) {
      case 'Today\'s Tasks':
        return 'Total tasks for today';

      case 'Completed':
        return 'Tasks completed today';

      case 'Upcoming':
        return 'Pending tasks for today';

      case 'This Week':
        return 'Weekly completion rate';

      case 'On Time':
        return 'Tasks completed on time';

      case 'Overdue':
        return 'Tasks past due time';

      default:
        return 'Productivity metric';
    }
  }

    Widget _buildGlassCard({
  required String title,
  required String subtitle,
  required IconData icon,
  required Color color,
  required VoidCallback onTap,
}) {
  return Container(
    decoration: BoxDecoration(
      // Enhanced gradient with more depth
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(0.25),
          Colors.white.withOpacity(0.15),
          Colors.white.withOpacity(0.08),
        ],
        stops: [0.0, 0.5, 1.0],
      ),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: Colors.white.withOpacity(0.3),
        width: 1.2,
      ),
      // Add subtle shadow for depth
      boxShadow: [
        BoxShadow(
          color: color.withOpacity(0.05),
          blurRadius: 20,
          offset: Offset(0, 8),
        ),
        BoxShadow(
          color: Colors.black.withOpacity(0.03),
          blurRadius: 10,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        splashColor: color.withOpacity(0.1),
        highlightColor: color.withOpacity(0.05),
        child: Container(
          padding: EdgeInsets.all(24),
          child: Row(
            children: [
              // Enhanced icon container with gradient
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color.withOpacity(0.2),
                      color.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: color.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Icon(
                  icon, 
                  color: color, 
                  size: 28,
                ),
              ),
              SizedBox(width: 20),
              
              // Content section
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Enhanced arrow with subtle animation feel
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Color(0xFF94A3B8),
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}



// Minimalist version
Widget _buildMinimalGlassCard({
  required String title,
  required String subtitle,
  required IconData icon,
  required Color color,
  required VoidCallback onTap,
}) {
  return Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(0.4),
          Colors.white.withOpacity(0.2),
          Colors.white.withOpacity(0.1),
        ],
      ),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: Colors.white.withOpacity(0.4),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.02),
          blurRadius: 16,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              Icon(icon, color: color, size: 24),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: color,
                  size: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
    Widget _buildAnalyticsPreview() {
      return Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Productivity Analysis',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '🧐',
                  style: TextStyle(
                    color: Color(0xFF1E293B),
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 50,
            height: 35,
            decoration: BoxDecoration(
              color: Color(0xFF6366F1).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.trending_up_rounded,
              color: Color(0xFF6366F1),
              size: 20,
            ),
          ),
        ],
      );
    }

    Widget _buildProfilePreview() {
      return Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Profile Status',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '🖋',
                  style: TextStyle(
                    color: Color(0xFF1E293B),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 50,
            height: 35,
            decoration: BoxDecoration(
              color: Color(0xFF10B981).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.person_outline_rounded,
              color: Color(0xFF10B981),
              size: 20,
            ),
          ),
        ],
      );
    }

    Widget _buildSettingsPreview() {
      return Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notifications',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '🔔',
                  style: TextStyle(
                    color: Color(0xFF1E293B),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 50,
            height: 35,
            decoration: BoxDecoration(
              color: Color(0xFF8B5CF6).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.tune_rounded,
              color: Color(0xFF8B5CF6),
              size: 20,
            ),
          ),
        ],
      );
    }

  void _showBottomSheet(BuildContext context, String title, Widget content) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white.withOpacity(0.7),
      elevation: 0,
      enableDrag: true,
      isDismissible: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 30,
              offset: Offset(0, -8),
            ),
          ],
        ),
        child: Container(
          
          decoration: BoxDecoration(
            image: DecorationImage(
                  image: AssetImage('assets/images/background.png'),
                  fit: BoxFit.cover,
                ),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withOpacity(0.9),
                Colors.white.withOpacity(0.8),
              ],
            ),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              // Header Section
              Container(
                padding: EdgeInsets.fromLTRB(24, 12, 24, 20),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.white.withOpacity(0.3),
                      width: 0.5,
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    // Drag Handle
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Color(0xFF94A3B8).withOpacity(0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    SizedBox(height: 20),

                    // Title Row
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B),
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),

                        // Close Button
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Color(0xFF64748B).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () => Navigator.pop(context),
                              child: Icon(
                                Icons.close_rounded,
                                color: Color(0xFF64748B),
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Content Area
              Expanded(
                child: Container(
                  width: double.infinity,
                  child: content,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBottomSheetForProfile(String title) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white.withOpacity(0.7),
    elevation: 0,
    enableDrag: true,
    isDismissible: true,
    builder: (context) => StatefulBuilder(  // Add this wrapper
      builder: (BuildContext context, StateSetter setModalState) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 30,
                offset: Offset(0, -8),
              ),
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/background.png'),
                fit: BoxFit.cover,
              ),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withOpacity(0.9),
                  Colors.white.withOpacity(0.8),
                ],
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(28),
                topRight: Radius.circular(28),
              ),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                // Header Section
                Container(
                  padding: EdgeInsets.fromLTRB(24, 12, 24, 20),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.white.withOpacity(0.3),
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Drag Handle
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Color(0xFF94A3B8).withOpacity(0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      SizedBox(height: 20),
                      // Title Row
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E293B),
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                          // Close Button
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Color(0xFF64748B).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () => Navigator.pop(context),
                                child: Icon(
                                  Icons.close_rounded,
                                  color: Color(0xFF64748B),
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Content Area - Pass the setModalState to your content
                Expanded(
                  child: Container(
                    width: double.infinity,
                    child: _buildProfileTabForBottomSheet(setModalState), // Modified content
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}


  // -------------------- Build Profile Tab --------------------

  Widget _buildAnalyticsTab() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _fetchUserAnalytics();
        setState(() {});
      },
      child: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOverviewSection(),
          ],
        ),
      ),
    );
  }

  // -------------------- Progress Overview -------------------
  Widget _buildOverviewSection() {
    // Calculate metrics using all tasks rather than just recent ones
    // We'll assume these metrics are calculated from the full data set in the analytics service
    final int totalTasks =
        _analyticsData.taskTrends.values.fold(0, (sum, count) => sum + count);
    final int completedTasks =
        (totalTasks * _analyticsData.completionRate / 100).round();
    final String avgCompletionTime =
        _formatCompletionTime(_analyticsData.averageCompletionTime);

    return Container(
      margin: EdgeInsets.symmetric(vertical: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with animation
          Row(
            children: [
              Icon(Icons.insights,
                  size: 28, color: Theme.of(context).primaryColor),
              SizedBox(width: 10),
              Text(
                'Your Progress Overview',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              Spacer(),
              _buildRefreshButton(),
            ],
          ),
          SizedBox(height: 20),

          // Main progress circular indicators
          Row(
            children: [
              Expanded(
                child: _buildProgressCard(
                  'Tasks Completed',
                  _analyticsData.completionRate / 100,
                  '${_analyticsData.completionRate.toStringAsFixed(0)}%',
                  '$completedTasks of $totalTasks total',
                  Colors.green,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: _buildProgressCard(
                  'Productivity Score',
                  _analyticsData.averageProductivity / 100,
                  '${_analyticsData.averageProductivity.toStringAsFixed(0)}%',
                  _getProductivityMessage(_analyticsData.averageProductivity),
                  Colors.blue,
                ),
              ),
            ],
          ),
          SizedBox(height: 24),

          // Task distribution by category
          DistributionChart(
            distributionData: _analyticsData.priorityDistribution,
            title: 'Priority Distribution',
          ),
          SizedBox(height: 24),
          // Task distribution by category
          DistributionChart(
              distributionData: _analyticsData.categoryDistribution,
              title: 'Category Distribution'),

          SizedBox(height: 24),

          _buildDetailedMetricsCard(),

          // Achievement badge (if applicable)
          if (_analyticsData.completionRate > 70) _buildAchievementBadge(),

          // Weekly trend
          SizedBox(height: 24),
          Card(
            color: Colors.white.withOpacity(0.75),
            elevation: 3,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Weekly Task Trend (7 Days)',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: _buildWeeklyTrendChart(),
                  ),
                  SizedBox(height: 8),
                  Text(
                    _getWeeklyTrendInsight(),
                    style: TextStyle(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          _buildMonthlyHeatmap(),
          SizedBox(
            height: 20,
          ),
          _buildProductivityInsights(),
          SizedBox(height: 16),
          _buildMoodSummaryCard(),
          SizedBox(height: 16),
          // ProductivityMoodInsightsWidget(
          //   emotionalProductivity: _analyticsData.emotionalProductivity,
          //   emotionScores: TaskAnalytics.emotionScores,
          // ),
          // SizedBox(height: 16),
          SizedBox(height: 66),
        ],
      ),
    );
  }

  Widget _buildProgressCard(
    String title,
    double progress,
    String value,
    String subtitle,
    Color color, {
    IconData? icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.25),
            Colors.white.withOpacity(0.1),
          ],
        ),
        border: Border.all(
          color: color.withOpacity(0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with icon and title
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Container(
                    padding: EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: color.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      icon,
                      color: color.withOpacity(0.9),
                      size: 16,
                    ),
                  ),
                  SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.black.withOpacity(0.85),
                      letterSpacing: 0.3,
                    ),
                    textAlign: TextAlign.center,
                    // maxLines: 1,
                    // overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            SizedBox(height: 16),

            _buildCircularProgressSection(progress, value, color),

            SizedBox(height: 12),

            // Compact subtitle
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.black.withOpacity(0.7),
                letterSpacing: 0.2,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircularProgressSection(
      double progress, String value, Color color) {
    return Container(
      height: 100,
      width: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.3),
            Colors.white.withOpacity(0.1),
          ],
        ),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.15),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Stack(
            children: [
              SizedBox(
                height: 100,
                width: 100,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 8,
                  backgroundColor: Colors.white.withOpacity(0.25),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    color.withOpacity(0.9),
                  ),
                  strokeCap: StrokeCap.round,
                ),
              ),
              Center(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.black.withOpacity(0.9),
                    shadows: [
                      Shadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 6,
                      ),
                      Shadow(
                        color: Colors.white.withOpacity(0.6),
                        blurRadius: 2,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailedMetricsCard() {
    final int totalTasks =
        _analyticsData.taskTrends.values.fold(0, (sum, count) => sum + count);
    final int completedTasks =
        (totalTasks * _analyticsData.completionRate / 100).round();
    final String avgCompletionTime =
        _formatCompletionTime(_analyticsData.averageCompletionTime);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.3),
            Colors.white.withOpacity(0.15),
            Colors.white.withOpacity(0.05),
          ],
          stops: [0.0, 0.5, 1.0],
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.8),
            blurRadius: 8,
            offset: Offset(-2, -2),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.25),
              Colors.white.withOpacity(0.1),
            ],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with enhanced styling
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.blue.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      Icons.analytics_outlined,
                      color: Colors.blue.withOpacity(0.8),
                      size: 20,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Detailed Metrics',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.black.withOpacity(0.85),
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),

              SizedBox(height: 24),

              // First row of metrics
              Row(
                children: [
                  Expanded(
                    child: _buildEnhancedDetailMetric(
                      Icons.check_circle_outline,
                      '$completedTasks',
                      'Tasks Completed',
                      Colors.green,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: _buildEnhancedDetailMetric(
                      Icons.pending_actions,
                      '${totalTasks - completedTasks}',
                      'Tasks Pending',
                      Colors.orange,
                    ),
                  ),
                ],
              ),

              SizedBox(height: 20),

              // Second row of metrics
              Row(
                children: [
                  Expanded(
                    child: _buildEnhancedDetailMetric(
                      Icons.timer_outlined,
                      avgCompletionTime,
                      'Avg. Completion Time',
                      Colors.purple,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: _buildEnhancedDetailMetric(
                      Icons.trending_up,
                      _getMostProductiveTime(),
                      'Most Productive Time',
                      Colors.blue,
                    ),
                  ),
                ],
              ),

              SizedBox(height: 20),

              // Third row of metrics
              Row(
                children: [
                  Expanded(
                    child: _buildEnhancedDetailMetric(
                      Icons.priority_high,
                      _getMostCommonPriority(),
                      'Most Common Priority',
                      Colors.red,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: _buildEnhancedDetailMetric(
                      Icons.mood_outlined,
                      _getMostCommonEmotion(),
                      'Most Common Feeling',
                      Colors.amber,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

// Enhanced metric item with liquid glass effect
  Widget _buildEnhancedDetailMetric(
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.4),
            Colors.white.withOpacity(0.2),
          ],
        ),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon with enhanced styling
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: color.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              color: color.withOpacity(0.8),
              size: 24,
            ),
          ),

          SizedBox(height: 12),

          // Value with enhanced styling
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color.withOpacity(0.9),
              letterSpacing: 0.2,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          SizedBox(height: 6),

          // Label with enhanced styling
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.black.withOpacity(0.7),
              letterSpacing: 0.1,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildRefreshButton() {
    return IconButton(
      icon: Icon(Icons.refresh, color: Colors.grey[600]),
      onPressed: () async {
        await _fetchUserAnalytics();
        setState(() {});
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text('Refreshing analytics data...')),
        // );
        SuccessToast.show(context, 'Refreshing analytics data...');
        // Call your refresh method
      },
      tooltip: 'Refresh analytics',
    );
  }

  Widget _buildAchievementBadge() {
    return Container(
      margin: EdgeInsets.only(top: 24),
      child: Card(
        elevation: 3,
        color: Colors.amber[50],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.amber, width: 1),
        ),
        child: Padding(
          padding: EdgeInsets.all(1),
          child: Row(
            children: [
              // Icon(Icons.emoji_events, color: Colors.amber, size: 40),
              Lottie.asset(
                'assets/lotties/archive.json',
                width: 120,
                height: 120,
              ),
              // SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'High Achiever!',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber[800],
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'You\'ve completed over 70% of your tasks. Keep up the great work!',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.amber[800],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatCompletionTime(double hours) {
    if (hours < 1) {
      return '${(hours * 60).round()} min';
    } else if (hours < 24) {
      return '${hours.round()} hr';
    } else {
      return '${(hours / 24).toStringAsFixed(1)} days';
    }
  }

  String _getProductivityMessage(double score) {
    if (score >= 80) return 'Exceptional!';
    if (score >= 60) return 'Very good';
    if (score >= 40) return 'Good progress';
    return 'Building momentum';
  }

  String _getMostProductiveTime() {
    final timeData = _analyticsData.timeOfDayDistribution;
    String mostProductiveTime = 'Morning';
    int highestCount = 0;

    timeData.forEach((time, count) {
      if (count > highestCount) {
        highestCount = count;
        mostProductiveTime = time.split(' ')[0];
      }
    });

    return mostProductiveTime;
  }

  String _getMostCommonPriority() {
    final priorityData = _analyticsData.priorityDistribution;
    String mostCommonPriority = 'Medium';
    int highestCount = 0;

    priorityData.forEach((priority, count) {
      if (count > highestCount) {
        highestCount = count;
        mostCommonPriority = priority;
      }
    });

    return mostCommonPriority;
  }

  String _getMostCommonEmotion() {
    final emotionData = _analyticsData.emotionalTrends;
    String mostCommonEmotion = '😊';
    double highestValue = 0;

    emotionData.forEach((emotion, value) {
      if (value > highestValue) {
        highestValue = value;
        mostCommonEmotion = emotion;
      }
    });

    return mostCommonEmotion;
  }

  Widget _buildMonthlyHeatmap() {
    return MonthlyTaskHeatmap(
      taskTrends: _analyticsData.taskTrends,
      baseColor: Theme.of(context).primaryColor,
      title: 'Monthly Task Activity',
    );
  }

  Widget _buildWeeklyTrendChart() {
    // Generate the last 7 days regardless of whether we have data for them
    final now = DateTime.now();
    final List<DateTime> last7Days = [];

    // Generate dates for the last 7 days
    for (int i = 6; i >= 0; i--) {
      // Create date for each of the last 7 days (including today)
      final date = DateTime(now.year, now.month, now.day - i);
      last7Days.add(date);
    }

    final List<FlSpot> spots = [];

    // Create spots for the line chart
    for (int i = 0; i < last7Days.length; i++) {
      final date = last7Days[i];
      // Use 0 if no data exists for this date
      final count = _analyticsData.taskTrends[date] ?? 0;
      spots.add(FlSpot(i.toDouble(), count.toDouble()));
    }

    // Calculate max Y value for chart scaling
    final maxY = spots.isEmpty
        ? 10.0
        : (spots.map((spot) => spot.y).reduce((a, b) => a > b ? a : b) * 1.2)
            .clamp(5.0, double.infinity);

    return LineChart(
      LineChartData(
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Theme.of(context).primaryColor,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: Theme.of(context).primaryColor,
                  strokeWidth: 1,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: Theme.of(context).primaryColor.withOpacity(0.2),
            ),
          ),
        ],
        minY: 0,
        maxY: maxY,
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Text(
                    '${value.toInt()}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1, // Ensure we only show labels at integer positions
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < last7Days.length) {
                  final date = last7Days[index];
                  // Format date as day/month
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        '${date.day}/${date.month}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          rightTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: 2,
        ),
        borderData: FlBorderData(
          show: false,
        ),
      ),
    );
  }

  String _getWeeklyTrendInsight() {
    // Generate the last 7 days
    final now = DateTime.now();
    final List<DateTime> last7Days = [];

    for (int i = 6; i >= 0; i--) {
      final date = DateTime(now.year, now.month, now.day - i);
      last7Days.add(date);
    }

    if (last7Days.length < 3) {
      return "Add more tasks to see trend insights";
    }

    // Calculate trend using a more robust approach (last 3 days vs previous 3 days)
    final recent3Days = last7Days.sublist(last7Days.length - 3);
    final previous3Days = last7Days.length >= 6
        ? last7Days.sublist(last7Days.length - 6, last7Days.length - 3)
        : last7Days.sublist(0, last7Days.length - 3);

    double recentSum = 0;
    for (var date in recent3Days) {
      recentSum += _analyticsData.taskTrends[date] ?? 0;
    }

    double previousSum = 0;
    for (var date in previous3Days) {
      previousSum += _analyticsData.taskTrends[date] ?? 0;
    }

    final recentAvg = recentSum / 3;
    final previousAvg =
        previousSum == 0 ? 0.1 : previousSum / 3; // Avoid division by zero

    if (recentAvg > previousAvg * 1.2) {
      return "Your task creation is trending upward. Great momentum!";
    } else if (previousAvg > recentAvg * 1.2) {
      return "Your task creation is trending downward. Looking for a break?";
    } else {
      return "Your task creation is staying consistent. Steady progress!";
    }
  }
  // -------------------------- Productivity Insights --------------------------

  Widget _buildProductivityInsights() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          color: Colors.white.withOpacity(0.75),
          elevation: 4,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Most Productive Time',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16),
                SizedBox(
                  height: 180,
                  child: _buildTimeDistributionChart(),
                ),
                SizedBox(height: 16),
                _buildProductivityTip(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeDistributionChart() {
    final data = _analyticsData.timeOfDayDistribution;
    final maxValue = data.values
        .reduce((curr, next) => curr > next ? curr : next)
        .toDouble();

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxValue,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            tooltipBgColor: Colors.blueGrey.withOpacity(0.9),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${rod.toY.round()} tasks',
                TextStyle(color: Colors.white),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                final timeSlots = data.keys.toList();
                if (value.toInt() < timeSlots.length) {
                  return Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      timeSlots[value.toInt()].split(' ')[0],
                      style: TextStyle(fontSize: 12),
                    ),
                  );
                }
                return Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: data.entries
            .map((e) => BarChartGroupData(
                  x: data.keys.toList().indexOf(e.key),
                  barRods: [
                    BarChartRodData(
                      toY: e.value.toDouble(),
                      color: Colors.blue.withOpacity(0.8),
                      width: 16,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ))
            .toList(),
      ),
    );
  }

  Widget _buildProductivityTip() {
    final timeDistribution = _analyticsData.timeOfDayDistribution;
    final isDataEmpty = timeDistribution.values.every((value) => value == 0);

    if (isDataEmpty) {
      return Center(
        child: Text(
          'No productivity data available',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
        ),
      );
    }

    final mostProductiveTime = _analyticsData.timeOfDayDistribution.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key
        .split(' ')[0];

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.tips_and_updates, color: Colors.amber),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'You seem to be most productive during $mostProductiveTime. Try scheduling important tasks during this time!',
              style: TextStyle(color: Colors.grey[800]),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------- Mood Insight --------------------------

  Widget _buildMoodSummaryCard() {
    final dominantMood = _getDominantMood();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white.withOpacity(0.75),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _getMoodColor(dominantMood).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    dominantMood,
                    style: TextStyle(fontSize: 32),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Dominant Mood',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        _getMoodDescription(dominantMood),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            _buildMoodProgressBars(),
          ],
        ),
      ),
    );
  }

  Widget _buildMoodProgressBars() {
    final sortedMoods = _analyticsData.emotionalTrends.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      children: sortedMoods.take(4).map((entry) {
        return Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${entry.key} ${_getMoodName(entry.key)}',
                    style: TextStyle(fontSize: 14),
                  ),
                  Text(
                    '${entry.value.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _getMoodColor(entry.key),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4),
              LinearProgressIndicator(
                value: entry.value / 100,
                backgroundColor: Colors.grey[200],
                color: _getMoodColor(entry.key),
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // -------------------- Build Profile Tab --------------------

  Widget _buildProfileTabForBottomSheet(StateSetter setModalState) {
  final colorScheme = Theme.of(context).colorScheme;

  if (_isLoadingProfile) {
    return Center(child: CircularProgressIndicator());
  }

  return SingleChildScrollView(
    padding: EdgeInsets.symmetric(horizontal: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: 24),
        Card(
          elevation: 0,
          color: Colors.white.withOpacity(0.8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: colorScheme.outlineVariant,
              width: 1,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Form(
              key: _profileFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Personal Information',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      // Modified edit button for bottom sheet
                      IconButton(
                        icon: Icon(_isEditing ? Icons.close : Icons.edit),
                        onPressed: () {
                          setModalState(() {  // Use setModalState instead of setState
                            _isEditing = !_isEditing;
                            if (_isEditing) {
                              // Initialize controllers
                              _usernameController.text = _userData['username'] ?? '';
                              _firstNameController.text = _userData['firstName'] ?? '';
                              _lastNameController.text = _userData['lastName'] ?? '';
                              _phoneController.text = _userData['phone'] ?? '';
                            }
                          });
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: 24),
                  AnimatedSwitcher(
                    duration: Duration(milliseconds: 300),
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: child,
                      );
                    },
                    child: _isEditing ? _buildEditForm(setModalState) : _buildProfileInfo(),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(height: 24),

          // Security Section
          Card(
            elevation: 0,
            color: Colors.white.withOpacity(0.8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: colorScheme.outlineVariant,
                width: 1,
              ),
            ),
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Form(
                key: _passwordFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.security,
                          color: colorScheme.primary,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Security',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ],
                    ),
                    SizedBox(height: 24),
                    _buildTextField(
                      controller: _currentPasswordController,
                      label: 'Current Password',
                      icon: Icons.lock_outline,
                      obscureText: true,
                      validator: (value) {
                        if (_newPasswordController.text.isNotEmpty &&
                            (value == null || value.isEmpty)) {
                          return 'Please enter your current password';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    _buildTextField(
                      controller: _newPasswordController,
                      label: 'New Password',
                      icon: Icons.lock,
                      obscureText: true,
                      validator: (value) {
                        if (value?.isEmpty ?? true) return null;
                        if ((value?.length ?? 0) < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: Icon(Icons.update),
                        label: Text('Update Password'),
                        onPressed: _updatePassword,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          SizedBox(height: 24),
      ],
    ),
  );
}

  Widget _buildEditForm(StateSetter setModalState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTextField(
          controller: _firstNameController,
          label: 'First Name',
          icon: Icons.person_outline,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your first name';
            }
            return null;
          },
        ),
        SizedBox(height: 16),
        _buildTextField(
          controller: _lastNameController,
          label: 'Last Name',
          icon: Icons.person_outline,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your last name';
            }
            return null;
          },
        ),
        SizedBox(height: 16),
        _buildTextField(
          controller: _usernameController,
          label: 'Username',
          icon: Icons.alternate_email,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a username';
            }
            return null;
          },
        ),
        SizedBox(height: 16),
        _buildTextField(
          controller: _phoneController,
          label: 'Phone',
          icon: Icons.phone,
          keyboardType: TextInputType.phone,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your phone number';
            }
            return null;
          },
        ),
        SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: Icon(Icons.cancel),
                label: Text('Cancel'),
                onPressed: () {
                  setModalState(() {
                    _isEditing = false;
                    // Reset controllers to original values
                    _usernameController.text = _userData['username'] ?? '';
                    _firstNameController.text = _userData['firstName'] ?? '';
                    _lastNameController.text = _userData['lastName'] ?? '';
                    _phoneController.text = _userData['phone'] ?? '';
                  });
                },
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: Icon(Icons.save),
                label: Text('Save'),
                onPressed: _updateProfile,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProfileInfo() {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        _buildInfoItem(
          icon: Icons.person_outline,
          title: 'Name',
          value:
              '${_userData['firstName'] ?? ''} ${_userData['lastName'] ?? ''}',
        ),
        Divider(height: 32),
        _buildInfoItem(
          icon: Icons.alternate_email,
          title: 'Username',
          value: _userData['username'] ?? '',
        ),
        Divider(height: 32),
        _buildInfoItem(
          icon: Icons.email,
          title: 'Email',
          value: widget.user.email ?? '',
        ),
        Divider(height: 32),
        _buildInfoItem(
          icon: Icons.phone,
          title: 'Phone',
          value: _userData['phone'] ?? '',
        ),
        Divider(height: 32),
        _buildInfoItem(
          icon: Icons.calendar_today,
          title: 'Registered Since',
          value: DateFormat.yMMMd().format(widget.user.metadata.creationTime!),
        ),
      ],
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String title,
    required String value,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: colorScheme.primary,
            size: 20,
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: 4),
              Text(
                value.isNotEmpty ? value : 'Not provided',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAnimatedEditButton() {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      height: 40,
      width: 40,
      decoration: BoxDecoration(
        color: _isEditing
            ? Colors.red.withOpacity(0.1)
            : Theme.of(context).colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        icon: Icon(
          _isEditing ? Icons.close : Icons.edit,
          color:
              _isEditing ? Colors.red : Theme.of(context).colorScheme.primary,
          size: 20,
        ),
        onPressed: () => setState(() => _isEditing = !_isEditing),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: colorScheme.primary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        filled: true,
        fillColor: colorScheme.surfaceVariant.withOpacity(0.3),
      ),
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
    );
  }

  // -------------------- Build Settings Tab --------------------

  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  title: Text('Log Out'),
                  leading: Icon(Icons.exit_to_app, color: Colors.red),
                  onTap: () async {
                    await FirebaseAuth.instance.signOut();
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (context) => LoginScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
