# Smart Room Guardian: IoT-Based Motion and Vibration Detection System

![Smart Room Guardian](https://img.shields.io/badge/Platform-IoT-blue) ![Flutter](https://img.shields.io/badge/Frontend-Flutter-02569B) ![ESP32](https://img.shields.io/badge/Hardware-ESP32-E7352C) ![PHP](https://img.shields.io/badge/Backend-PHP-777BB4) ![MySQL](https://img.shields.io/badge/Database-MySQL-4479A1)

> An intelligent IoT security system designed to protect children and elderly individuals at home through real-time motion and vibration detection with mobile app monitoring.

## 📋 Table of Contents

- [Project Overview](#-project-overview)
- [Problem Statement](#-problem-statement)
- [System Architecture](#-system-architecture)
- [Features](#-features)
- [Hardware Components](#-hardware-components)
- [Software Stack](#-software-stack)
- [Installation Guide](#-installation-guide)
- [API Documentation](#-api-documentation)
- [Mobile App Interface](#-mobile-app-interface)
- [Hardware Setup](#-hardware-setup)
- [Configuration](#-configuration)
- [Usage Guide](#-usage-guide)
- [Database Schema](#-database-schema)
- [Contributing](#-contributing)
- [License](#-license)

## 🎯 Project Overview

The **Smart Room Guardian** is a comprehensive IoT-based security system that provides real-time monitoring and protection for vulnerable individuals staying alone at home. The system combines hardware sensors with a mobile application to deliver intelligent monitoring, automatic alerts, and remote control capabilities.

### Main Objective
To develop a smart room guardian system that helps protect children or elderly individuals who are alone at home by detecting motion or vibration and alerting users through a digital interface.

### Sub Objectives
1. **Motion & Intrusion Detection**: Detect human movement and break-in attempts using PIR and vibration sensors
2. **Environmental Monitoring**: Display temperature and humidity readings on local OLED display
3. **Intelligent Alert System**: Activate relay-controlled buzzer when danger is detected
4. **Remote Monitoring**: Provide mobile interface for real-time monitoring and control

## 🚨 Problem Statement

In many homes today, children, students, and elderly people often stay alone without proper safety systems. These vulnerable individuals may not realize if someone enters their space without permission, especially during sleep or absence. Break-ins can occur quietly and go unnoticed without proper detection systems, creating fear and worry for families. The lack of reliable and affordable room monitoring increases risks of theft, injury, or harm.

**Our solution addresses these concerns through intelligent IoT monitoring with real-time alerts and remote accessibility.**

## 🏗️ System Architecture

```
┌─────────────┐    HTTPS/API    ┌──────────────┐    HTTP/JSON    ┌─────────────┐
│   Flutter   │ ◄────────────── │ PHP Backend  │ ◄────────────── │    ESP32    │
│ Mobile App  │                 │   + MySQL    │                 │  Hardware   │
└─────────────┘                 └──────────────┘                 └─────────────┘
      │                               │                               │
      ▼                               ▼                               ▼
┌─────────────┐                 ┌──────────────┐                 ┌─────────────┐
│ User Auth   │                 │ tbl_users    │                 │ Sensors:    │
│ Dashboard   │                 │ tbl_sensor   │                 │ • DHT11     │
│ Controls    │                 │ tbl_threshold│                 │ • PIR       │
│ History     │                 └──────────────┘                 │ • SW-420    │
└─────────────┘                                                  │ • OLED      │
                                                                 │ • Relay     │
                                                                 └─────────────┘
```

### Data Flow
1. **ESP32** reads sensors every 3 seconds
2. **Hardware** sends data via HTTP GET to PHP backend
3. **Backend** processes data, applies logic, stores in MySQL
4. **Mobile App** polls backend every 3 seconds for real-time updates
5. **Users** can configure thresholds and control devices remotely

## ✨ Features

### 🔒 Security Features
- **Real-time Motion Detection**: PIR sensor with instant alerts
- **Vibration Monitoring**: SW-420 sensor for door/window intrusion detection
- **Intelligent Alert System**: Automatic buzzer activation with configurable thresholds
- **Dual Control Modes**: Automatic sensor-based or manual user control

### 📱 Mobile Application
- **Secure Authentication**: User registration and login with password hashing
- **Live Dashboard**: Real-time sensor readings with 3-second refresh
- **Device Control**: Configure temperature/humidity thresholds and relay modes
- **Historical Analytics**: Data visualization with charts and event timeline
- **Remote Control**: Manual relay control from anywhere with internet

### 🌡️ Environmental Monitoring
- **Temperature Tracking**: Configurable high/low temperature alerts
- **Humidity Monitoring**: Real-time humidity levels with threshold alerts
- **Local Display**: OLED screen showing system status without internet dependency

### ☁️ Cloud Integration
- **Real-time Database**: MySQL storage with automatic data logging
- **RESTful APIs**: Secure HTTPS communication between components
- **Historical Data**: Long-term storage for trend analysis and reporting

## 🔧 Hardware Components

| Component | Model | Pin | Function |
|-----------|-------|-----|----------|
| **Microcontroller** | ESP32 | - | Main processing unit with WiFi |
| **Temperature/Humidity** | DHT11 | Pin 4 | Environmental monitoring |
| **Motion Sensor** | PIR HC-SR501 | Pin 13 | Human movement detection |
| **Vibration Sensor** | SW-420 | Pin 26 | Door/window intrusion detection |
| **Display** | OLED 0.91" | PIN 21 & PIN 22 | Local status display (128x32) |
| **Alert System** | 3.3V Relay | Pin 25 | Buzzer/alarm control |
| **Status Indicator** | Built-in LED | Pin 2 | WiFi connection status |

### Hardware Specifications
- **Power Supply**: 5V DC via USB or external adapter
- **WiFi**: 802.11 b/g/n (2.4 GHz)
- **Operating Temperature**: -10°C to 85°C
- **Sensor Range**: PIR up to 7 meters, vibration adjustable sensitivity

## 💻 Software Stack

### Frontend (Mobile App)
- **Framework**: Flutter 3.x
- **Language**: Dart
- **UI Components**: Material Design 3
- **HTTP Client**: dart:http
- **Local Storage**: SharedPreferences
- **Animations**: Custom animations with AnimationController

### Backend (Web Server)
- **Language**: PHP 8.x
- **Database**: MySQL 8.x
- **Web Server**: Apache/Nginx
- **API Format**: RESTful JSON APIs
- **Security**: HTTPS, password hashing, input validation

### Hardware (Embedded)
- **Platform**: Arduino IDE / PlatformIO
- **Language**: C++
- **Libraries**: 
  - WiFi.h (ESP32 connectivity)
  - DHT.h (temperature/humidity)
  - Adafruit_SSD1306.h (OLED display)
  - ArduinoJson.h (JSON parsing)
  - HTTPClient.h (API communication)

## 📦 Installation Guide

### Prerequisites
- Flutter SDK 3.0+
- Android Studio / VS Code
- PHP 8.0+
- MySQL 8.0+
- Arduino IDE 2.0+
- ESP32 Board Package

### 1. Database Setup
```sql
-- Import the database schema
mysql -u username -p < backend/database/threenqs_guardian.sql

-- Update database credentials in dbconnect.php
```

### 2. Backend Deployment (JomHosting cPanel)
```bash
# 1. Access cPanel File Manager
# 2. Navigate to public_html/guardian/ directory
# 3. Upload all PHP files from backend/server/ folder
# 4. Import database using cPanel phpMyAdmin:
#    - Go to phpMyAdmin in cPanel
#    - Create database: threenqs_guardian
#    - Import backend/database/threenqs_guardian.sql
# 5. Update database credentials in dbconnect.php with cPanel details

# Example dbconnect.php for JomHosting:
# $servername = "localhost";
# $username = "cpanel_username_dbname";
# $password = "your_database_password";
# $dbname = "cpanel_username_dbname";
```

### 3. Mobile App Setup
```bash
# Clone repository
git clone https://github.com/yourusername/smart-room-guardian.git
cd smart-room-guardian

# Install dependencies
flutter pub get

# Update server URL
nano lib/myconfig.dart

# Build and run
flutter run
```

### 4. Hardware Programming
```bash
# Open Arduino IDE
# Install required libraries:
# - DHT sensor library
# - Adafruit SSD1306
# - ArduinoJson

# Update WiFi credentials and server URL in smarthomeguardian.ino
# Upload to ESP32
```

## 📡 API Documentation

### Authentication Endpoints

#### User Registration
```http
POST /register_user.php
Content-Type: application/x-www-form-urlencoded

email=user@example.com&password=securepassword123
```

#### User Login
```http
POST /login_user.php
Content-Type: application/x-www-form-urlencoded

email=user@example.com&password=securepassword123
```

### Sensor Data Endpoints

#### Get Latest Sensor Reading
```http
GET /get_latest_sensor.php

Response:
{
  "status": "success",
  "data": {
    "temperature": 25.5,
    "humidity": 60.2,
    "motion_detected": "CLEAR",
    "vibration_detected": "DETECTED",
    "relay_state": "ON",
    "timestamp": "2025-01-08 10:30:00"
  },
  "system_status": "VIBRATION ALERT"
}
```

#### Get Historical Data
```http
GET /get_sensor_data.php?limit=50

Response:
{
  "status": "success",
  "data": [...],
  "count_in_response": 50,
  "total_records_in_table": 1250
}
```

### Control Endpoints

#### ESP32 Data Receiver
```http
GET /esp32_data_receiver.php?temp=25.5&hum=60&motion=CLEAR&vibration=DETECTED&relay=OFF

Response:
{
  "status": "success",
  "relay_command": "ON",
  "control_reason": "auto_sensor_detected",
  "mode": "AUTO"
}
```

#### Update Thresholds
```http
POST /update_thresholds.php
Content-Type: application/json

{
  "temp_high_threshold": 30.0,
  "temp_low_threshold": 18.0,
  "humidity_threshold": 90.0,
  "auto_relay": "yes"
}
```

#### Manual Relay Control
```http
GET /control_relay.php?relay_state=ON

Response:
{
  "status": "success",
  "relay_state": "ON",
  "control_reason": "manual_app_control"
}
```

## 📱 Mobile App Interface

### 🔐 Authentication Screens
- **Splash Screen**: Animated loading with brand colors
- **Login Screen**: Secure authentication with remember me option
- **Register Screen**: New user registration with validation

### 📊 Dashboard
- **Real-time Monitoring**: Live sensor readings updated every 3 seconds
- **System Status**: Current operational state with color-coded alerts
- **Recent Activities**: Timeline of motion, vibration, and relay events
- **Environmental Data**: Temperature and humidity with trend indicators

### 🎛️ Device Control
- **Threshold Configuration**: Adjustable temperature and humidity limits
- **Control Mode Toggle**: Switch between automatic and manual operation
- **Manual Relay Control**: Direct buzzer/alarm activation control
- **Settings Persistence**: All configurations saved to cloud database

### 📈 History & Analytics
- **Data Visualization**: Charts showing sensor trends over time
- **Event Statistics**: Summary of daily/weekly activity patterns
- **Export Functionality**: Data export for further analysis
- **Filter Options**: Date range and sensor type filtering

## 🔌 Hardware Setup

### Wiring Diagram
```
ESP32 Pin Layout:
├── Pin 4  → DHT11 Data Pin
├── Pin 13 → PIR Sensor Output
├── Pin 26 → SW-420 Vibration Output
├── Pin 25 → Relay Input (3.3V)
├── Pin 2  → Built-in LED (WiFi Status)
├── SDA    → OLED Display Data
├── SCL    → OLED Display Clock
├── 3.3V   → Sensor Power (DHT11, PIR, SW-420)
├── 5V     → Relay Power
└── GND    → Common Ground
```

### Assembly Instructions
1. **Connect DHT11**: Data to Pin 4, VCC to 3.3V, GND to ground
2. **Connect PIR**: OUT to Pin 13, VCC to 3.3V, GND to ground
3. **Connect SW-420**: DO to Pin 26, VCC to 3.3V, GND to ground
4. **Connect OLED**: SDA/SCL to I2C pins, VCC to 3.3V, GND to ground
5. **Connect Relay**: IN to Pin 25, VCC to 5V, GND to ground
6. **Connect Buzzer**: To relay NO/COM terminals

### Calibration
- **PIR Sensor**: Adjust sensitivity and delay potentiometers
- **SW-420**: Calibrate vibration threshold via onboard potentiometer
- **DHT11**: No calibration required (factory calibrated)

## ⚙️ Configuration

### WiFi Configuration
```cpp
// Update in smarthomeguardian.ino
const char* ssid = "Your_WiFi_SSID";
const char* pass = "Your_WiFi_Password";
String serverName = "https://your-domain.com/";
```

### Server Configuration
```dart
// Update in lib/myconfig.dart
class Myconfig {
  static const String servername = "https://your-domain.com";
}
```

### Database Configuration
```php
// Update in backend/server/dbconnect.php for JomHosting
$servername = "localhost";
$username = "cpanel_username_dbname";  // Usually: cpanel_username_dbname
$password = "your_database_password";   // Database password from cPanel
$dbname = "cpanel_username_dbname";     // Same as username for shared hosting
```

### Threshold Settings (Default Values)
- **Temperature High**: 30.0°C
- **Temperature Low**: 18.0°C
- **Humidity**: 90.0%
- **Auto Relay**: Enabled
- **PIR Warm-up**: 20 seconds
- **Vibration Latch**: 5 seconds

## 📖 Usage Guide

### Initial Setup
1. **Power on ESP32** and wait for WiFi connection (LED indicator)
2. **Install mobile app** and create user account
3. **Configure thresholds** via Device Control screen
4. **Test sensors** by triggering motion and vibration
5. **Verify alerts** on mobile dashboard

### Daily Operation
1. **Monitor Dashboard**: Check real-time sensor status
2. **Review Alerts**: Examine recent activities for any incidents
3. **Adjust Settings**: Modify thresholds based on environmental changes
4. **Check History**: Analyze patterns and trends over time

### Troubleshooting
| Issue | Solution |
|-------|----------|
| **No WiFi Connection** | Check credentials, restart ESP32 |
| **Sensor Not Reading** | Verify wiring, check power supply |
| **App Not Updating** | Check internet connection, verify server URL |
| **False Alarms** | Adjust PIR/vibration sensitivity |
| **Relay Not Working** | Check relay wiring, verify manual control |

## 🗄️ Database Schema

### tbl_users
```sql
CREATE TABLE `tbl_users` (
  `user_id` int(6) NOT NULL AUTO_INCREMENT,
  `user_email` varchar(50) NOT NULL,
  `user_password` varchar(255) NOT NULL,
  `user_regDate` datetime DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`user_id`)
);
```

### tbl_sensor
```sql
CREATE TABLE `tbl_sensor` (
  `sensor_id` int(6) NOT NULL AUTO_INCREMENT,
  `temperature` decimal(5,2) NOT NULL,
  `humidity` decimal(5,2) NOT NULL,
  `motion_detected` enum('CLEAR','DETECTED') NOT NULL,
  `vibration_detected` enum('CLEAR','DETECTED') NOT NULL,
  `relay_state` enum('OFF','ON') NOT NULL,
  `timestamp` datetime DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`sensor_id`)
);
```

### tbl_threshold
```sql
CREATE TABLE `tbl_threshold` (
  `threshold_id` int(11) NOT NULL,
  `temp_high_threshold` decimal(5,2) NOT NULL,
  `temp_low_threshold` decimal(5,2) NOT NULL,
  `humidity_threshold` decimal(5,2) NOT NULL,
  `auto_relay_control` enum('yes','no') NOT NULL,
  `current_relay_state` varchar(10) DEFAULT 'OFF',
  PRIMARY KEY (`threshold_id`)
);
```

## 🔒 Security Features

### Authentication & Authorization
- **Password Hashing**: PHP `password_hash()` with salt
- **HTTPS Communication**: Encrypted data transmission
- **Input Validation**: SQL injection and XSS prevention
- **Session Management**: Secure user session handling

### Data Protection
- **Encrypted Storage**: Sensitive data encryption at rest
- **Access Control**: User-specific data isolation
- **Audit Logging**: System activity tracking
- **Backup Strategy**: Regular database backups

## 🚀 Future Enhancements

### Planned Features
- [ ] **Push Notifications**: Real-time mobile alerts
- [ ] **Multi-room Support**: Multiple ESP32 units per account
- [ ] **Machine Learning**: AI-based anomaly detection
- [ ] **Integration APIs**: Third-party service connections
- [ ] **Voice Control**: Alexa/Google Assistant integration
- [ ] **Mobile Widget**: Quick status on home screen

### Hardware Upgrades
- [ ] **Camera Integration**: Visual verification of alerts
- [ ] **GPS Tracking**: Location-based automation
- [ ] **Battery Backup**: Uninterrupted operation during power outages
- [ ] **Solar Power**: Eco-friendly power solution

## 🤝 Contributing

We welcome contributions! Please follow these guidelines:

1. **Fork the repository**
2. **Create feature branch**: `git checkout -b feature/amazing-feature`
3. **Commit changes**: `git commit -m 'Add amazing feature'`
4. **Push to branch**: `git push origin feature/amazing-feature`
5. **Open Pull Request**

### Development Guidelines
- Follow Dart/Flutter style guidelines
- Add comments for complex logic
- Test on multiple devices
- Update documentation for new features

**Smart Room Guardian** - Protecting families through intelligent IoT technology 🏠🛡️

*Built with ❤️ for safer homes*
