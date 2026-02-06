//
//  Todo.swift
//  WTM
//
//  Created by Kutter Thornton on 2/6/26.
//


import Foundation
import Supabase

struct Todo: Identifiable, Decodable {
  var id: Int
  var title: String
}

