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
    
    // Prepare statement to prevent SQL injection
    $stmt = $conn->prepare("SELECT user_id, user_email, user_password FROM tbl_users WHERE user_email = ?");
    $stmt->bind_param("s", $input_email);
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($result->num_rows > 0) {
        $row = $result->fetch_assoc();
        
        // Verify password (using password_verify for hashed passwords)
        if (password_verify($input_password, $row['user_password'])) {
            // Login successful
            echo json_encode(array(
                "status" => "success", 
                "message" => "Login successful",
                "data" => array(
                    "user_id" => $row['user_id'],
                    "user_email" => $row['user_email']
                )
            ));
        } else {
            // Invalid password
            echo json_encode(array("status" => "error", "message" => "Invalid email or password"));
        }
    } else {
        // User not found
        echo json_encode(array("status" => "error", "message" => "Invalid email or password"));
    }
    
    $stmt->close();
} else {
    echo json_encode(array("status" => "error", "message" => "Only POST method allowed"));
}

$conn->close();
?> 