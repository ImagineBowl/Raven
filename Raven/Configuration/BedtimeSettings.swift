//
//  BedtimeSettings.swift
//  Raven
//
//  Created by Ahsan Minhas on 28/05/2026.
//

import Foundation

enum BedtimeSettings {
    static let defaultMinutes = 20
    static let storageKey = "bedtimeMinutes"

    static var minutes: Int {
        get {
            let stored = UserDefaults.standard.integer(forKey: storageKey)
            return stored > 0 ? stored : defaultMinutes
        }
        set {
            UserDefaults.standard.set(max(1, min(newValue, 480)), forKey: storageKey)
        }
    }
}
