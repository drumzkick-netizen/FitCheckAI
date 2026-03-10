//
//  PaywallView.swift
//  FitCheckAI
//

import StoreKit
import SwiftUI

struct PaywallView: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var selectedProductID: String?

    private var products: [Product] {
        subscriptionManager.products
    }

    private var selectedProduct: Product? {
        if let id = selectedProductID {
            return products.first(where: { $0.id == id })
        }
        return products.first
    }

    /// Match the primary gradient used elsewhere in the app.
    private var primaryGradient: LinearGradient {
        LinearGradient(
            colors: [AppColors.accent, AppColors.accentSecondary],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    var body: some View {
        VStack(spacing: 24) {
            headerSection
            blurredPreviewSection
            benefitsSection
            plansSection
            primaryButton
            footerLinks
        }
        .padding(.horizontal, 24)
        .padding(.top, 32)
        .padding(.bottom, 32)
        .background(AppBackground())
        .preferredColorScheme(.dark)
        .task {
            await subscriptionManager.refresh()
            if selectedProductID == nil {
                selectedProductID = products.first?.id
            }
        }
        .alert("Purchase Error", isPresented: Binding(get: {
            subscriptionManager.errorMessage != nil
        }, set: { newValue in
            if !newValue {
                subscriptionManager.errorMessage = nil
            }
        })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(subscriptionManager.errorMessage ?? "Something went wrong. Please try again.")
        }
        .onChange(of: subscriptionManager.isSubscribed) { _, newValue in
            if newValue {
                dismiss()
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("Unlock Your Full Style Score")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
            Text("See how to improve every outfit instantly.")
                .font(.subheadline)
                .foregroundStyle(AppColors.mutedText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Blurred preview

    private var blurredPreviewSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Locked Suggestions Preview")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(AppColors.mutedText)
            ZStack {
                VStack(alignment: .leading, spacing: 8) {
                    previewRow(text: "Tuck the white tee slightly into the waistband to show more shape.")
                    previewRow(text: "Swap the bulky sneakers for a slimmer profile to clean up the silhouette.")
                    previewRow(text: "Add a simple belt to define your waist and balance the top and bottom.")
                }
                .blur(radius: 8)
                .overlay(
                    LinearGradient(
                        colors: [Color.black.opacity(0.0), Color.black.opacity(0.5)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                )
                VStack {
                    Spacer()
                    Text("Unlock detailed improvement suggestions with FitCheckAI Pro.")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.55))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.bottom, 10)
                }
            }
            .padding(14)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .frame(maxWidth: .infinity)
    }

    private func previewRow(text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lightbulb")
                .font(.footnote)
                .foregroundStyle(AppColors.accent)
            Text(text)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.9))
        }
    }

    // MARK: - Benefits

    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(benefits, id: \.self) { benefit in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(AppColors.accent)
                    Text(benefit)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.95))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var benefits: [String] {
        [
            "Unlimited outfit analyses",
            "Advanced improvement suggestions",
            "Beat Your Score challenges",
            "Faster AI processing"
        ]
    }

    // MARK: - Plans

    private var plansSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(products, id: \.id) { product in
                planCard(for: product)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func planCard(for product: Product) -> some View {
        let isSelected = product.id == selectedProductID
        let isBestValue = product.id == "fitcheckai.pro.yearly"
        return Button {
            selectedProductID = product.id
        } label: {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(planTitle(for: product))
                            .font(.headline)
                            .foregroundStyle(.white)
                        if isBestValue {
                            Text("Best Value")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppColors.accent.opacity(0.25))
                                .foregroundStyle(AppColors.accent)
                                .clipShape(Capsule())
                        }
                    }
                    Text(pricePerPeriod(for: product))
                        .font(.caption)
                        .foregroundStyle(AppColors.mutedText)
                }
                Spacer()
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? AppColors.accent : AppColors.mutedText)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(isSelected ? 0.10 : 0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? AppColors.accent : Color.white.opacity(0.10), lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(PlainPressableStyle())
    }

    private func planTitle(for product: Product) -> String {
        switch product.id {
        case "fitcheckai.pro.weekly":
            return "Weekly"
        case "fitcheckai.pro.monthly":
            return "Monthly"
        case "fitcheckai.pro.yearly":
            return "Yearly"
        default:
            return product.displayName
        }
    }

    private func pricePerPeriod(for product: Product) -> String {
        let price = product.displayPrice
        if let subscription = product.subscription {
            let period = subscription.subscriptionPeriod
            let unitLabel: String
            switch period.unit {
            case .day:
                unitLabel = period.value == 1 ? "day" : "\(period.value) days"
            case .week:
                unitLabel = period.value == 1 ? "week" : "\(period.value) weeks"
            case .month:
                unitLabel = period.value == 1 ? "month" : "\(period.value) months"
            case .year:
                unitLabel = period.value == 1 ? "year" : "\(period.value) years"
            @unknown default:
                unitLabel = "period"
            }
            return "\(price)/\(unitLabel)"
        }
        return price
    }

    // MARK: - Primary CTA

    private var primaryButton: some View {
        VStack(spacing: 6) {
            Button {
                guard let product = selectedProduct else { return }
                Task {
                    _ = await subscriptionManager.purchase(product)
                }
            } label: {
                Text("Start 3-Day Free Trial")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(primaryGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(PlainPressableStyle())
            .disabled(subscriptionManager.isLoading || selectedProduct == nil)
            .opacity(subscriptionManager.isLoading ? 0.7 : 1)

            if let product = trialPricingProduct {
                Text(trialPriceLine(for: product))
                    .font(.caption)
                    .foregroundStyle(AppColors.mutedText)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    /// Prefer the monthly product for the post-trial price line; fall back to selected product.
    private var trialPricingProduct: Product? {
        if let monthly = products.first(where: { $0.id == "fitcheckai.pro.monthly" }) {
            return monthly
        }
        return selectedProduct
    }

    private func trialPriceLine(for product: Product) -> String {
        let priceText = pricePerPeriod(for: product)
        return "\(priceText) after trial"
    }

    // MARK: - Footer links

    private var footerLinks: some View {
        VStack(spacing: 8) {
            Button {
                Task {
                    await subscriptionManager.restore()
                }
            } label: {
                Text("Restore Purchases")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(AppColors.mutedText)
            }
            .buttonStyle(.plain)

            HStack(spacing: 16) {
                Button {
                    if let url = URL(string: "https://drumzkick-netizen.github.io/FitCheckAI/terms.html") {
                        openURL(url)
                    }
                } label: {
                    Text("Terms of Use")
                        .font(.caption)
                        .foregroundStyle(AppColors.mutedText.opacity(0.9))
                }
                .buttonStyle(.plain)

                Button {
                    if let url = URL(string: "https://drumzkick-netizen.github.io/FitCheckAI/privacy.html") {
                        openURL(url)
                    }
                } label: {
                    Text("Privacy Policy")
                        .font(.caption)
                        .foregroundStyle(AppColors.mutedText.opacity(0.9))
                }
                .buttonStyle(.plain)
            }
            Text("3-day free trial, then auto-renews until cancelled. Manage your subscription anytime in iPhone Settings.")
                .font(.caption2)
                .foregroundStyle(AppColors.mutedText.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
    }
}


