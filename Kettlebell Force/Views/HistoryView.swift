//
//  HistoryView.swift
//  Kettlebell Force
//
//  Created by Alexander Kvamme on 11/23/25.
//

import SwiftUI

struct HistoryView: View {
    @ObservedObject var dataStore = DataStore.shared
    @State private var selectedSession: SessionSummary?
    
    var body: some View {
        NavigationView {
            Group {
                if dataStore.sessions.isEmpty {
                    emptyStateView
                } else {
                    sessionListView
                }
            }
            .navigationTitle("History")
            .sheet(item: $selectedSession) { session in
                SessionDetailView(session: session)
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            Text("No Sessions Yet")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Start a session to see your training history here")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
    
    private var sessionListView: some View {
        List {
            ForEach(dataStore.sessions) { session in
                SessionRow(session: session)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedSession = session
                    }
            }
            .onDelete(perform: deleteSessions)
        }
    }
    
    private func deleteSessions(at offsets: IndexSet) {
        for index in offsets {
            dataStore.deleteSession(dataStore.sessions[index])
        }
    }
}

struct SessionRow: View {
    let session: SessionSummary
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(session.exerciseType.capitalized)
                    .font(.headline)
                Spacer()
                Text(dateFormatter.string(from: session.date))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 16) {
                Label("\(session.kettlebellMassKg, specifier: "%.1f") kg", systemImage: "scalemass")
                Label("\(session.reps.count) reps", systemImage: "repeat")
                Label("\(session.sessionPeakForceNorm, specifier: "%.2f")x BW", systemImage: "arrow.up")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    HistoryView()
}

