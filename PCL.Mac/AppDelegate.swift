//
//  AppDelegate.swift
//  PCL.Mac
//
//  Created by 温迪 on 2025/11/8.
//

import Foundation
import AppKit
import Core

class AppDelegate: NSObject, NSApplicationDelegate {
    private func registerFont() {
        let fontURL: URL = AppURLs.resourcesURL.appending(path: "PCL.ttf")
        CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, nil)
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        LogManager.shared.enableLogging(logsURL: AppURLs.logsDirectoryURL)
        registerFont()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
