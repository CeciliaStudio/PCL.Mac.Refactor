//
//  ContentView.swift
//  PCL.Mac
//
//  Created by 温迪 on 2025/11/8.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject private var dataManager: DataManager = .shared
    
    var body: some View {
        VStack(spacing: 0) {
            TitleBarView()
                .frame(maxWidth: .infinity)
            HStack(spacing: 0) {
                Rectangle()
                    .frame(width: AppRouter.shared.sidebar.width)
                    .background(.white)
                    .overlay { AppRouter.shared.sidebar }
                AppRouter.shared.content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.green)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.red)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .font(.pcl())
    }
}

#Preview {
    ContentView()
}
