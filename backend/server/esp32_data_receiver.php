<?php
// ENUM-compatible data receiver for ESP32
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

include_once("dbconnect.php");

try {
    // Get sensor data from ESP32
    $temp = $_GET['temp'] ?? 0;
    $humidity = $_GET['hum'] ?? 0;
    $motion = $_GET['motion'] ?? 'CLEAR';
    $vibration = $_GET['vibration'] ?? 'CLEAR';
    $currentRelayState = $_GET['relay'] ?? 'OFF';
    
    // Get current auto relay setting (ENUM 'yes'/'no')
    $settingsQuery = "SELECT auto_relay_control, current_relay_state FROM tbl_threshold WHERE threshold_id = 1";
    $settingsResult = $conn->query($settingsQuery);
    
    if ($settingsResult && $settingsResult->num_rows > 0) {
        $settingsRow = $settingsResult->fetch_assoc();
        $autoRelayEnabled = ($settingsRow['auto_relay_control'] === 'yes'); // Convert ENUM to boolean
        $currentDbRelayState = $settingsRow['current_relay_state'] ?: 'OFF';
    } else {
        // Create default settings if none exist
        $conn->query("INSERT INTO tbl_threshold (threshold_id, temp_high_threshold, temp_low_threshold, humidity_threshold, auto_relay_control, current_relay_state) VALUES (1, 30.0, 18.0, 90.0, 'yes', 'OFF')");
        $autoRelayEnabled = true;
        $currentDbRelayState = 'OFF';
    }
    
    // Determine relay command based on mode
    $relayCommand = 'OFF';
    $controlReason = 'default';
    
    if ($autoRelayEnabled) {
        // AUTO MODE: Relay based on sensors
        if ($motion === 'DETECTED' || $vibration === 'DETECTED') {
            $relayCommand = 'ON';
            $controlReason = 'auto_sensor_detected';
        } else {
            $relayCommand = 'OFF';
            $controlReason = 'auto_sensor_clear';
        }
    } else {
        // MANUAL MODE: Use current database relay command
        $relayCommand = $currentDbRelayState;
        $controlReason = 'manual_control';
    }
    
    // Update database with new relay command (only current_relay_state column exists)
    $updateStmt = $conn->prepare("UPDATE tbl_threshold SET current_relay_state = ? WHERE threshold_id = 1");
    if ($updateStmt) {
        $updateStmt->bind_param("s", $relayCommand);
        $updateStmt->execute();
        $updateStmt->close();
    }
    
    // Insert sensor data into database
    $insertStmt = $conn->prepare("INSERT INTO tbl_sensor (temperature, humidity, motion_detected, vibration_detected, relay_state, timestamp) VALUES (?, ?, ?, ?, ?, NOW())");
    if ($insertStmt) {
        $insertStmt->bind_param("ddsss", $temp, $humidity, $motion, $vibration, $relayCommand);
        $insertStmt->execute();
        $insertStmt->close();
    }
    
    // Return relay command to ESP32
    echo json_encode([
        'status' => 'success',
        'relay_command' => $relayCommand,
        'control_reason' => $controlReason,
        'mode' => $autoRelayEnabled ? 'AUTO' : 'MANUAL',
        'timestamp' => date('Y-m-d H:i:s')
    ]);
    
} catch (Exception $e) {
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage(),
        'relay_command' => 'OFF',
        'control_reason' => 'error',
        'timestamp' => date('Y-m-d H:i:s')
    ]);
}

$conn->close();
?> 