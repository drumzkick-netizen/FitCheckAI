//
//  PhotoAdjustmentView.swift
//  FitCheckAI
//

import SwiftUI
import UIKit

private let jpegCompressionQuality: CGFloat = 0.85
private let maxScale: CGFloat = 4.0
private let frameCornerRadius: CGFloat = 20
private let analysisFrameStrokeWidth: CGFloat = 2.5
private let analysisFrameOpacity: Double = 0.35

struct PhotoAdjustmentView: View {
    @EnvironmentObject private var flowViewModel: AppFlowViewModel

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var contentSize: CGSize = .zero
    @State private var hasInitializedScale = false
    @State private var hasAdjustedOnce = false

    private var image: UIImage? {
        flowViewModel.selectedImage
    }

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            headerSection
            imageAdjustmentArea
            adjustmentHintText
            actionsSection
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AmbientGlowBackground())
        .navigationTitle("Adjust Photo")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .onChange(of: flowViewModel.selectedImage?.hashValue) { _, _ in
            hasInitializedScale = false
            hasAdjustedOnce = false
            scale = 1
            lastScale = 1
            offset = .zero
            lastOffset = .zero
        }
    }

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("Position and zoom so the area to analyze is inside the frame.")
                .font(.subheadline)
                .foregroundStyle(AppColors.mutedText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var adjustmentHintText: some View {
        Text("Pinch to zoom and drag to adjust your frame.")
            .font(.subheadline)
            .foregroundStyle(AppColors.mutedText)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 10)
    }

    private var imageAdjustmentArea: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let imgW = image?.size.width ?? 1
            let imgH = image?.size.height ?? 1

            ZStack {
                Color.black.opacity(0.35)
                    .clipShape(RoundedRectangle(cornerRadius: frameCornerRadius))

                if let image = image, w > 0, h > 0, imgW > 0, imgH > 0 {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: imgW * scale, height: imgH * scale)
                        .offset(offset)
                }
            }
            .frame(width: w, height: h)
            .clipShape(RoundedRectangle(cornerRadius: frameCornerRadius))
            .overlay(analysisFrameOverlay)
            .overlay {
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        SimultaneousGesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    if !hasAdjustedOnce { hasAdjustedOnce = true }
                                    let fitted = min(w / imgW, h / imgH)
                                    let newScale = lastScale * value
                                    scale = min(maxScale, max(fitted, newScale))
                                }
                                .onEnded { _ in
                                    lastScale = scale
                                    clampOffsetToImageBounds(viewWidth: w, viewHeight: h, imgW: imgW, imgH: imgH)
                                    lastOffset = offset
                                },
                            DragGesture()
                                .onChanged { value in
                                    if !hasAdjustedOnce { hasAdjustedOnce = true }
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                }
                                .onEnded { _ in
                                    clampOffsetToImageBounds(viewWidth: w, viewHeight: h, imgW: imgW, imgH: imgH)
                                    lastOffset = offset
                                }
                        )
                    )
            }
            .onAppear {
                contentSize = CGSize(width: w, height: h)
                if !hasInitializedScale, let img = image, w > 0, h > 0, img.size.width > 0, img.size.height > 0 {
                    let s = min(w / img.size.width, h / img.size.height)
                    scale = s
                    lastScale = s
                    hasInitializedScale = true
                }
            }
            .onChange(of: geo.size) { _, newSize in
                contentSize = newSize
            }
        }
        .aspectRatio(3/4, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
    }

    /// Keeps the crop frame over the image (no empty edges).
    private func clampOffsetToImageBounds(viewWidth w: CGFloat, viewHeight h: CGFloat, imgW: CGFloat, imgH: CGFloat) {
        let maxOffsetX = max(0, (imgW * scale - w) / 2)
        let maxOffsetY = max(0, (imgH * scale - h) / 2)
        offset.width = min(maxOffsetX, max(-maxOffsetX, offset.width))
        offset.height = min(maxOffsetY, max(-maxOffsetY, offset.height))
    }

    /// Clear visible frame so the user understands what area will be analyzed.
    private var analysisFrameOverlay: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: frameCornerRadius)
                .stroke(Color.white.opacity(analysisFrameOpacity), lineWidth: analysisFrameStrokeWidth)

            Text("This area will be analyzed")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(.white.opacity(0.75))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.black.opacity(0.5))
                .clipShape(Capsule())
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
        }
        .allowsHitTesting(false)
    }

    private var actionsSection: some View {
        VStack(spacing: 16) {
            Button("Continue to Analyze") {
                applyCropAndContinue()
            }
            .buttonStyle(PrimaryButtonStyle())

            Button("Choose Another") {
                flowViewModel.selectedImage = nil
                flowViewModel.selectedImageData = nil
                if !flowViewModel.navigationPath.isEmpty {
                    flowViewModel.navigationPath.removeLast()
                }
            }
            .font(.headline)
            .foregroundStyle(AppColors.mutedText)
        }
        .padding(24)
    }

    private func applyCropAndContinue() {
        guard let image = image else { return }
        let imgW = image.size.width
        let imgH = image.size.height
        let w = contentSize.width
        let h = contentSize.height
        guard w > 0, h > 0, imgW > 0, imgH > 0 else { return }

        let cropRect = cropRectInImageSpace(viewWidth: w, viewHeight: h)
        guard let cropped = cropImage(image, to: cropRect) else { return }

        flowViewModel.selectedImage = cropped
        flowViewModel.selectedImageData = cropped.jpegData(compressionQuality: jpegCompressionQuality)

        if !flowViewModel.navigationPath.isEmpty {
            flowViewModel.navigationPath.removeLast()
        }
        if flowViewModel.selectedPurpose == .compare {
            flowViewModel.navigationPath.append(.compareCapture)
        } else if flowViewModel.selectedPurpose != nil {
            flowViewModel.navigationPath.append(.analyze)
        } else {
            flowViewModel.navigationPath.append(.purpose)
        }
    }

    /// View rect (0,0,w,h) maps to image: center of image at (w/2, h/2) + offset, image displayed at (imgW*scale, imgH*scale).
    private func cropRectInImageSpace(viewWidth w: CGFloat, viewHeight h: CGFloat) -> CGRect {
        let imgW = image?.size.width ?? 1
        let imgH = image?.size.height ?? 1
        let cropX = max(0, imgW / 2 - (w / 2 + offset.width) / scale)
        let cropY = max(0, imgH / 2 - (h / 2 + offset.height) / scale)
        let cropW = min(w / scale, imgW - cropX)
        let cropH = min(h / scale, imgH - cropY)
        return CGRect(x: cropX, y: cropY, width: max(1, cropW), height: max(1, cropH))
    }

    private func cropImage(_ image: UIImage, to rect: CGRect) -> UIImage? {
        let size = rect.size
        guard size.width > 0, size.height > 0 else { return nil }
        let renderer = UIGraphicsImageRenderer(size: size)
        let cropped = renderer.image { ctx in
            ctx.cgContext.clip(to: CGRect(origin: .zero, size: size))
            image.draw(at: CGPoint(x: -rect.origin.x, y: -rect.origin.y))
        }
        return cropped
    }
}

#Preview {
    NavigationStack {
        PhotoAdjustmentView()
            .environmentObject(AppFlowViewModel())
    }
}
