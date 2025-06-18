#include <WiFi.h>
#include <HTTPClient.h>
#include "DHT.h"
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <ArduinoJson.h>

// ==================== WiFi Config ====================
const char* ssid = "UUMWiFi_Guest";     // Your WiFi SSID
const char* pass = "";                   // Your WiFi Password (empty if none)
String serverName = "https://guardian.threelittlecar.com/";

// ==================== Pin Definitions ====================
#define DHTPIN 4                    // DHT11 sensor pin
#define RELAY_PIN 25                // Relay control pin
#define PIR_SENSOR_PIN 13           // PIR motion sensor pin
#define VIBRATION_SENSOR_PIN 26     // SW-420 vibration sensor pin
#define WIFI_LED_PIN 2              // Built-in LED to indicate WiFi status

// ==================== DHT11 Setup ====================
#define DHTTYPE DHT11
DHT dht(DHTPIN, DHTTYPE);
float temp = 0, hum = 0;

// ==================== OLED Setup ====================
#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 32
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, -1);

// ==================== Sensor State Variables ====================
bool motionDetected = false;
bool vibrationDetected = false;
bool relayState = false;
bool alertActive = false;
int pirWarmUp = 0;

// ==================== Timing Variables ====================
unsigned long previousMillis = 0;
const long interval = 5000;              // 5 seconds for sending data to database

unsigned long lastSensorCheck = 0;
const long sensorCheckInterval = 3000;    // Check sensors every 3 seconds

unsigned long lastDHTRead = 0;
const long dhtReadInterval = 15000;      // Read DHT11 every 15 seconds

unsigned long lastVibrationTime = 0;
const long vibrationLatchDuration = 5000; // Keep vibration "TRIGGERED" for 5 seconds after detection

unsigned long lastAlertTime = 0;
const long alertDuration = 5000;         // Alert display duration (5 seconds)

unsigned long lastOLEDUpdate = 0;
const long oledUpdateInterval = 1000;    // Update OLED every second

unsigned long lastTempPrint = 0;
const long tempPrintInterval = 5000;     // Print temperature every 5 seconds

unsigned long lastThresholdFetch = 0;
const long thresholdFetchInterval = 30000; // 30 seconds for fetching thresholds

unsigned long lastStatusMessage = 0;
const long statusMessageInterval = 5000;  // Print status message every 5 seconds

// ==================== Smart Data Sending Variables ====================
bool lastRelayAlertState = false;       // Previous relay alert state (for smart printing)
bool lastMotionPrintState = false;      // Previous motion print state (for smart printing)
bool lastVibrationPrintState = false;   // Previous vibration print state (for smart printing)

// ==================== Previous Threshold Values (for smart printing) ====================
float prevTempHighThreshold = 30.0;     // Previous temperature high threshold
float prevTempLowThreshold = 18.0;      // Previous temperature low threshold  
float prevHumThreshold = 90.0;          // Previous humidity threshold
bool prevAutoRelayEnabled = true;       // Previous auto relay setting

// ==================== Temperature Thresholds ====================
float TEMP_HIGH_THRESHOLD = 30.0;   // Too hot threshold
float TEMP_LOW_THRESHOLD = 18.0;    // Too cold threshold
float HUM_THRESHOLD = 90.0;          // Humidity threshold

// ==================== Auto Relay Control ====================
bool autoRelayEnabled = true;       // User can control relay (from database)

// ==================== Manual Relay Control Variables ====================
String relayCommand = "OFF";            // Relay command from PHP backend
String relayReason = "default";         // Reason for relay state from PHP
String lastRelayCommand = "";           // Track relay command changes

void setup() {
  Serial.begin(115200);
  
  // ==================== Pin Setup ====================
  pinMode(RELAY_PIN, OUTPUT);
  pinMode(PIR_SENSOR_PIN, INPUT);
  pinMode(VIBRATION_SENSOR_PIN, INPUT);
  pinMode(WIFI_LED_PIN, OUTPUT);
  
  // Initialize relay to OFF state
  digitalWrite(RELAY_PIN, HIGH);  // Relay OFF (active LOW)
  digitalWrite(WIFI_LED_PIN, LOW); // WiFi LED OFF initially
  
  // ==================== OLED Initialization ====================
  if (!display.begin(SSD1306_SWITCHCAPVCC, 0x3C)) {
    Serial.println("OLED initialization failed!");
    while (true);
  }
  
  displayMessage("Smart Home Guardian", "Initializing...", "", "");
  delay(2000);
  
  // ==================== WiFi Connection ====================
  displayMessage("WiFi Setup", "Connecting to:", ssid, "Please wait...");
  
  WiFi.begin(ssid, pass);
  Serial.print("Connecting to WiFi");
  
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  
  Serial.println("\nWiFi connected successfully!");
  digitalWrite(WIFI_LED_PIN, HIGH); // Turn on LED when WiFi connected
  
  // Display WiFi connection success
  displayMessage("WiFi Connected!", "IP Address:", WiFi.localIP().toString(), "System Ready");
  delay(3000);
  
  // ==================== Initialize Sensors ====================
  dht.begin();
  
  // Fetch initial thresholds from server
  fetchThresholds();
  
  // PIR sensor warm-up
  displayMessage("PIR Sensor", "Warming up...", "Please wait 20s", "");
  Serial.println("PIR Sensor warming up...");
  delay(20000);
  
  displayMessage("System Ready!", "All sensors active", "Monitoring...", "");
  Serial.println("Smart Home Guardian System Ready!");
  delay(2000);
}

void loop() {
  unsigned long currentMillis = millis();
  
  // ==================== Fetch Thresholds and Relay Commands Periodically ====================
  if (currentMillis - lastThresholdFetch >= thresholdFetchInterval) {
    lastThresholdFetch = currentMillis;
    fetchThresholds();
  }
  
  // ==================== Read Sensors ====================
  readSensors();
  
  // ==================== Update Alert Status Based on Sensors ====================
  updateAlertStatus();
  
  // ==================== Print System Status ====================
  if (currentMillis - lastTempPrint >= tempPrintInterval) {
    lastTempPrint = currentMillis;
    printSystemStatus();
  }
  
  // ==================== Print Periodic Status Messages ====================
  if (currentMillis - lastStatusMessage >= statusMessageInterval) {
    lastStatusMessage = currentMillis;
    printPeriodicStatus();
  }
  
  // ==================== Update OLED Display ====================
  if (currentMillis - lastOLEDUpdate >= oledUpdateInterval) {
    lastOLEDUpdate = currentMillis;
    updateOLEDDisplay();
  }
  
  // ==================== Send Data to Database Every 5 Seconds ====================
  if (currentMillis - previousMillis >= interval) {
    previousMillis = currentMillis;
    sendDataToServer(); // Send data and get relay commands
  }
  
  delay(100); // Small delay for system stability
}

void readSensors() {
  unsigned long currentMillis = millis();
  
  // ==================== Read DHT11 Every 15 Seconds (Less Important) ====================
  if (currentMillis - lastDHTRead >= dhtReadInterval) {
    lastDHTRead = currentMillis;
    temp = dht.readTemperature();
    hum = dht.readHumidity();
    
    if (isnan(temp) || isnan(hum)) {
      Serial.println("[ERROR] DHT read failed");
      temp = 0;
      hum = 0;
    } else {
      Serial.printf("[DHT] T=%.1f°C H=%.1f%%\n", temp, hum);
    }
  }
  
  // ==================== Read Security Sensors Every 500ms (More Important) ====================
  if (currentMillis - lastSensorCheck >= sensorCheckInterval) {
    lastSensorCheck = currentMillis;
    
    // ==================== Read PIR Sensor ====================
    int pirReading = digitalRead(PIR_SENSOR_PIN);
    if (pirReading == HIGH) {
      motionDetected = true;
      pirWarmUp = 1;
      // Only print motion detection message when state changes
      if (!lastMotionPrintState) {
        Serial.println("[MOTION] Detected");
        lastMotionPrintState = true;
      }
    } else {
      if (pirWarmUp == 1) {
        pirWarmUp = 0;
      }
      motionDetected = false;
      // Only print motion cleared message when state changes
      if (lastMotionPrintState) {
        Serial.println("[MOTION] Cleared");
        lastMotionPrintState = false;
      }
    }
    
    // ==================== Read Vibration Sensor ====================
    int vibrationReading = digitalRead(VIBRATION_SENSOR_PIN);
    if (vibrationReading == HIGH) {
      vibrationDetected = true;
      lastVibrationTime = currentMillis;
      // Only print vibration detection message when state changes
      if (!lastVibrationPrintState) {
        Serial.println("[VIBRATION] Detected");
        lastVibrationPrintState = true;
      }
    }
    
    // Keep vibration "TRIGGERED" for a duration even after physical vibration stops
    if (vibrationDetected && (currentMillis - lastVibrationTime > vibrationLatchDuration)) {
      vibrationDetected = false;
      // Only print vibration cleared message when state changes
      if (lastVibrationPrintState) {
        Serial.println("[VIBRATION] Cleared");
        lastVibrationPrintState = false;
      }
    }
  }
}

void printSystemStatus() {
  // Print simplified system status every 5 seconds
  Serial.printf("[SYSTEM] T=%.1f°C H=%.1f%% WiFi=%s\n", 
                temp, hum, 
                WiFi.status() == WL_CONNECTED ? "OK" : "FAIL");
  
  // Temperature alerts
  if (temp > TEMP_HIGH_THRESHOLD) {
    Serial.println("[ALERT] Temperature too high!");
  } else if (temp < TEMP_LOW_THRESHOLD) {
    Serial.println("[ALERT] Temperature too low!");
  }
}

void updateOLEDDisplay() {
  display.clearDisplay();
  display.setTextSize(2);  // Larger text for better visibility
  display.setTextColor(SSD1306_WHITE);
  
  if (alertActive) {
    // ==================== Alert Display (Large and Clear) ====================
    display.setCursor(0, 0);
    if (motionDetected && vibrationDetected) {
      display.println("HIGH");
      display.println("ALERT!");
    } else if (motionDetected) {
      display.println("MOTION");
      display.println("ALERT!");
    } else if (vibrationDetected) {
      display.println("DOOR/WIN");
      display.println("ALERT!");
    }
    
  } else {
    // ==================== Normal Display (Clean and Simple) ====================
    display.setTextSize(1);  // Smaller text for status
    display.setCursor(0, 0);
    
    // Temperature alert (most important for comfort)
    if (!isnan(temp)) {
      if (temp > TEMP_HIGH_THRESHOLD) {
        display.setTextSize(2);
        display.println("TOO HOT!");
        display.setTextSize(1);
        display.printf("%.1fC - Turn ON AC", temp);
      } else if (temp < TEMP_LOW_THRESHOLD) {
        display.setTextSize(2);
        display.println("TOO COLD!");
        display.setTextSize(1);
        display.printf("%.1fC - Turn OFF AC", temp);
      } else {
        // Normal temperature - show simple status
        display.setTextSize(2);
        display.println("ALL SAFE");
        display.setTextSize(1);
        display.setCursor(0, 20);
        display.printf("Temp: %.1fC", temp);
      }
    } else {
      display.setTextSize(2);
      display.println("SENSOR");
      display.println("ERROR");
    }
  }
  
  display.display();
}

void displayMessage(String line1, String line2, String line3, String line4) {
  display.clearDisplay();
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);
  
  display.setCursor(0, 0);
  display.println(line1);
  display.setCursor(0, 8);
  display.println(line2);
  display.setCursor(0, 16);
  display.println(line3);
  display.setCursor(0, 24);
  display.println(line4);
  
  display.display();
}

void fetchThresholds() {
  if (WiFi.status() == WL_CONNECTED) {
    WiFiClient client;
    HTTPClient http;
    String url = serverName + "get_threshold_arduino.php";

    http.begin(client, url);
    http.setTimeout(5000);
    int httpCode = http.GET();

    if (httpCode > 0) {
      String payload = http.getString();

      DynamicJsonDocument doc(1024);
      DeserializationError error = deserializeJson(doc, payload);

      if (!error) {
        // Get threshold values
        float newTempHigh = doc["temp_threshold"] | TEMP_HIGH_THRESHOLD;
        float newTempLow = doc["temp_low_threshold"] | TEMP_LOW_THRESHOLD;
        float newHumThreshold = doc["hum_threshold"] | HUM_THRESHOLD;
        bool newAutoRelay = doc["auto_relay"] | autoRelayEnabled;
        
        // Get relay command from PHP backend
        String newRelayCommand = doc["relay_command"] | "OFF";
        String newRelayReason = doc["relay_reason"] | "default";

        // Check if relay command changed
        if (newRelayCommand != lastRelayCommand) {
          relayCommand = newRelayCommand;
          relayReason = newRelayReason;
          lastRelayCommand = newRelayCommand;
          
          // Apply relay command immediately
          bool newRelayState = (relayCommand == "ON");
          relayState = newRelayState;
          digitalWrite(RELAY_PIN, relayState ? LOW : HIGH); // LOW = ON, HIGH = OFF
          
          Serial.printf("[RELAY] %s (%s)\n", relayCommand.c_str(), relayReason.c_str());
        }

        // Update threshold values
        TEMP_HIGH_THRESHOLD = newTempHigh;
        TEMP_LOW_THRESHOLD = newTempLow;
        HUM_THRESHOLD = newHumThreshold;
        autoRelayEnabled = newAutoRelay;

        // Check if settings changed
        bool settingsChanged = false;
        if (newTempHigh != prevTempHighThreshold || newTempLow != prevTempLowThreshold || 
            newHumThreshold != prevHumThreshold || newAutoRelay != prevAutoRelayEnabled) {
          settingsChanged = true;
          prevTempHighThreshold = newTempHigh;
          prevTempLowThreshold = newTempLow;
          prevHumThreshold = newHumThreshold;
          prevAutoRelayEnabled = newAutoRelay;
        }

        if (settingsChanged) {
          Serial.println("[CONFIG] Settings updated");
        }
      } else {
        Serial.println("[ERROR] JSON parsing failed");
      }
    } else {
      Serial.printf("[ERROR] HTTP: %d\n", httpCode);
    }
    http.end();
  }
}

void sendDataToServer() {
  if (WiFi.status() == WL_CONNECTED && !isnan(temp) && !isnan(hum)) {
    HTTPClient http;
    String motionStatus = motionDetected ? "DETECTED" : "CLEAR";
    String vibrationStatus = vibrationDetected ? "DETECTED" : "CLEAR";
    String currentRelayStatus = relayState ? "ON" : "OFF";
    
    String postData = serverName + "esp32_data_receiver.php?" + 
                     "temp=" + String(temp) + 
                     "&hum=" + String(hum) + 
                     "&motion=" + motionStatus +
                     "&vibration=" + vibrationStatus +
                     "&relay=" + currentRelayStatus;
                     
    http.begin(postData);
    http.setTimeout(5000);
    int httpCode = http.GET();
    
    if (httpCode > 0) {
      String response = http.getString();
      
      // Parse response to get relay command
      DynamicJsonDocument doc(1024);
      DeserializationError error = deserializeJson(doc, response);
      
      if (!error) {
        String newRelayCommand = doc["relay_command"] | "OFF";
        String newRelayReason = doc["control_reason"] | "default";
        
        // Apply relay command if it changed
        if (newRelayCommand != relayCommand) {
          relayCommand = newRelayCommand;
          relayReason = newRelayReason;
          
          bool newRelayState = (relayCommand == "ON");
          relayState = newRelayState;
          digitalWrite(RELAY_PIN, relayState ? LOW : HIGH);
          
          Serial.printf("[RELAY] %s (%s)\n", relayCommand.c_str(), relayReason.c_str());
        }
      }
      
      Serial.printf("[DB] Sent: T=%.1f H=%.1f M=%s V=%s R=%s\n", 
                    temp, hum, motionStatus.c_str(), vibrationStatus.c_str(), currentRelayStatus.c_str());
    } else {
      Serial.printf("[ERROR] HTTP: %d\n", httpCode);
    }
    http.end();
  }
}

void updateAlertStatus() {
  unsigned long currentMillis = millis();
  
  // Update alert status based on current sensor readings
  if (motionDetected || vibrationDetected) {
    alertActive = true;
    lastAlertTime = currentMillis;
  } else {
    // Clear alert after duration
    if (alertActive && (currentMillis - lastAlertTime > alertDuration)) {
      alertActive = false;
    }
  }
}

void printPeriodicStatus() {
  Serial.printf("[STATUS] Mode=%s Relay=%s Motion=%s Vibration=%s Reason=%s\n", 
                autoRelayEnabled ? "AUTO" : "MANUAL", 
                relayState ? "ON" : "OFF",
                motionDetected ? "DETECTED" : "CLEAR", 
                vibrationDetected ? "DETECTED" : "CLEAR",
                relayReason.c_str());
}


