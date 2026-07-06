import SwiftUI

@main
struct SleepYogaApp: App {
    @StateObject private var audio = AudioManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(audio)
                .preferredColorScheme(.dark)
        }
    }
}
