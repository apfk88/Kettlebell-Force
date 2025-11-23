//
//  SessionDetailView.swift
//  Kettlebell Force
//
//  Created by Alexander Kvamme on 11/23/25.
//

import SwiftUI

struct SessionDetailView: View {
    let session: SessionSummary
    @Environment(\.dismiss) var dismiss
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter
    }
    
    private var durationFormatter: DateComponentsFormatter {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Session Summary
                    VStack(spacing: 16) {
                        Text(session.exerciseType.capitalized)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text(dateFormatter.string(from: session.date))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Divider()
                        
                        // Summary Metrics
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 16) {
                            SummaryMetric(
                                title: "Duration",
                                value: durationFormatter.string(from: session.durationSec) ?? "\(Int(session.durationSec))s"
                            )
                            SummaryMetric(
                                title: "Reps",
                                value: "\(session.reps.count)"
                            )
                            SummaryMetric(
                                title: "Peak Force",
                                value: String(format: "%.1f N", session.sessionPeakForceN)
                            )
                            SummaryMetric(
                                title: "Peak Force (norm)",
                                value: String(format: "%.2f x BW", session.sessionPeakForceNorm)
                            )
                            SummaryMetric(
                                title: "Impulse",
                                value: String(format: "%.1f N·s", session.sessionImpulseNs)
                            )
                            SummaryMetric(
                                title: "KB Mass",
                                value: String(format: "%.1f kg", session.kettlebellMassKg)
                            )
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Reps List
                    if !session.reps.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Reps")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ForEach(Array(session.reps.enumerated()), id: \.element.id) { index, rep in
                                RepRow(repNumber: index + 1, rep: rep)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Session Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct SummaryMetric: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.headline)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

struct RepRow: View {
    let repNumber: Int
    let rep: RepSummary
    
    var body: some View {
        HStack {
            Text("#\(repNumber)")
                .font(.headline)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Peak: \(String(format: "%.1f N", rep.peakForceN)) (\(String(format: "%.2f", rep.peakForceNorm))x BW)")
                Text("Impulse: \(String(format: "%.1f N·s", rep.impulseNs))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(String(format: "%.1fs", rep.endTime - rep.startTime))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

#Preview {
    SessionDetailView(session: SessionSummary(
        exerciseType: "swing",
        kettlebellMassKg: 24.0,
        bodyMassKg: 70.0,
        durationSec: 300,
        reps: [],
        sessionPeakForceN: 500,
        sessionPeakForceNorm: 0.73,
        sessionImpulseNs: 1500
    ))
}

