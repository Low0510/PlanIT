import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;

class ProductivityMoodInsightsWidget extends StatefulWidget {
  final Map<String, double> emotionalProductivity;
  final Map<String, Map<String, double>> emotionScores;
  final Map<String, int> moodFrequency; // How often each mood is experienced
  final List<Map<String, dynamic>> recentTasks; // Recent task data for trends

  const ProductivityMoodInsightsWidget({
    Key? key,
    required this.emotionalProductivity,
    required this.emotionScores,
    this.moodFrequency = const {},
    this.recentTasks = const [],
  }) : super(key: key);

  @override
  State<ProductivityMoodInsightsWidget> createState() => _ProductivityMoodInsightsWidgetState();
}

class _ProductivityMoodInsightsWidgetState extends State<ProductivityMoodInsightsWidget> 
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentIndex = 0;
  bool _showInsights = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _showInsights = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Color _getMoodColor(String emoji) {
    final Map<String, Color> moodColors = {
      '😆': Colors.amber,
      '😍': Colors.pink,
      '🥳': Colors.purple,
      '🥴': Colors.orange,
      '😡': Colors.red,
      '😢': Colors.blue,
      '😫': Colors.indigo,
      '🚀': Colors.teal,
      '😊': Colors.green,
      '😴': Colors.grey,
      '🤔': Colors.brown,
      '😌': Colors.lightGreen,
    };
    return moodColors[emoji] ?? Colors.grey;
  }

  String _getMoodDescription(String emoji) {
    final Map<String, String> descriptions = {
      '😆': 'Joyful',
      '😍': 'Passionate',
      '🥳': 'Excited',
      '🥴': 'Overwhelmed',
      '😡': 'Frustrated',
      '😢': 'Sad',
      '😫': 'Exhausted',
      '🚀': 'Motivated',
      '😊': 'Happy',
      '😴': 'Tired',
      '🤔': 'Thoughtful',
      '😌': 'Calm',
    };
    return descriptions[emoji] ?? 'Unknown';
  }

  // Enhanced insights calculations
  Map<String, dynamic> _calculateInsights() {
    if (widget.emotionalProductivity.isEmpty) {
      return {
        'mostProductive': 'N/A',
        'leastProductive': 'N/A',
        'averageTime': 0.0,
        'efficiencyGap': 0.0,
        'recommendation': 'Start tracking your moods to get insights!'
      };
    }

    final sortedByTime = widget.emotionalProductivity.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    
    final mostProductive = sortedByTime.first;
    final leastProductive = sortedByTime.last;
    
    final avgTime = widget.emotionalProductivity.values.reduce((a, b) => a + b) / 
                   widget.emotionalProductivity.length;
    
    final efficiencyGap = ((leastProductive.value - mostProductive.value) / 
                          leastProductive.value * 100);

    // Generate personalized recommendation
    String recommendation = _generateRecommendation(mostProductive.key, leastProductive.key);

    return {
      'mostProductive': '${mostProductive.key} ${_getMoodDescription(mostProductive.key)}',
      'leastProductive': '${leastProductive.key} ${_getMoodDescription(leastProductive.key)}',
      'averageTime': avgTime,
      'efficiencyGap': efficiencyGap,
      'recommendation': recommendation,
      'mostProductiveTime': mostProductive.value,
      'leastProductiveTime': leastProductive.value,
    };
  }

  String _generateRecommendation(String bestMood, String worstMood) {
    final Map<String, String> moodStrategies = {
      '😆': 'Try starting your day with something that makes you laugh or smile',
      '😍': 'Work on projects you\'re passionate about during peak hours',
      '🥳': 'Channel your excitement into challenging tasks',
      '🚀': 'Set ambitious goals when you feel this motivated',
      '😊': 'This balanced mood is great for steady, consistent work',
      '😌': 'Use calm moments for detail-oriented or creative tasks',
    };

    final Map<String, String> avoidStrategies = {
      '🥴': 'When overwhelmed, break tasks into smaller chunks',
      '😡': 'Take a break to cool down before tackling important work',
      '😢': 'Be gentle with yourself - focus on easier tasks first',
      '😫': 'Rest is productive too - don\'t force it when exhausted',
      '😴': 'Consider if you need more sleep or a change of environment',
    };

    String recommendation = moodStrategies[bestMood] ?? 
                          'Try to recreate the conditions when you feel $bestMood';
    
    if (avoidStrategies.containsKey(worstMood)) {
      recommendation += '. ${avoidStrategies[worstMood]}';
    }

    return recommendation;
  }

  String _formatTime(double minutes) {
    if (!minutes.isFinite || minutes < 0) return 'N/A';
    
    if (minutes < 60) {
      return '${minutes.round()} min';
    } else {
      int hours = minutes ~/ 60;
      int remainingMins = (minutes % 60).round();
      if (remainingMins == 0) {
        return '${hours}h';
      } else {
        return '${hours}h ${remainingMins}m';
      }
    }
  }

  Widget _buildEnhancedBarChart() {
    if (widget.emotionalProductivity.isEmpty) {
      return _buildEmptyState();
    }

    // Sort by productivity (ascending - faster times first)
    final sortedData = widget.emotionalProductivity.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Average Task Completion Time',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Container(
          height: 280,
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: AnimatedOpacity(
            opacity: _showInsights ? 1.0 : 0.0,
            duration: Duration(milliseconds: 800),
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: sortedData.last.value * 1.2,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    tooltipBgColor: Colors.blueGrey,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        '${sortedData[group.x.toInt()].key}\n${_formatTime(rod.toY)}',
                        TextStyle(color: Colors.white),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        if (value.toInt() < sortedData.length) {
                          return Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              sortedData[value.toInt()].key,
                              style: TextStyle(fontSize: 16),
                            ),
                          );
                        }
                        return Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        return Text(
                          _formatTime(value),
                          style: TextStyle(fontSize: 10),
                        );
                      },
                      reservedSize: 40,
                    ),
                  ),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                barGroups: sortedData.asMap().entries.map((entry) {
                  final index = entry.key;
                  final data = entry.value;
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: data.value,
                        color: _getMoodColor(data.key),
                        width: 20,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailedInsights() {
    final insights = _calculateInsights();
    
    if (widget.emotionalProductivity.isEmpty) {
      return _buildEmptyState();
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: AnimatedOpacity(
        opacity: _showInsights ? 1.0 : 0.0,
        duration: Duration(milliseconds: 800),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🎯 Your Productivity Profile',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Colors.purple.shade800,
              ),
            ),
            SizedBox(height: 20),
            
            // Key Stats Row
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    '⚡ Best Performance',
                    insights['mostProductive'],
                    _formatTime(insights['mostProductiveTime']),
                    Colors.green,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    '🐌 Needs Attention',
                    insights['leastProductive'], 
                    _formatTime(insights['leastProductiveTime']),
                    Colors.orange,
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 16),
            
            // Efficiency Gap
            _buildInsightCard(
              icon: Icons.trending_up,
              title: 'Productivity Gap',
              content: 'You\'re ${insights['efficiencyGap'].toStringAsFixed(0)}% more efficient in your best mood vs worst. That\'s ${_formatTime(insights['leastProductiveTime'] - insights['mostProductiveTime'])} saved per task!',
              color: Colors.blue,
            ),
            
            // Personalized Recommendation
            _buildInsightCard(
              icon: Icons.lightbulb,
              title: 'Personalized Strategy',
              content: '船到桥头自然直\nEverthing will be fine!',
              color: Colors.amber,
            ),
            
            // Mood Distribution (if frequency data available)
            if (widget.moodFrequency.isNotEmpty)
              _buildInsightCard(
                icon: Icons.pie_chart,
                title: 'Mood Pattern',
                content: _getMoodDistributionInsight(),
                color: Colors.purple,
              ),
              
            // Weekly Trend (if recent tasks available)
            if (widget.recentTasks.isNotEmpty)
              _buildInsightCard(
                icon: Icons.timeline,
                title: 'Recent Trend',
                content: _getTrendInsight(),
                color: Colors.teal,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, String subtitle, Color color) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              // color: color.shade700,
            ),
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  String _getMoodDistributionInsight() {
    final total = widget.moodFrequency.values.reduce((a, b) => a + b);
    final mostFrequent = widget.moodFrequency.entries
        .reduce((a, b) => a.value > b.value ? a : b);
    
    final percentage = (mostFrequent.value / total * 100).round();
    return 'You experience ${mostFrequent.key} ${_getMoodDescription(mostFrequent.key).toLowerCase()} moods $percentage% of the time. This is your dominant emotional state.';
  }

  String _getTrendInsight() {
    // Analyze recent task trends - this would need actual implementation
    // based on your task data structure
    return 'Your productivity has been trending upward this week. Keep up the momentum!';
  }

  Widget _buildInsightCard({
    required IconData icon,
    required String title,
    required String content,
    required Color color,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  content,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: 250,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.mood,
            size: 48,
            color: Colors.grey.shade400,
          ),
          SizedBox(height: 16),
          Text(
            'Track your mood while completing tasks\nto unlock productivity insights',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Complete at least 3 tasks with different moods to see patterns',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmotionQuadrant() {
    if (widget.emotionalProductivity.isEmpty || widget.emotionScores.isEmpty) {
      return _buildEmptyState();
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            'Energy × Positivity Matrix',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Bubble size = faster completion time',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          SizedBox(height: 16),
          AspectRatio(
            aspectRatio: 1.0,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = constraints.maxWidth;
                  return Stack(
                    children: [
                      // Quadrant background colors
                      Positioned(
                        top: 0,
                        left: 0,
                        width: size / 2,
                        height: size / 2,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            border: Border(
                              right: BorderSide(color: Colors.grey.shade300),
                              bottom: BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        width: size / 2,
                        height: size / 2,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            border: Border(
                              left: BorderSide(color: Colors.grey.shade300),
                              bottom: BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        width: size / 2,
                        height: size / 2,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            border: Border(
                              right: BorderSide(color: Colors.grey.shade300),
                              top: BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        width: size / 2,
                        height: size / 2,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            border: Border(
                              left: BorderSide(color: Colors.grey.shade300),
                              top: BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                        ),
                      ),
                      
                      // Quadrant labels
                      Positioned(
                        top: 8,
                        left: 8,
                        child: _buildQuadrantLabel('Stressed\n(High Energy, Low Mood)', Colors.orange),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: _buildQuadrantLabel('Energized\n(High Energy, Good Mood)', Colors.green),
                      ),
                      Positioned(
                        bottom: 8,
                        left: 8,
                        child: _buildQuadrantLabel('Depleted\n(Low Energy, Low Mood)', Colors.red),
                      ),
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: _buildQuadrantLabel('Peaceful\n(Low Energy, Good Mood)', Colors.blue),
                      ),
                      
                      // Plot emotions
                      ...widget.emotionScores.entries.map((entry) {
                        final emoji = entry.key;
                        final scores = entry.value;
                        
                        if (!scores.containsKey('positivity') || !scores.containsKey('energy')) {
                          return SizedBox.shrink();
                        }
                        
                        final positivity = scores['positivity']!.clamp(0.0, 1.0);
                        final energy = scores['energy']!.clamp(0.0, 1.0);
                        final productivity = widget.emotionalProductivity[emoji] ?? 0.0;
                        
                        // Calculate position
                        final left = (size * positivity) - 15; // Center the bubble
                        final top = (size * (1 - energy)) - 15; // Inverse Y and center
                        
                        // Calculate bubble size (inverse of productivity time)
                        double bubbleSize = 30;
                        if (productivity > 0 && widget.emotionalProductivity.values.length > 1) {
                          final maxProd = widget.emotionalProductivity.values.reduce(math.max);
                          final minProd = widget.emotionalProductivity.values.reduce(math.min);
                          final range = maxProd - minProd;
                          
                          if (range > 0) {
                            // Larger bubble = faster (lower time)
                            final normalizedSpeed = (maxProd - productivity) / range;
                            bubbleSize = 25 + (normalizedSpeed * 25); // 25-50 range
                          }
                        }
                        
                        return Positioned(
                          left: left.clamp(5.0, size - 35), // Keep within bounds
                          top: top.clamp(5.0, size - 35),
                          child: GestureDetector(
                            onTap: () {
                              // Show detailed info
                              _showMoodDetails(emoji, productivity, positivity, energy);
                            },
                            child: Container(
                              width: bubbleSize,
                              height: bubbleSize,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _getMoodColor(emoji).withOpacity(0.8),
                                border: Border.all(
                                  color: _getMoodColor(emoji),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 4,
                                    offset: Offset(2, 2),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  emoji,
                                  style: TextStyle(fontSize: bubbleSize * 0.4),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  );
                },
              ),
            ),
          ),
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              children: [
                Text(
                  '💡 How to read this chart:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '• Larger bubbles = faster task completion\n• Top half = high energy states\n• Right half = positive moods\n• Tap bubbles for details',
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuadrantLabel(String text, Color color) {
    return Container(
      padding: EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          // color: color.shade800,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  void _showMoodDetails(String emoji, double productivity, double positivity, double energy) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$emoji ${_getMoodDescription(emoji)}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('⏱️ Average completion: ${_formatTime(productivity)}'),
            SizedBox(height: 8),
            Text('😊 Positivity: ${(positivity * 100).round()}%'),
            SizedBox(height: 8),
            Text('⚡ Energy: ${(energy * 100).round()}%'),
            SizedBox(height: 12),
            Text(
              _generateMoodSpecificTip(emoji),
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Got it!'),
          ),
        ],
      ),
    );
  }

  String _generateMoodSpecificTip(String emoji) {
    final Map<String, String> tips = {
      '😆': 'Laughter boosts creativity and problem-solving!',
      '😍': 'Passion drives excellence - use this for important work.',
      '🥳': 'High excitement is great for brainstorming sessions.',
      '🚀': 'This motivated mood is perfect for tackling challenges.',
      '😊': 'Balanced and steady - ideal for consistent progress.',
      '😌': 'Calm focus leads to quality work.',
      '🥴': 'When overwhelmed, try the 2-minute rule for small tasks.',
      '😡': 'Channel frustration into determination, but take breaks.',
      '😢': 'Be kind to yourself - some days are just harder.',
      '😫': 'Rest is productive too. Listen to your body.',
    };
    return tips[emoji] ?? 'Every mood has its place in your productivity journey.';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple.shade600, Colors.purple.shade400],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.psychology,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Mood & Productivity Intelligence',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          TabBar(
            controller: _tabController,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            indicatorColor: Colors.purple,
            labelColor: Colors.purple.shade800,
            unselectedLabelColor: Colors.grey.shade600,
            labelStyle: TextStyle(fontWeight: FontWeight.w600),
            tabs: [
              Tab(text: 'Performance'),
              Tab(text: 'Insights'),
              Tab(text: 'Energy Map'),
            ],
          ),
          Container(
            height: 400,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildEnhancedBarChart(),
                _buildDetailedInsights(),
                _buildEmotionQuadrant(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}