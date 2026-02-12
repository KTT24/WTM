//
//  BarMapView.swift
//  WTM
//
//  Created by Kutter Thornton on 2/6/26.
//

import Foundation
import SwiftUI
import MapKit
import CoreLocation

struct BarsMapView: View {
    
    @EnvironmentObject private var dataStore: AppDataStore
    @AppStorage("showCurrentPartyMarkers") private var showCurrentPartyMarkers: Bool = true
    @State private var cameraPosition: MapCameraPosition = .automatic
    
    @State private var selectedBar: Bars?
    @State private var showSettings = false
    @State private var localBars: [LocalBar] = []
    @State private var eventPins: [EventPin] = []
    @State private var isSearchingNearby = false
    @State private var locationMessage: String?
    @State private var hasSearchedNearby = false
    @State private var lastNearbySearch: Date = .distantPast
    @State private var didSetInitialRegion = false

    @StateObject private var locationManager = LocationManager()

    @State private var eventGeocoder = EventGeocoder()
    
    // Starting region – feel free to change (example: Lubbock area)
    private let initialRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 33.5779, longitude: -101.8552),
        span: MKCoordinateSpan(latitudeDelta: 0.12, longitudeDelta: 0.12)
    )

    private var filteredSavedBars: [Bars] {
        dataStore.nearbyBars
    }

    private var filteredLocalBars: [LocalBar] {
        localBars
    }

    private var pulsingBars: [(bar: Bars, color: Color)] {
        var result: [(bar: Bars, color: Color)] = []
        for bar in filteredSavedBars {
            if let color = pulseColor(for: bar) {
                result.append((bar: bar, color: color))
            }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            BarsMapContainer(
                cameraPosition: $cameraPosition,
                bars: filteredSavedBars,
                pulsingBars: pulsingBars,
                localBars: filteredLocalBars,
                eventPins: eventPins,
                selectedBar: $selectedBar,
                userLocation: locationManager.effectiveLocation,
                showUserLocation: shouldShowUserLocationDot,
                showSettings: $showSettings,
                locationMessage: locationMessage,
                isSearchingNearby: isSearchingNearby,
                onSelectLocalBar: { bar in
                    Task { await openLocalBar(bar) }
                },
                onOpenDebugBar: openDebugBarDetail,
                onRefreshNearby: refreshNearbyBars,
                onBarsLoaded: requestNearbyBarsIfNeeded,
                onEventsUpdated: { Task { await refreshEventPins() } }
            )
            .task {
                async let _ = dataStore.loadBars()
                async let _ = dataStore.loadEvents()
                _ = await ()
                requestNearbyBarsIfNeeded()
                await refreshEventPins()
            }
            .onChange(of: locationManager.location) { _ in
                requestNearbyBarsIfNeeded()
            }
            .onReceive(NotificationCenter.default.publisher(for: DebugLocationStore.notification)) { _ in
                hasSearchedNearby = false
                refreshNearbyBars()
            }
            .onChange(of: locationManager.authorizationStatus) { status in
                if status == .denied || status == .restricted {
                    locationMessage = "Location access is off. Enable it to find nearby bars."
                } else {
                    locationMessage = nil
                }
            }
            .onChange(of: dataStore.nearbyBars) { bars in
                guard !didSetInitialRegion, !bars.isEmpty else { return }
                didSetInitialRegion = true
                cameraPosition = .region(initialRegion)
            }
            .onChange(of: dataStore.events) { _ in
                Task { await refreshEventPins() }
            }
            .onChange(of: showCurrentPartyMarkers) { _ in
                Task { await refreshEventPins() }
            }
        }
    }
    
    private func requestNearbyBarsIfNeeded() {
        locationManager.requestAuthorization()
        locationManager.requestLocation()

        guard !hasSearchedNearby else { return }
        guard let location = locationManager.effectiveLocation else { return }
        hasSearchedNearby = true
        refreshNearbyBars(at: location)
    }

    private func refreshNearbyBars() {
        locationManager.requestAuthorization()
        locationManager.requestLocation()
        guard let location = locationManager.effectiveLocation else {
            locationMessage = "Enable location to find nearby bars."
            return
        }
        refreshNearbyBars(at: location)
    }

    private func refreshNearbyBars(at location: CLLocation) {
        guard !isSearchingNearby else { return }
        let now = Date()
        if now.timeIntervalSince(lastNearbySearch) < 45 {
            return
        }
        lastNearbySearch = now

        let searchRadiusMiles = 10.0
        let region = MKCoordinateRegion(
            center: location.coordinate,
            latitudinalMeters: 1609.34 * searchRadiusMiles,
            longitudinalMeters: 1609.34 * searchRadiusMiles
        )
        cameraPosition = .region(region)

        Task {
            isSearchingNearby = true
            defer { isSearchingNearby = false }
            do {
                let request = MKLocalSearch.Request()
                request.naturalLanguageQuery = "Bars"
                request.region = region
                request.resultTypes = .pointOfInterest

                let response = try await MKLocalSearch(request: request).start()
                let nearby = response.mapItems.compactMap { item -> LocalBar? in
                    guard let name = item.name, let loc = item.placemark.location else { return nil }
                    guard loc.distance(from: location) <= 1609.34 * searchRadiusMiles else { return nil }
                    let address = item.placemark.title ?? ""
                    return LocalBar(
                        name: name,
                        coordinate: loc.coordinate,
                        address: address
                    )
                }

                await MainActor.run {
                    let deduped = dedupeLocalBars(nearby)
                    localBars = deduped
                    dataStore.updateLocalBars(deduped)
                    let hasMatches = !filteredLocalBars.isEmpty || !filteredSavedBars.isEmpty
                    locationMessage = hasMatches ? nil : "No nearby bars found."
                }
            } catch {
                await MainActor.run {
                    locationMessage = "Could not find nearby bars."
                }
            }
        }
    }

    private func dedupeLocalBars(_ items: [LocalBar]) -> [LocalBar] {
        var seen = Set<String>()
        var deduped: [LocalBar] = []
        for item in items {
            let key = "\(item.name.lowercased())|\(item.coordinate.latitude)|\(item.coordinate.longitude)"
            if seen.insert(key).inserted {
                deduped.append(item)
            }
        }
        return deduped
    }

    private var shouldShowUserLocationDot: Bool {
        guard let location = locationManager.effectiveLocation else { return false }
        return !isUserInBar(location)
    }

    private func isUserInBar(_ location: CLLocation) -> Bool {
        let allBars = filteredSavedBars.map { bar in
            CLLocation(latitude: bar.latitude, longitude: bar.longitude)
        } + filteredLocalBars.map { bar in
            CLLocation(latitude: bar.coordinate.latitude, longitude: bar.coordinate.longitude)
        }

        let threshold: CLLocationDistance = 40
        return allBars.contains { $0.distance(from: location) <= threshold }
    }

    private func openLocalBar(_ bar: LocalBar) async {
        if let existing = existingBar(for: bar) {
            await MainActor.run {
                selectedBar = existing
            }
            return
        }

        let generatedId = BarIDGenerator.deterministicUUID(
            name: bar.name,
            latitude: bar.coordinate.latitude,
            longitude: bar.coordinate.longitude
        )

        let created = Bars(
            id: generatedId,
            name: bar.name,
            latitude: bar.coordinate.latitude,
            longitude: bar.coordinate.longitude,
            description: "",
            address: bar.address,
            popularity: 0,
            people_count: 0,
            hype_score: 0
        )

        let distance = locationManager.location.map {
            CLLocation(latitude: bar.coordinate.latitude, longitude: bar.coordinate.longitude).distance(from: $0)
        }

        do {
            let resolved = try await dataStore.recordNearby(created, distanceMeters: distance)
            await MainActor.run {
                selectedBar = resolved
                locationMessage = nil
            }
        } catch {
            await MainActor.run {
                locationMessage = "Could not save bar."
            }
        }
    }

    private func existingBar(for localBar: LocalBar) -> Bars? {
        let target = CLLocation(latitude: localBar.coordinate.latitude, longitude: localBar.coordinate.longitude)
        return dataStore.nearbyBars.first { bar in
            let distance = CLLocation(latitude: bar.latitude, longitude: bar.longitude)
                .distance(from: target)
            return distance <= 80 && bar.name.caseInsensitiveCompare(localBar.name) == .orderedSame
        }
    }

    private func refreshEventPins() async {
        guard showCurrentPartyMarkers else {
            await MainActor.run { eventPins = [] }
            return
        }

        let liveEvents = dataStore.liveEvents
        guard !liveEvents.isEmpty else {
            await MainActor.run { eventPins = [] }
            return
        }

        let pins = await eventGeocoder.resolve(events: liveEvents)
        await MainActor.run {
            eventPins = pins
        }
    }

    private func openDebugBarDetail() {
        selectedBar = Bars(
            id: UUID(uuidString: "11111111-2222-3333-4444-555555555555") ?? UUID(),
            name: "Dummy Night Spot",
            latitude: 33.5779,
            longitude: -101.8552,
            description: "Debug-only bar data used to validate BarDetailView layout and actions.",
            address: "123 Debug Ave, Lubbock, TX",
            popularity: 88,
            people_count: 36,
            hype_score: 8
        )
    }
}

private struct BarsMapContainer: View {
    @Binding var cameraPosition: MapCameraPosition
    let bars: [Bars]
    let pulsingBars: [(bar: Bars, color: Color)]
    let localBars: [LocalBar]
    let eventPins: [EventPin]
    @Binding var selectedBar: Bars?
    let userLocation: CLLocation?
    let showUserLocation: Bool
    @Binding var showSettings: Bool
    let locationMessage: String?
    let isSearchingNearby: Bool
    let onSelectLocalBar: (LocalBar) -> Void
    let onOpenDebugBar: () -> Void
    let onRefreshNearby: () -> Void
    let onBarsLoaded: () -> Void
    let onEventsUpdated: () -> Void

    var body: some View {
        BarsMap(
            cameraPosition: $cameraPosition,
            bars: bars,
            pulsingBars: pulsingBars,
            localBars: localBars,
            eventPins: eventPins,
            userLocation: userLocation,
            showUserLocation: showUserLocation,
            selectedBar: $selectedBar,
            onSelectLocalBar: onSelectLocalBar
        )
        .mapStyle(.standard)
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(item: $selectedBar) { bar in
            BarDetailView(bar: bar)
                .presentationDetents([.medium, .large])
                .presentationCornerRadius(50)
                .presentationDragIndicator(.hidden)
        }
        .overlay(alignment: .top) {
            VStack(spacing: 8) {
                BarsMapStatusBanner(
                    locationMessage: locationMessage,
                    isSearchingNearby: isSearchingNearby
                )
            }
        }
        .navigationTitle("Bars Nearby")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    onOpenDebugBar()
                } label: {
                    Image(systemName: "ladybug.fill")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                }
            }
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    onRefreshNearby()
                } label: {
                    Image(systemName: "location.magnifyingglass")
                }
            }
        }
        .onAppear {
            onBarsLoaded()
            onEventsUpdated()
        }
    }
}

private struct BarsMap: View {
    @Binding var cameraPosition: MapCameraPosition
    let bars: [Bars]
    let pulsingBars: [(bar: Bars, color: Color)]
    let localBars: [LocalBar]
    let eventPins: [EventPin]
    let userLocation: CLLocation?
    let showUserLocation: Bool
    @Binding var selectedBar: Bars?
    let onSelectLocalBar: (LocalBar) -> Void
    @State private var visibleRegion: MKCoordinateRegion?

    private var allPins: [MapPlacePin] {
        let saved = bars.map { MapPlacePin.saved($0) }
        let locals = localBars.map { MapPlacePin.local($0) }
        return saved + locals
    }

    private var shouldCluster: Bool {
        guard let visibleRegion else { return false }
        return visibleRegion.span.latitudeDelta > 0.02 || visibleRegion.span.longitudeDelta > 0.02
    }

    private var clusters: [PinCluster] {
        guard shouldCluster, let visibleRegion else {
            return allPins.map { PinCluster(center: $0.coordinate, pins: [$0]) }
        }
        return buildClusters(from: allPins, in: visibleRegion)
    }

    var body: some View {
        Map(position: $cameraPosition) {
            Group {
                if showUserLocation, let userLocation {
                    UserLocationAnnotation(location: userLocation)
                }
                BarPulseAnnotations(pulsingBars: pulsingBars)
                EventAnnotations(eventPins: eventPins)
                PlaceAnnotations(
                    clusters: clusters,
                    shouldCluster: shouldCluster,
                    selectedBar: $selectedBar,
                    onSelectLocalBar: onSelectLocalBar,
                    onSelectCluster: zoomIntoCluster
                )
            }
        }
        .onMapCameraChange { context in
            visibleRegion = context.region
        }
    }

    private func zoomIntoCluster(_ cluster: PinCluster) {
        guard let visibleRegion else { return }
        let nextSpan = MKCoordinateSpan(
            latitudeDelta: max(visibleRegion.span.latitudeDelta * 0.45, 0.002),
            longitudeDelta: max(visibleRegion.span.longitudeDelta * 0.45, 0.002)
        )
        cameraPosition = .region(
            MKCoordinateRegion(center: cluster.center, span: nextSpan)
        )
    }

    private func buildClusters(from pins: [MapPlacePin], in region: MKCoordinateRegion) -> [PinCluster] {
        guard !pins.isEmpty else { return [] }
        let latStep = max(region.span.latitudeDelta / 10, 0.003)
        let lonStep = max(region.span.longitudeDelta / 10, 0.003)

        var buckets: [String: [MapPlacePin]] = [:]
        for pin in pins {
            let latIndex = Int(floor(pin.coordinate.latitude / latStep))
            let lonIndex = Int(floor(pin.coordinate.longitude / lonStep))
            let key = "\(latIndex):\(lonIndex)"
            buckets[key, default: []].append(pin)
        }

        return buckets.values.map { bucket in
            let center = averageCoordinate(for: bucket)
            return PinCluster(center: center, pins: bucket)
        }
    }

    private func averageCoordinate(for pins: [MapPlacePin]) -> CLLocationCoordinate2D {
        let latSum = pins.reduce(0.0) { $0 + $1.coordinate.latitude }
        let lonSum = pins.reduce(0.0) { $0 + $1.coordinate.longitude }
        let count = Double(max(pins.count, 1))
        return CLLocationCoordinate2D(latitude: latSum / count, longitude: lonSum / count)
    }
}

private struct UserLocationAnnotation: MapContent {
    let location: CLLocation

    var body: some MapContent {
        Annotation("You", coordinate: location.coordinate) {
            UserLocationMarker()
        }
        .annotationTitles(.hidden)
    }
}

private struct EventAnnotations: MapContent {
    let eventPins: [EventPin]

    var body: some MapContent {
        ForEach(eventPins) { pin in
            Annotation(pin.event.name, coordinate: pin.coordinate) {
                CurrentPartyMarker()
            }
        }
    }
}

private struct BarPulseAnnotations: MapContent {
    let pulsingBars: [(bar: Bars, color: Color)]

    var body: some MapContent {
        ForEach(pulsingBars, id: \.bar.id) { entry in
            Annotation("", coordinate: CLLocationCoordinate2D(latitude: entry.bar.latitude, longitude: entry.bar.longitude)) {
                PulsingHalo(color: entry.color)
            }
            .annotationTitles(.hidden)
        }
    }
}

private struct PlaceAnnotations: MapContent {
    let clusters: [PinCluster]
    let shouldCluster: Bool
    @Binding var selectedBar: Bars?
    let onSelectLocalBar: (LocalBar) -> Void
    let onSelectCluster: (PinCluster) -> Void

    var body: some MapContent {
        ForEach(clusters) { cluster in
            if shouldCluster && cluster.pins.count > 1 {
                Annotation("Cluster", coordinate: cluster.center) {
                    Button {
                        onSelectCluster(cluster)
                    } label: {
                        ClusterPinMarker(count: cluster.pins.count)
                    }
                    .buttonStyle(.plain)
                }
                .annotationTitles(.hidden)
            } else if let pin = cluster.pins.first {
                switch pin {
                case .saved(let bar):
                    Annotation(bar.name, coordinate: CLLocationCoordinate2D(latitude: bar.latitude, longitude: bar.longitude)) {
                        Button {
                            selectedBar = bar
                        } label: {
                            BarPinMarker(color: markerColor(for: bar))
                        }
                        .buttonStyle(.plain)
                    }
                case .local(let localBar):
                    Annotation(localBar.name, coordinate: localBar.coordinate) {
                        Button {
                            onSelectLocalBar(localBar)
                        } label: {
                            LocalBarAnnotationView()
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private enum MapPlacePin: Identifiable {
    case saved(Bars)
    case local(LocalBar)

    var id: String {
        switch self {
        case .saved(let bar):
            return "saved-\(bar.id.uuidString)"
        case .local(let bar):
            return "local-\(bar.id.uuidString)"
        }
    }

    var coordinate: CLLocationCoordinate2D {
        switch self {
        case .saved(let bar):
            return CLLocationCoordinate2D(latitude: bar.latitude, longitude: bar.longitude)
        case .local(let bar):
            return bar.coordinate
        }
    }
}

private struct PinCluster: Identifiable {
    let id = UUID()
    let center: CLLocationCoordinate2D
    let pins: [MapPlacePin]
}

private struct BarsMapStatusBanner: View {
    let locationMessage: String?
    let isSearchingNearby: Bool

    var body: some View {
        Group {
            if let locationMessage {
                Text(locationMessage)
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding(.top, 44)
            } else if isSearchingNearby {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Finding nearby bars…")
                }
                .padding(12)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .padding(.top, 44)
            }
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
            .fill(color.opacity(0.24))
            .frame(width: 44, height: 44)
            .scaleEffect(animate ? 1.7 : 0.75)
            .opacity(animate ? 0.0 : 1.0)
            .animation(.easeOut(duration: 1.4).repeatForever(autoreverses: false), value: animate)
            .onAppear { animate = true }
    }
}

private struct LocalBarAnnotationView: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.95), Color.cyan.opacity(0.32)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 35, height: 35)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.62), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.20), radius: 6, x: 0, y: 3)

            Image(systemName: "wineglass.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.cyan, Color.blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }
}

private struct BarPinMarker: View {
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.96), Color.white.opacity(0.78)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 38, height: 38)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.58), lineWidth: 1.1)
                )
                .shadow(color: .black.opacity(0.20), radius: 7, x: 0, y: 3)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.98), color.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 28, height: 28)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.22), lineWidth: 1)
                )
                .overlay(
                    Image(systemName: "wineglass.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                )
        }
    }
}

private struct ClusterPinMarker: View {
    let count: Int

    private var label: String {
        count >= 5 ? "5+" : "\(count)"
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.95), Color.white.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 42, height: 42)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.55), lineWidth: 1.1)
                )
                .shadow(color: .black.opacity(0.22), radius: 8, x: 0, y: 4)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.indigo, Color.blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 32, height: 32)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                )
                .overlay(
                    Text(label)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                )
        }
    }
}

private struct UserLocationMarker: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.blue.opacity(0.24))
                .frame(width: 36, height: 36)
                .scaleEffect(animate ? 1.4 : 0.8)
                .opacity(animate ? 0.0 : 1.0)
                .animation(.easeOut(duration: 1.6).repeatForever(autoreverses: false), value: animate)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.white, Color.cyan.opacity(0.95)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 13, height: 13)
                .overlay(
                    Circle()
                        .stroke(Color.blue.opacity(0.95), lineWidth: 2.6)
                )
        }
        .onAppear { animate = true }
    }
}

private struct EventPin: Identifiable {
    let id: Int
    let event: Event
    let coordinate: CLLocationCoordinate2D
}

private struct CurrentPartyMarker: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.orange.opacity(0.35), lineWidth: 2)
                .frame(width: 30, height: 30)
                .scaleEffect(animate ? 1.6 : 0.8)
                .opacity(animate ? 0.0 : 1.0)
                .animation(.easeOut(duration: 1.4).repeatForever(autoreverses: false), value: animate)

            Circle()
                .fill(LinearGradient(colors: [Color.orange, Color.pink], startPoint: .top, endPoint: .bottom))
                .frame(width: 26, height: 26)
                .overlay(
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                )
                .shadow(color: .orange.opacity(0.45), radius: 6, x: 0, y: 2)
        }
        .onAppear { animate = true }
    }
}

private actor EventGeocoder {
    private var cache: [Int: CLLocationCoordinate2D] = [:]
    private let geocoder = CLGeocoder()

    func resolve(events: [Event]) async -> [EventPin] {
        let eventIds = Set(events.map { $0.id })
        cache = cache.filter { eventIds.contains($0.key) }

        var pins: [EventPin] = []
        for event in events {
            if let cached = cache[event.id] {
                pins.append(EventPin(id: event.id, event: event, coordinate: cached))
                continue
            }

            guard let coordinate = await geocode(event) else { continue }
            cache[event.id] = coordinate
            pins.append(EventPin(id: event.id, event: event, coordinate: coordinate))
        }
        return pins
    }

    private func geocode(_ event: Event) async -> CLLocationCoordinate2D? {
        let query = event.location.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return nil }
        do {
            let placemarks = try await geocoder.geocodeAddressString(query)
            return placemarks.first?.location?.coordinate
        } catch {
            return nil
        }
    }
}

// ────────────────────────────────────────────────
// 3. Preview
// ────────────────────────────────────────────────
#Preview {
    NavigationStack {
        BarsMapView()
    }
    .environmentObject(AppDataStore())
}
