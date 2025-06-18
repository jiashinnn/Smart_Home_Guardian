<?php
// ENUM-compatible threshold getter for Arduino
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

include_once("dbconnect.php");

try {
    // Get threshold settings and relay command for Arduino
    $stmt = $conn->prepare("SELECT temp_high_threshold, temp_low_threshold, humidity_threshold, auto_relay_control, current_relay_state FROM tbl_threshold WHERE threshold_id = 1");
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($result->num_rows > 0) {
        $row = $result->fetch_assoc();
        
        // Convert ENUM 'yes'/'no' to boolean for Arduino
        $autoRelayEnabled = ($row['auto_relay_control'] === 'yes');
        
        $response = [
            'status' => 'success',
            'temp_threshold' => floatval($row['temp_high_threshold']),
            'temp_low_threshold' => floatval($row['temp_low_threshold']),
            'hum_threshold' => floatval($row['humidity_threshold']),
            'auto_relay' => $autoRelayEnabled,
            'relay_command' => $row['current_relay_state'] ?: 'OFF',
            'relay_reason' => 'system'
        ];
        
        echo json_encode($response);
    } else {
        // Create default record if none exists
        $createStmt = $conn->prepare("INSERT INTO tbl_threshold (threshold_id, temp_high_threshold, temp_low_threshold, humidity_threshold, auto_relay_control, current_relay_state) VALUES (1, 30.0, 18.0, 90.0, 'yes', 'OFF')");
        $createStmt->execute();
        
        $response = [
            'status' => 'success',
            'temp_threshold' => 30.0,
            'temp_low_threshold' => 18.0,
            'hum_threshold' => 90.0,
            'auto_relay' => true,
            'relay_command' => 'OFF',
            'relay_reason' => 'default'
        ];
        
        echo json_encode($response);
    }
    
    $stmt->close();
} catch (Exception $e) {
    echo json_encode([
        'status' => 'error',
        'message' => 'Error: ' . $e->getMessage(),
        'temp_threshold' => 30.0,
        'temp_low_threshold' => 18.0,
        'hum_threshold' => 90.0,
        'auto_relay' => true,
        'relay_command' => 'OFF',
        'relay_reason' => 'error'
    ]);
}

$conn->close();
?> 