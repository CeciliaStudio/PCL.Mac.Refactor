//
//  FontExtension.swift
//  PCL.Mac
//
//  Created by 温迪 on 2025/11/8.
//

import SwiftUI

extension Font {
    static func pcl(size: CGFloat = 14) -> Font {
        .custom("PCL English", size: size)
    }
}
