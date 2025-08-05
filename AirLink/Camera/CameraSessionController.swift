//
//  CameraSessionController.swift
//  AirLink
//
//  Created by Chris on 8/10/25.
//

@preconcurrency import AVFoundation
import Vision
import Combine
import SwiftUI

@MainActor
final class CameraSessionController: NSObject, ObservableObject {
    
    // Published preview layer
    @Published var previewLayer: AVCaptureVideoPreviewLayer?
    
    // Private
    private let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let visionQueue = DispatchQueue(label: "vision.queue")
    
    private let trackerLogic: TrackerLogic
    private var currentOrientation: CGImagePropertyOrientation = .right
    
    init(trackerLogic: TrackerLogic) {
        self.trackerLogic = trackerLogic
        super.init()
        configureSession()
    }
    
    func start() {
        DispatchQueue.global(qos: .userInitiated).async { [weak session] in
            session?.startRunning()
        }
    }
    
    func stop() {
        DispatchQueue.global(qos: .userInitiated).async { [weak session] in
            session?.stopRunning()
        }
    }
    
    // MARK: session config
    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .high
        
        // Camera
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                   for: .video, position: .back),
              let input  = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input)
        else { return }
        session.addInput(input)
        
        // Output
        videoOutput.setSampleBufferDelegate(self, queue: visionQueue)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        guard session.canAddOutput(videoOutput) else { return }
        session.addOutput(videoOutput)
        
        session.commitConfiguration()
        
        // PreviewLayer
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        self.previewLayer = layer
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension CameraSessionController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // Vision request
        let request = VNDetectHumanRectanglesRequest { [weak self] req, _ in
            guard
                let self,
                let result = req.results?.first as? VNHumanObservation,
                result.confidence > 0.6
            else {
                Task { @MainActor in
                    self?.trackerLogic.processDetection(.zero, in: .zero)
                }
                return
            }
            
            Task { @MainActor in
                if let layer = self.previewLayer {
                    let rect = layer.layerRectConverted(fromMetadataOutputRect: result.boundingBox)
                    self.trackerLogic.processDetection(rect, in: layer.bounds)
                }
            }
        }
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                            orientation: currentOrientation,
                                            options: [:])
        try? handler.perform([request])
    }
}

