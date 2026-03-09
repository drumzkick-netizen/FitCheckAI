//
//  CompareCaptureView.swift
//  FitCheckAI
//

import PhotosUI
import SwiftUI
import UIKit

private let jpegCompressionQuality: CGFloat = 0.85
private let photoCardCornerRadius: CGFloat = 20
private let photoCardMinHeight: CGFloat = 260

/// Dedicated Photo Battle setup: choose Photo A and Photo B, then start the battle.
struct CompareCaptureView: View {
    @EnvironmentObject private var flowViewModel: AppFlowViewModel
    @State private var photoAPickerItem: PhotosPickerItem?
    @State private var photoBPickerItem: PhotosPickerItem?
    @State private var showCameraForA = false
    @State private var showCameraForB = false

    private var isCameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    private var canStartBattle: Bool {
        flowViewModel.selectedImage != nil && flowViewModel.compareImage != nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                headerSection
                photoSlot(
                    label: "Photo A",
                    image: flowViewModel.selectedImage,
                    isPlaceholder: flowViewModel.selectedImage == nil,
                    addButtonLabel: "Select First Outfit",
                    onCameraTap: { showCameraForA = true },
                    pickerItem: $photoAPickerItem
                )
                photoSlot(
                    label: "Photo B",
                    image: flowViewModel.compareImage,
                    isPlaceholder: flowViewModel.compareImage == nil,
                    addButtonLabel: "Select Second Outfit",
                    onCameraTap: { showCameraForB = true },
                    pickerItem: $photoBPickerItem
                )
                if (flowViewModel.selectedImage == nil || flowViewModel.compareImage == nil), !isCameraAvailable {
                    Text("Camera is not available on this device.")
                        .font(.caption)
                        .foregroundStyle(AppColors.mutedText)
                }
                Spacer(minLength: 32)
                startBattleButton
            }
            .padding(20)
            .padding(.bottom, 40)
        }
        .background(AmbientGlowBackground())
        .navigationTitle("Photo Battle")
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showCameraForA) {
            CameraPicker(
                onImagePicked: { applyPhotoA($0) },
                onCancel: {}
            )
        }
        .sheet(isPresented: $showCameraForB) {
            CameraPicker(
                onImagePicked: { image in
                    flowViewModel.compareImage = image
                    flowViewModel.compareImageData = image.jpegData(compressionQuality: jpegCompressionQuality)
                },
                onCancel: {}
            )
        }
        .onChange(of: photoAPickerItem) { _, newItem in
            Task { await loadImage(from: newItem, isPhotoA: true) }
        }
        .onChange(of: photoBPickerItem) { _, newItem in
            Task { await loadImage(from: newItem, isPhotoA: false) }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Photo Battle")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
            Text("Choose two outfits to see which one wins.")
                .font(.subheadline)
                .foregroundStyle(AppColors.mutedText)
        }
    }

    private func photoSlot(
        label: String,
        image: UIImage?,
        isPlaceholder: Bool,
        addButtonLabel: String,
        onCameraTap: @escaping () -> Void,
        pickerItem: Binding<PhotosPickerItem?>
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(label)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
            Group {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(minHeight: photoCardMinHeight)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: photoCardCornerRadius))
                        .overlay(
                            RoundedRectangle(cornerRadius: photoCardCornerRadius)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.4), radius: 16, x: 0, y: 8)
                } else {
                    RoundedRectangle(cornerRadius: photoCardCornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.06),
                                    Color.white.opacity(0.02)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(minHeight: photoCardMinHeight)
                        .overlay {
                            Text(addButtonLabel)
                                .font(.subheadline)
                                .foregroundStyle(AppColors.mutedText)
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: photoCardCornerRadius)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                }
            }

            if isPlaceholder {
                HStack(spacing: 12) {
                    Button {
                        onCameraTap()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "camera.fill")
                            Text("Take Photo")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(AppColors.cardBackground)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(CardTapButtonStyle())
                    .disabled(!isCameraAvailable)

                    PhotosPicker(selection: pickerItem, matching: .images) {
                        HStack(spacing: 8) {
                            Image(systemName: "photo.on.rectangle.angled")
                            Text("Choose from Library")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(AppColors.cardBackground)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(CardTapButtonStyle())
                }
            }
        }
    }

    private var startBattleButton: some View {
        Button("Start Battle") {
            AnalyticsService.log(.photoBattleStarted)
            flowViewModel.navigationPath.append(.compareAnalyze)
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(!canStartBattle)
        .opacity(canStartBattle ? 1 : 0.5)
    }

    private func applyPhotoA(_ image: UIImage?) {
        guard let image else {
            flowViewModel.selectedImage = nil
            flowViewModel.selectedImageData = nil
            return
        }
        // Downsample and compress to avoid retaining full-resolution Photo A in memory.
        if let originalJPEG = image.jpegData(compressionQuality: jpegCompressionQuality) {
            let preparedData = ImageUploadPreparer.prepareForAnalysis(imageData: originalJPEG)
            flowViewModel.selectedImageData = preparedData
            flowViewModel.selectedImage = UIImage(data: preparedData)
        } else {
            flowViewModel.selectedImage = image
            flowViewModel.selectedImageData = nil
        }
    }

    private func applyPhotoB(_ image: UIImage?) {
        guard let image else {
            flowViewModel.compareImage = nil
            flowViewModel.compareImageData = nil
            return
        }
        // Downsample and compress to avoid retaining full-resolution Photo B in memory.
        if let originalJPEG = image.jpegData(compressionQuality: jpegCompressionQuality) {
            let preparedData = ImageUploadPreparer.prepareForAnalysis(imageData: originalJPEG)
            flowViewModel.compareImageData = preparedData
            flowViewModel.compareImage = UIImage(data: preparedData)
        } else {
            flowViewModel.compareImage = image
            flowViewModel.compareImageData = nil
        }
    }

    private func loadImage(from item: PhotosPickerItem?, isPhotoA: Bool) async {
        guard let item else {
            if isPhotoA {
                flowViewModel.selectedImage = nil
                flowViewModel.selectedImageData = nil
            } else {
                flowViewModel.compareImage = nil
                flowViewModel.compareImageData = nil
            }
            return
        }
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            if isPhotoA {
                flowViewModel.selectedImage = nil
                flowViewModel.selectedImageData = nil
            } else {
                flowViewModel.compareImage = nil
                flowViewModel.compareImageData = nil
            }
            return
        }
        // Downsample and compress Photos picker image before storing.
        let preparedData = ImageUploadPreparer.prepareForAnalysis(imageData: data)
        let image = UIImage(data: preparedData)
        if isPhotoA {
            flowViewModel.selectedImage = image
            flowViewModel.selectedImageData = preparedData
        } else {
            flowViewModel.compareImage = image
            flowViewModel.compareImageData = preparedData
        }
    }
}

#Preview {
    NavigationStack {
        CompareCaptureView()
            .environmentObject(AppFlowViewModel())
    }
}
