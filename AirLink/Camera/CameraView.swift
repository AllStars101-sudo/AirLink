// CameraView.swift

import SwiftUI
import AVFoundation

enum CameraMode { case photo, video }

struct CameraView: View {
    @Environment(AirFrameModel.self) private var model
    
    // We create the controllers here as StateObjects to manage their lifecycle
    @StateObject private var trackerLogic: TrackerLogic
    @StateObject private var cameraController: CameraSessionController
    
    // State for the view itself
    @State private var showingControls = true
    @State private var flashOpacity: Double = 0
    @State private var cameraMode: CameraMode = .photo
    
    // Initialize the controllers, injecting the BluetoothManager dependency
    init() {
        // In a larger app, you'd pass the BluetoothManager from the environment.
        // For now, we create a temporary instance for the camera's lifecycle.
        let bluetoothManager = BluetoothManager()
        let tracker = TrackerLogic(bluetooth: bluetoothManager)
        
        _trackerLogic = StateObject(wrappedValue: tracker)
        _cameraController = StateObject(wrappedValue: CameraSessionController(trackerLogic: tracker))
    }
    
    var body: some View {
        ZStack {
            // Layer 1: The Camera Preview
            if let layer = cameraController.previewLayer {
                CameraPreview(layer: layer)
                    .ignoresSafeArea()
                    .onTapGesture {
                        // Hide/show controls on tap
                        withAnimation(.easeInOut) {
                            showingControls.toggle()
                        }
                    }
            } else {
                // Placeholder while camera starts
                ZStack {
                    Color.black.ignoresSafeArea()
                    ProgressView("Starting Camera…")
                        .tint(.white)
                }
            }
            
            // Layer 2: The Bounding Box Overlay
            if trackerLogic.isTracking {
                Rectangle()
                    .stroke(Color.yellow, lineWidth: 3)
                    .frame(width: trackerLogic.detectedPersonRect.width, height: trackerLogic.detectedPersonRect.height)
                    .position(x: trackerLogic.detectedPersonRect.midX, y: trackerLogic.detectedPersonRect.midY)
                    .transition(.opacity.combined(with: .scale))
            }
            
            // Layer 3: The UI Controls
            if showingControls {
                VStack {
                    // Top bar with camera switch button, spacer, close button
                    HStack {
                        Button {
                            cameraController.switchCamera()
                        } label: {
                            Image(systemName: "arrow.triangle.2.circlepath.camera")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 22, height: 22)
                                .padding()
                                .background(Circle().fill(.ultraThinMaterial))
                        }
                        .frame(width: 44, height: 44)
                        .accessibilityLabel(Text("Switch Camera"))
                        
                        Spacer()
                        
                        CloseButton()
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    Spacer()
                    
                    VStack(spacing: 16) {
                        // Mode selector styled like iOS Camera
                        HStack(spacing: 0) {
                            Button {
                                cameraMode = .video
                            } label: {
                                Text("VIDEO")
                                    .font(.headline)
                                    .foregroundColor(cameraMode == .video ? .yellow : .white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                            }
                            .background(cameraMode == .video ? Color.white.opacity(0.08) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            
                            Button {
                                cameraMode = .photo
                            } label: {
                                Text("PHOTO")
                                    .font(.headline)
                                    .foregroundColor(cameraMode == .photo ? .yellow : .white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                            }
                            .background(cameraMode == .photo ? Color.white.opacity(0.08) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                        }
                        .padding(6)
                        .background(Color(white: 0.08, opacity: 0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .frame(width: 220)
                        
                        // Main controls row
                        HStack {
                            // Tracking toggle button
                            Button {
                                cameraController.isTrackingEnabled.toggle()
                            } label: {
                                Image(systemName: "person.and.background.dotted")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 24, height: 24)
                                    .padding(12)
                                    .background(Circle().fill(.ultraThinMaterial))
                                    .foregroundColor(cameraController.isTrackingEnabled ? .blue : .gray)
                            }
                            .frame(width: 44, height: 44)
                            .accessibilityLabel(Text(cameraController.isTrackingEnabled ? "Disable Tracking" : "Enable Tracking"))
                            
                            Spacer()
                            
                            // Shutter area
                            ZStack {
                                if cameraMode == .photo {
                                    Button {
                                        cameraController.capturePhoto()
                                    } label: {
                                        Circle()
                                            .fill(Color.white)
                                            .frame(width: 68, height: 68)
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.gray.opacity(0.8), lineWidth: 2)
                                            )
                                    }
                                    .accessibilityLabel(Text("Capture Photo"))
                                } else {
                                    if cameraController.isRecording {
                                        Button {
                                            cameraController.stopRecording()
                                        } label: {
                                            Image(systemName: "stop.circle.fill")
                                                .resizable()
                                                .foregroundColor(.red)
                                                .frame(width: 68, height: 68)
                                        }
                                        .accessibilityLabel(Text("Stop Recording"))
                                    } else {
                                        Button {
                                            cameraController.startRecording()
                                        } label: {
                                            Image(systemName: "record.circle.fill")
                                                .resizable()
                                                .foregroundColor(.red)
                                                .frame(width: 68, height: 68)
                                        }
                                        .accessibilityLabel(Text("Start Video Recording"))
                                    }
                                }
                            }
                            
                            Spacer()
                            
                            // Thumbnail of last captured photo if available
                            if let lastPhoto = cameraController.lastCapturedPhoto {
                                Image(uiImage: lastPhoto)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 44, height: 44)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .shadow(radius: 2)
                                    .accessibilityLabel(Text("Last captured photo"))
                            } else {
                                Color.clear.frame(width: 44, height: 44)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 20)
                    .animation(.easeInOut, value: cameraController.isRecording)
                }
                .transition(.opacity)
            }
            
            // Flash overlay when photo is taken
            Color.white
                .opacity(flashOpacity)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
        .animation(.interpolatingSpring(stiffness: 300, damping: 20), value: trackerLogic.detectedPersonRect)
        .onAppear { cameraController.start() }
        .onDisappear { cameraController.stop() }
        // Observe lastCapturedPhoto changes to trigger flash
        .onChange(of: cameraController.lastCapturedPhoto) { _ in
            withAnimation(.easeOut(duration: 0.2)) {
                flashOpacity = 0.5
            }
            withAnimation(.easeIn(duration: 0.3).delay(0.1)) {
                flashOpacity = 0
            }
        }
    }
}

// MARK: - UI Components

private struct TrackingStatusIndicator: View {
    let isTracking: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isTracking ? "person.fill.checkmark" : "person.fill.questionmark")
            Text(isTracking ? "Tracking Subject" : "Searching...")
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .foregroundStyle(.primary)
        .padding(.bottom)
    }
}

private struct CameraPreview: UIViewRepresentable {
    let layer: AVCaptureVideoPreviewLayer
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        layer.frame = view.bounds
        view.layer.addSublayer(layer)
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // This ensures the layer resizes correctly on orientation changes
        DispatchQueue.main.async {
            layer.frame = uiView.bounds
        }
    }
}

private struct CloseButton: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        Button(action: { dismiss() }) {
            Image(systemName: "xmark")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.black)
                .padding(8)
                .background(.white.opacity(0.8), in: Circle())
        }
        .padding()
        .accessibilityLabel("Close Camera")
    }
}

#Preview {
    CameraView()
        .environment(AirFrameModel())
}
