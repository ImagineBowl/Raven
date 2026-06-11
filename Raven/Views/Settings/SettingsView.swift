//
//  SettingsView.swift
//  Raven
//
//  Created by Ahsan Minhas on 28/05/2026.
//

import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AudioPlayerService.self) private var player

    @AppStorage(BedtimeSettings.storageKey) private var bedtimeMinutes = BedtimeSettings.defaultMinutes
    @AppStorage(AppearanceSettings.storageKey) private var appearanceRaw = AppAppearance.system.rawValue
    @State private var viewModel = LibraryViewModel()
    @State private var presentedPlayerBook: Book?
    @State private var showAbout = false
    @State private var showPrivacy = false

    private let durationPresets = [15, 30, 45, 60]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RavenDesign.Spacing.stackLarge) {
                bedtimeSection
                appearanceSection
                librarySection
                aboutSection
                versionFooter
            }
            .padding(.horizontal, RavenDesign.Spacing.pageMargin)
            .padding(.top, RavenDesign.Spacing.stackLarge)
            .padding(.bottom, player.currentBook == nil ? 32 : 96)
        }
        .scrollIndicators(.hidden)
        .background(RavenDesign.Colors.paper.ignoresSafeArea())
        .safeAreaInset(edge: .top, spacing: 0) {
            SettingsScreenHeader()
        }
        .safeAreaInset(edge: .bottom, spacing: 8) {
            if let book = player.currentBook {
                MiniPlayerBar(book: book) {
                    presentedPlayerBook = book
                }
                .padding(.bottom)
                .padding(.horizontal, RavenDesign.Spacing.pageMargin)
            }
        }
        .fullScreenCover(isPresented: playerCoverIsPresented) {
            if let presentedPlayerBook {
                PlayerView(book: presentedPlayerBook)
            }
        }
        .sheet(isPresented: $viewModel.showDocumentPicker) {
            FolderDocumentPicker(
                onPick: { url in
                    viewModel.showDocumentPicker = false
                    Task {
                        await viewModel.addFolderToLibrary(
                            url: url,
                            modelContext: modelContext,
                            player: player
                        )
                    }
                },
                onCancel: {
                    viewModel.showDocumentPicker = false
                }
            )
        }
        .overlay {
            if viewModel.isImporting {
                ProgressView("Adding to library…")
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .alert("Library Error", isPresented: .init(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .sheet(isPresented: $showAbout) {
            SettingsInfoSheet(
                title: "About Raven",
                message: "Raven is a local-first audiobook player. Import folders of audio, listen with transcripts, and keep everything on your device."
            )
        }
        .sheet(isPresented: $showPrivacy) {
            SettingsInfoSheet(
                title: "Privacy Policy",
                message: "Raven does not collect account data or upload your library. Audiobooks, playback progress, and transcripts stay on this device."
            )
        }
    }

    private var bedtimeSection: some View {
        VStack(alignment: .leading, spacing: RavenDesign.Spacing.stackSmall) {
            RavenLibraryCard {
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        SettingsIconBadge(systemImage: "moon.fill", color: Color(red: 0.345, green: 0.337, blue: 0.839))
                        Text("Bedtime Mode")
                            .font(RavenDesign.Typography.bodyUI().weight(.medium))
                            .foregroundStyle(RavenDesign.Colors.onSurface)
                        Spacer()
                        Toggle("", isOn: bedtimeModeBinding)
                            .labelsHidden()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)

                    RavenDesign.Colors.outlineVariant.opacity(0.2)
                        .frame(height: 1)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Timer Duration")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(RavenDesign.Colors.onSurfaceVariant)
                            .textCase(.uppercase)
                            .tracking(0.8)

                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4),
                            spacing: 8
                        ) {
                            ForEach(durationPresets, id: \.self) { minutes in
                                durationButton(minutes: minutes)
                            }
                        }
                    }
                    .padding(16)
                }
            }

            Text("Playback will automatically fade out and pause after the selected duration.")
                .font(.system(size: 13))
                .foregroundStyle(RavenDesign.Colors.onSurfaceVariant.opacity(0.8))
                .padding(.horizontal, 4)
        }
    }

    private var selectedAppearance: AppAppearance {
        AppAppearance(rawValue: appearanceRaw) ?? AppearanceSettings.defaultAppearance
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: RavenDesign.Spacing.stackSmall) {
            RavenLibraryCard {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        SettingsIconBadge(
                            systemImage: "paintpalette.fill",
                            color: Color(red: 0.196, green: 0.843, blue: 0.294)
                        )
                        Text("Appearance")
                            .font(RavenDesign.Typography.bodyUI().weight(.medium))
                            .foregroundStyle(RavenDesign.Colors.onSurface)
                        Spacer()
                    }

                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3),
                        spacing: 8
                    ) {
                        ForEach(AppAppearance.allCases) { appearance in
                            appearanceButton(appearance)
                        }
                    }
                }
                .padding(16)
            }

            Text("Choose Light or Dark, or match your iPhone’s system setting.")
                .font(.system(size: 13))
                .foregroundStyle(RavenDesign.Colors.onSurfaceVariant.opacity(0.8))
                .padding(.horizontal, 4)
        }
    }

    private var librarySection: some View {
        RavenLibraryCard {
            SettingsNavigationRow(
                title: "Import Folders",
                systemImage: "folder",
                iconColor: Color(red: 0, green: 0.478, blue: 1),
                action: { viewModel.showDocumentPicker = true }
            )
        }
    }

    private var aboutSection: some View {
        RavenLibraryCard {
            VStack(spacing: 0) {
                SettingsNavigationRow(
                    title: "About Raven",
                    systemImage: "text.book.closed.fill",
                    iconColor: RavenDesign.Colors.primary,
                    action: { showAbout = true }
                )

                RavenDesign.Colors.outlineVariant.opacity(0.2)
                    .frame(height: 1)
                    .padding(.leading, 56)

                SettingsNavigationRow(
                    title: "Privacy Policy",
                    systemImage: "lock.fill",
                    iconColor: Color(red: 1, green: 0.584, blue: 0),
                    action: { showPrivacy = true }
                )
            }
        }
    }

    private var versionFooter: some View {
        VStack(spacing: 4) {
            Text("Raven")
                .font(.system(size: 13, weight: .medium))
                .tracking(2)
                .textCase(.uppercase)
            Text("Version \(appVersion)")
                .font(.system(size: 11))
        }
        .foregroundStyle(RavenDesign.Colors.onSurfaceVariant)
        .opacity(0.4)
        .frame(maxWidth: .infinity)
        .padding(.top, RavenDesign.Spacing.stackMedium)
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    private var playerCoverIsPresented: Binding<Bool> {
        Binding(
            get: { presentedPlayerBook != nil },
            set: { isPresented in
                if !isPresented {
                    presentedPlayerBook = nil
                }
            }
        )
    }

    private var bedtimeModeBinding: Binding<Bool> {
        Binding(
            get: { player.isBedtimeModeEnabled },
            set: { player.setBedtimeMode(enabled: $0) }
        )
    }

    private var highlightedDuration: Int {
        if durationPresets.contains(bedtimeMinutes) {
            return bedtimeMinutes
        }
        return durationPresets.min(by: {
            abs($0 - bedtimeMinutes) < abs($1 - bedtimeMinutes)
        }) ?? 30
    }

    private func appearanceButton(_ appearance: AppAppearance) -> some View {
        let isSelected = selectedAppearance == appearance

        return Button {
            appearanceRaw = appearance.rawValue
        } label: {
            VStack(spacing: 6) {
                Image(systemName: appearance.systemImage)
                    .font(.system(size: 16, weight: .semibold))
                Text(appearance.title)
                    .font(RavenDesign.Typography.bodyUI().weight(.medium))
            }
            .foregroundStyle(isSelected ? RavenDesign.Colors.onPrimary : RavenDesign.Colors.onSurface)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                isSelected ? RavenDesign.Colors.primary : RavenDesign.Colors.surfaceContainerHighest,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
        }
        .buttonStyle(RavenPressButtonStyle())
    }

    private func durationButton(minutes: Int) -> some View {
        let isSelected = highlightedDuration == minutes

        return Button {
            bedtimeMinutes = minutes
            BedtimeSettings.minutes = minutes
            if player.isBedtimeModeEnabled {
                player.setBedtimeMode(enabled: true)
            }
        } label: {
            Text("\(minutes)m")
                .font(RavenDesign.Typography.bodyUI().weight(.medium))
                .foregroundStyle(isSelected ? RavenDesign.Colors.onPrimary : RavenDesign.Colors.onSurface)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    isSelected ? RavenDesign.Colors.primary : RavenDesign.Colors.surfaceContainerHighest,
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
        }
        .buttonStyle(RavenPressButtonStyle())
    }
}

struct SettingsScreenHeader: View {
    var body: some View {
        Text("Settings")
            .font(RavenDesign.Typography.displayLarge())
            .foregroundStyle(RavenDesign.Colors.onSurface)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, RavenDesign.Spacing.pageMargin)
            .padding(.bottom, RavenDesign.Spacing.stackMedium)
            .padding(.top, 4)
            .background {
                Rectangle()
                    .fill(RavenDesign.Colors.paper)
                    .ignoresSafeArea(edges: .top)
                    .overlay(alignment: .bottom) {
                        RavenDesign.Colors.outlineVariant.opacity(0.2)
                            .frame(height: 1)
                    }
            }
    }
}

private struct SettingsIconBadge: View {
    let systemImage: String
    let color: Color

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 18))
            .foregroundStyle(.white)
            .frame(width: 32, height: 32)
            .background(color, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct SettingsNavigationRow: View {
    let title: String
    let systemImage: String
    let iconColor: Color
    var trailingText: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                SettingsIconBadge(systemImage: systemImage, color: iconColor)
                Text(title)
                    .font(RavenDesign.Typography.bodyUI().weight(.medium))
                    .foregroundStyle(RavenDesign.Colors.onSurface)
                Spacer()
                if let trailingText {
                    Text(trailingText)
                        .font(.system(size: 15))
                        .foregroundStyle(RavenDesign.Colors.onSurfaceVariant.opacity(0.6))
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(RavenDesign.Colors.onSurfaceVariant.opacity(0.4))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsInfoSheet: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let message: String

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(message)
                    .font(RavenDesign.Typography.bodyUI())
                    .foregroundStyle(RavenDesign.Colors.onSurfaceVariant)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(RavenDesign.Spacing.pageMargin)
            }
            .background(RavenDesign.Colors.paper)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    SettingsView()
        .environment(AudioPlayerService())
        .modelContainer(for: [Book.self, Chapter.self, TranscriptSegment.self], inMemory: true)
}
