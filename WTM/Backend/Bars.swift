//
//  Bar.swift
//  WTM
//
//  Created by Kutter Thornton on 2/6/26.
//


import Foundation
import MapKit
import SwiftUI

struct Bars: Identifiable, Decodable, Encodable, Equatable {
    let id: UUID
    let name: String
    let latitude: Double
    let longitude: Double
    let description: String
    let address: String
    let popularity: Int
    let people_count: Int
    let hype_score: Int
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    var hypeColor: Color {
        let score = hype_score
        if score < 3 {
            return .green
        } else if score < 7 && score > 3 {
            return .yellow
        } else {
            return .red
        }
    }

    func updating(peopleCount: Int? = nil, hypeScore: Int? = nil) -> Bars {
        Bars(
            id: id,
            name: name,
            latitude: latitude,
            longitude: longitude,
            description: description,
            address: address,
            popularity: popularity,
            people_count: peopleCount ?? people_count,
            hype_score: hypeScore ?? hype_score
        )
    }
}
