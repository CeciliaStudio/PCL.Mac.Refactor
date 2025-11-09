//
//  Architecture.swift
//  PCL.Mac
//
//  Created by 温迪 on 2025/11/8.
//

import Foundation

public enum Architecture {
    case arm64, x64, fatFile, unknown
    
    public static func getFileArchitecture(_ url: URL) -> Architecture {
        guard let fh = try? FileHandle(forReadingFrom: url) else { return .unknown }
        defer { try? fh.close() }
        
        guard let magicData = try? fh.read(upToCount: 4), magicData.count == 4 else { return .unknown }
        let magic = magicData.withUnsafeBytes { $0.load(as: UInt32.self) }
        let isFat = (magic == 0xBEBAFECA || magic == 0xBFBAFECA || magic == 0xCAFEBABE || magic == 0xCAFEBABF)
        
        if isFat {
            guard let nfatArchData = try? fh.read(upToCount: 4), nfatArchData.count == 4 else { return .unknown }
            let nfatArch = nfatArchData.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
            
            var foundX64 = false
            var foundArm64 = false
            
            for _ in 0..<nfatArch {
                guard let archData = try? fh.read(upToCount: 20), archData.count == 20 else { return .unknown }
                let cputype = archData.prefix(4).withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
                switch cputype {
                case 0x1000007: foundX64 = true // CPU_TYPE_X86_64
                case 0x100000C: foundArm64 = true // CPU_TYPE_ARM64
                default: break
                }
            }
            if foundX64 && foundArm64 {
                return .fatFile
            } else if foundArm64 {
                return .arm64
            } else if foundX64 {
                return .x64
            } else {
                return .unknown
            }
        }
        
        guard let cputypeData = try? fh.read(upToCount: 4), cputypeData.count == 4 else { return .unknown }
        let cputype = cputypeData.withUnsafeBytes { $0.load(as: UInt32.self) }
        switch cputype {
        case 0x100000C: return .arm64
        case 0x1000007: return .x64
        default: return .unknown
        }
    }
}
