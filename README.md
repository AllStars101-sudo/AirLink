## AirLink — Intelligent iOS Controller for the AirFrame Gimbal

Author: Chris Pagolu
Course: ELEC3117  
Platform: iOS 26 (Swift 5, SwiftUI)  
Date: 2025-08-11

### Abstract
AirLink is an iOS 26 SwiftUI application that connects to an ESP32‑based three‑axis gimbal (AirFrame) over Bluetooth LE to provide live status, mode control, and AI‑assisted operation. The system integrates: (1) hardware control via BLE services/characteristics; (2) a camera and on‑device vision pipeline for person tracking; and (3) an AI assistant (“Aerial”) that uses external LLM providers (Claude, OpenAI, Gemini) to translate natural‑language intents into concrete gimbal tool actions. The app targets modern iOS 26 APIs only and applies a cohesive “Liquid Glass” UI aesthetic. This report describes the architecture, implementation, evaluation considerations, and future work.

### Table of Contents
- 1. Introduction
- 2. System Overview
- 3. Architecture
  - 3.1 Core Model and State
  - 3.2 Bluetooth Integration
  - 3.3 Camera and Vision Tracking
  - 3.4 AI Assistant and Tooling
  - 3.5 UI/UX and Navigation
- 4. Security, Privacy, and Ethics
- 5. Testing and Evaluation
- 6. Results and Discussion
- 7. Limitations
- 8. Future Work
- 9. Build and Run Guide
- 10. References
- Appendix A: BLE UUIDs
- Appendix B: Key Types and Files

### 1. Introduction
Stabilized mobile capture is now ubiquitous across filmmaking, robotics, and sports analytics. This project delivers an iOS controller for a custom gimbal platform (AirFrame) with three pillars: robust BLE control, intelligent tracking, and natural‑language AI assistance to lower the barrier from idea to shot execution.

Objectives:
- Provide a reliable BLE control surface for AirFrame modes and configuration.
- Implement live attitude visualization and telemetry.
- Offer person‑tracking using the iPhone camera and Vision framework.
- Introduce an AI assistant that maps user intent to gimbal “tools” (functions) safely.
- Ship a cohesive, modern iOS 26 UI with Liquid Glass styling.

Scope and constraints:
- iOS 26 only; no backward‑compatibility layers.
- BLE protocol conforms to AirOS sample UUIDs on ESP32.
- External AI providers require user‑supplied API keys for full functionality; a demo mode is provided.

### 2. System Overview
- Hardware link: Bluetooth LE to the AirFrame (ESP32‑based controller).
- Camera pipeline: AVCaptureSession for preview, photos, and video; Vision for person detection.
- Tracking loop: bounding box → angular speed commands (pan/tilt) → BLE.
- AI assistant: chat/voice interface calling gimbal tools (set mode, calibrate, PID tune).
- Data and settings: lightweight persistence with UserDefaults; conversation history is stored locally.
- UI: SwiftUI with custom Liquid Glass components and smooth motion/transition design.

High‑level module diagram (Mermaid):

```mermaid
graph TD
  UI[SwiftUI Views
  (Tabs: Control, Status, Camera, Aerial, Settings)] --> Model(AirFrameModel)
  Model -->|delegate| BLE[BluetoothManager]
  Model -->|creates| Aerial[AerialAIService]
  Camera[CameraSessionController<br/>+ Vision Rectangle Detection] --> Tracker[TrackerLogic]
  Tracker -->|commands| BLE
  Aerial --> Claude[ClaudeService]
  Aerial --> OpenAI[OpenAIService]
  Aerial --> Gemini[GeminiService]
  Aerial --> Tools[AirFrameToolService]
  Tools --> Model
```

### 3. Architecture

#### 3.1 Core Model and State
- `AirFrameModel` is the app’s observable source of truth injected via SwiftUI environment. It tracks connection state, gimbal attitude (pitch/roll/yaw), current mode, calibration status, onboarding flags, and selected tab. It also holds the lazily‑initialized `AerialAIService`.
- Demo mode simulates connection and publishes smooth attitude values for UI/testing without hardware.

#### 3.2 Bluetooth Integration
- `BluetoothManager` encapsulates CoreBluetooth central, scanning for the AirOS service, connecting, and discovering characteristics.
- It writes commands (mode changes, calibration, yaw reset, PID settings) and subscribes for notifications (angles, status). Updates propagate to `AirFrameModel` via a delegate.
- BLE UUIDs and roles are documented in Appendix A.

#### 3.3 Camera and Vision Tracking
- `CameraSessionController` manages `AVCaptureSession`, providing preview, photo capture, and video recording with thumbnail extraction. It runs a `VNDetectHumanRectanglesRequest` on a background queue.
- `TrackerLogic` converts the detected person’s bounding box into smoothed pan/tilt speed commands with dead‑zone and first‑order easing, throttling BLE sends to avoid timeouts and jitter.
- Toggling “Tracking” switches the gimbal to Person Tracking mode and starts the command stream; turning off restores Locked mode.

#### 3.4 AI Assistant and Tooling
- `AerialAIService` orchestrates chat, voice input/output, scene analysis, and provider selection. It stores multi‑conversation history via `ConversationHistoryManager` with local persistence.
- Provider adapters:
  - `ClaudeService` (Anthropic) and `OpenAIService` (OpenRouter) implement JSON tool/function calls and error handling.
  - `GeminiService` performs image‑based scene analysis to suggest framing and gimbal positioning.
- `AirFrameToolService` surfaces a typed catalog of tools (set mode, calibrate, status, PID adjust, quick setups, etc.) and executes them against `AirFrameModel` under `@MainActor` where UI state changes occur.
- API keys are resolved via environment variables or UserDefaults using `APIKeyManager`. Missing keys automatically trigger “Demo Mode” responses for a graceful, offline experience.

#### 3.5 UI/UX and Navigation
- App entry is `AirLinkApp` with `RootView` gating onboarding before presenting `MainTabView` (Control, Status, Camera, Aerial, Settings).
- Visual language: Liquid Glass surfaces and flexible headers, implemented via dedicated modifiers and containers (e.g., `liquidGlassEffect`, `FlexibleHeader`, `GlassEffectContainer`) to centralize style rather than scattering raw `.ultraThinMaterial` usage.
- Aerial onboarding and chat screens use animated gradient backgrounds and motion‑respecting transitions. Controls provide haptics and clear accessibility labels.

### 4. Security, Privacy, and Ethics
- Keys: `APIKeyManager` prefers Xcode environment variables; UserDefaults storage is for dev only. No keys are bundled.
- Networking: All LLM calls use HTTPS with provider‑specific headers; errors and non‑200 responses are surfaced to the user.
- Privacy: Voice recognition (Speech framework) and audio session usage are scoped to user actions; transcription isn’t persisted unless included in chat history by design.
- AI disclosure: Aerial clearly indicates Demo vs Full AI mode and references partner technologies (Anthropic, Google) in onboarding copy.

### 5. Testing and Evaluation
- Manual validation: connection lifecycle, mode switching, calibration, yaw reset, PID adjustments, and tracking toggles.
- Camera tests: preview startup, photo capture flash, video start/stop, thumbnail generation, Photos Library writes (authorized).
- Vision loop: bounding box temporal stability, dead‑zone effectiveness, speed clamping, BLE command cadence under movement.
- AI: tool call correctness (parameter parsing), fallback to demo responses without keys, and voice round‑trip latency.
- Automation scaffolding exists in `AirLinkTests`/`AirLinkUITests`; expand with scenario tests (BLE mock, tracker math, tool serialization).

### 6. Results and Discussion
- The app reliably connects to AirFrame devices and maintains a responsive control surface.
- Person tracking yields smooth, damped motion suitable for typical walking‑pace subjects under adequate light.
- Aerial’s tool interface cleanly bridges natural language commands to deterministic device actions, avoiding free‑form text control risks.
- The Liquid Glass UI keeps overlays readable atop dynamic content (camera preview, charts) with minimal visual noise.

### 7. Limitations
- BLE protocol assumes a fixed UUID map and little error recovery for characteristic availability edge cases.
- Vision detector uses rectangle/person heuristics; challenging scenes (occlusion/low light) can drop detections.
- PID tuning UI applies values immediately without a timed rollback or baseline snapshot.
- Keys in UserDefaults are not production‑secure; use Keychain or device‑managed secrets for deployment.

### 8. Future Work
- Robust BLE reconnection and characteristic presence negotiation; richer error surfacing.
- Expand computer vision with object/person ID tracking, Kalman smoothing, and auto‑reframe strategies.
- Record and export stabilized video with inline gimbal telemetry for post‑analysis.
- Keychain‑backed secrets and optional iCloud sync of non‑sensitive app preferences.
- Deeper unit/UITest coverage including BLE mocks and snapshot tests for views.

### 9. Build and Run Guide
Prerequisites:
- Xcode with iOS 26 SDK; iPhone running iOS 26.
- Optional: API keys set in the scheme’s Environment Variables: `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `GEMINI_API_KEY`.

Steps:
1) Open `AirLink.xcodeproj` and select the `AirLink` scheme.  
2) Choose a physical iPhone target (camera and BLE require device).  
3) Run. On first launch, complete onboarding, then open Settings → AI Settings to verify Demo/Full mode.  
4) To test tracking, switch to Camera tab and enable the tracking toggle; verify the gimbal switches to Person Tracking mode.  

Troubleshooting:
- If no device is found, ensure AirFrame is powered and advertising the documented service UUID.  
- For AI: without keys, Aerial runs in Demo mode and will not call external APIs.  

### 10. References
- Apple Developer Documentation: SwiftUI, AVFoundation, Vision, Speech, CoreBluetooth.  
- Anthropic Messages API, OpenRouter Chat Completions, Google Generative Language API (Gemini).  
- Project source files listed in Appendix B.

### Appendix A: BLE UUIDs

Service
- AirOS Primary Service: `4fafc201-1fb5-459e-8fcc-c5c9c331914b`

Read‑only Characteristics (notify):
- Pitch Angle: `a1e8f36e-685b-4869-9828-c107a6729938`
- Roll Angle: `43a85368-8422-4573-a554-411a4a6e87f1`
- Yaw Angle: `e974ac4a-8182-4458-9419-4ac9c6c5184e`
- Gimbal Status: `c8a4a58b-1579-4451-b016-1f38e3115a3a`

Read‑write Characteristics:
- Gimbal Mode: `2a79d494-436f-45b6-890f-563534ab2c84`
- Gimbal Control (string commands): `f7a7a5a8-5e58-4c8d-9b6e-3aa5d6c5b768`

PID Characteristics:
- Pitch PID: `b16b472c-88a4-4734-9f85-01458e08d669`
- Roll PID:  `8184457e-85a8-4217-a9a3-a7d57947a612`
- Yaw PID:   `5d9b73b3-81e0-4368-910a-e322359b8676`
- Kalman Params: `6e13e51a-f3c2-46a4-b203-92147395c5d0`

### Appendix B: Key Types and Files
- App Entry: `AirLinkApp.swift` → `RootView` → `MainTabView`.
- Model and State: `AirFrameModel.swift`, `ConversationHistory.swift`.
- BLE: `BluetoothManager.swift` (delegate to `AirFrameModel`).
- Camera and Tracking: `CameraSessionController.swift`, `TrackerLogic.swift`, `CameraView.swift`.
- AI Assistant: `AerialAIService.swift`, `AirFrameToolService.swift`, `ClaudeService.swift`, `OpenAIService.swift`, `GeminiService.swift`, `VoiceService.swift`, `APIKeyManager.swift`.
- UI Views: `ControlView.swift`, `StatusView.swift`, `AerialView.swift`, `AerialOnboardingView.swift`, `SettingsView.swift`, `APIKeySettingsView.swift`, `PIDTuningView.swift`, `ConnectionView.swift`, `MainTabView.swift`, `RootView.swift`.
- UI Utilities: `FlexibleHeader.swift` (Liquid Glass header/background system).

Notes on UI style: The project centralizes Liquid Glass effects in reusable modifiers/containers to ensure consistent, accessible backgrounds across cards and overlays.


