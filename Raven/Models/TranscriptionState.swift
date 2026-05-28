//
//  TranscriptionState.swift
//  Raven
//
//  Created by Ahsan Minhas on 28/05/2026.
//

import Foundation

enum TranscriptionState: String, Codable {
    case none
    case processing
    case completed
    case failed
}
