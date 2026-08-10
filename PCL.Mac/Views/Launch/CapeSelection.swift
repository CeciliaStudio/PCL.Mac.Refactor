//
//  CapeSelection.swift
//  PCL.Mac
//
//  Created by Wunanc on 2026/8/10.
//

import Foundation
import Core

enum CapeSelection {
    private static let service: MinecraftProfileService = .shared
    private static let thumbnailCropRect = CGRect(x: 1, y: 1, width: 10, height: 16)

    static func request(for account: Account) {
        guard let microsoftAccount = account as? MicrosoftAccount else {
            hint("只有正版账号支持更换披风。", type: .info)
            return
        }

        Task { @MainActor in
            do {
                let account: Account = microsoftAccount
                hint("正在获取披风列表……")
                if try await account.shouldRefresh() {
                    try await account.refresh()
                }

                let capes = try await service.fetchCapes(accessToken: microsoftAccount.accessToken)
                guard !capes.isEmpty else {
                    hint("当前账号没有可用的披风。", type: .info)
                    return
                }

                let items: [ListItem] = capes.enumerated().map { index, cape in
                    .init(
                        image: ListItem.Image.networkCropped(cape.url, thumbnailCropRect),
                        imageSize: 40,
                        name: cape.alias ?? "披风 \(index + 1)",
                        description: cape.isActive ? "当前使用" : nil
                    )
                }

                guard let index = await MessageBoxManager.shared.showListAsync(
                    title: "选择披风",
                    items: items
                ) else {
                    return
                }

                let cape = capes[index]
                guard !cape.isActive else {
                    hint("这件披风已经在使用中。", type: .info)
                    return
                }

                try await service.activateCape(cape, accessToken: microsoftAccount.accessToken)
                hint("披风更换成功！", type: .finish)
            } catch let error where error.isCancellationError {
            } catch {
                err("更换披风失败：\(error.localizedDescription)")
                hint("更换披风失败：\(error.localizedDescription)", type: .critical)
            }
        }
    }
}
