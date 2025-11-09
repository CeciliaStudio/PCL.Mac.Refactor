//
//  JavaSearchTests.swift
//  PCL.Mac
//
//  Created by 温迪 on 2025/11/9.
//

import Testing
import Foundation
import Core

struct JavaSearchTests {
    @Test func testSearch() throws {
        let runtimes = try JavaSearcher.search()
        for runtime in runtimes {
            print("\(runtime.type) \(runtime.versionNumber) (\(runtime.version)) \(runtime.architecture) \(runtime.executableURL)")
        }
    }
}
