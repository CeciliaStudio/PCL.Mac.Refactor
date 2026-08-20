//
//  AppWindow.swift
//  PCL.Mac
//
//  Created by AnemoFlower on 2025/11/29.
//

import SwiftUI
import Core

private final class TrafficLightView: NSView {
    private let buttons: [NSButton]
    
    init(styleMask: NSWindow.StyleMask) {
        self.buttons = [
            NSWindow.standardWindowButton(.closeButton, for: styleMask),
            NSWindow.standardWindowButton(.miniaturizeButton, for: styleMask)
        ].compactMap { $0 }
        super.init(frame: .zero)
        
        buttons.forEach { button in
            addSubview(button)
        }
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var isFlipped: Bool { true }
    
    override var intrinsicContentSize: NSSize {
        NSSize(width: 84, height: 84)
    }
    
    override func layout() {
        super.layout()
        
        buttons[0].frame.origin = .init(x: 0, y: 0)
        buttons[1].frame.origin = .init(x: 22, y: 0)
    }
    
    func connect(to window: NSWindow) {
        let actions: [Selector] = [
            #selector(NSWindow.performClose(_:)),
            #selector(NSWindow.miniaturize(_:))
        ]
        for (button, action) in zip(buttons, actions) {
            button.target = window
            button.action = action
        }
    }
}

private final class WindowContentView: NSView {
    private let hostingView: NSView
    private let trafficLights: NSView
    
    init(hostingView: NSView, trafficLights: NSView) {
        self.hostingView = hostingView
        self.trafficLights = trafficLights
        super.init(frame: .zero)
        addSubview(hostingView)
        addSubview(trafficLights)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var isFlipped: Bool { true }
    
    override func layout() {
        super.layout()
        hostingView.frame = self.bounds
        
        trafficLights.frame = CGRect(
            x: 18,
            y: 18,
            width: 84,
            height: 84
        )
    }
}

class AppWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    
    init(instanceManager: InstanceManager) {
        let styleMask: NSWindow.StyleMask = [
            .titled, .closable, .resizable, .miniaturizable, .fullSizeContentView
        ]
        super.init(
            contentRect: .init(x: 0, y: 0, width: 1000, height: 550),
            styleMask: styleMask,
            backing: .buffered, defer: false
        )
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        
        let hostingView = NSHostingView(rootView: RootView(instanceManager: instanceManager))
        
        for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            standardWindowButton(button)?.isHidden = true
        }
        
        let trafficLights = TrafficLightView(styleMask: styleMask)
        trafficLights.connect(to: self)
        let containerView = WindowContentView(hostingView: hostingView, trafficLights: trafficLights)
        contentView = containerView
        
        setFrameAutosaveName("AppWindow")
        center()
    }
}
