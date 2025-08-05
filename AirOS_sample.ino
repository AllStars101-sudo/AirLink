// AirOS - Advanced Gimbal Controller
// ===================================
// Features:
// - BLE Control for iOS/Android App
// - Kalman Filter for Sensor Fusion
// - PID Control for Stabilization
// - Multiple Gimbal Modes (Lock, Pan Follow, FPV)
// - Persistent Settings Storage (Preferences)
// - Remote Commands for Calibration and Reset

#include <Wire.h>
#include <Preferences.h>
#include "BMI088.h"
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <ESP32Servo.h>

// --- Pin Definitions
#define PITCH_SERVO_PIN 25  // Changed from 9
#define ROLL_SERVO_PIN  26  // Changed from 10  
#define YAW_SERVO_PIN   27  // Changed from 11

// --- Constants
#define MAX_DT 0.1              // Maximum allowed delta time (100ms)
#define MIN_DT 0.001            // Minimum delta time (1ms)
#define PID_OUTPUT_LIMIT 45.0   // Maximum PID output in degrees
#define INTEGRAL_LIMIT 10.0     // Integral windup limit
#define YAW_WRAP_LIMIT 180.0    // Yaw angle wrapping limit

// Yaw drift correction constants
#define STATIONARY_THRESHOLD 2.0    // Degrees/sec - below this is considered stationary
#define STATIONARY_TIME_MS 2000     // Time to be stationary before drift correction
#define YAW_BIAS_ALPHA 0.995        // Low-pass filter for yaw bias estimation
#define MAX_YAW_BIAS 5.0            // Maximum allowed yaw bias (deg/s)
#define LONG_STATIONARY_TIME_MS 5000  // Time for aggressive drift correction
#define YAW_DECAY_RATE 0.98         // Decay factor when stationary (closer to 1 = slower decay)

// --- Global Objects
Bmi088Accel accel(Wire, 0x18);  // BMI088 accelerometer (SDO1 grounded)
Bmi088Gyro gyro(Wire, 0x68);    // BMI088 gyroscope (SDO2 grounded)
Preferences prefs;

// --- Servo Objects
Servo pitchServo;
Servo rollServo;
Servo yawServo;

// --- Timing & Control
unsigned long timer = 0;
float dt = 0;

// --- BLE UUIDs (Universally Unique Identifiers)
#define SERVICE_UUID           "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
// READ-ONLY Characteristics (ESP32 to App)
#define PITCH_ANGLE_CHAR_UUID  "a1e8f36e-685b-4869-9828-c107a6729938"
#define ROLL_ANGLE_CHAR_UUID   "43a85368-8422-4573-a554-411a4a6e87f1"
#define YAW_ANGLE_CHAR_UUID    "e974ac4a-8182-4458-9419-4ac9c6c5184e"
#define GIMBAL_STATUS_CHAR_UUID "c8a4a58b-1579-4451-b016-1f38e3115a3a"
// READ-WRITE Characteristics (App to ESP32)
#define GIMBAL_MODE_CHAR_UUID      "2a79d494-436f-45b6-890f-563534ab2c84"
#define GIMBAL_CONTROL_CHAR_UUID   "f7a7a5a8-5e58-4c8d-9b6e-3aa5d6c5b768"
#define P_GAIN_CHAR_UUID           "b16b472c-88a4-4734-9f85-01458e08d669"
#define I_GAIN_CHAR_UUID           "8184457e-85a8-4217-a9a3-a7d57947a612"
#define D_GAIN_CHAR_UUID           "5d9b73b3-81e0-4368-910a-e322359b8676"
#define KALMAN_PARAMS_CHAR_UUID    "6e13e51a-f3c2-46a4-b203-92147395c5d0"

BLECharacteristic *pPitchAngleCharacteristic;
BLECharacteristic *pRollAngleCharacteristic;
BLECharacteristic *pYawAngleCharacteristic;
BLECharacteristic *pGimbalStatusCharacteristic;


// --- Data Structures
enum GimbalMode {
    MODE_INACTIVE,
    MODE_LOCKED,
    MODE_PAN_FOLLOW,
    MODE_FPV,
    MODE_PERSON_TRACKING
};

enum GimbalStatus {
    STATUS_INACTIVE,
    STATUS_CALIBRATING,
    STATUS_LOCKED,
    STATUS_PAN_FOLLOW,
    STATUS_FPV,
    STATUS_PERSON_TRACKING
};

struct PIDSettings {
    float p, i, d;
};

struct GimbalSettings {
    GimbalMode mode;
    PIDSettings pitchPID;
    PIDSettings rollPID;
    PIDSettings yawPID;
    float kalman_q_angle;
    float kalman_q_bias;
    float kalman_r_measure;
};

GimbalSettings settings;

struct PIDController {
    float integral = 0;
    float prevError = 0;
    
    void reset() {
        integral = 0;
        prevError = 0;
    }
};

PIDController pitchController, rollController, yawController;

struct KalmanFilter {
    float Q_angle, Q_bias, R_measure;
    float angle = 0, bias = 0, rate = 0;
    float P[2][2];
    
    void init(float q_angle, float q_bias, float r_measure) {
        Q_angle = q_angle;
        Q_bias = q_bias;
        R_measure = r_measure;
        angle = 0;
        bias = 0;
        rate = 0;
        // Initialize P matrix with appropriate values for faster convergence
        P[0][0] = 1.0;    // Initial angle uncertainty
        P[0][1] = 0.0;
        P[1][0] = 0.0;
        P[1][1] = 1.0;    // Initial bias uncertainty
    }
};

KalmanFilter kalmanX, kalmanY;

float pitchOffset = 0, rollOffset = 0, yawOffset = 0;
bool isCalibrated = false;

// Pan follow mode variables
float yawSetpointTarget = 0;  // Target yaw for pan follow
float panFollowRate = 0.5;    // Rate of pan following (0-1)

// Person tracking variables
float personTrackingPanSpeed = 0;   // Person tracking pan speed (-45 to +45 deg/s)
float personTrackingTiltSpeed = 0;  // Person tracking tilt speed (-45 to +45 deg/s)
unsigned long lastPersonTrackingUpdate = 0;  // Last time tracking data was received
#define PERSON_TRACKING_TIMEOUT_MS 1000  // Switch back to locked if no data for 1 second

// Yaw drift correction variables
struct YawDriftCorrection {
    float yawBias = 0;              // Estimated gyro bias (deg/s)
    float yawAngle = 0;             // Drift-corrected yaw angle
    unsigned long stationaryStart = 0;  // When stationary period started
    bool isStationary = false;      // Currently stationary flag
    float lastGyroYaw = 0;          // For stationary detection
    
    void reset() {
        yawBias = 0;
        yawAngle = 0;
        stationaryStart = 0;
        isStationary = false;
        lastGyroYaw = 0;
    }
};

YawDriftCorrection yawCorrection;

// --- Function Prototypes
void saveSettings();
void loadSettings();
void applyDefaultSettings();
void performCalibration();
float wrapAngle(float angle);
void updateYawWithDriftCorrection(float gyroYaw, float dt);
void resetYawAngle();
void initializeKalmanWithCurrentPosition();

// --- BLE Callbacks
class GimbalControlCallback: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) {
        String value = pCharacteristic->getValue();
        if (value.length() > 0) {
            // Debug: Show received command
            Serial.println("=== BLE COMMAND RECEIVED ===");
            Serial.print("📱 iOS App sent: '"); Serial.print(value); Serial.println("'");
            
            value.toLowerCase();
            if (value == "calibrate") {
                Serial.println("🎯 Executing: CALIBRATE");
                performCalibration();
            } else if (value == "save") {
                Serial.println("💾 Executing: SAVE SETTINGS");
                saveSettings();
            } else if (value == "defaults") {
                Serial.println("🔄 Executing: RESTORE DEFAULTS");
                applyDefaultSettings();
                saveSettings();
            } else if (value == "reset_pid") {
                Serial.println("🎛️ Executing: RESET PID");
                pitchController.reset();
                rollController.reset();
                yawController.reset();
                Serial.println("PID controllers reset");
            } else if (value == "reset_yaw") {
                Serial.println("🧭 Executing: RESET YAW");
                resetYawAngle();
                Serial.println("Yaw angle reset to 0");
            } else if (value == "yaw_status") {
                Serial.println("📊 Executing: YAW STATUS");
                Serial.print("Yaw Status - Angle: "); Serial.print(yawCorrection.yawAngle, 2);
                Serial.print("°, Bias: "); Serial.print(yawCorrection.yawBias, 4);
                Serial.print("°/s, Stationary: "); Serial.println(yawCorrection.isStationary ? "YES" : "NO");
            } else if (value == "force_decay") {
                Serial.println("⚡ Executing: FORCE DECAY");
                yawCorrection.yawAngle *= 0.9;  // Immediate 10% decay
                Serial.print("Forced yaw decay - New angle: "); Serial.println(yawCorrection.yawAngle, 2);
            } else if (value.startsWith("track_pan:")) {
                Serial.println("🎯 Executing: PERSON TRACKING PAN");
                personTrackingPanSpeed = value.substring(10).toFloat();
                lastPersonTrackingUpdate = millis();
                Serial.print("Pan tracking speed: "); Serial.println(personTrackingPanSpeed);
            } else if (value.startsWith("track_tilt:")) {
                Serial.println("🎯 Executing: PERSON TRACKING TILT");
                personTrackingTiltSpeed = value.substring(11).toFloat();
                lastPersonTrackingUpdate = millis();
                Serial.print("Tilt tracking speed: "); Serial.println(personTrackingTiltSpeed);
            } else {
                Serial.print("❓ Unknown command: '"); Serial.print(value); Serial.println("'");
            }
            Serial.println("============================");
        }
    }
};

class GimbalModeCallback: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) {
        uint8_t* data = pCharacteristic->getData();
        if (pCharacteristic->getLength() > 0) {
            GimbalMode newMode = (GimbalMode)data[0];
            
            // Debug: Show mode change
            Serial.println("=== MODE CHANGE RECEIVED ===");
            Serial.print("📱 iOS App sent mode: "); Serial.print(data[0]); Serial.print(" (");
            switch(newMode) {
                case MODE_INACTIVE: Serial.print("INACTIVE"); break;
                case MODE_LOCKED: Serial.print("LOCKED"); break;
                case MODE_PAN_FOLLOW: Serial.print("PAN_FOLLOW"); break;
                case MODE_FPV: Serial.print("FPV"); break;
                case MODE_PERSON_TRACKING: Serial.print("PERSON_TRACKING"); break;
                default: Serial.print("UNKNOWN"); break;
            }
            Serial.println(")");
            
            if (newMode != settings.mode) {
                Serial.print("🔄 Changing from mode "); Serial.print(settings.mode);
                Serial.print(" to mode "); Serial.println(newMode);
                
                // Reset PID controllers when changing modes
                pitchController.reset();
                rollController.reset();
                yawController.reset();
                settings.mode = newMode;
                Serial.println("✅ Mode change completed, PID reset");
            } else {
                Serial.println("⏭️ Mode unchanged");
            }
            Serial.println("============================");
        }
    }
};

// Generic PID Gain Callback
void updatePIDGain(BLECharacteristic *pCharacteristic, PIDSettings &pid) {
    uint8_t* data = pCharacteristic->getData();
    if (pCharacteristic->getLength() == sizeof(PIDSettings)) {
        memcpy(&pid, data, sizeof(PIDSettings));
        Serial.println("Updated PID gains.");
    }
}

class PIDGainCallback: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) {
        String uuid = pCharacteristic->getUUID().toString();
        uint8_t* data = pCharacteristic->getData();
        
        Serial.println("=== PID UPDATE RECEIVED ===");
        Serial.print("📱 iOS App sent PID data, length: "); Serial.println(pCharacteristic->getLength());
        Serial.print("Expected length: "); Serial.println(sizeof(PIDSettings));
        
        if (pCharacteristic->getLength() == sizeof(PIDSettings)) {
            PIDSettings newPID;
            memcpy(&newPID, data, sizeof(PIDSettings));
            
            if (uuid == P_GAIN_CHAR_UUID) {
                Serial.println("🎛️ Updating PITCH PID gains:");
                Serial.print("  P: "); Serial.print(newPID.p, 4);
                Serial.print(", I: "); Serial.print(newPID.i, 4);
                Serial.print(", D: "); Serial.println(newPID.d, 4);
                memcpy(&settings.pitchPID, data, sizeof(PIDSettings));
            } else if (uuid == I_GAIN_CHAR_UUID) {
                Serial.println("🎛️ Updating ROLL PID gains:");
                Serial.print("  P: "); Serial.print(newPID.p, 4);
                Serial.print(", I: "); Serial.print(newPID.i, 4);
                Serial.print(", D: "); Serial.println(newPID.d, 4);
                memcpy(&settings.rollPID, data, sizeof(PIDSettings));
            } else if (uuid == D_GAIN_CHAR_UUID) {
                Serial.println("🎛️ Updating YAW PID gains:");
                Serial.print("  P: "); Serial.print(newPID.p, 4);
                Serial.print(", I: "); Serial.print(newPID.i, 4);
                Serial.print(", D: "); Serial.println(newPID.d, 4);
                memcpy(&settings.yawPID, data, sizeof(PIDSettings));
            } else {
                Serial.print("❓ Unknown PID UUID: "); Serial.println(uuid);
            }
        } else {
            Serial.println("❌ Invalid PID data length");
        }
        Serial.println("============================");
    }
};


// --- Utility Functions
float wrapAngle(float angle) {
    while (angle > YAW_WRAP_LIMIT) angle -= 360.0;
    while (angle < -YAW_WRAP_LIMIT) angle += 360.0;
    return angle;
}

float constrainFloat(float value, float min_val, float max_val) {
    if (value > max_val) return max_val;
    if (value < min_val) return min_val;
    return value;
}

// --- PID Logic with Improvements
float calculatePID(float setpoint, float input, PIDController& controller, const PIDSettings& pid) {
    // Ensure dt is within reasonable bounds
    if (dt < MIN_DT || dt > MAX_DT) {
        return 0; // Return 0 output for invalid dt
    }
    
    float error = setpoint - input;
    
    // Integral term with windup protection
    controller.integral += error * dt;
    controller.integral = constrainFloat(controller.integral, -INTEGRAL_LIMIT, INTEGRAL_LIMIT);
    
    // Derivative term
    float derivative = (error - controller.prevError) / dt;
    
    // Calculate output
    float output = (pid.p * error) + (pid.i * controller.integral) + (pid.d * derivative);
    
    // Limit output
    output = constrainFloat(output, -PID_OUTPUT_LIMIT, PID_OUTPUT_LIMIT);
    
    controller.prevError = error;
    return output;
}

// --- Enhanced Kalman Filter Logic
void initKalman(KalmanFilter* kalman) {
    kalman->init(settings.kalman_q_angle, settings.kalman_q_bias, settings.kalman_r_measure);
}

float kalmanCalculate(KalmanFilter* kalman, float newAngle, float newRate, float p_dt) {
    // Bounds check on dt
    if (p_dt < MIN_DT || p_dt > MAX_DT) {
        return kalman->angle; // Return previous angle for invalid dt
    }
    
    // Prediction step
    kalman->rate = newRate - kalman->bias;
    kalman->angle += p_dt * kalman->rate;
    
    // Prediction covariance update
    float dt2 = p_dt * p_dt;
    kalman->P[0][0] += p_dt * (p_dt * kalman->P[1][1] - kalman->P[0][1] - kalman->P[1][0] + kalman->Q_angle);
    kalman->P[0][1] -= p_dt * kalman->P[1][1];
    kalman->P[1][0] -= p_dt * kalman->P[1][1];
    kalman->P[1][1] += kalman->Q_bias * p_dt;
    
    // Ensure P matrix symmetry (prevent numerical drift)
    kalman->P[0][1] = kalman->P[1][0];
    
    // Update step
    float S = kalman->P[0][0] + kalman->R_measure;
    
    // Prevent division by very small numbers
    if (S < 1e-6) S = 1e-6;
    
    float K[2] = {kalman->P[0][0] / S, kalman->P[1][0] / S};
    
    float y = newAngle - kalman->angle;
    kalman->angle += K[0] * y;
    kalman->bias += K[1] * y;
    
    // Covariance update using Joseph form (numerically stable)
    float P00_temp = kalman->P[0][0];
    float P01_temp = kalman->P[0][1];
    
    kalman->P[0][0] -= K[0] * P00_temp;
    kalman->P[0][1] -= K[0] * P01_temp;
    kalman->P[1][0] -= K[1] * P00_temp;
    kalman->P[1][1] -= K[1] * P01_temp;
    
    // Ensure P matrix stays positive definite
    if (kalman->P[0][0] < 1e-6) kalman->P[0][0] = 1e-6;
    if (kalman->P[1][1] < 1e-6) kalman->P[1][1] = 1e-6;
    
    return kalman->angle;
}

// --- IMU Helpers
float getPitch(float accelX, float accelY, float accelZ) {
    return atan2(-accelX, sqrt(accelY * accelY + accelZ * accelZ)) * 180.0 / PI;
}

float getRoll(float accelX, float accelY, float accelZ) {
    return atan2(accelY, accelZ) * 180.0 / PI;
}

// --- Yaw Drift Correction Functions
void updateYawWithDriftCorrection(float gyroYaw, float dt) {
    // Detect if the gimbal is stationary
    float gyroMagnitude = abs(gyroYaw);
    unsigned long currentTime = millis();
    
    if (gyroMagnitude < STATIONARY_THRESHOLD) {
        if (!yawCorrection.isStationary) {
            // Just became stationary
            yawCorrection.stationaryStart = currentTime;
            yawCorrection.isStationary = true;
            Serial.println("Yaw: Stationary detected - starting drift correction");
        } else {
            // Has been stationary for a while
            unsigned long stationaryDuration = currentTime - yawCorrection.stationaryStart;
            
            if (stationaryDuration > STATIONARY_TIME_MS) {
                // Update bias estimate using more aggressive learning when stationary
                float targetBias = gyroYaw;  // Assume this should be zero when stationary
                float learningRate = (stationaryDuration > LONG_STATIONARY_TIME_MS) ? 0.02 : 0.005;
                yawCorrection.yawBias = (1.0 - learningRate) * yawCorrection.yawBias + 
                                       learningRate * targetBias;
                
                // Constrain bias to reasonable limits
                yawCorrection.yawBias = constrainFloat(yawCorrection.yawBias, -MAX_YAW_BIAS, MAX_YAW_BIAS);
                
                // For very long stationary periods, apply gentle decay towards 0
                if (stationaryDuration > LONG_STATIONARY_TIME_MS) {
                    yawCorrection.yawAngle *= YAW_DECAY_RATE;
                    
                    // Debug output for long stationary correction
                    static unsigned long lastDecayMsg = 0;
                    if (currentTime - lastDecayMsg > 1000) {
                        Serial.print("Yaw: Long stationary decay - Angle: ");
                        Serial.print(yawCorrection.yawAngle, 2);
                        Serial.print("°, Bias: ");
                        Serial.println(yawCorrection.yawBias, 4);
                        lastDecayMsg = currentTime;
                    }
                }
            }
            
            // CRITICAL: When stationary, DON'T integrate gyro readings at all
            // This prevents further drift accumulation
            // yawCorrection.yawAngle stays the same (frozen)
        }
    } else {
        // Not stationary - normal integration with bias correction
        yawCorrection.isStationary = false;
        
        // Apply bias correction and integrate
        float correctedGyroYaw = gyroYaw - yawCorrection.yawBias;
        yawCorrection.yawAngle += correctedGyroYaw * dt;
        yawCorrection.yawAngle = wrapAngle(yawCorrection.yawAngle);
    }
    
    yawCorrection.lastGyroYaw = gyroYaw;
}

void resetYawAngle() {
    yawCorrection.yawAngle = 0;
    yawCorrection.yawBias = 0;  // Also reset bias estimate
    yawCorrection.isStationary = false;
    yawController.reset();  // Reset PID controller too
    Serial.print("Yaw reset - Bias was: "); 
    Serial.println(yawCorrection.yawBias, 4);
}

void initializeKalmanWithCurrentPosition() {
    // Read current IMU data to get actual starting position
    accel.readSensor();  // Read accelerometer data
    
    // Calculate actual angles with calibration offsets applied
    float currentPitch = getPitch(accel.getAccelX_mss(), accel.getAccelY_mss(), accel.getAccelZ_mss()) - pitchOffset;
    float currentRoll = getRoll(accel.getAccelX_mss(), accel.getAccelY_mss(), accel.getAccelZ_mss()) - rollOffset;
    
    // Initialize Kalman filters with actual starting position
    kalmanX.angle = currentPitch;
    kalmanY.angle = currentRoll;
    
    Serial.print("Kalman initialized with actual position - Pitch: ");
    Serial.print(currentPitch, 2);
    Serial.print("°, Roll: ");
    Serial.print(currentRoll, 2);
    Serial.println("°");
}

// --- Setup
void setup() {
    Serial.begin(115200);
    delay(1000);
    Serial.println("=== AirOS Gimbal Controller Starting ===");

    // --- Load Settings
    loadSettings();

    // --- Initialize I2C & IMU
    Wire.begin();
    
    // Initialize accelerometer
    int status = accel.begin();
    if (status < 0) {
        Serial.println("BMI088 Accel Init Failed. Halting.");
        Serial.println(status);
        while(1);
    }
    
    // Initialize gyroscope
    status = gyro.begin();
    if (status < 0) {
        Serial.println("BMI088 Gyro Init Failed. Halting.");
        Serial.println(status);
        while(1);
    }
    
    // Configure accelerometer (200Hz, 4G range)
    accel.setOdr(Bmi088Accel::ODR_200HZ_BW_80HZ);
    accel.setRange(Bmi088Accel::RANGE_6G);  // Using 6G instead of 4G (closest available)
    
    // Configure gyroscope (200Hz, 500 dps)
    gyro.setOdr(Bmi088Gyro::ODR_200HZ_BW_23HZ);
    gyro.setRange(Bmi088Gyro::RANGE_500DPS);
    
    Serial.println("BMI088 Initialized and Configured.");

    // --- Initialize Kalman Filters
    initKalman(&kalmanX);
    initKalman(&kalmanY);
    Serial.println("Kalman Filters Initialized.");

    // --- BLE Setup
    BLEDevice::init("AirOS Gimbal");
    BLEServer *pServer = BLEDevice::createServer();
    BLEService *pService = pServer->createService(SERVICE_UUID);

    // READ-ONLY Characteristics
    pPitchAngleCharacteristic = pService->createCharacteristic(PITCH_ANGLE_CHAR_UUID, BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY);
    pRollAngleCharacteristic = pService->createCharacteristic(ROLL_ANGLE_CHAR_UUID, BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY);
    pYawAngleCharacteristic = pService->createCharacteristic(YAW_ANGLE_CHAR_UUID, BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY);
    pGimbalStatusCharacteristic = pService->createCharacteristic(GIMBAL_STATUS_CHAR_UUID, BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY);
    
    pPitchAngleCharacteristic->addDescriptor(new BLE2902());
    pRollAngleCharacteristic->addDescriptor(new BLE2902());
    pYawAngleCharacteristic->addDescriptor(new BLE2902());
    pGimbalStatusCharacteristic->addDescriptor(new BLE2902());

    // READ-WRITE Characteristics
    BLECharacteristic* pModeCharacteristic = pService->createCharacteristic(GIMBAL_MODE_CHAR_UUID, BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_WRITE);
    pModeCharacteristic->setCallbacks(new GimbalModeCallback());

    BLECharacteristic* pControlCharacteristic = pService->createCharacteristic(GIMBAL_CONTROL_CHAR_UUID, BLECharacteristic::PROPERTY_WRITE);
    pControlCharacteristic->setCallbacks(new GimbalControlCallback());

    // PID Gain Characteristics
    BLECharacteristic* pPitchPIDCharacteristic = pService->createCharacteristic(P_GAIN_CHAR_UUID, BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_WRITE);
    BLECharacteristic* pRollPIDCharacteristic = pService->createCharacteristic(I_GAIN_CHAR_UUID, BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_WRITE);
    BLECharacteristic* pYawPIDCharacteristic = pService->createCharacteristic(D_GAIN_CHAR_UUID, BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_WRITE);
    
    pPitchPIDCharacteristic->setCallbacks(new PIDGainCallback());
    pRollPIDCharacteristic->setCallbacks(new PIDGainCallback());
    pYawPIDCharacteristic->setCallbacks(new PIDGainCallback());
    
    pService->start();
    BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
    pAdvertising->addServiceUUID(SERVICE_UUID);
    pAdvertising->setScanResponse(true);
    BLEDevice::startAdvertising();
    
    Serial.println("🚀 =================================");
    Serial.println("📡 BLE Server Started Successfully!");
    Serial.println("🔍 Device Name: 'AirOS Gimbal'");
    Serial.println("📶 Status: ADVERTISING & READY");
    Serial.println("📱 Waiting for iOS app connection...");
    Serial.println("===================================");

    // --- Initialize Servos
    pitchServo.attach(PITCH_SERVO_PIN);
    rollServo.attach(ROLL_SERVO_PIN);
    yawServo.attach(YAW_SERVO_PIN);
    
    // Center servos at startup
    pitchServo.write(90);
    rollServo.write(90);
    yawServo.write(90);
    Serial.println("Servos initialized and centered.");

    // --- Calibration (Always performed on startup)
    performCalibration();

    timer = micros();
    Serial.println("Setup Complete. Starting main loop.");
    Serial.println("Pitch\tRoll\tYaw\tRawP\tRawR\tRawY\tYBias\tStatus");
}

// --- Main Loop
void loop() {
    // --- Time Calculation with bounds checking
    unsigned long currentTime = micros();
    dt = (currentTime - timer) / 1000000.0;
    timer = currentTime;
    
    // Constrain dt to reasonable bounds
    dt = constrainFloat(dt, MIN_DT, MAX_DT);

    // --- Sensor Reading with error handling
    accel.readSensor();  // Read accelerometer data
    gyro.readSensor();   // Read gyroscope data
    
    float accelPitch = getPitch(accel.getAccelX_mss(), accel.getAccelY_mss(), accel.getAccelZ_mss()) - pitchOffset;
    float accelRoll = getRoll(accel.getAccelX_mss(), accel.getAccelY_mss(), accel.getAccelZ_mss()) - rollOffset;
    float gyroPitch = gyro.getGyroX_rads() * 180.0 / PI;  // Convert rad/s to deg/s
    float gyroRoll = gyro.getGyroY_rads() * 180.0 / PI;   // Convert rad/s to deg/s
    float gyroYaw = gyro.getGyroZ_rads() * 180.0 / PI - yawOffset;  // Convert rad/s to deg/s

    // --- Filtering
    float filteredPitch = kalmanCalculate(&kalmanX, accelPitch, gyroPitch, dt);
    float filteredRoll = kalmanCalculate(&kalmanY, accelRoll, gyroRoll, dt);
    
    // Improved yaw calculation with drift compensation
    static float yawAngle = 0;
    updateYawWithDriftCorrection(gyroYaw, dt); // Apply drift correction
    yawAngle = yawCorrection.yawAngle; // Use the drift-corrected angle

    // --- State Machine (Gimbal Mode Logic)
    float pitchSetpoint = 0, rollSetpoint = 0, yawSetpoint = 0;
    
    switch (settings.mode) {
        case MODE_LOCKED:
            // Setpoints are 0, gimbal stays level
            pitchSetpoint = 0;
            rollSetpoint = 0;
            yawSetpoint = 0;
            break;
            
        case MODE_PAN_FOLLOW:
            // Pitch and Roll are locked, Yaw follows user input smoothly
            pitchSetpoint = 0;
            rollSetpoint = 0;
            // Smooth pan following - yaw setpoint moves toward target
            yawSetpoint += (yawSetpointTarget - yawSetpoint) * panFollowRate * dt;
            yawSetpoint = wrapAngle(yawSetpoint);
            break;
            
        case MODE_FPV:
            // All axes follow the camera/user movement
            pitchSetpoint = filteredPitch;
            rollSetpoint = filteredRoll;
            yawSetpoint = yawAngle;
            break;
            
        case MODE_PERSON_TRACKING:
            // Check if we have recent tracking data
            if (millis() - lastPersonTrackingUpdate < PERSON_TRACKING_TIMEOUT_MS) {
                // Use person tracking speeds to adjust setpoints
                // Convert tracking speeds to angle adjustments
                static float personTrackingYawTarget = 0;
                static float personTrackingPitchTarget = 0;
                
                // Integrate tracking speeds over time
                float deltaTimeSeconds = dt;
                personTrackingYawTarget += personTrackingPanSpeed * deltaTimeSeconds;
                personTrackingPitchTarget += personTrackingTiltSpeed * deltaTimeSeconds;
                
                // Clamp targets to reasonable limits
                personTrackingYawTarget = constrainFloat(personTrackingYawTarget, -90, 90);
                personTrackingPitchTarget = constrainFloat(personTrackingPitchTarget, -45, 45);
                
                // Set gimbal targets
                pitchSetpoint = personTrackingPitchTarget;
                rollSetpoint = 0;  // Keep roll level
                yawSetpoint = personTrackingYawTarget;
                
                // Wrap yaw angle
                yawSetpoint = wrapAngle(yawSetpoint);
            } else {
                // No recent tracking data - fall back to locked mode
                Serial.println("⚠️ Person tracking timeout - switching to locked mode");
                settings.mode = MODE_LOCKED;
                pitchSetpoint = 0;
                rollSetpoint = 0;
                yawSetpoint = 0;
            }
            break;
            
        case MODE_INACTIVE:
        default:
            // Reset PIDs and do nothing
            pitchController.reset();
            rollController.reset();
            yawController.reset();
            pitchSetpoint = filteredPitch;  // Don't fight current position
            rollSetpoint = filteredRoll;
            yawSetpoint = yawAngle;
            break;
    }
    
    // --- PID Calculation
    float pitchOutput = 0, rollOutput = 0, yawOutput = 0;
    
    if (settings.mode != MODE_INACTIVE) {
        pitchOutput = calculatePID(pitchSetpoint, filteredPitch, pitchController, settings.pitchPID);
        rollOutput = calculatePID(rollSetpoint, filteredRoll, rollController, settings.rollPID);
        yawOutput = calculatePID(yawSetpoint, yawAngle, yawController, settings.yawPID);
    }

    // --- Servo Control
    if (settings.mode != MODE_INACTIVE) {
        int pitchServoAngle = 90 + (int)pitchOutput;
        int rollServoAngle = 90 + (int)rollOutput;
        int yawServoAngle = 90 + (int)yawOutput;
        
        pitchServo.write(constrain(pitchServoAngle, 0, 180));
        rollServo.write(constrain(rollServoAngle, 0, 180));
        yawServo.write(constrain(yawServoAngle, 0, 180));
    } else {
        // In inactive mode, center all servos
        pitchServo.write(90);
        rollServo.write(90);
        yawServo.write(90);
    }
    
    // --- BLE Notifications
    static unsigned long lastNotify = 0;
    static unsigned long lastDebug = 0;
    if (millis() - lastNotify > 100) { // Update app 10 times per second
        // Send data to iOS app
        pPitchAngleCharacteristic->setValue(filteredPitch);
        pPitchAngleCharacteristic->notify();
        pRollAngleCharacteristic->setValue(filteredRoll);
        pRollAngleCharacteristic->notify();
        pYawAngleCharacteristic->setValue(yawAngle);
        pYawAngleCharacteristic->notify();
        
        uint8_t statusVal = (uint8_t)settings.mode;
        pGimbalStatusCharacteristic->setValue(&statusVal, 1);
        pGimbalStatusCharacteristic->notify();

        // Debug: BLE communication status every 2 seconds
        if (millis() - lastDebug > 2000) {
            Serial.println("=== BLE DEBUG ===");
            Serial.println("📡 SENDING to iOS App:");
            Serial.print("  Pitch: "); Serial.print(filteredPitch, 2); Serial.println("°");
            Serial.print("  Roll: "); Serial.print(filteredRoll, 2); Serial.println("°");
            Serial.print("  Yaw: "); Serial.print(yawAngle, 2); Serial.println("°");
            Serial.print("  Mode: "); Serial.print(statusVal); Serial.print(" (");
            switch(settings.mode) {
                case MODE_INACTIVE: Serial.print("INACTIVE"); break;
                case MODE_LOCKED: Serial.print("LOCKED"); break;
                case MODE_PAN_FOLLOW: Serial.print("PAN_FOLLOW"); break;
                case MODE_FPV: Serial.print("FPV"); break;
                case MODE_PERSON_TRACKING: Serial.print("PERSON_TRACKING"); break;
            }
            Serial.println(")");
            Serial.println("================");
            lastDebug = millis();
        }

        // Serial monitoring output (compact format)
        Serial.print("P:"); Serial.print(filteredPitch, 1); 
        Serial.print(" R:"); Serial.print(filteredRoll, 1); 
        Serial.print(" Y:"); Serial.print(yawAngle, 1);
        Serial.print(" M:"); Serial.print(statusVal);
        Serial.print(" "); Serial.println(yawCorrection.isStationary ? "STAT" : "MOVE");

        lastNotify = millis();
    }
    
    delay(2); // Small delay to prevent watchdog issues
    yield();
}

// --- Settings Management Functions
void applyDefaultSettings() {
    settings.mode = MODE_LOCKED;
    settings.pitchPID = {1.2, 0.1, 0.05};  // More conservative defaults
    settings.rollPID = {1.2, 0.1, 0.05};
    settings.yawPID = {0.8, 0.05, 0.02};
    settings.kalman_q_angle = 0.001;
    settings.kalman_q_bias = 0.003;
    settings.kalman_r_measure = 0.03;
    Serial.println("Applied default settings.");
}

void saveSettings() {
    prefs.begin("gimbal_settings", false);
    prefs.putBytes("settings", &settings, sizeof(GimbalSettings));
    prefs.end();
    Serial.println("Gimbal settings saved.");
}

void loadSettings() {
    prefs.begin("gimbal_settings", true);
    size_t expectedSize = sizeof(GimbalSettings);
    size_t actualSize = prefs.getBytesLength("settings");
    
    bool settingsFound = false;
    if (actualSize == expectedSize) {
        settingsFound = prefs.getBytes("settings", &settings, expectedSize) == expectedSize;
    }
    prefs.end();
    
    if (!settingsFound) {
        Serial.println("No saved settings found, applying defaults.");
        applyDefaultSettings();
        saveSettings();
    } else {
        Serial.println("Loaded saved settings.");
    }
}

void performCalibration() {
    Serial.println("Starting new calibration...");
    
    uint8_t statusVal = (uint8_t)STATUS_CALIBRATING;
    pGimbalStatusCharacteristic->setValue(&statusVal, 1);
    pGimbalStatusCharacteristic->notify();
    
    // Reset PID controllers during calibration
    pitchController.reset();
    rollController.reset();
    yawController.reset();
    
    // Reset yaw drift correction system
    yawCorrection.reset();
    
    float pitchSum = 0, rollSum = 0, yawSum = 0;
    int validSamples = 0;
    
    for (int i = 0; i < 500; i++) {
        accel.readSensor();  // Read accelerometer data
        gyro.readSensor();   // Read gyroscope data
        
        pitchSum += getPitch(accel.getAccelX_mss(), accel.getAccelY_mss(), accel.getAccelZ_mss());
        rollSum += getRoll(accel.getAccelX_mss(), accel.getAccelY_mss(), accel.getAccelZ_mss());
        yawSum += gyro.getGyroZ_rads() * 180.0 / PI;  // Convert rad/s to deg/s
        validSamples++;
        
        delay(5);
    }
    
    if (validSamples > 0) {
        pitchOffset = pitchSum / validSamples;
        rollOffset = rollSum / validSamples;
        yawOffset = yawSum / validSamples;
        
        // Initialize yaw bias with the calibrated offset
        yawCorrection.yawBias = yawOffset;
        
        isCalibrated = true;
        Serial.println("Calibration complete.");
        Serial.print("Offsets - Pitch: "); Serial.print(pitchOffset);
        Serial.print(", Roll: "); Serial.print(rollOffset);
        Serial.print(", Yaw: "); Serial.println(yawOffset);
        Serial.print("Initial Yaw Bias: "); Serial.println(yawCorrection.yawBias, 4);
        
        // Initialize Kalman filters with actual starting position
        delay(10); // Brief delay to ensure IMU is ready
        initializeKalmanWithCurrentPosition();
    } else {
        Serial.println("Calibration failed - no valid samples");
    }
}
