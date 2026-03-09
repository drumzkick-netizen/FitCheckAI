//
//  PurposeSelectionView.swift
//  FitCheckAI
//

import SwiftUI

struct PurposeSelectionView: View {
    @EnvironmentObject private var flowViewModel: AppFlowViewModel

    private var purposeConfig: [(purpose: PhotoPurpose, icon: String, title: String, subtitle: String)] {
        [
            (.outfit, "tshirt.fill", "Outfit Check", "Style, fit & colors"),
            (.dating, "heart.fill", "Dating Profile", "Warmth & confidence"),
            (.social, "square.and.arrow.up", "Social Media", "Engagement & impact"),
            (.professional, "briefcase.fill", "Professional", "Clarity & presentation"),
            (.compare, "square.on.square", "Photo Battle", "Pick the strongest"),
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                if let image = flowViewModel.selectedImage {
                    imagePreviewCard(image)
                }
                purposesSection
            }
            .appScreenContent()
            .padding(.top, 20)
            .padding(.bottom, 32)
        }
        .background(AmbientGlowBackground())
        .navigationTitle("Choose Purpose")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Start Over") {
                    startOver()
                }
                .font(.subheadline)
                .foregroundStyle(AppColors.mutedText)
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("What's this photo for?")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
            Text("Choose how AI should judge this photo.")
                .font(.subheadline)
                .foregroundStyle(AppColors.mutedText)
        }
        .fadeSlideIn(delay: 0, offset: 8)
    }

    private func imagePreviewCard(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(maxHeight: 160)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .fadeSlideIn(delay: 0.06, offset: 10)
    }

    private var purposesSection: some View {
        VStack(spacing: 10) {
            ForEach(Array(purposeConfig.enumerated()), id: \.element.purpose.id) { index, config in
                purposeCard(
                    purpose: config.purpose,
                    icon: config.icon,
                    title: config.title,
                    subtitle: config.subtitle
                )
                .fadeSlideIn(delay: 0.1 + Double(index) * AppMotion.staggerDelay, offset: 8)
            }
        }
    }

    private func purposeCard(
        purpose: PhotoPurpose,
        icon: String,
        title: String,
        subtitle: String
    ) -> some View {
        Button {
            flowViewModel.selectedPurpose = purpose
            if purpose == .compare {
                flowViewModel.selectedImage = nil
                flowViewModel.selectedImageData = nil
                flowViewModel.compareImage = nil
                flowViewModel.compareImageData = nil
                flowViewModel.navigationPath.append(.compareCapture)
            } else {
                flowViewModel.navigationPath.append(.analyze)
            }
        } label: {
            GlowCard(padding: 16, cornerRadius: 24) {
                HStack(spacing: 14) {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(AppGradients.forPurpose(purpose).opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(title)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                            PurposeBadgeView(text: PurposeBadge.label(for: purpose))
                        }
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(AppColors.mutedText)
                        Text(PhotoPurposeTips.oneLineHint(for: purpose))
                            .font(.caption2)
                            .foregroundStyle(AppColors.mutedText.opacity(0.85))
                    }
                    Spacer()
                    if flowViewModel.selectedPurpose == purpose {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(AppColors.accent)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(AppColors.mutedText)
                    }
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(
                        flowViewModel.selectedPurpose == purpose ? AppColors.accent.opacity(0.5) : Color.clear,
                        lineWidth: 1.5
                    )
            )
        }
        .buttonStyle(CardTapButtonStyle())
    }

    private func startOver() {
        flowViewModel.resetFlow()
        flowViewModel.requestedTabIndex = 0
    }
}

#Preview {
    NavigationStack {
        PurposeSelectionView()
            .environmentObject(AppFlowViewModel())
    }
}
