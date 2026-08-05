//
//  NeoforgeInstallService.swift
//  PCL.Mac
//
//  Created by AnemoFlower on 2026/3/21.
//

import Foundation

public class NeoforgeInstallService: ForgeInstallService {
    override func installerDownloadURLs() -> [URL] {
        let root = URL(string: "https://maven.neoforged.net/releases")!
        
        if minecraftVersion.id == "1.20.1" {
            let version = !self.version.hasPrefix("1.20.1-") ? "1.20.1-\(self.version)" : self.version
            return [root.appending(path: "net/neoforged/forge/\(version)/forge-\(version)-installer.jar")]
        }
        return [root.appending(path: "net/neoforged/neoforge/\(version)/neoforge-\(version)-installer.jar")]
    }
}
