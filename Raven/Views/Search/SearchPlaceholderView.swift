//
//  SearchPlaceholderView.swift
//  Raven
//
//  Created by Ahsan Minhas on 29/05/2026.
//

import SwiftUI

struct SearchPlaceholderView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("Search", systemImage: "magnifyingglass")
            } description: {
                Text("Search your library once you add audiobooks.")
            }
            .navigationTitle("Search")
        }
    }
}

#Preview {
    SearchPlaceholderView()
}
