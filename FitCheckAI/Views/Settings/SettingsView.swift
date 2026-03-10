//
//  SettingsView.swift
//  FitCheckAI
//

import SwiftUI
import StoreKit

struct SettingsView: View {
    @EnvironmentObject private var historyViewModel: HistoryViewModel
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Environment(\.openURL) private var openURL
    @State private var showClearConfirmation = false
    @State private var showCleared = false
    @State private var showPaywall = false
    #if DEBUG
    @AppStorage("fitcheck_debug_results_enabled") private var debugResultsEnabled: Bool = false
    #endif

    private var appVersion: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                headerSection
                appSection
                proSection
                dataSection
                legalSection
                aboutSection
                #if DEBUG
                debugSection
                #endif
                Spacer(minLength: 40)
            }
            .appScreenContent()
            .padding(.top, 20)
            .padding(.bottom, 32)
        }
        .background(AmbientGlowBackground())
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .environmentObject(subscriptionManager)
        }
        .alert("Clear History?", isPresented: $showClearConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                historyViewModel.clearAll()
                showCleared = true
            }
        } message: {
            Text("All analysis history will be removed. This cannot be undone.")
        }
        .alert("History Cleared", isPresented: $showCleared) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your history has been cleared.")
        }
    }

    // MARK: - Header (consistent with Analyze / Results)

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Settings")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
            Text("App and data preferences.")
                .font(.subheadline)
                .foregroundStyle(AppColors.mutedText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 8)
    }

    // MARK: - App

    private var appSection: some View {
        SettingsSectionCard(title: "App") {
            HStack(alignment: .top, spacing: 16) {
                BrandMarkView(size: 44, lineWidth: 3, showGlow: false)
                VStack(alignment: .leading, spacing: 6) {
                    Text(AppBrand.appDisplayName)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(AppBrand.appTagline)
                        .font(.subheadline)
                        .foregroundStyle(AppColors.mutedText)
                    Text("Version \(appVersion)")
                        .font(.caption)
                        .foregroundStyle(AppColors.mutedText.opacity(0.8))
                }
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - Data

    private var dataSection: some View {
        SettingsSectionCard(title: "Data") {
            VStack(alignment: .leading, spacing: 14) {
                Text("Your past ratings are stored on this device. Clear them anytime.")
                    .font(.caption)
                    .foregroundStyle(AppColors.mutedText)
                Button {
                    showClearConfirmation = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "trash")
                            .font(.subheadline)
                        Text("Clear History")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(AppColors.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                }
                .buttonStyle(PlainPressableStyle())
            }
        }
    }

    // MARK: - Pro

    private var proSection: some View {
        SettingsSectionCard(title: "Pro") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: "star.circle.fill")
                        .font(.title2)
                        .foregroundStyle(AppColors.accent)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("FitCheckAI Pro")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("Unlock unlimited analyses")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.mutedText)
                    }
                    Spacer()
                    Text(subscriptionManager.isSubscribed ? "Active" : "Not Subscribed")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(subscriptionManager.isSubscribed ? AppColors.scoreHigh : AppColors.mutedText)
                }

                if !subscriptionManager.isSubscribed {
                    Button {
                        showPaywall = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .font(.caption)
                            Text("Upgrade to Pro")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(AppColors.accent)
                        )
                    }
                    .buttonStyle(PlainPressableStyle())
                }

                HStack(spacing: 16) {
                    Button {
                        Task {
                            try? await AppStore.sync()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                                .font(.caption)
                            Text("Restore Purchases")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(AppColors.accent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(PlainPressableStyle())

                    Button {
                        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                            openURL(url)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "person.crop.circle.badge.checkmark")
                                .font(.caption)
                            Text("Manage Subscription")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(AppColors.mutedText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(PlainPressableStyle())
                }
            }
        }
    }

    // MARK: - Legal

    private var legalSection: some View {
        SettingsSectionCard(title: "Legal") {
            VStack(alignment: .leading, spacing: 0) {
                settingsLinkRow(
                    title: "Privacy Policy",
                    urlString: "https://drumzkick-netizen.github.io/FitCheckAI/privacy.html"
                )
                Divider()
                    .background(Color.white.opacity(0.08))
                    .padding(.vertical, 6)
                settingsLinkRow(
                    title: "Terms of Use",
                    urlString: "https://drumzkick-netizen.github.io/FitCheckAI/terms.html"
                )
            }
        }
    }

    private func settingsLinkRow(title: String, urlString: String) -> some View {
        let url = URL(string: urlString) ?? URL(string: "https://drumzkick-netizen.github.io/FitCheckAI")!
        return Button {
            openURL(url)
        } label: {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundStyle(AppColors.mutedText)
            }
            .padding(.vertical, 2)
        }
        .buttonStyle(PlainPressableStyle())
    }

    // MARK: - About

    private var aboutSection: some View {
        SettingsSectionCard(title: "About") {
            VStack(alignment: .leading, spacing: 8) {
                Text("FitCheckAI analyzes outfit photos and provides AI-powered style feedback so you can improve your look before posting or heading out.")
                    .font(.caption)
                    .foregroundStyle(AppColors.mutedText.opacity(0.85))
            }
        }
    }

    // MARK: - Debug (DEBUG builds only)

    #if DEBUG
    private var debugSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Developer")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(AppColors.mutedText.opacity(0.9))
            VStack(alignment: .leading, spacing: 6) {
                Text("Environment: \(AppConfig.currentEnvironment.rawValue)")
                    .font(.caption2)
                    .foregroundStyle(AppColors.mutedText.opacity(0.8))
                Text("Backend: \(AppConfig.backendBaseURL)")
                    .font(.caption2)
                    .foregroundStyle(AppColors.mutedText.opacity(0.8))
                    .lineLimit(2)
                Text("On a physical device, set DevBackendHost in Info.plist to your Mac's LAN IP for local backend.")
                    .font(.caption2)
                    .foregroundStyle(AppColors.mutedText.opacity(0.6))
                    .lineLimit(3)
                Toggle(isOn: $debugResultsEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Show Results Debug Panel")
                            .font(.caption2)
                            .fontWeight(.semibold)
                        Text("Internal only. Shows analysis facts and counts on the results screen.")
                            .font(.caption2)
                            .foregroundStyle(AppColors.mutedText.opacity(0.7))
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: AppColors.accent))
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    #endif
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(HistoryViewModel())
    }
}
