import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'myconfig.dart';

class Dashboard extends StatefulWidget {
  final VoidCallback? onNavigateToHistory;
  
  const Dashboard({super.key, this.onNavigateToHistory});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseAnimation;

  Timer? _dataTimer;

  // Sensor data
  double temperature = 0.0;
  double humidity = 0.0;
  bool motionDetected = false;
  bool vibrationDetected = false;
  bool relayState = false;
  String systemStatus = "LOADING...";

  // Thresholds
  double tempHighThreshold = 30.0;
  double tempLowThreshold = 18.0;
  double humidityThreshold = 90.0;

  // Loading states
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = "";
  DateTime? _lastUpdate;

  // Recent activities (real data)
  List<Map<String, dynamic>> recentActivities = [];

  // Theme colors
  final Color primaryColor = const Color(0xFFe6d4cb);
  final Color secondaryColor = const Color(0xFFd5b7b6);
  final Color accentColor = const Color(0xFFbca3af);
  final Color mutedColor = const Color(0xFFb1a9b9);
  final Color successColor = const Color(0xFF10B981);
  final Color warningColor = const Color(0xFFF59E0B);
  final Color dangerColor = const Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Start animations
    _fadeController.forward();
    _slideController.forward();
    _pulseController.repeat(reverse: true);

    // Initial data fetch
    _fetchInitialData();

    // Start periodic data fetching
    _startDataFetching();
  }

  Future<void> _fetchInitialData() async {
    await Future.wait([
      _fetchThresholdData(isInitialLoad: true),
      _fetchLatestSensorData(isInitialLoad: true),
      _fetchRecentActivities(),
    ]);

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _startDataFetching() {
    _dataTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        _fetchLatestSensorData();
        _fetchRecentActivities();
      }
    });
  }

  Future<void> _fetchRecentActivities() async {
    if (!mounted) return;

    try {
      final response = await http.get(
        Uri.parse("${Myconfig.servername}/get_sensor_data.php?limit=10"),
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['status'] == 'success') {
          List<Map<String, dynamic>> activities = [];

          for (var record in jsonData['data']) {
            final timestamp = DateTime.parse(record['timestamp'])
                .toUtc()
                .add(const Duration(hours: 8));

            // Motion detected event
            if (record['motion_detected'] == 'DETECTED') {
              activities.add({
                'title': 'Motion Detected',
                'subtitle': 'Someone is moving in the room',
                'icon': Icons.directions_walk,
                'color': dangerColor,
                'time': timestamp,
              });
            }

            // Vibration detected event
            if (record['vibration_detected'] == 'DETECTED') {
              activities.add({
                'title': 'Vibration Alert',
                'subtitle': 'Door or window activity detected',
                'icon': Icons.vibration,
                'color': warningColor,
                'time': timestamp,
              });
            }

            // Relay activation
            if (record['relay_state'] == 'ON') {
              activities.add({
                'title': 'Buzzer Activated',
                'subtitle': 'Security alert triggered',
                'icon': Icons.notifications_active,
                'color': dangerColor,
                'time': timestamp,
              });
            }

            // Temperature alerts
            final temp = record['temperature']?.toDouble() ?? 0.0;
            if (temp > tempHighThreshold) {
              activities.add({
                'title': 'High Temperature',
                'subtitle': 'Temperature: ${temp.toStringAsFixed(1)}°C',
                'icon': Icons.thermostat,
                'color': dangerColor,
                'time': timestamp,
              });
            } else if (temp < tempLowThreshold) {
              activities.add({
                'title': 'Low Temperature',
                'subtitle': 'Temperature: ${temp.toStringAsFixed(1)}°C',
                'icon': Icons.ac_unit,
                'color': warningColor,
                'time': timestamp,
              });
            }

            // All clear events
            if (record['motion_detected'] == 'NOT_DETECTED' &&
                record['vibration_detected'] == 'NOT_DETECTED' &&
                record['relay_state'] == 'OFF') {
              activities.add({
                'title': 'All Clear',
                'subtitle': 'No security threats detected',
                'icon': Icons.check_circle,
                'color': successColor,
                'time': timestamp,
              });
            }
          }

          // Sort by time (newest first) and take latest 8
          activities.sort((a, b) => b['time'].compareTo(a['time']));

          if (mounted) {
            setState(() {
              recentActivities = activities.take(8).toList();
            });
          }
        }
      }
    } catch (e) {
      print("Error fetching recent activities: $e");
    }
  }

  Future<void> _fetchThresholdData({bool isInitialLoad = false}) async {
    if (!mounted) return;

    try {
      final response = await http.get(
        Uri.parse("${Myconfig.servername}/get_threshold_arduino.php"),
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['status'] == 'success') {
          if (mounted) {
            setState(() {
              tempHighThreshold =
                  jsonData['temp_threshold']?.toDouble() ?? 30.0;
              tempLowThreshold =
                  jsonData['temp_low_threshold']?.toDouble() ?? 18.0;
              humidityThreshold = jsonData['hum_threshold']?.toDouble() ?? 90.0;
              print(
                  "Thresholds loaded: High: ${tempHighThreshold}°C, Low: ${tempLowThreshold}°C, Humidity: ${humidityThreshold}%");
            });
          }
        } else {
          if (mounted) {
            final message = jsonData['message'] ?? 'Failed to load thresholds.';
            if (isInitialLoad) {
              _errorMessage += "Threshold Error: $message; ";
            } else {
              _errorMessage = "Threshold Error: $message";
            }
            _hasError = true;
          }
        }
      } else {
        if (mounted) {
          final message =
              "Server error fetching thresholds: ${response.statusCode}";
          if (isInitialLoad) {
            _errorMessage += "$message; ";
          } else {
            _errorMessage = message;
          }
          _hasError = true;
        }
      }
    } catch (e) {
      print("Error fetching threshold data: $e");
      if (mounted) {
        final message = "Error fetching thresholds: $e";
        if (isInitialLoad) {
          _errorMessage += "$message; ";
        } else {
          _errorMessage = message;
        }
        _hasError = true;
      }
    }
  }

  Future<void> _fetchLatestSensorData({bool isInitialLoad = false}) async {
    if (!mounted) return;

    try {
      final response = await http.get(
        Uri.parse("${Myconfig.servername}/get_latest_sensor.php"),
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['status'] == 'success') {
          final data = jsonData['data'];
          if (mounted) {
            setState(() {
              temperature = data['temperature']?.toDouble() ?? 0.0;
              humidity = data['humidity']?.toDouble() ?? 0.0;
              motionDetected = data['motion_detected'] == 'DETECTED';
              vibrationDetected = data['vibration_detected'] == 'DETECTED';
              relayState = data['relay_state'] == 'ON';
              systemStatus = jsonData['system_status'] ?? 'MONITORING';
              _lastUpdate =
                  DateTime.now().toUtc().add(const Duration(hours: 8));
              _hasError = false;
              _errorMessage = "";

              print(
                  "Sensor data updated: ${temperature}°C, ${humidity}%, Motion: $motionDetected, Vibration: $vibrationDetected, Relay: $relayState");
            });
          }
        } else if (jsonData['status'] == 'no_data') {
          if (mounted) {
            setState(() {
              systemStatus = "OFFLINE";
              _hasError = false;
              _errorMessage = "";
            });
          }
        } else {
          if (mounted) {
            final message =
                jsonData['message'] ?? 'Failed to load sensor data.';
            if (!isInitialLoad) {
              setState(() {
                _errorMessage = "Sensor Error: $message";
                _hasError = true;
              });
            }
          }
        }
      } else {
        if (mounted) {
          final message =
              "Server error fetching sensor data: ${response.statusCode}";
          if (!isInitialLoad) {
            setState(() {
              _errorMessage = message;
              _hasError = true;
            });
          }
        }
      }
    } catch (e) {
      print("Error fetching sensor data: $e");
      if (mounted) {
        final message = "Error fetching sensor data: $e";
        if (!isInitialLoad) {
          setState(() {
            _errorMessage = message;
            _hasError = true;
          });
        }
      }
    }
  }

  String _formatMalaysianDateTime(DateTime dateTime) {
    // dateTime is already in Malaysia time (UTC+8)
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year.toString();
    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');

    final hour12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final amPm = hour >= 12 ? 'pm' : 'am';

    return '$day/$month/$year ${hour12.toString().padLeft(2, '0')}:${minute}$amPm';
  }

  String _getSecurityMessage() {
    if (vibrationDetected && motionDetected) {
      return "⚠️ High Alert: Door opened & someone is moving!";
    } else if (vibrationDetected) {
      return "⚠️ Door is opened";
    } else if (motionDetected) {
      return "👤 Someone is moving";
    }
    return "All secure";
  }

  Color _getSecurityMessageColor() {
    if (vibrationDetected && motionDetected) {
      return dangerColor;
    } else if (vibrationDetected || motionDetected) {
      return warningColor;
    }
    return successColor;
  }

  Color _getStatusColor() {
    switch (systemStatus) {
      case "MONITORING":
        return successColor;
      case "ALERT":
        return dangerColor;
      case "WARNING":
        return warningColor;
      case "OFFLINE":
        return mutedColor;
      default:
        return warningColor;
    }
  }

  void _refreshData() {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = "";
    });
    _fetchInitialData();
  }

  void _logout() async {
    // Show confirmation dialog
    bool? shouldLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true) {
      // Clear any stored user data (if using SharedPreferences)
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
      } catch (e) {
        print('Error clearing preferences: $e');
      }

      // Navigate to login screen and clear navigation stack
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/login',
          (Route<dynamic> route) => false,
        );
      }
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _pulseController.dispose();
    _dataTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: CustomScrollView(
              slivers: [
                // App Bar with rounded corners
                SliverAppBar(
                  expandedHeight: 120.0,
                  floating: false,
                  pinned: true,
                  backgroundColor: primaryColor,
                  automaticallyImplyLeading: false,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(25),
                      bottomRight: Radius.circular(25),
                    ),
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    title: Padding(
                      padding: const EdgeInsets.only(left: 16.0),
                      child: const Text(
                        'Smart Home Guardian',
                        style: TextStyle(
                          color: Color(0xFF5d4e75),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    background: Container(
                      decoration: BoxDecoration(
                        image: const DecorationImage(
                          image: AssetImage('assets/images/background.png'),
                          fit: BoxFit.cover,
                        ),
                        color: primaryColor,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(25),
                          bottomRight: Radius.circular(25),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              primaryColor.withOpacity(0.1), // Very light at top
                              primaryColor.withOpacity(0.25), // Slightly darker at bottom for text readability
                            ],
                          ),
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(25),
                            bottomRight: Radius.circular(25),
                          ),
                        ),
                      ),
                    ),
                  ),
                  actions: [
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      child: IconButton(
                        icon:
                            const Icon(Icons.refresh, color: Color(0xFF5d4e75)),
                        onPressed: _refreshData,
                        splashRadius: 20,
                        tooltip: 'Refresh Data',
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(right: 16),
                      child: IconButton(
                        icon:
                            const Icon(Icons.logout, color: Color(0xFF5d4e75)),
                        onPressed: _logout,
                        splashRadius: 20,
                        tooltip: 'Logout',
                      ),
                    ),
                  ],
                ),

                // Content
                SliverPadding(
                  padding: const EdgeInsets.all(16.0),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // Last Updated - moved to top
                      if (!_isLoading && _lastUpdate != null)
                        _buildLastUpdatedCard(),
                      const SizedBox(height: 16),

                      // Loading indicator
                      if (_isLoading)
                        Container(
                          padding: const EdgeInsets.all(20),
                          child: Center(
                            child:
                                CircularProgressIndicator(color: primaryColor),
                          ),
                        ),

                      // Error message
                      if (_hasError && _errorMessage.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: dangerColor.withOpacity(0.1),
                            border: Border.all(color: dangerColor, width: 1),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: dangerColor.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error, color: dangerColor),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _errorMessage,
                                  style: TextStyle(color: dangerColor),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Overall Alerts Card
                      if (!_isLoading) _buildOverallAlertsCard(),
                      const SizedBox(height: 16),

                      // System Status Card
                      if (!_isLoading) _buildSystemStatusCard(),
                      const SizedBox(height: 16),

                      // Buzzer Status Card (Clickable)
                      if (!_isLoading) _buildSecurityMessageCard(),
                      const SizedBox(height: 16),

                      // Environmental Status Card
                      if (!_isLoading) _buildEnvironmentalStatusCard(),
                      const SizedBox(height: 16),

                      // Sensor Grid - PIR and Vibration first
                      if (!_isLoading) _buildSensorGrid(),
                      const SizedBox(height: 16),

                      // Quick Actions
                      if (!_isLoading) _buildQuickActions(),
                      const SizedBox(height: 24),

                      // Recent Activity
                      if (!_isLoading) _buildRecentActivity(),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSecurityMessageCard() {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Use "Control" tab to manage buzzer'),
            backgroundColor: const Color(0xFF5d4e75),
            action: SnackBarAction(
              label: 'Got it',
              textColor: Colors.white,
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: (relayState ? dangerColor : successColor).withOpacity(0.1),
          border: Border.all(
              color: relayState ? dangerColor : successColor, width: 2),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: (relayState ? dangerColor : successColor)
                  .withOpacity(0.2),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: relayState ? dangerColor : successColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (relayState ? dangerColor : successColor)
                        .withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.campaign,
                color: Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Buzzer Status',
                    style: TextStyle(
                      color: const Color(0xFF5d4e75).withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    relayState ? 'ON' : 'OFF',
                    style: TextStyle(
                      color: relayState ? dangerColor : successColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.touch_app,
              color: const Color(0xFF5d4e75).withOpacity(0.5),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLastUpdatedCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: mutedColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.schedule, color: mutedColor, size: 20),
          const SizedBox(width: 8),
          Text(
            'Last updated: ${_formatMalaysianDateTime(_lastUpdate!)}',
            style: TextStyle(
              color: const Color(0xFF5d4e75),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemStatusCard() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: systemStatus == "MONITORING" ? 1.0 : _pulseAnimation.value,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _getStatusColor().withOpacity(0.1),
              border: Border.all(color: _getStatusColor(), width: 2),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: _getStatusColor().withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: _getStatusColor(),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _getStatusColor().withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    systemStatus == "MONITORING"
                        ? Icons.shield_rounded
                        : Icons.warning_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'System Status',
                        style: TextStyle(
                          color: const Color(0xFF5d4e75).withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        systemStatus,
                        style: TextStyle(
                          color: _getStatusColor(),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSensorGrid() {
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.2,
      children: [
        // PIR Motion - Priority 1
        _buildSensorCard(
          'PIR Motion',
          motionDetected ? 'DETECTED' : 'CLEAR',
          Icons.directions_walk,
          motionDetected ? dangerColor : successColor,
        ),

        // Vibration - Priority 2
        _buildSensorCard(
          'Vibration',
          vibrationDetected ? 'DETECTED' : 'CLEAR',
          Icons.vibration,
          vibrationDetected ? warningColor : successColor,
        ),

        // Temperature - Priority 3
        Tooltip(
          message: _lastUpdate != null
              ? 'Temperature: ${temperature.toStringAsFixed(1)}°C\nRecorded: ${_formatMalaysianDateTime(_lastUpdate!)}\nThresholds: ${tempLowThreshold.toStringAsFixed(1)}°C - ${tempHighThreshold.toStringAsFixed(1)}°C'
              : 'Temperature: ${temperature.toStringAsFixed(1)}°C',
          child: _buildSensorCard(
            'Temperature',
            '${temperature.toStringAsFixed(1)}°C',
            Icons.thermostat,
            _getTemperatureColor(),
          ),
        ),

        // Humidity - Priority 4
        GestureDetector(
          onLongPress: () {
            _showTooltip('Humidity: ${humidity.toStringAsFixed(1)}%\n'
                'Recorded: ${_lastUpdate != null ? _formatMalaysianDateTime(_lastUpdate!) : 'Loading...'}\n'
                'Threshold: Max ${humidityThreshold.toStringAsFixed(1)}%');
          },
          child: _buildSensorCard(
            'Humidity',
            '${humidity.toStringAsFixed(1)}%',
            Icons.water_drop,
            _getHumidityColor(),
          ),
        ),
      ],
    );
  }

  Color _getTemperatureColor() {
    if (temperature > tempHighThreshold) return dangerColor;
    if (temperature < tempLowThreshold) return warningColor;
    return successColor;
  }

  Color _getHumidityColor() {
    if (humidity > humidityThreshold) return warningColor;
    return successColor;
  }

  Widget _buildSensorCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 40,
            color: color,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: const Color(0xFF5d4e75).withOpacity(0.7),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: TextStyle(
              color: const Color(0xFF5d4e75),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  'Refresh',
                  'Update Data',
                  Icons.refresh,
                  successColor,
                  _refreshData,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  'Status',
                  systemStatus,
                  Icons.info_outline,
                  _getStatusColor(),
                  () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('System Status: $systemStatus'),
                        backgroundColor: _getStatusColor(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String title, String subtitle, IconData icon,
      Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: const Color(0xFF5d4e75).withOpacity(0.7),
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              subtitle,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    // Limit to 5 most recent activities
    List<Map<String, dynamic>> limitedActivities =
        recentActivities.take(5).toList();

    return Container(
      decoration: BoxDecoration(
        color: secondaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Activity',
                  style: TextStyle(
                    color: const Color(0xFF5d4e75),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    // Navigate to history tab using callback
                    widget.onNavigateToHistory?.call();
                  },
                  icon: Icon(
                    Icons.history,
                    color: primaryColor,
                    size: 16,
                  ),
                  label: Text(
                    'View All',
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
          if (limitedActivities.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'No recent activities',
                style: TextStyle(
                  color: const Color(0xFF5d4e75).withOpacity(0.6),
                  fontSize: 14,
                ),
              ),
            )
          else
            ...limitedActivities.map((activity) => _buildActivityItem(
                  activity['title'],
                  activity['subtitle'],
                  activity['icon'],
                  activity['color'],
                  _formatMalaysianDateTime(activity['time']),
                )),
          if (recentActivities.length > 5)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'more activities...',
                  style: TextStyle(
                    color: const Color(0xFF5d4e75).withOpacity(0.5),
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(
      String title, String subtitle, IconData icon, Color color, String time) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF5d4e75),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: const Color(0xFF5d4e75).withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: TextStyle(
              color: const Color(0xFF5d4e75).withOpacity(0.5),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverallAlertsCard() {
    // Focus on PIR and Vibration sensors only (no temperature/humidity)
    int motionCount = motionDetected ? 1 : 0;
    int vibrationCount = vibrationDetected ? 1 : 0;
    int totalAlerts = motionCount + vibrationCount;
    
    String safetyStatus = "ALL SAFE";
    String statusMessage = "Your home is secure and protected";
    Color statusColor = successColor;
    IconData safetyIcon = Icons.shield_rounded;

    // Determine status based on PIR and Vibration only
    if (motionDetected && vibrationDetected) {
      safetyStatus = "HIGH ALERT";
      statusMessage = "Motion and vibration detected - Check your home immediately";
      statusColor = dangerColor;
      safetyIcon = Icons.warning_rounded;
    } else if (motionDetected) {
      safetyStatus = "MOTION DETECTED";
      statusMessage = "Someone is moving in the monitored area";
      statusColor = dangerColor;
      safetyIcon = Icons.visibility_rounded;
    } else if (vibrationDetected) {
      safetyStatus = "VIBRATION ALERT";
      statusMessage = "Door or window activity detected";
      statusColor = warningColor;
      safetyIcon = Icons.vibration_rounded;
    }

    return Container(
      width: double.infinity,
      height: 550, // Make it bigger
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          // Multiple shadows for depth and blur effect
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.2), 
            blurRadius: 30,
            offset: const Offset(0, 15),
            spreadRadius: -5,
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.8),
            blurRadius: 15,
            offset: const Offset(-10, -10),
            spreadRadius: -5,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
            decoration: BoxDecoration(
            image: const DecorationImage(
              image: AssetImage('assets/images/backgroundcard.png'),
              fit: BoxFit.cover,
            ),
            borderRadius: BorderRadius.circular(24),
            ),
          child: Container(
            // Light overlay for text readability while preserving background colors
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.08),
                  Colors.black.withOpacity(0.12),
                  Colors.black.withOpacity(0.18),
                ],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Safety Icon
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: totalAlerts > 0 ? _pulseAnimation.value : 1.0,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              colors: [
                                statusColor,
                                statusColor.withOpacity(0.8),
                              ],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.6),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Icon(
                            safetyIcon,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Title
                  Text(
                    'Current Safety In Home',
                    style: TextStyle(
                      color: const Color(0xFF2c3e50),
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      shadows: [
                        Shadow(
                          offset: const Offset(0, 1),
                          blurRadius: 2,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Status with Frame - PROMINENT DISPLAY
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(0.25),
                          Colors.white.withOpacity(0.15),
                          Colors.white.withOpacity(0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.4),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                        BoxShadow(
                          color: Colors.white.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        Color statusColor = motionDetected || vibrationDetected 
                            ? const Color(0xFFD32F2F) 
                            : const Color.fromARGB(255, 62, 167, 67);
                        
                        return Transform.scale(
                          scale: 1.0 + (_pulseAnimation.value * 0.05),
                          child: Text(
                            safetyStatus,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2.0,
                              shadows: [
                                Shadow(
                                  offset: const Offset(0, 2),
                                  blurRadius: 4,
                                  color: Colors.white.withOpacity(0.5),
                                ),
                                Shadow(
                                  offset: const Offset(2, 2),
                                  blurRadius: 8,
                                  color: Colors.white.withOpacity(0.3),
                                ),
                                // Glow effect
                                Shadow(
                                  offset: const Offset(0, 0),
                                  blurRadius: 20,
                                  color: statusColor.withOpacity(0.3),
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        );
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Status Message with Frame
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.25), // Gray transparent background
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.grey.withOpacity(0.4),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                        BoxShadow(
                          color: Colors.white.withOpacity(0.5),
                          blurRadius: 4,
                          offset: const Offset(0, -1),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: const Color(0xFF64748B),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            statusMessage,
                            style: const TextStyle(
                              color: Color(0xFF64748B), // Dark gray instead of black
                              fontSize: 15,
                              fontWeight: FontWeight.w500, // Less bold
                              height: 1.5,
                              letterSpacing: 0.2,
                            ),
                            textAlign: TextAlign.left, // Align text to the left
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Alert Counts Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Motion Count
                      _buildAlertCounter(
                        icon: Icons.directions_walk_rounded,
                        count: motionCount,
                        label: motionCount == 1 ? "1 motion detected" : "No motion",
                        color: motionDetected ? dangerColor : Colors.white.withOpacity(0.6),
                        isActive: motionDetected,
                      ),
                      
                      // Divider
                      Container(
                        width: 2,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withOpacity(0.2),
                              Colors.white.withOpacity(0.6),
                              Colors.white.withOpacity(0.2),
                            ],
                          ),
                        ),
                      ),
                      
                      // Vibration Count
                      _buildAlertCounter(
                        icon: Icons.vibration_rounded,
                        count: vibrationCount,
                        label: vibrationCount == 1 ? "1 vibration detected" : "No vibration",
                        color: vibrationDetected ? warningColor : Colors.white.withOpacity(0.6),
                        isActive: vibrationDetected,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Helper widget for alert counters
  Widget _buildAlertCounter({
    required IconData icon,
    required int count,
    required String label,
    required Color color,
    required bool isActive,
  }) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: isActive ? (0.95 + _pulseAnimation.value * 0.1) : 1.0,
          child: Column(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: isActive ? color.withOpacity(0.2) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: color,
                    width: isActive ? 2 : 1,
                  ),
                  boxShadow: isActive ? [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ] : null,
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  shadows: [
                    Shadow(
                      offset: const Offset(0, 1),
                      blurRadius: 2,
                      color: Colors.black.withOpacity(0.3),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEnvironmentalStatusCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: mutedColor.withOpacity(0.1),
        border: Border.all(color: mutedColor, width: 2),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Environmental Status',
            style: TextStyle(
              color: const Color(0xFF5d4e75).withOpacity(0.7),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _getEnvironmentalMessage(),
            style: TextStyle(
              color: const Color(0xFF5d4e75),
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  String _getEnvironmentalMessage() {
    List<String> messages = [];

    if (temperature > tempHighThreshold) {
      messages.add("Temperature is too hot");
    } else if (temperature < tempLowThreshold) {
      messages.add("Temperature is too cold");
    }

    if (humidity > humidityThreshold) {
      messages.add("Humidity is too high");
    }

    if (messages.isEmpty) {
      return "🌟 Environmental conditions are optimal";
    } else {
      return "⚠️ ${messages.join(" and ")}";
    }
  }

  void _showTooltip(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.info_outline, color: primaryColor),
              const SizedBox(width: 8),
              Text(
                'Sensor Details',
                style: TextStyle(
                  color: const Color(0xFF5d4e75),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: TextStyle(
              color: const Color(0xFF5d4e75),
              fontSize: 14,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Got it',
                style: TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
