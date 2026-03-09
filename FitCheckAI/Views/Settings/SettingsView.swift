//
//  SettingsView.swift
//  FitCheckAI
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var historyViewModel: HistoryViewModel
    @State private var showClearConfirmation = false
    @State private var showCleared = false
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

    // MARK: - Legal

    private var legalSection: some View {
        SettingsSectionCard(title: "Legal") {
            VStack(alignment: .leading, spacing: 0) {
                settingsLinkRow(title: "Privacy Policy", urlString: "https://example.com/privacy")
                Divider()
                    .background(Color.white.opacity(0.08))
                    .padding(.vertical, 6)
                settingsLinkRow(title: "Terms of Use", urlString: "https://example.com/terms")
            }
        }
    }

    private func settingsLinkRow(title: String, urlString: String) -> some View {
        let url = URL(string: urlString) ?? URL(string: "https://example.com")!
        return Link(destination: url) {
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
    }

    // MARK: - About

    private var aboutSection: some View {
        SettingsSectionCard(title: "About") {
            VStack(alignment: .leading, spacing: 8) {
                Text(AppBrand.shortAboutText)
                    .font(.subheadline)
                    .foregroundStyle(AppColors.mutedText)
                Text("Get confident feedback before you post or send.")
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
