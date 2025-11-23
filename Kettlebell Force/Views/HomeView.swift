//
//  HomeView.swift
//  Kettlebell Force
//
//  Created by Alexander Kvamme on 11/23/25.
//

import SwiftUI
import MetaWear

struct HomeView: View {
    @ObservedObject var dataStore = DataStore.shared
    @StateObject private var metaMotionManager = MetaMotionManager()
    @State private var showingSessionView = false
    @State private var selectedSession: SessionSummary?
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if dataStore.sessions.isEmpty {
                    Spacer()
                    emptyStateView
                    Spacer()
                } else {
                    List {
                        ForEach(dataStore.sessions.prefix(10)) { session in
                            SessionRow(session: session)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedSession = session
                                }
                        }
                        .onDelete(perform: deleteSessions)
                    }
                    .listStyle(.plain)
                }
                
                // Start New Session Button
                Button(action: {
                    showingSessionView = true
                }) {
                    Text("Start New Session")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("Kettlebell Force")
            .sheet(isPresented: $showingSessionView) {
                SessionView(metaMotionManager: metaMotionManager)
            }
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
    
    private func deleteSessions(at offsets: IndexSet) {
        for index in offsets {
            dataStore.deleteSession(dataStore.sessions[index])
        }
    }
}

#Preview {
    HomeView()
}

