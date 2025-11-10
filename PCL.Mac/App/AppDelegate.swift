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
        let fontURL = AppURLs.resourcesURL.appending(path: "PCL.ttf")
        var error: Unmanaged<CFError>?
        CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, &error)
        if let error = error?.takeUnretainedValue() {
            err("无法注册字体：\(error.localizedDescription)")
        } else {
            log("成功注册字体")
        }
    }
    
    func applicationWillFinishLaunching(_ notification: Notification) {
        LogManager.shared.enableLogging(logsURL: AppURLs.logsDirectoryURL)
        registerFont()
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
