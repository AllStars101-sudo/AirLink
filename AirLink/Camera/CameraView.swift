// CameraView.swift

import SwiftUI
import AVFoundation

struct CameraView: View {
    @Environment(AirFrameModel.self) private var model
    
    // We create the controllers here as StateObjects to manage their lifecycle
    @StateObject private var trackerLogic: TrackerLogic
    @StateObject private var cameraController: CameraSessionController
    
    // State for the view itself
    @State private var showingControls = true
    
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
                    HStack {
                        Spacer()
                        CloseButton()
                    }
                    Spacer()
                    TrackingStatusIndicator(isTracking: trackerLogic.isTracking)
                }
                .transition(.opacity)
            }
        }
        .animation(.interpolatingSpring(stiffness: 300, damping: 20), value: trackerLogic.detectedPersonRect)
        .onAppear { cameraController.start() }
        .onDisappear { cameraController.stop() }
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
