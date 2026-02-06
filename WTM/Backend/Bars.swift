//
//  Bar.swift
//  WTM
//
//  Created by Kutter Thornton on 2/6/26.
//


import Foundation
import Supabase
import MapKit
import SwiftUI

struct Bars: Identifiable,  Decodable, Encodable {
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
}

