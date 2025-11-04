//
//  Supabase.swift
//  Unify
//
//  Created by Jonas Dunkenberger on 03.11.25.
//


import Supabase
import Foundation

let supabase = SupabaseClient(
  supabaseURL: URL(string: "https://gtyyrkwfkzzyhsearkgn.supabase.co")!,
  supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd0eXlya3dma3p6eWhzZWFya2duIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MjA3NTAxMywiZXhwIjoyMDc3NjUxMDEzfQ.dt-HvTcJ0mNpmzC9KKDCCXYvrRb_hldeuzBg55AQY8g"
)
