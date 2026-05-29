//
//  LaunchScreenView.swift
//  Raven
//
//  Created by Ahsan Minhas on 28/05/2026.
//

import SwiftUI

struct LaunchScreenView: View {
    @Binding var isPresented: Bool

    /// Stitch spec: 120 pt logo; starts scaled down for the zoom-in animation.
    private static let logoSize: CGFloat = 120
    private static let logoCornerRadius: CGFloat = 28
    private static let initialLogoScale: CGFloat = 77 / logoSize
    private static let zoomSpring = Animation.spring(response: 0.75, dampingFraction: 0.72)
    private static let holdAtFullZoom: Duration = .milliseconds(300)
    private static let exitFadeDuration: Duration = .milliseconds(350)
    private static let exitAnimation = Animation.easeInOut(duration: 0.35)
    private static let footerFade = Animation.easeOut(duration: 1.2)

    @State private var logoScale = initialLogoScale
    @State private var contentOpacity = 1.0
    @State private var footerOpacity: CGFloat = 0
    @State private var footerOffset: CGFloat = 10
    @State private var floatOffset: CGFloat = 0

    var body: some View {
        Color("LaunchBackground")
            .ignoresSafeArea()
            .overlay {
                PaperGrainOverlay()
            }
            .overlay {
                logoMark
                    .scaleEffect(logoScale)
                    .offset(y: floatOffset)
            }
            .overlay(alignment: .bottom) {
                brandFooter
                    .padding(.bottom, 60)
            }
            .opacity(contentOpacity)
            .onAppear(perform: runLaunchSequence)
    }

    private var logoMark: some View {
        RavenLogoView(size: Self.logoSize, cornerRadius: Self.logoCornerRadius)
            .background {
                RoundedRectangle(cornerRadius: Self.logoCornerRadius, style: .continuous)
                    .fill(.white)
            }
            .clipShape(
                RoundedRectangle(cornerRadius: Self.logoCornerRadius, style: .continuous)
            )
            .shadow(color: .black.opacity(0.08), radius: 15, x: 0, y: 10)
    }

    private var brandFooter: some View {
        Text("Raven")
            .font(.subheadline)
            .tracking(3.4)
            .textCase(.uppercase)
            .foregroundStyle(Color.primary.opacity(0.8))
            .opacity(footerOpacity)
            .offset(y: footerOffset)
    }

    private func runLaunchSequence() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            withAnimation(Self.footerFade) {
                footerOpacity = 0.5
                footerOffset = 0
            }
        }

        withAnimation(Self.zoomSpring, completionCriteria: .removed) {
            logoScale = 1.0
        } completion: {
            Task { @MainActor in
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    floatOffset = -8
                }

                try? await Task.sleep(for: Self.holdAtFullZoom)

                withAnimation(Self.exitAnimation) {
                    contentOpacity = 0
                }
                try? await Task.sleep(for: Self.exitFadeDuration)
                isPresented = false
            }
        }
    }
}

private struct PaperGrainOverlay: View {
    var body: some View {
        Image("PaperGrain")
            .resizable(resizingMode: .tile)
            .opacity(0.03)
            .blendMode(.multiply)
            .ignoresSafeArea()
            .allowsHitTesting(false)
    }
}

#Preview {
    LaunchScreenView(isPresented: .constant(true))
}
