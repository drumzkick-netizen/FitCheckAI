//
//  CameraCaptureView.swift
//  FitCheckAI
//

import AVFoundation
import Combine
import SwiftUI
import UIKit

private let jpegCompressionQuality: CGFloat = 0.85
private let previewCornerRadius: CGFloat = 24

// MARK: - Camera session controller

final class CameraSessionController: NSObject, ObservableObject {
    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var captureCompletion: ((UIImage?) -> Void)?
    private var isFront = false
    /// Used so Swift recognizes ObservableObject conformance when subclassing NSObject.
    @Published private(set) var sessionRunning = false

    override init() {
        super.init()
    }

    func configure() {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .photo
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else { return }
        if session.canAddInput(input) {
            session.addInput(input)
        }
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }
    }

    func switchCamera() {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        let currentInput = session.inputs.first as? AVCaptureDeviceInput
        let position: AVCaptureDevice.Position = isFront ? .back : .front
        isFront.toggle()
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let newInput = try? AVCaptureDeviceInput(device: device) else { return }
        if let old = currentInput {
            session.removeInput(old)
        }
        if session.canAddInput(newInput) {
            session.addInput(newInput)
        }
    }

    func startSession() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
            DispatchQueue.main.async { self?.sessionRunning = self?.session.isRunning ?? false }
        }
    }

    func stopSession() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.stopRunning()
            DispatchQueue.main.async { self?.sessionRunning = false }
        }
    }

    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        captureCompletion = completion
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
}

extension CameraSessionController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let completion = captureCompletion
        captureCompletion = nil
        guard let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else {
            DispatchQueue.main.async { completion?(nil) }
            return
        }
        DispatchQueue.main.async { completion?(image) }
    }
}

// MARK: - Preview UIViewRepresentable

final class CameraPreviewUIView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
    }
}

struct CameraPreviewRepresentable: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        uiView.previewLayer.session = session
    }
}

// MARK: - SwiftUI screen

struct CameraCaptureView: View {
    /// When set (e.g. from fullScreenCover), dismiss by calling this. When nil, dismiss by popping navigation.
    var onDismiss: (() -> Void)? = nil

    @EnvironmentObject private var flowViewModel: AppFlowViewModel
    @StateObject private var cameraSession = CameraSessionController()
    @State private var isCapturing = false
    @State private var showLibrary = false

    private var contextTip: String? {
        guard let purpose = flowViewModel.selectedPurpose else { return nil }
        switch purpose {
        case .outfit: return "Show your full body or upper body"
        case .dating: return "Show your face clearly"
        case .social: return "Make sure you're the main focus"
        case .professional: return "Use a clean, well-lit shot"
        case .compare: return "Use a clear photo of you"
        case .improveFit: return "Show your outfit clearly for improvement suggestions"
        }
    }

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                headerSection
                previewSection
                controlsSection
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .onAppear {
            cameraSession.configure()
            cameraSession.startSession()
        }
        .onDisappear {
            cameraSession.stopSession()
        }
        .sheet(isPresented: $showLibrary) {
            libraryPickerSheet
        }
    }

    private var headerSection: some View {
        VStack(spacing: 6) {
            Text("Take Photo")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
            if let tip = contextTip {
                Text(tip)
                    .font(.caption)
                    .foregroundStyle(AppColors.mutedText)
            }
        }
        .padding(.top, 20)
        .padding(.bottom, 16)
    }

    private var previewSection: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                CameraPreviewRepresentable(session: cameraSession.session)
                    .clipShape(RoundedRectangle(cornerRadius: previewCornerRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: previewCornerRadius)
                            .stroke(AppColors.accent.opacity(0.25), lineWidth: 2)
                    )
                    .shadow(color: Color.black.opacity(0.5), radius: 20, x: 0, y: 8)
                    .padding(.horizontal, 20)
            }
            .frame(width: size.width, height: size.height)
        }
        .aspectRatio(3/4, contentMode: .fit)
        .padding(.horizontal, 4)
    }

    private var controlsSection: some View {
        VStack(spacing: 20) {
            HStack(spacing: 24) {
                Button("Cancel") {
                    dismissCamera()
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(AppColors.mutedText)

                Spacer()

                Button {
                    showLibrary = true
                } label: {
                    Label("Library", systemImage: "photo.on.rectangle.angled")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.mutedText)
                }

                Spacer()

                Button {
                    if AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) != nil {
                        cameraSession.switchCamera()
                    }
                } label: {
                    Image(systemName: "camera.rotate.fill")
                        .font(.title2)
                        .foregroundStyle(AppColors.mutedText)
                }
            }
            .padding(.horizontal, 32)

            Button {
                takePhoto()
            } label: {
                ZStack {
                    Circle()
                        .fill(AppColors.background)
                        .frame(width: 76, height: 76)
                    Circle()
                        .stroke(AppColors.accent, lineWidth: 4)
                        .frame(width: 72, height: 72)
                    Circle()
                        .fill(AppColors.accent)
                        .frame(width: 60, height: 60)
                }
            }
            .buttonStyle(PlainPressableStyle())
            .disabled(isCapturing)
            .opacity(isCapturing ? 0.6 : 1)
        }
        .padding(.top, 24)
        .padding(.bottom, 40)
    }

    private var libraryPickerSheet: some View {
        PhotosPickerViewRepresentable { image in
            showLibrary = false
            if let image = image {
                applyImage(image)
                dismissCamera()
            }
        } onCancel: {
            showLibrary = false
        }
    }

    private func takePhoto() {
        guard !isCapturing else { return }
        isCapturing = true
        cameraSession.capturePhoto { image in
            isCapturing = false
            guard let image = image else { return }
            applyImage(image)
            dismissCamera()
        }
    }

    private func applyImage(_ image: UIImage) {
        // Downsample and compress immediately to avoid keeping full-resolution images in memory.
        guard let originalJPEG = image.jpegData(compressionQuality: jpegCompressionQuality) else {
            flowViewModel.selectedImage = image
            flowViewModel.selectedImageData = nil
            return
        }
        let preparedData = ImageUploadPreparer.prepareForAnalysis(imageData: originalJPEG)
        flowViewModel.selectedImageData = preparedData
        flowViewModel.selectedImage = UIImage(data: preparedData)
    }

    private func dismissCamera() {
        if let onDismiss {
            onDismiss()
        } else if !flowViewModel.navigationPath.isEmpty {
            flowViewModel.navigationPath.removeLast()
        }
    }
}

// MARK: - Simple Photos picker wrapper (sheet)

struct PhotosPickerViewRepresentable: UIViewControllerRepresentable {
    var onPick: (UIImage?) -> Void
    var onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick, onCancel: onCancel)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onPick: (UIImage?) -> Void
        let onCancel: () -> Void

        init(onPick: @escaping (UIImage?) -> Void, onCancel: @escaping () -> Void) {
            self.onPick = onPick
            self.onCancel = onCancel
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let image = info[.originalImage] as? UIImage
            onPick(image)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
        }
    }
}

#Preview {
    NavigationStack {
        CameraCaptureView()
            .environmentObject(AppFlowViewModel())
    }
}
