import Foundation
import Supabase

class SupabaseService {
    static let shared = SupabaseService()
    
    let client: SupabaseClient
    
    private init() {
        client = SupabaseClient(
            supabaseURL: URL(string: "https://pcchrtwfjgfoequvbufq.supabase.co")!,
            supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBjY2hydHdmamdmb2VxdXZidWZxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDI1MzIzNzMsImV4cCI6MjA1ODEwODM3M30.26SUBW05sMirT7SiRuI48_BWIQ8Lox1VOa1Sr4Iz2aw"
        )
    }
}
