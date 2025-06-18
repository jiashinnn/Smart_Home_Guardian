# New Backend-Controlled Relay System

## Overview
The relay control logic has been moved from Arduino to PHP backend for easier management and control. This provides better flexibility for both automatic sensor-based control and manual app-based control.

## System Architecture

### Old System (Arduino-Controlled)
```
Arduino → Sensors → Arduino Logic → Relay Control → Database (logging only)
```

### New System (Backend-Controlled)
```
Arduino → Sensors → PHP Backend → Relay Decision → Database → Arduino → Physical Relay
```

## Data Flow

### 1. Sensor Data Transmission
- **Arduino** reads sensors (PIR, vibration, DHT11)
- **Arduino** sends data to `esp32_data_receiver.php`
- **PHP** receives sensor data and current relay state

### 2. Relay Control Logic (in PHP)
- **PHP** checks `auto_relay_control` setting from database
- **Auto Mode**: PHP decides relay state based on sensor data
  - Motion OR Vibration detected → Relay ON
  - Both sensors clear → Relay OFF
- **Manual Mode**: PHP uses `manual_relay_state` from database
- **PHP** updates `current_relay_state` in database

### 3. Relay Command Application
- **Arduino** fetches `current_relay_state` from `get_threshold_arduino.php`
- **Arduino** applies the relay command physically
- **Arduino** has no decision-making logic, just executes commands

## Database Changes

### New Columns in `tbl_threshold`
```sql
ALTER TABLE tbl_threshold ADD COLUMN current_relay_state VARCHAR(10) DEFAULT 'OFF';
ALTER TABLE tbl_threshold ADD COLUMN relay_control_reason VARCHAR(50) DEFAULT 'default';
ALTER TABLE tbl_threshold ADD COLUMN relay_last_update TIMESTAMP DEFAULT CURRENT_TIMESTAMP;
```

### Existing Columns Used
- `auto_relay_control` - Enable/disable automatic sensor-based control
- `manual_relay_state` - Manual relay command from app
- `manual_relay_timestamp` - When manual command was sent

## File Changes

### PHP Backend Files

#### 1. `esp32_data_receiver.php` (Major Update)
- **Added**: Relay control logic
- **Added**: Auto/manual mode handling
- **Added**: Database column creation
- **Added**: JSON response with relay commands

#### 2. `get_threshold_arduino.php` (Updated)
- **Added**: Returns `relay_command` field
- **Added**: Returns `relay_reason` field
- **Added**: Database column checks

#### 3. `control_relay.php` (Simplified)
- **Simplified**: Only updates manual state
- **Removed**: Direct relay control logic
- **Added**: Better logging

### Arduino Code (`smarthomeguardian.ino`)

#### Major Changes
- **Removed**: All relay control logic functions
- **Removed**: `checkSecuritySensors()` function
- **Removed**: `processManualRelayControl()` function
- **Removed**: Manual relay variables
- **Added**: `relayCommand` and `relayReason` variables
- **Updated**: `fetchThresholds()` to apply relay commands
- **Updated**: `sendDataToServer()` to parse relay responses
- **Added**: `updateAlertStatus()` for OLED display only

#### Simplified Logic
```cpp
// Arduino now only:
1. Reads sensors
2. Sends data to PHP
3. Receives relay command from PHP
4. Applies relay command physically
5. Updates OLED display
```

### Flutter App (`device_control.dart`)

#### Updates
- **Updated**: `_loadCurrentSettings()` to use `relay_command` instead of `manual_relay_state`
- **Updated**: Success message to reflect backend control
- **Removed**: Direct sensor state checking for relay status

## Benefits of New System

### 1. Easier Manual Control
- Manual commands are processed by PHP backend
- No complex Arduino logic for manual vs auto modes
- Immediate response through database

### 2. Better Debugging
- All relay decisions logged in database
- Clear separation of concerns
- Easier to trace control flow

### 3. More Flexible
- Easy to add new control logic in PHP
- Can implement complex rules without Arduino changes
- Better integration with web/mobile apps

### 4. Cleaner Arduino Code
- Arduino focuses only on hardware interface
- No complex decision-making logic
- Simpler serial output for debugging

## Testing

### Test File: `test_new_system.php`
Run this file to verify the system works:
1. Tests auto mode with motion detection
2. Tests manual control mode
3. Verifies Arduino gets correct commands
4. Tests mode switching

### Manual Testing Steps
1. **Auto Mode Test**:
   - Enable auto relay in app
   - Trigger motion sensor
   - Check relay turns ON
   - Clear sensors
   - Check relay turns OFF

2. **Manual Mode Test**:
   - Disable auto relay in app
   - Use manual ON/OFF buttons
   - Check relay responds to app commands
   - Verify sensors don't affect relay

## Serial Monitor Output

### New Clean Format
```
[DHT] T=25.1°C H=60.5%
[MOTION] Detected
[RELAY] ON (auto_sensor_detected)
[DB] Sent: T=25.1 H=60.5 M=DETECTED V=CLEAR R=ON
[STATUS] Mode=AUTO Relay=ON Motion=DETECTED Vibration=CLEAR
```

### Key Tags
- `[DHT]` - Temperature/humidity readings
- `[MOTION]` - Motion sensor state changes
- `[VIBRATION]` - Vibration sensor state changes
- `[RELAY]` - Relay state changes with reason
- `[DB]` - Database communication
- `[STATUS]` - Periodic system status
- `[CONFIG]` - Settings updates
- `[ERROR]` - Error messages

## Troubleshooting

### Common Issues

1. **Relay not responding**
   - Check `current_relay_state` in database
   - Verify Arduino is fetching thresholds
   - Check PHP backend logs

2. **Manual control not working**
   - Ensure auto relay is disabled
   - Check `manual_relay_state` in database
   - Verify `control_relay.php` response

3. **Auto mode not working**
   - Check `auto_relay_control` setting
   - Verify sensor data reaching PHP
   - Check `esp32_data_receiver.php` logic

### Debug Commands
```sql
-- Check current relay state
SELECT current_relay_state, relay_control_reason, auto_relay_control FROM tbl_threshold WHERE threshold_id = 1;

-- Check recent sensor data
SELECT * FROM tbl_sensor ORDER BY timestamp DESC LIMIT 5;

-- Reset relay state
UPDATE tbl_threshold SET current_relay_state = 'OFF' WHERE threshold_id = 1;
```

## Migration Notes

### From Old System
1. Upload new Arduino code
2. Update PHP files
3. Database columns will be created automatically
4. Test both auto and manual modes
5. Remove old test files if any

### Backward Compatibility
- Database structure is backward compatible
- Flutter app works with new backend
- OLED display functionality preserved
- Serial monitor output improved

## Future Enhancements

### Possible Additions
1. **Scheduled Control**: Time-based relay control
2. **Geofencing**: Location-based control
3. **Smart Rules**: Complex condition-based control
4. **Remote Monitoring**: Real-time status updates
5. **Alert Notifications**: Push notifications for events

### Easy Implementation
Since control logic is now in PHP, these features can be added without Arduino changes, making the system much more extensible and maintainable.