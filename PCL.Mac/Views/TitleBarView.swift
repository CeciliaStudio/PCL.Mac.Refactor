//
//  TitleBarView.swift
//  PCL.Mac
//
//  Created by 温迪 on 2025/11/10.
//

import SwiftUI

struct TitleBarView: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(.blue)
            HStack(spacing: 5) {
                PageButton("启动", "LaunchPageIcon", .launch)
                PageButton("下载", "DownloadPageIcon", .download)
                PageButton("联机", "MultiplayerPageIcon", .multiplayer)
                PageButton("设置", "SettingsPageIcon", .settings)
                PageButton("更多", "OthersPageIcon", .other)
            }
        }
        .frame(height: 48)
    }
}

private struct PageButton: View {
    @ObservedObject private var dataManager: DataManager = .shared
    @State private var isRoot: Bool
    @State private var isHovered: Bool = false
    private let label: String
    private let image: String
    private let route: AppRoute
    
    init(_ label: String, _ image: String, _ route: AppRoute) {
        self.label = label
        self.image = image
        self.route = route
        self._isRoot = State(initialValue: AppRouter.shared.getRoot() == route)
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 13)
                .fill(backgroundColor)
            HStack(spacing: 7) {
                Image(image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16)
                    .foregroundStyle(foregroundColor)
                MyText(label, 14, foregroundColor)
            }
        }
        .frame(width: 78, height: 27)
        .onChange(of: AppRouter.shared.getRoot()) { newValue in
            withAnimation(.easeInOut(duration: 0.2)) {
                isRoot = AppRouter.shared.getRoot() == route
            }
        }
        .contentShape(Rectangle())
        .onHover { isHovered in
            withAnimation(.easeInOut(duration: 0.1)) {
                self.isHovered = isHovered
            }
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if AppRouter.shared.getRoot() != route {
                        AppRouter.shared.setRoot(route)
                    }
                }
        )
    }
    
    private var foregroundColor: Color {
        isRoot ? .pclBlue : .white
    }
    
    private var backgroundColor: Color {
        isRoot ? .white : (isHovered ? .init(0xFFFFFF, alpha: 0.25) : .clear)
    }
}
