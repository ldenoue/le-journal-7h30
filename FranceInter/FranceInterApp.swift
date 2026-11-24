import SwiftUI

@main
struct FranceInterApp: App {
    var body: some Scene {
        WindowGroup {
            JournalView()
                .preferredColorScheme(.dark)
        }
    }
}

