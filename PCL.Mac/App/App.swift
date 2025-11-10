//
//  PCL_MacApp.swift
//  PCL.Mac
//
//  Created by 温迪 on 2025/11/8.
//

import SwiftUI

@main
struct PCL_MacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate: AppDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
