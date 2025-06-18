import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'myconfig.dart';
import 'dart:async';

class DeviceControl extends StatefulWidget {
  const DeviceControl({super.key});

  @override
  State<DeviceControl> createState() => _DeviceControlState();
}

class _DeviceControlState extends State<DeviceControl> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  // Controllers for threshold inputs
  final TextEditingController _tempHighController = TextEditingController();
  final TextEditingController _tempLowController = TextEditingController();
  final TextEditingController _humidityController = TextEditingController();
  
  // Current values
  double tempHighThreshold = 30.0;
  double tempLowThreshold = 18.0;
  double humidityThreshold = 90.0;
  bool relayState = false;
  bool autoRelayEnabled = true;
  
  // Loading states
  bool _isLoading = true;
  bool _isSaving = false;
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

  Timer? _dataTimer;

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
    _loadCurrentSettings();
    
    // Start periodic data fetching for real-time relay status
    _startDataFetching();
  }

  void _startDataFetching() {
    _dataTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        _fetchCurrentRelayStatus();
      }
    });
  }

  Future<void> _fetchCurrentRelayStatus() async {
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
              // Update relay state from actual sensor data
              relayState = data['relay_state'] == 'ON';
            });
          }
        }
      }
    } catch (e) {
      // Silent fail for periodic updates to avoid spam
      print("Error fetching relay status: $e");
    }
  }

  Future<void> _loadCurrentSettings() async {
    try {
      // Load thresholds
      final thresholdResponse = await http.get(
        Uri.parse("${Myconfig.servername}/get_threshold_arduino.php"),
      );
      
      if (thresholdResponse.statusCode == 200) {
        final thresholdData = jsonDecode(thresholdResponse.body);
        if (thresholdData['status'] == 'success') {
          setState(() {
            tempHighThreshold = thresholdData['temp_threshold']?.toDouble() ?? 30.0;
            tempLowThreshold = thresholdData['temp_low_threshold']?.toDouble() ?? 18.0;
            humidityThreshold = thresholdData['hum_threshold']?.toDouble() ?? 90.0;
            autoRelayEnabled = thresholdData['auto_relay'] ?? true;
            
            // Update controllers
            _tempHighController.text = tempHighThreshold.toString();
            _tempLowController.text = tempLowThreshold.toString();
            _humidityController.text = humidityThreshold.toString();
          });
        }
      }
      
      // Get current relay state from sensor data (real-time status)
      await _fetchCurrentRelayStatus();
      
      setState(() {
        _isLoading = false;
        _hasError = false;
      });
      
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = "Error loading settings: $e";
      });
    }
  }

  Future<void> _saveThresholds() async {
    setState(() {
      _isSaving = true;
    });
    
    try {
      final response = await http.post(
        Uri.parse("${Myconfig.servername}/update_thresholds.php"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'temp_high_threshold': double.parse(_tempHighController.text),
          'temp_low_threshold': double.parse(_tempLowController.text),
          'humidity_threshold': double.parse(_humidityController.text),
          'auto_relay': autoRelayEnabled ? 'yes' : 'no',
        }),
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['status'] == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Thresholds updated successfully!'),
              backgroundColor: successColor,
              duration: const Duration(seconds: 2),
            ),
          );
          
          setState(() {
            tempHighThreshold = double.parse(_tempHighController.text);
            tempLowThreshold = double.parse(_tempLowController.text);
            humidityThreshold = double.parse(_humidityController.text);
          });
        } else {
          throw Exception(jsonData['message'] ?? 'Failed to update thresholds');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving thresholds: $e'),
          backgroundColor: dangerColor,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _controlRelay(bool newState) async {
    // Only allow manual control when auto relay is disabled
    if (autoRelayEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please disable Auto Relay Control first to use manual control'),
          backgroundColor: warningColor,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    try {
      final response = await http.get(
        Uri.parse("${Myconfig.servername}/control_relay.php?relay_state=${newState ? 'ON' : 'OFF'}"),
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['status'] == 'success') {
          setState(() {
            relayState = newState;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Manual relay control: ${newState ? 'ON' : 'OFF'} - Command will be applied by backend'),
              backgroundColor: successColor,
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          throw Exception(jsonData['message'] ?? 'Failed to control relay');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error controlling relay: $e'),
          backgroundColor: dangerColor,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _saveAutoRelaySetting(bool autoRelayValue) async {
    try {
      final response = await http.post(
        Uri.parse("${Myconfig.servername}/update_thresholds.php"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'temp_high_threshold': tempHighThreshold,
          'temp_low_threshold': tempLowThreshold,
          'humidity_threshold': humidityThreshold,
          'auto_relay': autoRelayValue ? 'yes' : 'no',
        }),
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['status'] == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Auto relay control ${autoRelayValue ? 'enabled' : 'disabled'}'),
              backgroundColor: successColor,
              duration: const Duration(seconds: 2),
            ),
          );
          
          // Reload current settings to get updated relay state
          await _loadCurrentSettings();
        } else {
          throw Exception(jsonData['message'] ?? 'Failed to update auto relay setting');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving auto relay setting: $e'),
          backgroundColor: dangerColor,
          duration: const Duration(seconds: 3),
        ),
      );
      
      // Revert the switch state on error
      setState(() {
        autoRelayEnabled = !autoRelayValue;
      });
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _dataTimer?.cancel();
    _tempHighController.dispose();
    _tempLowController.dispose();
    _humidityController.dispose();
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
                        'Device Control',
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
                        icon: const Icon(Icons.refresh, color: Color(0xFF5d4e75)),
                        onPressed: _loadCurrentSettings,
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
                          Container(
                            padding: const EdgeInsets.all(20),
                            child: Center(
                              child: CircularProgressIndicator(color: primaryColor),
                            ),
                          )
                      else ...[
                        // Error message
                        if (_hasError)
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
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
                          ),
                        
                        // Relay Control Section
                        _buildRelayControlSection(),
                        const SizedBox(height: 24),
                        
                        // Threshold Settings Section
                        _buildThresholdSection(),
                        const SizedBox(height: 24),
                        
                        // Save Button
                        _buildSaveButton(),
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

  Widget _buildRelayControlSection() {
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
                Icons.power_settings_new,
                color: relayState ? successColor : Colors.grey,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                'Buzzer Control',
                style: TextStyle(
                  color: const Color(0xFF5d4e75),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Control Mode Indicator
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (autoRelayEnabled ? primaryColor : warningColor).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: (autoRelayEnabled ? primaryColor : warningColor).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  autoRelayEnabled ? Icons.auto_mode : Icons.touch_app,
                  color: autoRelayEnabled ? primaryColor : warningColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Control Mode: ${autoRelayEnabled ? 'AUTOMATIC' : 'MANUAL'}',
                  style: TextStyle(
                    color: autoRelayEnabled ? primaryColor : warningColor,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Current Status
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (relayState ? successColor : Colors.grey).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (relayState ? successColor : Colors.grey).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  relayState ? Icons.power : Icons.power_off,
                  color: relayState ? successColor : Colors.grey,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Buzzer Status: ${relayState ? 'ON' : 'OFF'}',
                        style: TextStyle(
                          color: relayState ? successColor : Colors.grey,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        autoRelayEnabled 
                          ? 'Controlled by sensors' 
                          : 'Manual control active',
                        style: TextStyle(
                          color: const Color(0xFF5d4e75).withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Manual Control Buttons (only enabled when auto relay is off)
          if (!autoRelayEnabled) ...[
            Text(
              'Manual Control',
              style: TextStyle(
                color: const Color(0xFF5d4e75).withOpacity(0.8),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: relayState ? null : () => _controlRelay(true),
                    icon: const Icon(Icons.power),
                    label: const Text('Turn ON'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: successColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: !relayState ? null : () => _controlRelay(false),
                    icon: const Icon(Icons.power_off),
                    label: const Text('Turn OFF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            // Auto mode message
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: primaryColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Relay is controlled automatically by motion and vibration sensors. Turn off Auto Relay Control to enable manual control.',
                      style: TextStyle(
                        color: const Color(0xFF5d4e75),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: 16),
          
          // Auto Relay Toggle
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: accentColor.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.auto_mode,
                  color: autoRelayEnabled ? primaryColor : Colors.grey,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Auto Relay Control',
                        style: TextStyle(
                          color: const Color(0xFF5d4e75),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        autoRelayEnabled 
                          ? 'Sensors control relay automatically' 
                          : 'Manual control only',
                        style: TextStyle(
                          color: autoRelayEnabled 
                            ? const Color(0xFF5d4e75).withOpacity(0.6)
                            : const Color(0xFFEF4444), // Red color for manual mode
                          fontSize: 12,
                          fontWeight: autoRelayEnabled ? FontWeight.normal : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: autoRelayEnabled,
                  onChanged: (value) async {
                    setState(() {
                      autoRelayEnabled = value;
                    });
                    
                    // Save the auto relay setting immediately
                    await _saveAutoRelaySetting(value);
                  },
                  activeColor: primaryColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThresholdSection() {
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
                Icons.tune,
                color: warningColor,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                'Threshold Settings',
                style: TextStyle(
                  color: const Color(0xFF5d4e75),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Temperature High Threshold
          _buildThresholdInput(
            'High Temperature Threshold',
            _tempHighController,
            '°C',
            Icons.thermostat,
            dangerColor,
          ),
          const SizedBox(height: 16),
          
          // Temperature Low Threshold
          _buildThresholdInput(
            'Low Temperature Threshold',
            _tempLowController,
            '°C',
            Icons.ac_unit,
            primaryColor,
          ),
          const SizedBox(height: 16),
          
          // Humidity Threshold
          _buildThresholdInput(
            'Humidity Threshold',
            _humidityController,
            '%',
            Icons.water_drop,
            warningColor,
          ),
        ],
      ),
    );
  }

  Widget _buildThresholdInput(
    String label,
    TextEditingController controller,
    String unit,
    IconData icon,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: const Color(0xFF5d4e75).withOpacity(0.8),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: accentColor.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Color(0xFF5d4e75)),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: color),
              suffixText: unit,
              suffixStyle: TextStyle(color: const Color(0xFF5d4e75).withOpacity(0.6)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
              hintText: 'Enter value',
              hintStyle: TextStyle(color: const Color(0xFF5d4e75).withOpacity(0.4)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isSaving ? null : _saveThresholds,
        icon: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5d4e75)),
                ),
              )
            : const Icon(Icons.save),
        label: Text(_isSaving ? 'Saving...' : 'Save Settings'),
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: const Color(0xFF5d4e75),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
} 