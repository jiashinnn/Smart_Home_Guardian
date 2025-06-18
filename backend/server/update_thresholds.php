<?php
// Updated threshold updater for ENUM auto_relay_control column
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

include_once("dbconnect.php");

try {
    // Get input data
    $input = null;
    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        $input = json_decode(file_get_contents('php://input'), true);
    } else {
        $input = $_GET;
    }
    
    // Debug: Log the received data
    error_log("Received data: " . json_encode($input));
    
    if (!$input) {
        throw new Exception("No input data received");
    }
    
    // Check if threshold_id = 1 exists
    $checkQuery = "SELECT COUNT(*) as count FROM tbl_threshold WHERE threshold_id = 1";
    $checkResult = $conn->query($checkQuery);
    $checkCount = $checkResult->fetch_assoc()['count'];
    
    error_log("Threshold records with ID 1: " . $checkCount);
    
    if ($checkCount == 0) {
        // Create the record if it doesn't exist
        $createQuery = "INSERT INTO tbl_threshold (threshold_id, temp_high_threshold, temp_low_threshold, humidity_threshold, auto_relay_control, current_relay_state) 
                        VALUES (1, 30.0, 18.0, 90.0, 'yes', 'OFF')";
        $createResult = $conn->query($createQuery);
        
        if (!$createResult) {
            throw new Exception("Failed to create threshold record: " . $conn->error);
        }
        
        error_log("Created new threshold record with ID 1");
    }
    
    // Get current values from database
    $currentQuery = "SELECT temp_high_threshold, temp_low_threshold, humidity_threshold, auto_relay_control FROM tbl_threshold WHERE threshold_id = 1";
    $currentResult = $conn->query($currentQuery);
    
    if (!$currentResult) {
        throw new Exception("Database query failed: " . $conn->error);
    }
    
    if ($currentResult->num_rows == 0) {
        throw new Exception("No threshold record found with threshold_id = 1 after creation attempt");
    }
    
    $currentValues = $currentResult->fetch_assoc();
    error_log("Current DB values: " . json_encode($currentValues));
    
    // Process auto_relay for ENUM column
    $newAutoRelay = null;
    if (isset($input['auto_relay'])) {
        $autoRelayInput = $input['auto_relay'];
        // Convert to ENUM values: 'yes' or 'no'
        $newAutoRelay = ($autoRelayInput === 'yes' || $autoRelayInput === '1' || $autoRelayInput === 1 || $autoRelayInput === true) ? 'yes' : 'no';
        
        error_log("Auto relay conversion: '$autoRelayInput' -> '$newAutoRelay' (current: " . $currentValues['auto_relay_control'] . ")");
    }
    
    // Build update query
    $updateFields = [];
    $params = [];
    $types = "";
    
    // Temperature high threshold
    if (isset($input['temp_high_threshold'])) {
        $tempHigh = floatval($input['temp_high_threshold']);
        if ($tempHigh >= -50 && $tempHigh <= 100) {
            $updateFields[] = "temp_high_threshold = ?";
            $params[] = $tempHigh;
            $types .= "d";
        }
    }
    
    // Temperature low threshold
    if (isset($input['temp_low_threshold'])) {
        $tempLow = floatval($input['temp_low_threshold']);
        if ($tempLow >= -50 && $tempLow <= 100) {
            $updateFields[] = "temp_low_threshold = ?";
            $params[] = $tempLow;
            $types .= "d";
        }
    }
    
    // Humidity threshold
    if (isset($input['humidity_threshold'])) {
        $humidity = floatval($input['humidity_threshold']);
        if ($humidity >= 0 && $humidity <= 100) {
            $updateFields[] = "humidity_threshold = ?";
            $params[] = $humidity;
            $types .= "d";
        }
    }
    
    // Auto relay control (ENUM: 'yes' or 'no')
    if ($newAutoRelay !== null) {
        $updateFields[] = "auto_relay_control = ?";
        $params[] = $newAutoRelay;
        $types .= "s"; // String for ENUM
    }
    
    if (empty($updateFields)) {
        echo json_encode([
            'status' => 'error',
            'message' => 'No valid fields to update',
            'received_data' => $input,
            'timestamp' => date('Y-m-d H:i:s')
        ]);
        exit;
    }
    
    // Execute update
    $updateSql = "UPDATE tbl_threshold SET " . implode(", ", $updateFields) . " WHERE threshold_id = 1";
    
    error_log("Update SQL: $updateSql");
    error_log("Update params: " . json_encode($params));
    
    $stmt = $conn->prepare($updateSql);
    if (!$stmt) {
        throw new Exception("SQL prepare failed: " . $conn->error);
    }
    
    if (!empty($params)) {
        $stmt->bind_param($types, ...$params);
    }
    
    $executeResult = $stmt->execute();
    if (!$executeResult) {
        throw new Exception("SQL execute failed: " . $stmt->error);
    }
    
    $affectedRows = $stmt->affected_rows;
    $stmt->close();
    
    error_log("Affected rows: $affectedRows");
    
    // Get final values to confirm
    $finalQuery = "SELECT temp_high_threshold, temp_low_threshold, humidity_threshold, auto_relay_control FROM tbl_threshold WHERE threshold_id = 1";
    $finalResult = $conn->query($finalQuery);
    $finalValues = $finalResult->fetch_assoc();
    
    error_log("Final DB values: " . json_encode($finalValues));
    
    // Always return success if query executed
    echo json_encode([
        'status' => 'success',
        'message' => $affectedRows > 0 ? 'Settings updated successfully' : 'Settings confirmed (no changes needed)',
        'affected_rows' => $affectedRows,
        'updated_values' => [
            'temp_high_threshold' => floatval($finalValues['temp_high_threshold']),
            'temp_low_threshold' => floatval($finalValues['temp_low_threshold']),
            'humidity_threshold' => floatval($finalValues['humidity_threshold']),
            'auto_relay' => $finalValues['auto_relay_control'], // Return as-is for ENUM
        ],
        'debug_info' => [
            'input_auto_relay' => $input['auto_relay'] ?? 'not_provided',
            'converted_auto_relay' => $newAutoRelay,
            'current_db_auto_relay' => $currentValues['auto_relay_control'],
            'final_db_auto_relay' => $finalValues['auto_relay_control'],
            'threshold_records_found' => $checkCount
        ],
        'timestamp' => date('Y-m-d H:i:s')
    ]);
    
} catch (Exception $e) {
    error_log("Update thresholds error: " . $e->getMessage());
    echo json_encode([
        'status' => 'error',
        'message' => 'Error updating settings: ' . $e->getMessage(),
        'timestamp' => date('Y-m-d H:i:s')
    ]);
}

$conn->close();
?> 