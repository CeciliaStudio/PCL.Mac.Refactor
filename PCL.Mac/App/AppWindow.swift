//
//  AppWindow.swift
//  PCL.Mac
//
//  Created by AnemoFlower on 2025/11/29.
//

import SwiftUI
import Core

fileprivate let osMajorVersion = ProcessInfo.processInfo.operatingSystemVersion.majorVersion

class AppWindow: NSWindow, NSWindowDelegate {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    
    init(instanceManager: InstanceManager) {
        super.init(
            contentRect: .init(x: 0, y: 0, width: 1000, height: 550),
            styleMask: [.titled, .closable, .resizable, .miniaturizable, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        
        self.standardWindowButton(.zoomButton)?.isHidden = true
        
        self.contentView = NSHostingView(rootView: RootView(instanceManager: instanceManager))
        self.delegate = self
        
        self.setFrameAutosaveName("AppWindow")
        self.center()
    }
    
    func windowDidUpdate(_ notification: Notification) {
        guard osMajorVersion >= 14 else { return }
        
        guard let close = standardWindowButton(.closeButton),
              let titlebarView = close.superview else {
            return
        }
        
        let offset = osMajorVersion >= 26 ? 9 : 11
        let origin = CGPoint(x: offset, y: -offset)
        guard titlebarView.frame.origin != origin else {
            return
        }
        
        titlebarView.frame.origin = origin
    }
}
