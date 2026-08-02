//
//  LocaleUtils.swift
//  PCL.Mac
//
//  Created by AnemoFlower on 2026/2/4.
//

import Foundation
import CoreLocation

public enum LocaleUtils {
    @MainActor private static var inChinaMainland: Bool?
    
    /// 判断系统地区设置是否为中国大陆。
    public static func isSystemLocaleChinese() -> Bool {
        return Locale.current.identifier == "zh_CN"
    }
    
    /// 根据当前网络的公网 IP 推断所在地是否为中国大陆（网络所在地），并非精确的设备物理位置。
    ///
    /// 查询使用了 [CloudFlare Trace](https://www.cloudflare-cn.com/cdn-cgi/trace) 基于出口 IP 进行地区判断，
    /// 结果会受到 VPN / 代理 / 网络环境等影响。
    public static func isInChinaMainland(strict: Bool = true, useCache: Bool = true) async -> Bool {
        if let inChinaMainland = await inChinaMainland, useCache {
            return inChinaMainland
        }
        do {
            let response: String = try String(
                data: await HTTPClient.shared.get("https://www.cloudflare-cn.com/cdn-cgi/trace", revalidate: true, timeout: 10).data,
                encoding: .utf8
            ).unwrap("解析字符串失败。")
            let inChinaMainland = response.contains("\nloc=CN\n")
            await MainActor.run {
                Self.inChinaMainland = inChinaMainland
            }
            return inChinaMainland
        } catch {
            err("获取地区失败：\(error.localizedDescription)")
            return !strict
        }
    }
}
