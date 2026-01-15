import SwiftUI

@main
struct SYSMApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(HiddenTitleBarWindowStyle())
        .windowResizability(.contentSize)
        .commands {
            SidebarCommands()
            ToolbarCommands()
        }
    }
}