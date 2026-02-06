//
//  BarDetailView.swift
//  WTM
//
//  Created by Kutter Thornton on 2/6/26.
//

import SwiftUI
import MapKit
import Supabase

struct BarDetailView: View {
    
    let bar: Bars
    
    @State private var currentPeopleCount: Int
    @State private var currentHypeScore: Int
    @State private var region: MKCoordinateRegion
    
    private let headerGradient: LinearGradient
    
    @State private var errorMessage: String?   // for showing update failures (optional)
    
    init(bar: Bars) {
        self.bar = bar
        
        // Safely unwrap optionals with sensible defaults
        self._currentPeopleCount = State(initialValue: bar.people_count ?? 0)
        self._currentHypeScore    = State(initialValue: bar.hype_score    ?? 5)
        
        // Map region – fallback if coordinate is nil
        let center = bar.coordinate ?? CLLocationCoordinate2D(latitude: 33.5779, longitude: -101.8552)
        self._region = State(initialValue: MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
        ))
        
        let palettes: [[Color]] = [
            [.blue.opacity(0.85), .purple.opacity(0.65)],
            [.mint.opacity(0.85), .blue.opacity(0.7)],
            [.orange.opacity(0.85), .pink.opacity(0.65)],
            [.indigo.opacity(0.85), .teal.opacity(0.65)],
            [.cyan.opacity(0.85), .purple.opacity(0.6)]
        ]
        let colors = palettes.randomElement() ?? [.blue.opacity(0.85), .purple.opacity(0.65)]
        self.headerGradient = LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(bar.name)
                        .font(.largeTitle.bold())
                        .foregroundStyle(headerGradient)
                    
                    HStack {
                        Text("Hype: \(currentHypeScore)/10")
                            .font(.title3.bold())
                            .foregroundStyle(.primary)
                        
                        Spacer()
                        
                        Text("\(currentPeopleCount) people here")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }.padding(10)
                
                
                // Check-in / Check-out buttons
                HStack(spacing: 12) {
                    Button {
                        Task { await updateCounts(delta: 1) }
                    } label: {
                        Label("I'm here rn", systemImage: "person.fill.checkmark")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.blue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    Button {
                        Task { await updateCounts(delta: -1) }
                    } label: {
                        Label("I just left", systemImage: "person.fill.xmark")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.red)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }.padding(10)
                
                let desc = bar.description
                // Description
                if !desc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("About")
                            .font(.headline)
                        Text(desc)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }
                let addr = bar.address
                // Address
                if !addr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Address")
                            .font(.headline)
                        Text(addr)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                
                
                
                // Optional error message
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.top, 8)
                }
            }
            .padding()
        }
        .navigationTitle(bar.name)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var hypeColor: Color {
        switch currentHypeScore {
        case 8...10: return .yellow
        case 5..<8:  return .blue
        default:     return .gray
        }
    }
    
    // Updates both people_count and hype_score in Supabase
    private func updateCounts(delta: Int) async {
        let barId = bar.id
        
        do {
            let newPeople = max(0, currentPeopleCount + delta)
            
            // Simple hype formula — feel free to change this logic
            // Example: hype = min(10, people / 4)   → every 4 people = +1 hype
            let newHype = min(10, newPeople / 4)
            
            try await supabase
                .from("bars")
                .update([
                    "people_count": newPeople,
                    "hype_score":   newHype
                ])
                .eq("id", value: barId)           // ← change "id" if your PK column has different name
                .execute()
            
            await MainActor.run {
                currentPeopleCount = newPeople
                currentHypeScore   = newHype
                errorMessage       = nil
            }
            
            print("Success → People: \(newPeople), Hype: \(newHype)")
        } catch {
            print("Update failed:", error.localizedDescription)
            await MainActor.run {
                errorMessage = "Failed to update: \(error.localizedDescription)"
            }
        }
    }
}
