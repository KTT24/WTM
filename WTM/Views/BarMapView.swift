//
//  BarMapView.swift
//  WTM
//
//  Created by Kutter Thornton on 2/6/26.
//

import Foundation
import SwiftUI
import MapKit
import Supabase

struct BarsMapView: View {
    
    @State private var bars: [Bars] = []
    @State private var cameraPosition: MapCameraPosition = .automatic
    
    @State private var selectedBar: Bars?
    
    // Starting region – feel free to change (example: Lubbock area)
    private let initialRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 33.5779, longitude: -101.8552),
        span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
    )
    
    
    
    var body: some View {
        NavigationStack {
            Map(position: $cameraPosition) {
                ForEach(bars) { bar in
                    if let pulse = pulseColor(for: bar) {
                        Annotation("", coordinate: CLLocationCoordinate2D(latitude: bar.latitude, longitude: bar.longitude)) {
                            PulsingHalo(color: pulse)
                        }
                        .annotationTitles(.hidden)
                    }

                    Annotation(bar.name, coordinate: CLLocationCoordinate2D(latitude: bar.latitude, longitude: bar.longitude)) {
                        Button {
                            selectedBar = bar
                        } label: {
                            Image(systemName: "mappin.circle.fill")
                                .font(.title2)
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(markerColor(for: bar), .white)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .mapStyle(.standard)
            .sheet(item: $selectedBar) { bar in
                BarDetailView(bar: bar)
                    .presentationDetents([.medium, .large])
                    .presentationCornerRadius(34)
                    .presentationDragIndicator(.hidden)
            }
            .task {
                await loadBars()
            }
            .overlay(alignment: .top) {
                if bars.isEmpty {
                    Text("Failed")
                        .padding(12)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .padding(.top, 44)
                }
            }
            .navigationTitle("Bars Nearby")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
        

    
    
    private func loadBars() async {
        do {
            let fetchedBars: [Bars] = try await supabase
                .from("bars")
                .execute()
                .value
            
            
            await MainActor.run {
                withAnimation {
                    self.bars = fetchedBars
                }
                
                // Optional: center map on first bar or keep automatic
                if !fetchedBars.isEmpty {
                    cameraPosition = .region(initialRegion)
                }
            }
        } catch {
            print("Error loading bars:", error.localizedDescription)
        }
    }
}

private func markerColor(for bar: Bars) -> Color {
    if bar.hype_score >= 7 {
        return .orange
    }
    if bar.hype_score >= 5 {
        return .blue
    }
    return .red
}

private func pulseColor(for bar: Bars) -> Color? {
    if bar.hype_score >= 7 {
        return .orange
    }
    if bar.hype_score >= 5 {
        return .blue
    }
    return nil
}

private struct PulsingHalo: View {
    let color: Color
    @State private var animate = false

    var body: some View {
        Circle()
            .fill(color.opacity(0.25))
            .frame(width: 34, height: 34)
            .scaleEffect(animate ? 1.6 : 0.8)
            .opacity(animate ? 0.0 : 1.0)
            .animation(.easeOut(duration: 1.4).repeatForever(autoreverses: false), value: animate)
            .onAppear { animate = true }
    }
}

// ────────────────────────────────────────────────
// 3. Preview
// ────────────────────────────────────────────────
#Preview {
    NavigationStack {
        BarsMapView()
    }
}
