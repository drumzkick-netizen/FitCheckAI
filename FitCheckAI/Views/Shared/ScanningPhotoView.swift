//
//  ScanningPhotoView.swift
//  FitCheckAI
//

import SwiftUI

struct ScanningPhotoView: View {
    let image: UIImage
    var isAnimating: Bool = true

    @State private var scanOffset: CGFloat = 0

    private static let cornerRadius: CGFloat = 22
    private static let scanBandHeight: CGFloat = 120
    /// One-way top-to-bottom duration for a calm, premium feel.
    private static let scanDuration: Double = 2.8
    private static let maxHeight: CGFloat = 380

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = min(geo.size.height, Self.maxHeight)
            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: height)
                    .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius))

                RoundedRectangle(cornerRadius: Self.cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.15),
                                Color.black.opacity(0.05),
                                Color.black.opacity(0.2)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .allowsHitTesting(false)

                if isAnimating {
                    scanBandView(width: width)
                        .offset(y: -height / 2 - Self.scanBandHeight / 2 + scanOffset)
                        .allowsHitTesting(false)
                }
            }
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Self.cornerRadius)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .frame(maxHeight: Self.maxHeight)
        .aspectRatio(3/4, contentMode: .fit)
        .shadow(color: Color.black.opacity(0.5), radius: 24, x: 0, y: 12)
        .shadow(color: AppColors.accent.opacity(0.12), radius: 32, x: 0, y: 8)
        .onAppear {
            if isAnimating {
                scanOffset = 0
                withAnimation(.easeInOut(duration: Self.scanDuration).repeatForever(autoreverses: false)) {
                    scanOffset = Self.maxHeight + Self.scanBandHeight
                }
            }
        }
        .onChange(of: isAnimating) { _, newValue in
            if !newValue {
                scanOffset = 0
            }
        }
    }

    /// Soft glowing horizontal band, blurred and semi-transparent. No harsh neon; clipped by parent.
    private func scanBandView(width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(
                LinearGradient(
                    colors: [
                        Color.clear,
                        Color.white.opacity(0.04),
                        Color.white.opacity(0.12),
                        Color.white.opacity(0.06),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: width + 40, height: Self.scanBandHeight)
            .blur(radius: 20)
    }
}

#Preview {
    ZStack {
        AppColors.background.ignoresSafeArea()
        if let img = UIImage(systemName: "photo") {
            ScanningPhotoView(image: img, isAnimating: true)
                .padding()
        }
    }
    .preferredColorScheme(.dark)
}
