//
//  AppConfig.swift
//  DealingInDealsApp
//
//  Created by Ishan Bansal on 9/10/25.
//

import Foundation

enum AppConfig {
    static let basePosts = "https://dealingindeals.com/wp-json/wp/v2/posts"
    static let perPage = 100
    static let afterISO8601 = "2025-01-01T00:00:00Z"
    static let requestTimeout: TimeInterval = 20
    static let nyTimeZoneID = "America/New_York"
}

