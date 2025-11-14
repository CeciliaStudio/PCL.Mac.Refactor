//
//  ContentView.swift
//  PCL.Mac
//
//  Created by 温迪 on 2025/11/8.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject private var dataManager: DataManager = .shared
    @State private var sidebarWidth: CGFloat = AppRouter.shared.sidebar.width
    
    var body: some View {
        VStack(spacing: 0) {
            TitleBarView()
            HStack(spacing: 0) {
                Rectangle()
                    .fill(.white)
                    .frame(width: sidebarWidth)
                    .overlay(AnyView(AppRouter.shared.sidebar.content))
                    .onChange(of: AppRouter.shared.sidebar.width) { newValue in
                        withAnimation(.spring(response: 0.1, dampingFraction: 0.8)) {
                            sidebarWidth = newValue
                        }
                    }
                AppRouter.shared.content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.green)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ContentView()
}
