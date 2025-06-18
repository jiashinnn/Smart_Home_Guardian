import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:math' as math;
import 'myconfig.dart';

class History extends StatefulWidget {
  const History({super.key});

  @override
  State<History> createState() => _HistoryState();
}

class _HistoryState extends State<History> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Data
  List<Map<String, dynamic>> sensorData = [];
  List<Map<String, dynamic>> todayEvents = [];

  // Statistics
  int totalEvents = 0;
  double avgTemperature = 0.0;
  double maxHumidity = 0.0;
  int motionEvents = 0;
  int vibrationEvents = 0;
  int relayActivations = 0;

  // Loading states
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = "";

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

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );

    _fadeController.forward();
    _loadHistoryData();
  }

  Future<void> _loadHistoryData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      // Load sensor data for charts (last 20 records)
      final response = await http.get(
        Uri.parse("${Myconfig.servername}/get_sensor_data.php?limit=20"),
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['status'] == 'success') {
          setState(() {
            sensorData = List<Map<String, dynamic>>.from(jsonData['data']);
          });

          _calculateStatistics();
          _generateTodayEvents();
        } else {
          throw Exception(jsonData['message'] ?? 'Failed to load data');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = "Error loading history: $e";
      });
    }
  }

  void _calculateStatistics() {
    if (sensorData.isEmpty) return;

    double tempSum = 0;
    double maxHum = 0;
    int motionCount = 0;
    int vibrationCount = 0;
    int relayCount = 0;

    final today = DateTime.now().toUtc().add(const Duration(hours: 8));
    final todayStart = DateTime(today.year, today.month, today.day);

    for (var data in sensorData) {
      final timestamp = DateTime.parse(data['timestamp'])
          .toUtc()
          .add(const Duration(hours: 8));

      // Calculate averages from all data - safely convert to double
      double temp = (data['temperature'] is int)
          ? (data['temperature'] as int).toDouble()
          : (data['temperature'] as double);
      double hum = (data['humidity'] is int)
          ? (data['humidity'] as int).toDouble()
          : (data['humidity'] as double);

      tempSum += temp;
      if (hum > maxHum) {
        maxHum = hum;
      }

      // Count today's events only
      if (timestamp.isAfter(todayStart)) {
        if (data['motion_detected'] == 'DETECTED') motionCount++;
        if (data['vibration_detected'] == 'DETECTED') vibrationCount++;
        if (data['relay_state'] == 'ON') relayCount++;
      }
    }

    setState(() {
      avgTemperature = tempSum / sensorData.length;
      maxHumidity = maxHum;
      motionEvents = motionCount;
      vibrationEvents = vibrationCount;
      relayActivations = relayCount;
      totalEvents = motionCount + vibrationCount + relayCount;
    });
  }

  void _generateTodayEvents() {
    final today = DateTime.now().toUtc().add(const Duration(hours: 8));
    final todayStart = DateTime(today.year, today.month, today.day);

    List<Map<String, dynamic>> events = [];

    for (var data in sensorData) {
      final timestamp = DateTime.parse(data['timestamp'])
          .toUtc()
          .add(const Duration(hours: 8));

      if (timestamp.isAfter(todayStart)) {
        // Motion events
        if (data['motion_detected'] == 'DETECTED') {
          events.add({
            'time': _formatTime(timestamp),
            'type': 'Motion',
            'description': 'Motion detected in monitored area',
            'icon': Icons.motion_photos_on,
            'color': dangerColor,
          });
        }

        // Vibration events
        if (data['vibration_detected'] == 'DETECTED') {
          events.add({
            'time': _formatTime(timestamp),
            'type': 'Vibration',
            'description': 'Door/Window vibration detected',
            'icon': Icons.vibration,
            'color': warningColor,
          });
        }

        // Relay events
        if (data['relay_state'] == 'ON') {
          events.add({
            'time': _formatTime(timestamp),
            'type': 'Relay',
            'description': 'Relay activated (device turned on)',
            'icon': Icons.power,
            'color': successColor,
          });
        }

        // All clear events (when everything is normal)
        if (data['motion_detected'] == 'CLEAR' &&
            data['vibration_detected'] == 'CLEAR' &&
            data['relay_state'] == 'OFF') {
          events.add({
            'time': _formatTime(timestamp),
            'type': 'All Clear',
            'description': 'All sensors normal, system monitoring',
            'icon': Icons.check_circle,
            'color': successColor,
          });
        }
      }
    }

    // Sort by time (most recent first)
    events.sort((a, b) => b['time'].compareTo(a['time']));

    setState(() {
      todayEvents = events.take(20).toList(); // Show last 20 events
    });
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _showChartTooltip(String title, String content) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: CustomScrollView(
              slivers: [
                // App Bar
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
                        'History & Analytics',
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
                      margin: const EdgeInsets.only(right: 16),
                      child: IconButton(
                        icon:
                            const Icon(Icons.refresh, color: Color(0xFF5d4e75)),
                        onPressed: _loadHistoryData,
                        splashRadius: 20,
                      ),
                    ),
                  ],
                ),

                // Content
                SliverPadding(
                  padding: const EdgeInsets.all(16.0),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      if (_isLoading)
                        const Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFFe6d4cb)),
                        )
                      else if (_hasError)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: dangerColor.withOpacity(0.1),
                            border: Border.all(color: dangerColor, width: 1),
                            borderRadius: BorderRadius.circular(8),
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
                        )
                      else ...[
                        // Statistics Section
                        _buildStatisticsSection(),
                        const SizedBox(height: 24),

                        // Charts Section
                        _buildChartsSection(),
                        const SizedBox(height: 24),

                        // Today's Events Section
                        _buildTodayEventsSection(),
                      ],
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

  Widget _buildStatisticsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentColor.withOpacity(0.3),
          width: 1,
        ),
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
          Row(
            children: [
              Icon(
                Icons.analytics,
                color: primaryColor,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                'Today\'s Statistics',
                style: TextStyle(
                  color: const Color(0xFF5d4e75),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Statistics Grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.2,
            children: [
              _buildStatCard(
                'Total Events',
                totalEvents.toString(),
                Icons.event,
                const Color(0xFFFF8C00),
              ),
              _buildStatCard(
                'Avg Temperature',
                '${avgTemperature.toStringAsFixed(1)}°C',
                Icons.thermostat,
                warningColor,
              ),
              _buildStatCard(
                'Max Humidity',
                '${maxHumidity.toStringAsFixed(1)}%',
                Icons.water_drop,
                successColor,
              ),
              _buildStatCard(
                'Motion Events',
                motionEvents.toString(),
                Icons.motion_photos_on,
                dangerColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: const Color(0xFF5d4e75).withOpacity(0.7),
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildChartsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentColor.withOpacity(0.3),
          width: 1,
        ),
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
          Row(
            children: [
              Icon(
                Icons.show_chart,
                color: successColor,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Sensor Charts (Last 50)',
                  style: TextStyle(
                    color: const Color(0xFF5d4e75),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Temperature Chart with custom implementation
          _buildCustomChart(
            sensorData.map<double>((d) => (d['temperature'] is int) ? (d['temperature'] as int).toDouble() : (d['temperature'] as double)).toList(), 
            warningColor, 
            'Temperature (°C)', 
            15.0, 
            40.0,
            '°C'
          ),
          const SizedBox(height: 16),
          // Humidity Chart with custom implementation
          _buildCustomChart(
            sensorData.map<double>((d) => (d['humidity'] is int) ? (d['humidity'] as int).toDouble() : (d['humidity'] as double)).toList(), 
            successColor, 
            'Humidity (%)', 
            40.0, 
            100.0,
            '%'
          ),
        ],
      ),
    );
  }

  Widget _buildCustomChart(List<double> data, Color color, String title,
      double chartMinValue, double chartMaxValue, String unit) {
    if (data.isEmpty) {
      return Container(
        height: 400,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            'No data available',
            style: TextStyle(color: const Color(0xFF5d4e75).withOpacity(0.6)),
          ),
        ),
      );
    }

    // Calculate actual data min/max for display
    double dataMinValue = data.reduce((a, b) => a < b ? a : b);
    double dataMaxValue = data.reduce((a, b) => a > b ? a : b);

    double range = chartMaxValue - chartMinValue;
    if (range == 0) range = 1; // Avoid division by zero

    return Container(
      height: 400,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: const Color(0xFF5d4e75),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${data.length} readings',
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: successColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Min: ${dataMinValue.toStringAsFixed(1)}',
                  style: TextStyle(
                    color: successColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: dangerColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Max: ${dataMaxValue.toStringAsFixed(1)}',
                  style: TextStyle(
                    color: dangerColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: warningColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Avg: ${(data.reduce((a, b) => a + b) / data.length).toStringAsFixed(1)}',
                  style: TextStyle(
                    color: warningColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: CustomChart(
              data: data,
              timestamps: sensorData.map((d) => _formatTime(DateTime.parse(d['timestamp']).toUtc().add(const Duration(hours: 8)))).toList(),
              color: color,
              chartMinValue: chartMinValue,
              chartMaxValue: chartMaxValue,
              unit: unit,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayEventsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentColor.withOpacity(0.3),
          width: 1,
        ),
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
          Row(
            children: [
              Icon(
                Icons.event_note,
                color: dangerColor,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                'Today\'s Security Events',
                style: TextStyle(
                  color: const Color(0xFF5d4e75),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (todayEvents.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'No events recorded today',
                  style: TextStyle(
                    color: const Color(0xFF5d4e75).withOpacity(0.6),
                    fontSize: 16,
                  ),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: todayEvents.length,
              separatorBuilder: (context, index) => Divider(
                color: Colors.white.withOpacity(0.1),
                height: 1,
              ),
              itemBuilder: (context, index) {
                final event = todayEvents[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: event['color'].withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      event['icon'],
                      color: event['color'],
                      size: 20,
                    ),
                  ),
                  title: Text(
                    event['type'],
                    style: const TextStyle(
                      color: Color(0xFF5d4e75),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    event['description'],
                    style: TextStyle(
                      color: const Color(0xFF5d4e75).withOpacity(0.6),
                      fontSize: 12,
                    ),
                  ),
                  trailing: Text(
                    event['time'],
                    style: TextStyle(
                      color: const Color(0xFF5d4e75).withOpacity(0.5),
                      fontSize: 12,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class CustomChart extends StatefulWidget {
  final List<double> data;
  final List<String> timestamps;
  final Color color;
  final double chartMinValue;
  final double chartMaxValue;
  final String unit;

  const CustomChart({
    Key? key,
    required this.data,
    required this.timestamps,
    required this.color,
    required this.chartMinValue,
    required this.chartMaxValue,
    required this.unit,
  }) : super(key: key);

  @override
  State<CustomChart> createState() => _CustomChartState();
}

class _CustomChartState extends State<CustomChart> {
  int? hoveredIndex;
  Offset? tapPosition;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (details) {
        final RenderBox renderBox = context.findRenderObject() as RenderBox;
        final localPosition = renderBox.globalToLocal(details.globalPosition);
        
        // Calculate which data point was tapped
        final leftPadding = 40.0; // Match the chart's left padding
        final rightPadding = 20.0; // Match the chart's right padding
        final chartWidth = renderBox.size.width - leftPadding - rightPadding;
        final pointWidth = chartWidth / (widget.data.length - 1);
        final tappedIndex = ((localPosition.dx - leftPadding) / pointWidth).round();
        
        if (tappedIndex >= 0 && tappedIndex < widget.data.length) {
          setState(() {
            hoveredIndex = tappedIndex;
            tapPosition = localPosition;
          });
          
          // Show tooltip
          _showTooltip(context, tappedIndex, details.globalPosition);
        }
      },
      onPanUpdate: (details) {
        final RenderBox renderBox = context.findRenderObject() as RenderBox;
        final localPosition = renderBox.globalToLocal(details.globalPosition);
        
        // Calculate which data point is being hovered
        final leftPadding = 40.0;
        final rightPadding = 20.0;
        final chartWidth = renderBox.size.width - leftPadding - rightPadding;
        final pointWidth = chartWidth / (widget.data.length - 1);
        final hoveredIdx = ((localPosition.dx - leftPadding) / pointWidth).round();
        
        if (hoveredIdx >= 0 && hoveredIdx < widget.data.length && hoveredIdx != hoveredIndex) {
          setState(() {
            hoveredIndex = hoveredIdx;
            tapPosition = localPosition;
          });
          
          // Close any existing tooltip and show new one
          Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
          _showTooltip(context, hoveredIdx, details.globalPosition);
        }
      },
      onPanEnd: (details) {
        setState(() {
          hoveredIndex = null;
          tapPosition = null;
        });
      },
      child: CustomPaint(
        painter: ChartPainter(
          data: widget.data,
          timestamps: widget.timestamps,
          color: widget.color,
          chartMinValue: widget.chartMinValue,
          chartMaxValue: widget.chartMaxValue,
          hoveredIndex: hoveredIndex,
        ),
        size: Size.infinite,
      ),
    );
  }

  void _showTooltip(BuildContext context, int index, Offset globalPosition) {
    final value = widget.data[index];
    final timestamp = widget.timestamps[index];
    
    // Get screen dimensions to prevent tooltip from going off-screen
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    // Calculate tooltip position with bounds checking
    final tooltipWidth = 120.0;
    final tooltipHeight = 60.0;
    
    double left = globalPosition.dx - (tooltipWidth / 2);
    double top = globalPosition.dy - tooltipHeight - 10;
    
    // Ensure tooltip stays within screen bounds
    if (left < 10) left = 10;
    if (left + tooltipWidth > screenWidth - 10) left = screenWidth - tooltipWidth - 10;
    if (top < 10) top = globalPosition.dy + 10; // Show below if no space above
    
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => Stack(
        children: [
          Positioned(
            left: left,
            top: top,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: tooltipWidth,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      timestamp,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${value.toStringAsFixed(1)}${widget.unit}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
    
    // Auto dismiss after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }
}

class ChartPainter extends CustomPainter {
  final List<double> data;
  final List<String> timestamps;
  final Color color;
  final double chartMinValue;
  final double chartMaxValue;
  final int? hoveredIndex;

  ChartPainter({
    required this.data,
    required this.timestamps,
    required this.color,
    required this.chartMinValue,
    required this.chartMaxValue,
    this.hoveredIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = color.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final hoveredDotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.2)
      ..strokeWidth = 1;

    // Chart dimensions with proper padding for Y-axis labels and X-axis time labels
    final leftPadding = 40.0; // More space for Y-axis labels
    final rightPadding = 20.0;
    final topPadding = 20.0;
    final bottomPadding = 40.0; // More space for X-axis time labels
    
    final chartWidth = size.width - leftPadding - rightPadding;
    final chartHeight = size.height - topPadding - bottomPadding;
    final startX = leftPadding;
    final startY = topPadding;
    final endX = startX + chartWidth;
    final endY = startY + chartHeight;

    // Draw chart border
    final borderPaint = Paint()
      ..color = color.withOpacity(0.3)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    
    canvas.drawRect(
      Rect.fromLTWH(startX, startY, chartWidth, chartHeight),
      borderPaint,
    );

    // Draw grid lines and Y-axis labels
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );
    
    for (int i = 0; i <= 4; i++) {
      final y = startY + (chartHeight / 4) * i;
      
      // Draw horizontal grid line
      canvas.drawLine(
        Offset(startX, y),
        Offset(startX + chartWidth, y),
        gridPaint,
      );
      
      // Calculate and draw Y-axis label
      final valueRatio = 1.0 - (i / 4.0); // Invert because canvas Y increases downward
      final labelValue = chartMinValue + (chartMaxValue - chartMinValue) * valueRatio;
      
      textPainter.text = TextSpan(
        text: labelValue.toStringAsFixed(0),
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      );
      textPainter.layout();
      
      // Position label to the left of the chart
      textPainter.paint(
        canvas,
        Offset(startX - textPainter.width - 8, y - textPainter.height / 2),
      );
    }

    // Draw X-axis time labels (show every 4th timestamp to avoid crowding)
    if (timestamps.isNotEmpty) {
      final step = math.max(1, (timestamps.length / 5).ceil()); // Show max 5 labels
      for (int i = 0; i < timestamps.length; i += step) {
        final x = startX + (chartWidth / (timestamps.length - 1)) * i;
        
        textPainter.text = TextSpan(
          text: timestamps[i],
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        );
        textPainter.layout();
        
        // Position label below the chart
        textPainter.paint(
          canvas,
          Offset(x - textPainter.width / 2, startY + chartHeight + 8),
        );
      }
    }

    // Clip canvas to chart area to ensure nothing draws outside
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(startX, startY, chartWidth, chartHeight));

    // Calculate points with proper clamping
    final points = <Offset>[];
    final fillPoints = <Offset>[];
    
    for (int i = 0; i < data.length; i++) {
      final x = startX + (chartWidth / (data.length - 1)) * i;
      
      // Clamp the data value to chart boundaries
      final clampedValue = math.max(chartMinValue, math.min(chartMaxValue, data[i]));
      
      // Calculate normalized position within chart area
      final normalizedValue = (clampedValue - chartMinValue) / (chartMaxValue - chartMinValue);
      final y = startY + chartHeight - (normalizedValue * chartHeight);
      
      // Ensure y is within chart boundaries
      final clampedY = math.max(startY, math.min(startY + chartHeight, y));
      
      points.add(Offset(x, clampedY));
      
      if (i == 0) {
        fillPoints.add(Offset(x, startY + chartHeight));
      }
      fillPoints.add(Offset(x, clampedY));
      if (i == data.length - 1) {
        fillPoints.add(Offset(x, startY + chartHeight));
      }
    }

    // Draw fill area
    if (fillPoints.length > 2) {
      final fillPath = Path();
      fillPath.addPolygon(fillPoints, true);
      canvas.drawPath(fillPath, fillPaint);
    }

    // Draw line with clipping
    if (points.length > 1) {
      final path = Path();
      path.moveTo(points[0].dx, points[0].dy);
      
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      
      canvas.drawPath(path, paint);
    }

    // Restore canvas (remove clipping for dots)
    canvas.restore();
    canvas.save();

    // Draw dots (these can be slightly outside for visual appeal)
    for (int i = 0; i < points.length; i++) {
      final isHovered = hoveredIndex == i;
      final dotRadius = isHovered ? 6.0 : 4.0;
      
      canvas.drawCircle(
        points[i],
        dotRadius,
        isHovered ? hoveredDotPaint : dotPaint,
      );
      
      // Draw white border for dots
      canvas.drawCircle(
        points[i],
        dotRadius,
        Paint()
          ..color = Colors.white
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke,
      );
    }
    
    canvas.restore();
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
 