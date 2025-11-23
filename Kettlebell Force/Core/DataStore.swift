//
//  DataStore.swift
//  Kettlebell Force
//
//  Created by Alexander Kvamme on 11/23/25.
//

import Foundation
import Combine

final class DataStore: ObservableObject {
    @Published var userProfile: UserProfile
    @Published var sessions: [SessionSummary] = []
    
    private let userProfileURL: URL
    private let sessionsURL: URL
    
    static let shared = DataStore()
    
    private init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        userProfileURL = documentsPath.appendingPathComponent("userProfile.json")
        sessionsURL = documentsPath.appendingPathComponent("sessions.json")
        
        // Load user profile
        if let data = try? Data(contentsOf: userProfileURL),
           let profile = try? JSONDecoder().decode(UserProfile.self, from: data) {
            self.userProfile = profile
        } else {
            self.userProfile = UserProfile.default
            saveUserProfile()
        }
        
        // Load sessions
        if let data = try? Data(contentsOf: sessionsURL),
           let sessions = try? JSONDecoder().decode([SessionSummary].self, from: data) {
            self.sessions = sessions.sorted { $0.date > $1.date }
        }
    }
    
    func saveUserProfile() {
        if let data = try? JSONEncoder().encode(userProfile) {
            try? data.write(to: userProfileURL)
        }
    }
    
    func saveSession(_ session: SessionSummary) {
        sessions.append(session)
        sessions.sort { $0.date > $1.date }
        saveSessions()
    }
    
    func deleteSession(_ session: SessionSummary) {
        sessions.removeAll { $0.id == session.id }
        saveSessions()
    }
    
    private func saveSessions() {
        if let data = try? JSONEncoder().encode(sessions) {
            try? data.write(to: sessionsURL)
        }
    }
}

