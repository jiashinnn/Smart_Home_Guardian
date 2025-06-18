<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json");

// Handle preflight requests
if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    exit(0);
}

// Include database connection
include_once("dbconnect.php");

// Get POST data
if ($_SERVER["REQUEST_METHOD"] == "POST") {
    $input_email = $_POST['email'] ?? '';
    $input_password = $_POST['password'] ?? '';
    
    // Validate input
    if (empty($input_email) || empty($input_password)) {
        echo json_encode(array("status" => "error", "message" => "Email and password are required"));
        exit;
    }
    
    // Validate email format
    if (!filter_var($input_email, FILTER_VALIDATE_EMAIL)) {
        echo json_encode(array("status" => "error", "message" => "Invalid email format"));
        exit;
    }
    
    // Validate password length
    if (strlen($input_password) < 6) {
        echo json_encode(array("status" => "error", "message" => "Password must be at least 6 characters long"));
        exit;
    }
    
    // Check if email already exists
    $stmt = $conn->prepare("SELECT user_id FROM tbl_users WHERE user_email = ?");
    $stmt->bind_param("s", $input_email);
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($result->num_rows > 0) {
        echo json_encode(array("status" => "error", "message" => "Email already exists"));
        $stmt->close();
        exit;
    }
    $stmt->close();
    
    // Hash the password securely
    $hashed_password = password_hash($input_password, PASSWORD_DEFAULT);
    
    // Insert new user
    $stmt = $conn->prepare("INSERT INTO tbl_users (user_email, user_password, user_regDate) VALUES (?, ?, NOW())");
    $stmt->bind_param("ss", $input_email, $hashed_password);
    
    if ($stmt->execute()) {
        echo json_encode(array(
            "status" => "success", 
            "message" => "Registration successful",
            "data" => array(
                "user_id" => $conn->insert_id,
                "user_email" => $input_email
            )
        ));
    } else {
        echo json_encode(array("status" => "error", "message" => "Registration failed: " . $stmt->error));
    }
    
    $stmt->close();
} else {
    echo json_encode(array("status" => "error", "message" => "Only POST method allowed"));
}

$conn->close();
?> 