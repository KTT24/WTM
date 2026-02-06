//
//  Bar.swift
//  WTM
//
//  Created by Kutter Thornton on 2/6/26.
//


import Foundation
import Supabase

struct Bar: Identifiable,  Decodable {
    let id: UUID
    let name: String
    let description: String
    let address: String
    let popularity: Int
    let people_count: Int
    let hype_score: Int
}

