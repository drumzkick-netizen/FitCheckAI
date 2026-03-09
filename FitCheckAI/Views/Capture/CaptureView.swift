//
//  CaptureView.swift
//  FitCheckAI
//

import AVFoundation
import PhotosUI
import SwiftUI
import UIKit

private let jpegCompressionQuality: CGFloat = 0.85

struct CaptureView: View {
    @EnvironmentObject private var flowViewModel: AppFlowViewModel
    @State private var selectedItem: PhotosPickerItem?
    @State private var showCameraCapture = false
    @State private var showLibraryPicker = false

    private var isCameraAvailable: Bool {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                previewSection
                if let hint = PhotoPurposeTips.captureHint(for: flowViewModel.selectedPurpose) {
                    Text(hint)
                        .font(.caption)
                        .foregroundStyle(AppColors.mutedText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                }
                choiceSection
                Spacer(minLength: 24)
                continueButton
            }
            .padding()
            .padding(.bottom, 32)
        }
        .background(AmbientGlowBackground())
        .navigationTitle("Select Photo")
        .preferredColorScheme(.dark)
        .onAppear {
            if flowViewModel.preferCameraOnNextCapture {
                flowViewModel.preferCameraOnNextCapture = false
                showCameraCapture = true
            } else if flowViewModel.preferLibraryOnNextCapture {
                flowViewModel.preferLibraryOnNextCapture = false
                showLibraryPicker = true
            }
        }
        .fullScreenCover(isPresented: $showCameraCapture) {
            CameraCaptureView(onDismiss: {
                showCameraCapture = false
            })
            .environmentObject(flowViewModel)
        }
        .fullScreenCover(isPresented: $showLibraryPicker) {
            LibraryPickerSheetView(flowViewModel: flowViewModel, jpegQuality: jpegCompressionQuality) {
                showLibraryPicker = false
            }
        }
    }

    private var previewSection: some View {
        Group {
            if let image = flowViewModel.selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 300)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppColors.cardBackground)
                    .frame(height: 200)
                    .overlay {
                        Text("Select a photo or take one")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.mutedText)
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )
            }
        }
        .padding(.horizontal, 4)
    }

    private var choiceSection: some View {
        VStack(spacing: 12) {
            Button {
                showCameraCapture = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "camera.fill")
                        .font(.title2)
                    Text("Take Photo")
                        .font(.headline)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(AppColors.mutedText)
                }
                .foregroundStyle(.white)
                .glassCard(padding: 16, cornerRadius: 20)
            }
            .buttonStyle(CardTapButtonStyle())

            if !isCameraAvailable {
                Text("Camera is not available on this device.")
                    .font(.caption)
                    .foregroundStyle(AppColors.mutedText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            PhotosPicker(
                selection: $selectedItem,
                matching: .images
            ) {
                HStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.title2)
                    Text("Choose from Library")
                        .font(.headline)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(AppColors.mutedText)
                }
                .foregroundStyle(.white)
                .glassCard(padding: 16, cornerRadius: 20)
            }
            .buttonStyle(CardTapButtonStyle())
            .onChange(of: selectedItem) { _, newItem in
                Task {
                    await loadImage(from: newItem)
                }
            }
        }
    }

    private var continueButton: some View {
        Button("Continue") {
            flowViewModel.navigationPath.append(.adjustPhoto)
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(flowViewModel.selectedImage == nil)
        .opacity(flowViewModel.selectedImage == nil ? 0.6 : 1)
    }

    private func applyCameraImage(_ image: UIImage) {
        flowViewModel.selectedImage = image
        flowViewModel.selectedImageData = image.jpegData(compressionQuality: jpegCompressionQuality)
    }

    private func loadImage(from item: PhotosPickerItem?) async {
        guard let item else {
            flowViewModel.selectedImage = nil
            flowViewModel.selectedImageData = nil
            return
        }
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            flowViewModel.selectedImage = nil
            flowViewModel.selectedImageData = nil
            return
        }
        flowViewModel.selectedImageData = data
        flowViewModel.selectedImage = UIImage(data: data)
    }
}

// MARK: - Library-only picker sheet (e.g. from Home "Upload Photo")
private struct LibraryPickerSheetView: View {
    @ObservedObject var flowViewModel: AppFlowViewModel
    let jpegQuality: CGFloat
    let onDismiss: () -> Void
    @State private var selectedItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                PhotosPicker(
                    selection: $selectedItem,
                    matching: .images
                ) {
                    Label("Choose from Library", systemImage: "photo.on.rectangle.angled")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(BorderedProminentPressableStyle(tint: AppColors.accent))
                Spacer()
            }
            .padding()
            .background(AmbientGlowBackground())
            .navigationTitle("Choose Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onDismiss()
                    }
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(AppColors.accent)
                    .fixedSize(horizontal: true, vertical: false)
                    .buttonStyle(.plain)
                }
            }
            .onChange(of: selectedItem) { _, newItem in
                Task {
                    guard let newItem else { return }
                    guard let data = try? await newItem.loadTransferable(type: Data.self) else { return }
                    flowViewModel.selectedImageData = data
                    flowViewModel.selectedImage = UIImage(data: data)
                    await MainActor.run { onDismiss() }
                }
            }
        }
        .environmentObject(flowViewModel)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    NavigationStack {
        CaptureView()
            .environmentObject(AppFlowViewModel())
    }
}
