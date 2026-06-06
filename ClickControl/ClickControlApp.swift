//
//  ClickControlApp.swift
//  ClickControl
//
//  Created by kota113 on 2026/06/06.
//

import SwiftUI

@main
struct ClickControlApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
