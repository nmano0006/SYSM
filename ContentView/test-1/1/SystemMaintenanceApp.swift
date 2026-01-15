import SwiftUI

@main
struct SystemMaintenanceApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 1000, minHeight: 800)
        }
        .windowResizability(.contentSize)
    }
}