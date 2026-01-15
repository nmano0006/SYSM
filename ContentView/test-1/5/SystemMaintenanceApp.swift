//
//  SystemMaintenanceApp.swift
//  SystemMaintenance
//
//  Created by Developer on 12/29/2024.
//

import SwiftUI

@main
struct SystemMaintenanceApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 1000, minHeight: 800)
        }
        .windowResizability(.contentSize)
        .commands {
            // Add Donation menu item
            CommandGroup(after: .appInfo) {
                Divider()
                Button("Support Development") {
                    // Open donation page
                    if let url = URL(string: "https://www.paypal.com/donate/?business=H3PV9HX92AVMJ&no_recurring=0&item_name=Support+development+of+all+my+apps+and+tools.+Donations+fund+testing+hardware%2C+servers%2C+and+continued+open-source+development.&currency_code=CAD") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])
            }
        }
    }
}