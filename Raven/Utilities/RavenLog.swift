//
//  RavenLog.swift
//  Raven
//
//  Created by Ahsan Minhas on 19/06/2026.
//

import os

enum RavenLog {
    static let modelStorage = Logger(subsystem: "com.Imaginebowl.Raven", category: "ModelStorage")
    static let playback = Logger(subsystem: "com.Imaginebowl.Raven", category: "Playback")
}
