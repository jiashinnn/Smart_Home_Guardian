<?php
// ENUM-compatible relay controller
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

include_once("dbconnect.php");

try {
    $relayState = $_GET['relay_state'] ?? 'OFF';
    
    // Validate relay state
    if (!in_array($relayState, ['ON', 'OFF'])) {
        throw new Exception("Invalid relay state. Use 'ON' or 'OFF'");
    }
    
    // Check if we're in manual mode (ENUM 'no' = manual, 'yes' = auto)
    $checkModeQuery = "SELECT auto_relay_control FROM tbl_threshold WHERE threshold_id = 1";
    $result = $conn->query($checkModeQuery);
    
    if ($result && $result->num_rows > 0) {
        $row = $result->fetch_assoc();
        if ($row['auto_relay_control'] === 'yes') { // ENUM 'yes' = auto mode
            throw new Exception("Cannot control relay manually while in auto mode. Switch to manual mode first.");
        }
    } else {
        // Create default record if none exists
        $conn->query("INSERT INTO tbl_threshold (threshold_id, temp_high_threshold, temp_low_threshold, humidity_threshold, auto_relay_control, current_relay_state) VALUES (1, 30.0, 18.0, 90.0, 'no', 'OFF')");
    }
    
    // Update relay command in database (only current_relay_state column exists)
    $updateStmt = $conn->prepare("UPDATE tbl_threshold SET current_relay_state = ? WHERE threshold_id = 1");
    if ($updateStmt) {
        $updateStmt->bind_param("s", $relayState);
        $executeResult = $updateStmt->execute();
        
        if (!$executeResult) {
            throw new Exception("Failed to update relay state in database");
        }
        $updateStmt->close();
    } else {
        throw new Exception("Failed to prepare SQL statement");
    }
    
    echo json_encode([
        'status' => 'success',
        'message' => "Manual relay control: $relayState",
        'relay_state' => $relayState,
        'control_reason' => 'manual_app_control',
        'timestamp' => date('Y-m-d H:i:s')
    ]);
    
} catch (Exception $e) {
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage(),
        'timestamp' => date('Y-m-d H:i:s')
    ]);
}

$conn->close();
?> 