<?php
// These lines are for debugging. REMOVE/COMMENT THEM IN PRODUCTION.
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS'); // Allow POST as Flutter uses it, GET for direct testing
header('Access-Control-Allow-Headers: Content-Type');

include_once("dbconnect.php");

try {
    // Get the limit parameter from query string, default to 20
    $limit = isset($_GET['limit']) ? intval($_GET['limit']) : 20;
    
    if ($limit < 1) {
        $limit = 20;
    } elseif ($limit > 500) { // Max limit
        $limit = 500;
    }
    
    $tableName = "tbl_sensor";
    // Select all necessary columns for Smart Home Guardian
    $columns = "sensor_id, temperature, humidity, motion_detected, vibration_detected, relay_state, timestamp"; 

    // Fetch sensor data ordered by most recent first
    $sql = "SELECT $columns FROM $tableName ORDER BY timestamp DESC LIMIT ?";
    
    $stmt = $conn->prepare($sql);
    if ($stmt === false) {
        throw new Exception("SQL prepare failed: (" . $conn->errno . ") " . $conn->error . " --- Query: " . $sql);
    }

    // Bind the limit parameter
    $stmt->bind_param("i", $limit); // "i" for integer limit
    
    if (!$stmt->execute()) {
        throw new Exception("SQL execute failed: (" . $stmt->errno . ") " . $stmt->error);
    }
    
    $result = $stmt->get_result();
    
    $sensorData = [];
    while ($row = $result->fetch_assoc()) {
        $sensorData[] = [
            'sensor_id' => intval($row['sensor_id']),
            'temperature' => floatval($row['temperature']),
            'humidity' => floatval($row['humidity']),
            'motion_detected' => $row['motion_detected'],
            'vibration_detected' => $row['vibration_detected'],
            'relay_state' => $row['relay_state'],
            'timestamp' => $row['timestamp']
        ];
    }
    $stmt->close();
    
    // Reverse for chronological order for charts (oldest first)
    $sensorData = array_reverse($sensorData);
    
    // Get total records in the table
    $totalCount = 0;
    $countSql = "SELECT COUNT(*) as total_count FROM $tableName";
    $countStmt = $conn->prepare($countSql);
    if ($countStmt) {
        $countStmt->execute();
        $countResult = $countStmt->get_result();
        $totalCount = $countResult->fetch_assoc()['total_count'];
        $countStmt->close();
    }

    // Get latest sensor reading for current status
    $latestSql = "SELECT $columns FROM $tableName ORDER BY timestamp DESC LIMIT 1";
    $latestStmt = $conn->prepare($latestSql);
    $latestData = null;
    
    if ($latestStmt) {
        $latestStmt->execute();
        $latestResult = $latestStmt->get_result();
        if ($latestRow = $latestResult->fetch_assoc()) {
            $latestData = [
                'sensor_id' => intval($latestRow['sensor_id']),
                'temperature' => floatval($latestRow['temperature']),
                'humidity' => floatval($latestRow['humidity']),
                'motion_detected' => $latestRow['motion_detected'],
                'vibration_detected' => $latestRow['vibration_detected'],
                'relay_state' => $latestRow['relay_state'],
                'timestamp' => $latestRow['timestamp']
            ];
        }
        $latestStmt->close();
    }

    echo json_encode([
        'status' => 'success',
        'data' => $sensorData,
        'latest_reading' => $latestData,
        'count_in_response' => count($sensorData),
        'total_records_in_table' => intval($totalCount),
        'limit_applied' => $limit
    ]);
    
} catch (Exception $e) {
    error_log("API Error in get_sensor_data.php: " . $e->getMessage() . " --- Trace: " . $e->getTraceAsString());
    echo json_encode([
        'status' => 'error',
        'message' => 'Server error processing request. Check server logs.',
        // 'detailed_error' => $e->getMessage() // For development only
    ]);
}

$conn->close();
?> 