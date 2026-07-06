import SwiftUI

@main
struct NemuriYogaApp: App {
    @StateObject private var audio = AudioManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(audio)
                .preferredColorScheme(.dark)
        }
    }
}
