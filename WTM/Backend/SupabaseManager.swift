//
//  SupabaseManager.swift
//  WTM
//
//  Created by Kutter Thornton on 2/6/26.
//
import Foundation
import Supabase

let supabase = SupabaseClient(
  supabaseURL: URL(string: "https://wtjtbcczhcqurqmqvxsx.supabase.co")!,
  supabaseKey: "sb_publishable_VcQ0E-a0m7XMibk1b6D61Q_qtS0bgF0"
)
        
let auth = supabase.auth
