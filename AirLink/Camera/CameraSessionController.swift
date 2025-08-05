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
import Photos

@MainActor
final class CameraSessionController: NSObject, ObservableObject {
    
    // Published preview layer
    @Published var previewLayer: AVCaptureVideoPreviewLayer?
    @Published var isRecording: Bool = false
    @Published var isFrontCamera: Bool = false
    @Published var isTrackingEnabled: Bool = true
    @Published var lastCapturedPhoto: UIImage?
    
    // Private
    private let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let photoOutput = AVCapturePhotoOutput()
    private let movieOutput = AVCaptureMovieFileOutput()
    private let visionQueue = DispatchQueue(label: "vision.queue")
    private var currentCamera: AVCaptureDevice.Position = .back
    
    private let trackerLogic: TrackerLogic
    private var currentOrientation: CGImagePropertyOrientation = .right
    
    init(trackerLogic: TrackerLogic) {
        self.trackerLogic = trackerLogic
        super.init()
        configureSession()
        photoOutput.isHighResolutionCaptureEnabled = true
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
        
        // Photo output
        guard session.canAddOutput(photoOutput) else { return }
        session.addOutput(photoOutput)

        // Movie output
        guard session.canAddOutput(movieOutput) else { return }
        session.addOutput(movieOutput)
        
        session.commitConfiguration()
        
        // PreviewLayer
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        self.previewLayer = layer
    }
    
    // MARK: - Camera Controls
    func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    func startRecording() {
        guard !isRecording else { return }
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mov")
        movieOutput.startRecording(to: outputURL, recordingDelegate: self)
        isRecording = true
    }

    func stopRecording() {
        guard isRecording else { return }
        movieOutput.stopRecording()
        isRecording = false
    }

    func switchCamera() {
        currentCamera = (currentCamera == .back) ? .front : .back
        isFrontCamera = (currentCamera == .front)
        reconfigureSessionForCamera(position: currentCamera)
    }
    
    private func reconfigureSessionForCamera(position: AVCaptureDevice.Position) {
        session.beginConfiguration()
        // Remove all current inputs
        for input in session.inputs {
            session.removeInput(input)
        }
        // Add new input
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input)
        else {
            session.commitConfiguration()
            return
        }
        session.addInput(input)
        session.commitConfiguration()
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension CameraSessionController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        guard isTrackingEnabled else {
            Task { @MainActor in
                self.trackerLogic.processDetection(.zero, in: .zero)
            }
            return
        }
        
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

// MARK: - AVCapturePhotoCaptureDelegate
extension CameraSessionController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else { return }
        Task { @MainActor in
            self.lastCapturedPhoto = image
        }
        
        // Save to Photos
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized || status == .limited else { return }
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            })
        }
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate
extension CameraSessionController: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        // You can handle the saved video URL here (e.g., save to Photo Library)
        // isRecording is reset in stopRecording()
        
        // Save video to Photos
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized || status == .limited else { return }
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outputFileURL)
            })
        }
    }
}
