//
//  RavenLogoView.swift
//  Raven
//
//  Created by Ahsan Minhas on 28/05/2026.
//

import SwiftUI

struct RavenLogoView: View {
    var size: CGFloat = 120
    var cornerRadius: CGFloat?

    var body: some View {
        Image("RavenLogo")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: cornerRadius ?? size * 0.22,
                    style: .continuous
                )
            )
    }
}

#Preview {
    RavenLogoView(size: 200)
        .padding()
}
