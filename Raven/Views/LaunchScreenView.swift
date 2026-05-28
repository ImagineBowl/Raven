//
//  LaunchScreenView.swift
//  Raven
//
//  Created by Ahsan Minhas on 28/05/2026.
//

import SwiftUI

struct LaunchScreenView: View {
    @Binding var isPresented: Bool

    /// Keep in sync with `LaunchLogo` asset (logoSize × initialLogoScale = 77 pt).
    private static let initialLogoScale: CGFloat = 0.55
    private static let logoSize: CGFloat = 140
    private static let zoomSpring = Animation.spring(response: 0.75, dampingFraction: 0.72)
    private static let holdAtFullZoom: Duration = .milliseconds(300)
    private static let exitFadeDuration: Duration = .milliseconds(350)
    private static let exitAnimation = Animation.easeInOut(duration: 0.35)

    @State private var logoScale = initialLogoScale
    @State private var contentOpacity = 1.0

    var body: some View {
        Color("LaunchBackground")
            .ignoresSafeArea()
            .overlay {
                RavenLogoView(size: Self.logoSize)
                    .scaleEffect(logoScale)
            }
            .opacity(contentOpacity)
            .onAppear(perform: runLaunchSequence)
    }

    private func runLaunchSequence() {
        withAnimation(Self.zoomSpring, completionCriteria: .removed) {
            logoScale = 1.0
        } completion: {
            Task { @MainActor in
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

#Preview {
    LaunchScreenView(isPresented: .constant(true))
}
