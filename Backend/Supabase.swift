import Supabase
import Foundation

// Haupt Supabase Client
let supabase: SupabaseClient = {
    let urlString = Secrets.supabaseUrl
    let key = Secrets.supabaseKey

    guard let url = URL(string: urlString) else {
        fatalError("❌ SUPABASE_URL ist kein gültiger URL-String: \(urlString)")
    }

    return SupabaseClient(
        supabaseURL: url,
        supabaseKey: key
    )
}()
