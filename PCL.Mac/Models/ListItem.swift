//
//  ListItem.swift
//  PCL.Mac
//
//  Created by AnemoFlower on 2026/1/26.
//

import SwiftUI

struct ListItem {
    public let image: Image?
    public let imageSize: CGFloat
    public let name: String
    public let description: String?
    
    init(image: Image? = nil, imageSize: CGFloat = 36, name: String, description: String?) {
        self.image = image
        self.imageSize = imageSize
        self.name = name
        self.description = description
    }
    
    init(image: ImageResource?, imageSize: CGFloat = 36, name: String, description: String?) {
        self.init(image: image.map(Image.resource), imageSize: imageSize, name: name, description: description)
    }
    
    enum Image {
        case system(String)
        case resource(ImageResource)
        case nsImage(NSImage)
        case network(URL)
        /// 网络图片中按左上角为原点的像素区域裁剪后显示。
        case networkCropped(URL, CGRect)
        
        @ViewBuilder
        func makeView() -> some View {
            switch self {
            case .system(let name): SwiftUI.Image(systemName: name).resizable()
            case .resource(let imageResource): SwiftUI.Image(imageResource).resizable()
            case .nsImage(let nsImage): SwiftUI.Image(nsImage: nsImage).resizable().interpolation(.none)
            case .network(let url): NetworkImage(url: url)
            case .networkCropped(let url, let cropRect): NetworkImage(url: url, cropRect: cropRect)
            }
        }
    }
}
