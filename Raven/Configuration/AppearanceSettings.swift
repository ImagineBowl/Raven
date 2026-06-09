//
//  AppearanceSettings.swift
//  Raven
//
//  Created by Ahsan Minhas on 09/06/2026.
//

import SwiftUI

enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var systemImage: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max.fill"
        case .dark: "moon.fill"
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

enum AppearanceSettings {
    static let storageKey = "appAppearance"
    static let defaultAppearance: AppAppearance = .system

    static var appearance: AppAppearance {
        get {
            guard let raw = UserDefaults.standard.string(forKey: storageKey),
                  let appearance = AppAppearance(rawValue: raw) else {
                return defaultAppearance
            }
            return appearance
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: storageKey)
        }
    }
}
