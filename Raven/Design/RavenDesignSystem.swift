//
//  RavenDesignSystem.swift
//  Raven
//
//  Created by Ahsan Minhas on 29/05/2026.
//

import SwiftUI

/// Stitch design tokens mapped to SwiftUI.
enum RavenDesign {
    enum Colors {
        static let paper = Color("LaunchBackground")
        static let primary = Color(red: 0.016, green: 0.086, blue: 0.180)
        static let onPrimary = Color.white
        static let onSurfaceVariant = Color(red: 0.267, green: 0.278, blue: 0.302)
        static let outlineVariant = Color(red: 0.773, green: 0.776, blue: 0.808)
        static let surfaceContainerHighest = Color(red: 0.890, green: 0.886, blue: 0.898)
        static let surfaceLowest = Color.white
        static let surfaceContainer = Color(red: 0.937, green: 0.929, blue: 0.941)
        static let secondaryContainer = Color(red: 0.902, green: 0.886, blue: 0.863)
        static let primaryContainer = Color(red: 0.102, green: 0.169, blue: 0.267)
        static let playerSurface = Color(red: 0.200, green: 0.200, blue: 0.220)
        static let primaryFixedDim = Color(red: 0.714, green: 0.780, blue: 0.906)
    }

    enum Typography {
        static func displayLarge() -> Font {
            .system(size: 34, weight: .bold, design: .serif)
        }

        static func headlineMedium() -> Font {
            .system(size: 22, weight: .semibold, design: .default)
        }

        static func bodyUI() -> Font {
            .system(size: 17, weight: .regular, design: .default)
        }

        static func bodyReading() -> Font {
            .system(size: 20, weight: .regular, design: .serif)
        }

        static func transcriptActive() -> Font {
            .system(size: 24, weight: .medium, design: .serif)
        }

        static func labelCaps() -> Font {
            .system(size: 12, weight: .semibold, design: .default)
        }
    }

    enum Spacing {
        static let pageMargin: CGFloat = 20
        static let stackLarge: CGFloat = 32
        static let stackMedium: CGFloat = 16
        static let stackSmall: CGFloat = 8
    }

    enum BookCover {
        static let featuredSize: CGFloat = 96
        static let compactSize: CGFloat = 64
    }
}

struct RavenPrimaryButton: View {
    let title: String
    let systemImage: String
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 20))
                Text(title)
                    .fontWeight(.semibold)
            }
            .font(RavenDesign.Typography.bodyUI())
            .foregroundStyle(RavenDesign.Colors.onPrimary)
            .padding(.horizontal, 40)
            .padding(.vertical, 16)
            .background(RavenDesign.Colors.primary, in: Capsule())
            .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
        }
        .buttonStyle(RavenPressButtonStyle())
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.6 : 1)
    }
}

struct RavenPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct LibraryScreenHeader: View {
    var onAddFolder: (() -> Void)?
    var isAddDisabled = false

    var body: some View {
        HStack(alignment: .bottom) {
            Text("Library")
                .font(RavenDesign.Typography.displayLarge())
                .foregroundStyle(RavenDesign.Colors.primary)
            Spacer()
            if let onAddFolder {
                Button(action: onAddFolder) {
                    Image(systemName: "folder.badge.plus")
                        .font(.title3)
                        .foregroundStyle(RavenDesign.Colors.primary)
                }
                .disabled(isAddDisabled)
                .opacity(isAddDisabled ? 0.5 : 1)
            }
        }
        .padding(.horizontal, RavenDesign.Spacing.pageMargin)
        .padding(.bottom, RavenDesign.Spacing.stackMedium)
        .padding(.top, 4)
        .frame(maxWidth: .infinity)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(alignment: .bottom) {
                    RavenDesign.Colors.outlineVariant.opacity(0.2)
                        .frame(height: 1)
                }
        }
    }
}

struct RavenProgressBar: View {
    let progress: Double
    var height: CGFloat = 4

    var body: some View {
        GeometryReader { geometry in
            Capsule()
                .fill(RavenDesign.Colors.surfaceContainerHighest)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(RavenDesign.Colors.primary)
                        .frame(width: geometry.size.width * min(max(progress, 0), 1))
                }
        }
        .frame(height: height)
    }
}

struct RavenLibraryCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(RavenDesign.Spacing.pageMargin)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(RavenDesign.Colors.surfaceLowest)
                    .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
