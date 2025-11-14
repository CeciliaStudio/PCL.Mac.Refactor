//
//  ColorExtension.swift
//  PCL.Mac
//
//  Created by 温迪 on 2025/11/13.
//

import SwiftUI

extension Color {
    static let pclBlue: Color = .init(0x0f6fcd)
    
    init(_ hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}
