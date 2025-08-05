import Foundation

class AirFrameToolService {
    weak var airFrameModel: AirFrameModel?
    
    // MARK: - Available Tools
    func availableTools() -> [AITool] {
        return [
            AITool(
                name: "set_gimbal_mode",
                description: "Change the gimbal operating mode (locked, pan follow, FPV, person tracking, or inactive)",
                parameters: [
                    "mode": AIToolParameter(
                        type: "string",
                        description: "The desired gimbal mode",
                        enumValues: ["locked", "pan_follow", "fpv", "person_tracking", "inactive"],
                        required: true
                    )
                ]
            ),
            
            AITool(
                name: "calibrate_gimbal",
                description: "Calibrate the gimbal sensors and reset to neutral position",
                parameters: [:]
            ),
            
            AITool(
                name: "reset_yaw",
                description: "Reset the yaw angle to zero degrees",
                parameters: [:]
            ),
            
            AITool(
                name: "get_gimbal_status",
                description: "Get current gimbal angles, mode, and connection status",
                parameters: [:]
            ),
            
            AITool(
                name: "adjust_pid_settings",
                description: "Fine-tune PID controller settings for smoother gimbal movement",
                parameters: [
                    "axis": AIToolParameter(
                        type: "string",
                        description: "Which axis to adjust (pitch, roll, or yaw)",
                        enumValues: ["pitch", "roll", "yaw"],
                        required: true
                    ),
                    "p": AIToolParameter(
                        type: "number",
                        description: "Proportional gain (0.1-5.0)",
                        required: false
                    ),
                    "i": AIToolParameter(
                        type: "number",
                        description: "Integral gain (0.01-1.0)",
                        required: false
                    ),
                    "d": AIToolParameter(
                        type: "number",
                        description: "Derivative gain (0.001-0.5)",
                        required: false
                    )
                ]
            ),
            
            AITool(
                name: "save_settings",
                description: "Save current gimbal settings to persistent storage",
                parameters: [:]
            ),
            
            AITool(
                name: "restore_defaults",
                description: "Restore gimbal settings to factory defaults",
                parameters: [:]
            ),
            
            AITool(
                name: "get_connection_status",
                description: "Check if the AirFrame is connected via Bluetooth",
                parameters: [:]
            ),
            
            AITool(
                name: "position_for_shot",
                description: "Position the gimbal optimally for a specific type of shot",
                parameters: [
                    "shot_type": AIToolParameter(
                        type: "string",
                        description: "Type of shot to optimize for",
                        enumValues: ["portrait", "landscape", "action", "macro", "wide_angle", "tracking"],
                        required: true
                    ),
                    "subject_direction": AIToolParameter(
                        type: "string",
                        description: "Direction of the main subject relative to camera",
                        enumValues: ["center", "left", "right", "above", "below"],
                        required: false
                    )
                ]
            ),
            
            AITool(
                name: "analyze_scene",
                description: "Analyze the current camera view to suggest optimal gimbal positioning for the best shot",
                parameters: [:]
            ),
            
            AITool(
                name: "quick_setup",
                description: "Quickly set up the gimbal for common scenarios",
                parameters: [
                    "scenario": AIToolParameter(
                        type: "string",
                        description: "The shooting scenario to set up for",
                        enumValues: ["selfie", "group_photo", "timelapse", "video_call", "streaming", "wildlife"],
                        required: true
                    )
                ]
            )
        ]
    }
    
    // MARK: - Tool Execution
    func executeTool(name: String, input: [String: Any]) async throws -> String {
        guard let airFrameModel = airFrameModel else {
            return "AirFrame not available. Please ensure the device is connected."
        }
        
        switch name {
        case "set_gimbal_mode":
            return await setGimbalMode(input: input, model: airFrameModel)
            
        case "calibrate_gimbal":
            return await calibrateGimbal(model: airFrameModel)
            
        case "reset_yaw":
            return await resetYaw(model: airFrameModel)
            
        case "get_gimbal_status":
            return await getGimbalStatus(model: airFrameModel)
            
        case "adjust_pid_settings":
            return await adjustPIDSettings(input: input, model: airFrameModel)
            
        case "save_settings":
            return await saveSettings(model: airFrameModel)
            
        case "restore_defaults":
            return await restoreDefaults(model: airFrameModel)
            
        case "get_connection_status":
            return await getConnectionStatus(model: airFrameModel)
            
        case "position_for_shot":
            return await positionForShot(input: input, model: airFrameModel)
            
        case "analyze_scene":
            return await analyzeScene(model: airFrameModel)
            
        case "quick_setup":
            return await quickSetup(input: input, model: airFrameModel)
            
        default:
            return "Unknown tool: \(name)"
        }
    }
    
    // MARK: - Tool Implementations
    @MainActor
    private func setGimbalMode(input: [String: Any], model: AirFrameModel) async -> String {
        guard let modeString = input["mode"] as? String else {
            return "Invalid mode parameter"
        }
        
        let mode: GimbalMode
        switch modeString.lowercased() {
        case "locked":
            mode = .locked
        case "pan_follow":
            mode = .panFollow
        case "fpv":
            mode = .fpv
        case "person_tracking":
            mode = .personTracking
        case "inactive":
            mode = .inactive
        default:
            return "Invalid mode: \(modeString). Valid modes are: locked, pan_follow, fpv, person_tracking, inactive"
        }
        
        model.setGimbalMode(mode)
        return "Gimbal mode set to \(mode.displayName)"
    }
    
    @MainActor
    private func calibrateGimbal(model: AirFrameModel) async -> String {
        guard model.isConnected else {
            return "Cannot calibrate: AirFrame is not connected"
        }
        
        model.calibrateGimbal()
        return "Gimbal calibration started. Please keep the AirFrame still during calibration."
    }
    
    @MainActor
    private func resetYaw(model: AirFrameModel) async -> String {
        guard model.isConnected else {
            return "Cannot reset yaw: AirFrame is not connected"
        }
        
        model.resetYaw()
        return "Yaw angle reset to zero degrees"
    }
    
    @MainActor
    private func getGimbalStatus(model: AirFrameModel) async -> String {
        let connectionStatus = model.isConnected ? "Connected" : "Disconnected"
        let mode = model.currentMode.displayName
        let pitch = String(format: "%.1f°", model.currentPitch)
        let roll = String(format: "%.1f°", model.currentRoll)
        let yaw = String(format: "%.1f°", model.currentYaw)
        let calibrating = model.isCalibrating ? " (Calibrating)" : ""
        
        return """
        AirFrame Status:
        • Connection: \(connectionStatus)
        • Mode: \(mode)\(calibrating)
        • Pitch: \(pitch)
        • Roll: \(roll)
        • Yaw: \(yaw)
        """
    }
    
    @MainActor
    private func adjustPIDSettings(input: [String: Any], model: AirFrameModel) async -> String {
        guard model.isConnected else {
            return "Cannot adjust PID: AirFrame is not connected"
        }
        
        guard let axis = input["axis"] as? String else {
            return "Missing axis parameter"
        }
        
        let p = (input["p"] as? Double) ?? (input["p"] as? Float).map(Double.init)
        let i = (input["i"] as? Double) ?? (input["i"] as? Float).map(Double.init)
        let d = (input["d"] as? Double) ?? (input["d"] as? Float).map(Double.init)
        
        guard p != nil || i != nil || d != nil else {
            return "At least one PID parameter (p, i, d) must be specified"
        }
        
        // Get current values as defaults
        let currentP: Float = 1.0 // These would ideally come from the model
        let currentI: Float = 0.1
        let currentD: Float = 0.05
        
        let newP = Float(p ?? Double(currentP))
        let newI = Float(i ?? Double(currentI))
        let newD = Float(d ?? Double(currentD))
        
        // Validate ranges
        guard (0.1...5.0).contains(newP) else {
            return "P gain must be between 0.1 and 5.0"
        }
        guard (0.01...1.0).contains(newI) else {
            return "I gain must be between 0.01 and 1.0"
        }
        guard (0.001...0.5).contains(newD) else {
            return "D gain must be between 0.001 and 0.5"
        }
        
        switch axis.lowercased() {
        case "pitch":
            model.setPitchPID(p: newP, i: newI, d: newD)
            return "Pitch PID updated: P=\(newP), I=\(newI), D=\(newD)"
        case "roll":
            model.setRollPID(p: newP, i: newI, d: newD)
            return "Roll PID updated: P=\(newP), I=\(newI), D=\(newD)"
        case "yaw":
            model.setYawPID(p: newP, i: newI, d: newD)
            return "Yaw PID updated: P=\(newP), I=\(newI), D=\(newD)"
        default:
            return "Invalid axis: \(axis). Valid axes are: pitch, roll, yaw"
        }
    }
    
    @MainActor
    private func saveSettings(model: AirFrameModel) async -> String {
        guard model.isConnected else {
            return "Cannot save settings: AirFrame is not connected"
        }
        
        model.saveSettings()
        return "Current gimbal settings saved to AirFrame memory"
    }
    
    @MainActor
    private func restoreDefaults(model: AirFrameModel) async -> String {
        guard model.isConnected else {
            return "Cannot restore defaults: AirFrame is not connected"
        }
        
        model.restoreDefaults()
        return "Gimbal settings restored to factory defaults"
    }
    
    @MainActor
    private func getConnectionStatus(model: AirFrameModel) async -> String {
        if model.isConnected {
            return "AirFrame is connected and ready"
        } else if model.isConnecting {
            return "Connecting to AirFrame..."
        } else if let error = model.connectionError {
            return "AirFrame connection failed: \(error)"
        } else {
            return "AirFrame is not connected. Please connect in the Control tab."
        }
    }
    
    @MainActor
    private func positionForShot(input: [String: Any], model: AirFrameModel) async -> String {
        guard model.isConnected else {
            return "Cannot position gimbal: AirFrame is not connected"
        }
        
        guard let shotType = input["shot_type"] as? String else {
            return "Missing shot_type parameter"
        }
        
        let subjectDirection = input["subject_direction"] as? String ?? "center"
        
        // Set appropriate mode based on shot type
        switch shotType.lowercased() {
        case "portrait", "macro":
            model.setGimbalMode(.locked)
            return "Gimbal set to locked mode for \(shotType) shot. Position your subject and the gimbal will maintain steady framing."
            
        case "landscape", "wide_angle":
            model.setGimbalMode(.locked)
            return "Gimbal set to locked mode for \(shotType) shot. The gimbal will maintain horizon level for stable landscape shots."
            
        case "action":
            model.setGimbalMode(.fpv)
            return "Gimbal set to FPV mode for action shots. This will follow your camera movements while maintaining stabilization."
            
        case "tracking":
            model.setGimbalMode(.personTracking)
            return "Gimbal set to person tracking mode. Enable tracking in the Camera tab to automatically follow subjects."
            
        default:
            return "Unknown shot type: \(shotType). Available types: portrait, landscape, action, macro, wide_angle, tracking"
        }
    }
    
    @MainActor
    private func analyzeScene(model: AirFrameModel) async -> String {
        guard model.isConnected else {
            return "Cannot analyze scene: AirFrame is not connected"
        }
        
        return """
        📸 **Scene Analysis**
        
        I'm analyzing the current view to suggest optimal gimbal positioning. 
        
        **Current Settings:**
        • Mode: \(model.currentMode.displayName)
        • Pitch: \(String(format: "%.1f°", model.currentPitch))
        • Roll: \(String(format: "%.1f°", model.currentRoll))
        • Yaw: \(String(format: "%.1f°", model.currentYaw))
        
        **Recommendations:**
        For the best shot composition, I recommend switching to Camera tab where I can access the live view for detailed scene analysis using AI vision.
        
        Would you like me to switch to a specific gimbal mode or adjust the positioning?
        """
    }
    
    @MainActor
    private func quickSetup(input: [String: Any], model: AirFrameModel) async -> String {
        guard model.isConnected else {
            return "Cannot set up gimbal: AirFrame is not connected"
        }
        
        guard let scenario = input["scenario"] as? String else {
            return "Missing scenario parameter"
        }
        
        switch scenario.lowercased() {
        case "selfie":
            model.setGimbalMode(.locked)
            return "🤳 **Selfie Mode Ready!**\nGimbal set to locked mode for stable selfies. The gimbal will keep you perfectly framed while you focus on getting the perfect shot."
            
        case "group_photo":
            model.setGimbalMode(.locked)
            return "👥 **Group Photo Setup Complete!**\nGimbal locked for stable group shots. Consider using the timer function on your camera app for best results."
            
        case "timelapse":
            model.setGimbalMode(.locked)
            return "⏰ **Timelapse Mode Activated!**\nGimbal locked for ultra-stable timelapse recording. Remember to keep your phone charged for longer sequences!"
            
        case "video_call":
            model.setGimbalMode(.locked)
            return "📹 **Video Call Ready!**\nGimbal stabilized for professional video calls. You'll look steady and professional on camera."
            
        case "streaming":
            model.setGimbalMode(.fpv)
            return "🎮 **Streaming Setup Complete!**\nGimbal in FPV mode for dynamic streaming content. Great for showing your movements while maintaining stabilization."
            
        case "wildlife":
            model.setGimbalMode(.personTracking)
            return "🦅 **Wildlife Mode Engaged!**\nGimbal set to tracking mode. Switch to Camera tab to enable subject tracking for following moving animals."
            
        default:
            return "Unknown scenario: \(scenario). Available scenarios: selfie, group_photo, timelapse, video_call, streaming, wildlife"
        }
    }
}

// MARK: - Supporting Types
struct AITool {
    let name: String
    let description: String
    let parameters: [String: AIToolParameter]
    
    func toClaudeFormat() -> ClaudeToolFormat {
        var properties: [String: Any] = [:]
        var required: [String] = []
        
        for (paramName, param) in parameters {
            var paramSchema: [String: Any] = [
                "type": param.type,
                "description": param.description
            ]
            
            if !param.enumValues.isEmpty {
                paramSchema["enum"] = param.enumValues
            }
            
            properties[paramName] = paramSchema
            
            if param.required {
                required.append(paramName)
            }
        }
        
        let schema: [String: Any] = [
            "type": "object",
            "properties": properties,
            "required": required
        ]
        
        return ClaudeToolFormat(name: name, description: description, inputSchema: schema)
    }
}

struct AIToolParameter {
    let type: String
    let description: String
    let enumValues: [String]
    let required: Bool
    
    init(type: String, description: String, enumValues: [String] = [], required: Bool = false) {
        self.type = type
        self.description = description
        self.enumValues = enumValues
        self.required = required
    }
}