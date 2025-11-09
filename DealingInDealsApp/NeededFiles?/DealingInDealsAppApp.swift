//
//  DealingInDealsAppApp.swift
//  DealingInDealsApp
//
//  Created by Ishan Bansal on 9/9/25.
//

import SwiftUI
import UIKit

@main
struct DealingInDealsAppApp: App {
    init() {
        // Configure navigation bar background to AppBackgroundBlue
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        // Use the asset color; fall back to system background if missing
        let bgColor = UIColor(named: "AppBackgroundBlue") ?? UIColor.systemBackground
        appearance.backgroundColor = bgColor
        appearance.shadowColor = .clear
        
        // Title text colors for readability
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor.label
        ]
        appearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor.label
        ]

        // Apply to all navigation bar states
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().tintColor = UIColor.label // bar button items
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
