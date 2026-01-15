//
//  SystemMaintenanceApp.swift
//  SystemMaintenance
//
//  Created by Z790 on 2025-12-29.
//

import SwiftUI

@main
struct SystemMaintenanceApp: App {
    var body: some Scene {
        WindowGroup {
            SystemMaintenanceView()
                .frame(minWidth: 1200, minHeight: 800)
        }
        .windowResizability(.contentSize)
    }
}