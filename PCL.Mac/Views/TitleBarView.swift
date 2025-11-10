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
            HStack {
                PageButton(route: .launch)
                PageButton(route: .download)
            }
        }
        .frame(height: 48)
    }
}

private struct PageButton: View {
    private let route: AppRoute
    
    init(route: AppRoute) {
        self.route = route
    }
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(.cyan)
            MyText(String(describing: route))
        }
        .frame(width: 80, height: 30)
        .onTapGesture {
            AppRouter.shared.setRoot(route)
        }
    }
}
