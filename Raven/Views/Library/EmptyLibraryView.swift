//
//  EmptyLibraryView.swift
//  Raven
//
//  Created by Ahsan Minhas on 29/05/2026.
//

import SwiftUI

struct EmptyLibraryView: View {
    var isAddDisabled: Bool
    var onAddFolder: () -> Void

    @State private var appeared = false

    var body: some View {
        ZStack {
            RavenDesign.Colors.paper
                .ignoresSafeArea()

            RavenLogoView(size: 320, cornerRadius: 70)
                .grayscale(1)
                .opacity(0.04)
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: RavenDesign.Spacing.stackLarge) {
                    Text("Your Library is Empty")
                        .font(RavenDesign.Typography.headlineMedium())
                        .foregroundStyle(RavenDesign.Colors.primary)

                    Text("Import your audiobooks from the Files app to get started.")
                        .font(RavenDesign.Typography.bodyUI())
                        .foregroundStyle(RavenDesign.Colors.onSurfaceVariant)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .frame(maxWidth: 280)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)

                RavenPrimaryButton(
                    title: "Add Folder",
                    systemImage: "folder",
                    isDisabled: isAddDisabled,
                    action: onAddFolder
                )
                .padding(.top, RavenDesign.Spacing.stackLarge)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)

                Spacer()
            }
            .padding(.horizontal, RavenDesign.Spacing.pageMargin)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.7)) {
                appeared = true
            }
        }
    }
}

#Preview {
    EmptyLibraryView(isAddDisabled: false, onAddFolder: {})
}
