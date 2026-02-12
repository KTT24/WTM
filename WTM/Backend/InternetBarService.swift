import Foundation
import MapKit
import CoreLocation
import Contacts

final class InternetBarService {
    func enrich(_ bar: Bars) async -> Bars {
        do {
            guard let match = try await bestMatch(for: bar) else { return bar }
            return merge(bar, with: match)
        } catch {
            return bar
        }
    }

    private func bestMatch(for bar: Bars) async throws -> MKMapItem? {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = bar.name
        request.resultTypes = .pointOfInterest
        request.region = MKCoordinateRegion(
            center: bar.coordinate,
            latitudinalMeters: 2_500,
            longitudinalMeters: 2_500
        )

        let response = try await MKLocalSearch(request: request).start()
        let items = response.mapItems.filter { $0.placemark.location != nil }
        guard !items.isEmpty else { return nil }

        let normalizedName = normalize(bar.name)
        let exactNameMatches = items.filter { item in
            guard let name = item.name else { return false }
            return normalize(name) == normalizedName
        }

        let candidates = exactNameMatches.isEmpty ? items : exactNameMatches
        let target = CLLocation(latitude: bar.latitude, longitude: bar.longitude)

        return candidates.min { lhs, rhs in
            let lhsDistance = lhs.placemark.location?.distance(from: target) ?? .greatestFiniteMagnitude
            let rhsDistance = rhs.placemark.location?.distance(from: target) ?? .greatestFiniteMagnitude
            return lhsDistance < rhsDistance
        }
    }

    private func merge(_ bar: Bars, with item: MKMapItem) -> Bars {
        let resolvedAddress = formattedAddress(from: item.placemark)
        let resolvedDescription = buildDescription(for: item, fallback: bar.description)

        return Bars(
            id: bar.id,
            name: item.name ?? bar.name,
            latitude: item.placemark.coordinate.latitude,
            longitude: item.placemark.coordinate.longitude,
            description: resolvedDescription,
            address: resolvedAddress.isEmpty ? bar.address : resolvedAddress,
            popularity: bar.popularity,
            people_count: bar.people_count,
            hype_score: bar.hype_score
        )
    }

    private func buildDescription(for item: MKMapItem, fallback: String) -> String {
        var parts: [String] = []

        if let category = item.pointOfInterestCategory?.rawValue,
           !category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append("Category: \(prettyCategory(category))")
        }

        if let phone = item.phoneNumber,
           !phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append("Phone: \(phone)")
        }

        if let website = item.url?.absoluteString,
           !website.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append("Website: \(website)")
        }

        let generated = parts.joined(separator: " • ")
        if !generated.isEmpty { return generated }
        return fallback
    }

    private func formattedAddress(from placemark: MKPlacemark) -> String {
        if let postal = placemark.postalAddress {
            let formatted = CNPostalAddressFormatter.string(from: postal, style: .mailingAddress)
                .replacingOccurrences(of: "\n", with: ", ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !formatted.isEmpty { return formatted }
        }

        let parts = [
            placemark.subThoroughfare,
            placemark.thoroughfare,
            placemark.locality,
            placemark.administrativeArea,
            placemark.postalCode
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }

        if !parts.isEmpty {
            return parts.joined(separator: ", ")
        }

        return placemark.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func prettyCategory(_ raw: String) -> String {
        raw
            .split(separator: ".")
            .last
            .map(String.init)?
            .replacingOccurrences(of: "_", with: " ")
            .capitalized ?? raw
    }

    private func normalize(_ value: String) -> String {
        value
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined()
    }
}
