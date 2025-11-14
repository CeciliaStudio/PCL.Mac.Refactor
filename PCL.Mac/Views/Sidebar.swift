//
//  Sidebar.swift
//  PCL.Mac
//
//  Created by 温迪 on 2025/11/9.
//

import SwiftUI

protocol Sidebar {
    init()
    associatedtype Body : View
    
    var width: CGFloat { get }
    
    @ViewBuilder
    var content: Self.Body { get }
}

struct EmptySidebar: Sidebar {
    let width: CGFloat = 0
    
    var content: some View {
        EmptyView()
    }
}
