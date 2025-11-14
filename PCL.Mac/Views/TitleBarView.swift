//
//  TitleBarView.swift
//  PCL.Mac
//
//  Created by 温迪 on 2025/11/10.
//

import SwiftUI

struct TitleBarView: View {
    var body: some View {
        ZStack(alignment: .leading) {
            Rectangle()
                .fill(.blue)
            Image("Title")
                .resizable()
                .scaledToFit()
                .frame(height: 19)
                .padding()
            HStack {
                Spacer()
                PageButton("启动", "LaunchPageIcon", .launch)
                PageButton("下载", "DownloadPageIcon", .download)
                PageButton("联机", "MultiplayerPageIcon", .multiplayer)
                PageButton("设置", "SettingsPageIcon", .settings)
                PageButton("更多", "OthersPageIcon", .other)
                Spacer()
            }
        }
        .frame(height: 48)
    }
}

private struct PageButton: View {
    @ObservedObject private var router: AppRouter = .shared
    @State private var isHovered: Bool = false
    private var isRoot: Bool { router.getRoot() == route }
    private let label: String
    private let image: String
    private let route: AppRoute
    
    init(_ label: String, _ image: String, _ route: AppRoute) {
        self.label = label
        self.image = image
        self.route = route
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
        .contentShape(Rectangle())
        .onHover { isHovered in
            self.isHovered = isHovered
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if router.getRoot() != route {
                        router.setRoot(route)
                    }
                }
        )
        .animation(.easeInOut(duration: 0.2), value: isRoot)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
    }
    
    private var foregroundColor: Color {
        isRoot ? .pclBlue : .white
    }
    
    private var backgroundColor: Color {
        isRoot ? .white : (isHovered ? .init(0xFFFFFF, alpha: 0.25) : .clear)
    }
}
