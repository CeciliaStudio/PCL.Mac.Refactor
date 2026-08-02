//
//  NetworkImage.swift
//  PCL.Mac
//
//  Created by AnemoFlower on 2026/3/19.
//

import SwiftUI
import Core

struct NetworkImage: View {
    @State private var nsImage: NSImage = .init(size: .zero)
    private let url: URL
    
    init(url: URL) {
        self.url = url
    }
    
    var body: some View {
        Image(nsImage: nsImage)
            .resizable()
            .scaledToFit()
            .task(id: url) {
                do {
                    let data: Data = try await HTTPClient.shared.get(url).data
                    guard let nsImage: NSImage = .init(data: data) else {
                        throw SimpleError("解码 NSImage 失败。")
                    }
                    await MainActor.run {
                        withAnimation(nil) {
                            self.nsImage = nsImage
                        }
                    }
                } catch let error where error.isCancellationError {
                } catch {
                    err("加载图片 \(url.absoluteString) 失败：\(error.localizedDescription)")
                }
            }
    }
}
