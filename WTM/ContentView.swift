////
////  ContentView.swift
////  WTM
////
//
//import SwiftUI
//import SwiftData
//import MapKit
//import CoreLocation
//import Combine
//
//// Top of the file (outside any struct) — keep the class definition here
//final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
//    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
//    
//    private let manager = CLLocationManager()
//
//    override init() {
//        super.init()
//        authorizationStatus = manager.authorizationStatus
//        manager.delegate = self
//    }
//
//    func requestAuthorization() {
//        if manager.authorizationStatus == .notDetermined {
//            manager.requestWhenInUseAuthorization()
//        }
//        let status = manager.authorizationStatus
//        if status == .authorizedWhenInUse || status == .authorizedAlways {
//            manager.startUpdatingLocation()
//        }
//    }
//
//    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
//        DispatchQueue.main.async { [weak self] in
//            guard let self else { return }
//            self.authorizationStatus = manager.authorizationStatus
//            if self.authorizationStatus == .authorizedWhenInUse || self.authorizationStatus == .authorizedAlways {
//                self.manager.startUpdatingLocation()
//            }
//        }
//    }
//}
//
//
//struct ContentView: View {
//    
//    
//    @StateObject private var locationManager = LocationManager()
//    
//    @Environment(\.modelContext) private var modelContext
//    @Query private var visitedBars: [BarLocation]
//
//    @State private var hotspots: [BarHotspot] = []
//    @State private var realtimeTask: Task<Void, Never>?
//
//    
//    @State private var cameraPosition: MapCameraPosition = .region(
//        MKCoordinateRegion(
//            center: CLLocationCoordinate2D(latitude: 33.5779, longitude: -101.8552),
//            span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
//        )
//    )
//
//    @State private var selectedBar: BarHotspot?
//    @State private var showAccount = false
//
//    @AppStorage("debugModeEnabled") private var debugModeEnabled = false
//
//    #if DEBUG
//    @State private var showDebugTools = false
//    #endif
//
//    var body: some View {
//        NavigationStack {
//            ZStack(alignment: .bottomTrailing) {
//                Map(position: $cameraPosition) {
//                    ForEach(hotspots) { bar in
//                        Annotation(bar.name, coordinate: bar.coordinate) {
//                            let color: Color = bar.hypeScore >= 8 ? .red : bar.hypeScore >= 5 ? .blue : .gray
//                            PulsatingMarker(color: color)
//                        }
//                    }
//                }
//
//                if debugModeEnabled {
//                    Button {
//                        #if DEBUG
//                        showDebugTools = true
//                        #endif
//                    } label: {
//                        Image(systemName: "ladybug.fill")
//                            .font(.title2)
//                            .padding(16)
//                            .background(.ultraThinMaterial, in: Circle())
//                    }
//                    .padding()
//                }
//            }
//            .ignoresSafeArea()
//            .sheet(item: $selectedBar) { bar in
//                BarDetailView(bar: bar)
//                    .presentationDetents([.medium, .large])
//            }
//            .sheet(isPresented: $showAccount) {
//                AccountView()
//            }
//            #if DEBUG
//            .sheet(isPresented: $showDebugTools) {
//                DebugToolsView(hotspots: $hotspots)
//            }
//            #endif
//            .toolbar {
//                ToolbarItem(placement: .topBarTrailing) {
//                    Button {
//                        showAccount = true
//                    } label: {
//                        Image(systemName: "person.circle")
//                    }
//                }
//            }
//            .onAppear {
//                locationManager.requestAuthorization()
//
//                let provider = SupabaseBarProvider()
//                realtimeTask = Task {
//                    for await updated in provider.realtimeBarUpdates() {
//                        await MainActor.run {
//                            hotspots = updated
//                        }
//                    }
//                }
//
//                // Optional: seed once (uncomment if needed)
//                // Task {
//                //     try? await provider.seedFromLocalIfNeeded()
//                // }
//            }
//            .onDisappear {
//                realtimeTask?.cancel()
//            }
//        }
//    }
//}
//
//// PulsatingMarker (keep your original implementation)
//private struct PulsatingMarker: View {
//    let color: Color
//    
//    var body: some View {
//        ZStack {
//            Circle()
//                .fill(color.opacity(0.3))
//                .frame(width: 44, height: 44)
//                .scaleEffect(animate ? 1.6 : 0.9)
//                .opacity(animate ? 0 : 1)
//                .animation(.easeOut(duration: 1.5).repeatForever(autoreverses: false), value: animate)
//            
//            Image(systemName: "mappin.circle.fill")
//                .symbolRenderingMode(.palette)
//                .foregroundStyle(color, .white)
//                .font(.title2)
//                .shadow(radius: 2)
//        }
//        .onAppear { animate = true }
//    }
//    
//    @State private var animate = false
//}




import Supabase
import SwiftUI

struct ContentView: View {
  @State var bars: [Bars] = []

  var body: some View {
    NavigationStack {
        List(bars) { bars in
            Text(bars.name)
        }
      .navigationTitle("bar names")
      .task {
        do {
          bars = try await supabase.from("bars").select().execute().value
        } catch {
          debugPrint(error)
        }
      }
    }
  }
}

#Preview {
  ContentView()
}

