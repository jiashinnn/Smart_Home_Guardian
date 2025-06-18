<?php
// These lines are for debugging. REMOVE/COMMENT THEM IN PRODUCTION.
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

include_once("dbconnect.php");

try {
    $tableName = "tbl_sensor";
    $columns = "sensor_id, temperature, humidity, motion_detected, vibration_detected, relay_state, timestamp";
    
    // Get the most recent sensor reading
    $sql = "SELECT $columns FROM $tableName ORDER BY timestamp DESC LIMIT 1";
    
    $stmt = $conn->prepare($sql);
    if ($stmt === false) {
        throw new Exception("SQL prepare failed: (" . $conn->errno . ") " . $conn->error . " --- Query: " . $sql);
    }
    
    if (!$stmt->execute()) {
        throw new Exception("SQL execute failed: (" . $stmt->errno . ") " . $stmt->error);
    }
    
    $result = $stmt->get_result();
    
    if ($row = $result->fetch_assoc()) {
        $sensorData = [
            'sensor_id' => intval($row['sensor_id']),
            'temperature' => floatval($row['temperature']),
            'humidity' => floatval($row['humidity']),
            'motion_detected' => $row['motion_detected'],
            'vibration_detected' => $row['vibration_detected'],
            'relay_state' => $row['relay_state'],
            'timestamp' => $row['timestamp']
        ];
        
        // Determine system status based on sensor readings
        $systemStatus = "MONITORING";
        if ($row['motion_detected'] === 'DETECTED') {
            $systemStatus = "MOTION DETECTED";
        } elseif ($row['vibration_detected'] === 'DETECTED') {
            $systemStatus = "VIBRATION ALERT";
        }
        
        echo json_encode([
            'status' => 'success',
            'data' => $sensorData,
            'system_status' => $systemStatus,
            'timestamp' => date('Y-m-d H:i:s') // Server timestamp
        ]);
        
    } else {
        // No data found
        echo json_encode([
            'status' => 'no_data',
            'message' => 'No sensor data found in database',
            'system_status' => 'OFFLINE',
            'timestamp' => date('Y-m-d H:i:s')
        ]);
    }
    
    $stmt->close();
    
} catch (Exception $e) {
    error_log("API Error in get_latest_sensor.php: " . $e->getMessage() . " --- Trace: " . $e->getTraceAsString());
    echo json_encode([
        'status' => 'error',
        'message' => 'Server error processing request. Check server logs.',
        'system_status' => 'ERROR',
        'timestamp' => date('Y-m-d H:i:s')
        // 'detailed_error' => $e->getMessage() // For development only
    ]);
}

$conn->close();
?> 