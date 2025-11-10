//
//  AppRouter.swift
//  PCL.Mac
//
//  Created by 温迪 on 2025/11/9.
//

import SwiftUI

enum AppRoute {
    case launch, download, multiplayer, settings, other
}

class AppRouter {
    static let shared: AppRouter = .init()
    
    var path: [AppRoute] = [.launch] {
        didSet {
            DataManager.shared.objectWillChange.send()
        }
    }
    
    @ViewBuilder
    var content: some View {
        switch getLast() {
        case .launch:
            LaunchView()
        default:
            EmptyView()
        }
    }
    
    var sidebar: some Sidebar {
        LaunchSidebar()
    }
    
    func getLast() -> AppRoute {
        return path[path.count - 1]
    }
    
    func getRoot() -> AppRoute {
        return path[0]
    }
    
    func setRoot(_ newRoot: AppRoute) {
        path = [newRoot]
    }
    
    func append(_ route: AppRoute) {
        path.append(route)
    }
    
    func removeLast() {
        if path.count > 1 {
            path.removeLast()
        }
    }
    
    private init() {
    }
}
