//
//  AppURLs.swift
//  PCL.Mac
//
//  Created by 温迪 on 2025/11/8.
//

import Foundation

public struct AppURLs {
    public static let contentsURL: URL = Bundle.main.bundleURL.appending(path: "Contents")
    public static let resourcesURL: URL = contentsURL.appending(path: "Resources")
    
    public static let applicationSupportURL: URL = .applicationSupportDirectory.appending(path: "PCL.Mac.Refactor")
    public static let logsDirectoryURL: URL = applicationSupportURL.appending(path: "Logs")
    public static let configURL: URL = applicationSupportURL.appending(path: "Config")
    public static let cacheURL: URL = applicationSupportURL.appending(path: "Caches")
    public static let temperatureURL: URL = applicationSupportURL.appending(path: "Temp")
    public static let authlibInjectorURL: URL = applicationSupportURL.appending(path: "authlib-injector.jar")
}
