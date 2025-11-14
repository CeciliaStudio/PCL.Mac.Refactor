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

class AppRouter: ObservableObject {
    static let shared: AppRouter = .init()
    
    @Published private(set) var path: [AppRoute] = [.launch]
    
    @ViewBuilder
    var content: some View {
        switch getLast() {
        case .launch:
            LaunchView()
        case .download:
            DownloadView()
        default:
            Spacer()
        }
    }
    
    var sidebar: any Sidebar {
        switch getRoot() {
        case .launch:
            LaunchSidebar()
        case .download:
            DownloadSidebar()
        default:
            EmptySidebar()
        }
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
