//
//  ProgressThrottler.swift
//  Raven
//
//  Created by Ahsan Minhas on 28/05/2026.
//

import Foundation
import os

/// Coalesces high-frequency progress callbacks so UI updates stay smooth during heavy work.
final class ProgressThrottler: Sendable {
    private let minimumInterval: TimeInterval
    private let state: OSAllocatedUnfairLock<State>

    private struct State: Sendable {
        nonisolated init() {}
        var lastDelivered = Date.distantPast
        var lastMessage: String?
    }

    nonisolated init(minimumInterval: TimeInterval = 1.0) {
        self.minimumInterval = minimumInterval
        self.state = OSAllocatedUnfairLock(initialState: State())
    }

    nonisolated func report(_ message: String, deliver: @Sendable (String) -> Void) {
        let shouldDeliver = state.withLock { state -> Bool in
            let now = Date()
            let isNewMessage = message != state.lastMessage
            guard isNewMessage, now.timeIntervalSince(state.lastDelivered) >= minimumInterval else {
                return false
            }
            state.lastDelivered = now
            state.lastMessage = message
            return true
        }

        if shouldDeliver {
            deliver(message)
        }
    }

    nonisolated func flush(_ message: String, deliver: @Sendable (String) -> Void) {
        state.withLock { state in
            state.lastDelivered = Date()
            state.lastMessage = message
        }
        deliver(message)
    }
}
