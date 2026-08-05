//
//  FileDownloader.swift
//  PCL.Mac
//
//  Created by AnemoFlower on 2026/7/4.
//

import Foundation

public class FileDownloader {
    public static let shared: FileDownloader = {
        let configuration = URLSessionConfiguration.default
        let session = URLSession(configuration: configuration, delegate: DownloadDelegate.shared, delegateQueue: DownloadDelegate.queue)
        return .init(session: session)
    }()

    private let session: URLSession
    private let sourceManager: DownloadSourceManager
    private let maxRetryCount: Int = 3

    public init(session: URLSession, sourceManager: DownloadSourceManager = .shared) {
        self.session = session
        self.sourceManager = sourceManager
    }

    /// 下载单个文件。
    /// - Parameters:
    ///   - file: 下载项。
    ///   - preferMirror: 是否优先使用镜像源，为 `nil` 时由全局策略决定。
    ///   - progressHandler: 进度回调。
    ///   - checkDestination: 是否检查目标文件已存在且校验通过。
    public func download(
        _ file: DownloadItem,
        preferMirror: Bool? = nil,
        progressHandler: (@MainActor (Double) -> Void)? = nil,
        checkDestination: Bool = true
    ) async throws {
        if checkDestination && FileManager.default.fileExists(atPath: file.destination.path) {
            if try FileUtils.check(file) {
                debug("文件 \(file.destination.lastPathComponent) 已存在且校验通过，跳过下载")
                await progressHandler?(1)
                return
            } else {
                warn("文件 \(file.destination.lastPathComponent) 已存在但校验未通过")
                try FileManager.default.removeItem(at: file.destination)
            }
        }

        try FileManager.default.createDirectory(at: file.destination.deletingLastPathComponent(), withIntermediateDirectories: true)

        let candidates = file.urls.flatMap { sourceManager.orderedCandidates(for: $0, preferMirror: preferMirror) }
        if candidates.isEmpty {
            err("\(file.destination.lastPathComponent) 的候选列表为空")
            throw DownloadError.unknownError
        }
        
        var lastError: Error?

        for candidate in candidates {
            for retryCount in 0...maxRetryCount {
                await progressHandler?(0)

                var request = URLRequest(url: candidate.url)
                request.setValue("PCL-Mac/\(Metadata.appVersion)", forHTTPHeaderField: "User-Agent")
                for (key, value) in candidate.headers ?? [:] {
                    request.setValue(value, forHTTPHeaderField: key)
                }

                do {
                    log("下载 \(candidate.url) → \(file.destination)")
                    let task = session.downloadTask(with: request)
                    try await DownloadDelegate.shared.start(task, destination: file.destination, progressHandler: progressHandler)

                    // 校验
                    if file.checksums != nil {
                        guard try FileUtils.check(file) else {
                            try FileManager.default.removeItem(at: file.destination)
                            throw DownloadError.checksumMismatch
                        }
                    }
                    if file.executable {
                        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: file.destination.path)
                    }
                    return
                } catch {
                    try? FileManager.default.removeItem(at: file.destination)

                    if error.isCancellationError { throw error }

                    lastError = error

                    if case DownloadError.checksumMismatch = error {
                        warn("校验失败 \(candidate.url.lastPathComponent)，尝试下一个候选")
                        break
                    }

                    if let downloadError = error as? DownloadError,
                       case .badStatusCode = downloadError {
                        warn("\(candidate.url.lastPathComponent) 返回错误，尝试下一个候选")
                        break
                    }

                    if retryCount < maxRetryCount {
                        warn("下载 \(candidate.url.lastPathComponent) 失败: \(error.localizedDescription)，重试 (\(retryCount + 1)/\(maxRetryCount))")
                        try await Task.sleep(seconds: Double(retryCount + 1) * 0.5)
                    }
                }
            }
            log("候选 \(candidate.url) 已耗尽重试次数，尝试下一个候选")
        }

        throw lastError ?? DownloadError.unknownError
    }

    /// 批量下载文件。
    /// - Parameters:
    ///   - files: 下载项列表。
    ///   - preferMirror: 是否优先使用镜像源，为 `nil` 时由全局策略决定。
    ///   - maxConcurrency: 最大并发数，为 `nil` 时使用当前下载源推荐并发数。
    ///   - progressHandler: 进度回调。
    public func download(
        files: [DownloadItem],
        preferMirror: Bool? = nil,
        maxConcurrency: Int? = nil,
        progressHandler: (@MainActor (Double) -> Void)? = nil
    ) async throws {
        let total = files.count
        var skipped = 0

        var items: [DownloadItem] = []
        items.reserveCapacity(files.count)

        for file in files {
            if FileManager.default.fileExists(atPath: file.destination.path) {
                if try FileUtils.check(file) {
                    skipped += 1
                    continue
                }
                try FileManager.default.removeItem(at: file.destination)
            }
            items.append(file)
        }
        if items.isEmpty {
            await progressHandler?(1.0)
            return
        }

        let progressHandler = await ConcurrentProgressHandler(
            initial: Double(skipped) / Double(total),
            totalHandler: progressHandler ?? { _ in }
        )
        let multiplier = 1.0 / Double(total)
        await progressHandler.startCalculate()

        let concurrency = maxConcurrency ?? sourceManager.recommendedConcurrency

        try await withThrowingTaskGroup(of: Void.self) { group in
            let semaphore = AsyncSemaphore(value: concurrency)

            for item in items {
                if Task.isCancelled { break }
                await semaphore.wait()
                group.addTask {
                    defer { Task { await semaphore.signal() } }
                    try await self.download(item, preferMirror: preferMirror, progressHandler: await progressHandler.handler(withMultiplier: multiplier), checkDestination: false)
                }
            }

            try await group.waitForAll()
        }
    }

    public func download(url: URL, destination: URL, sha1: String? = nil, preferMirror: Bool? = nil, progressHandler: (@MainActor (Double) -> Void)? = nil) async throws {
        try await download(.init(url: url, destination: destination, sha1: sha1), preferMirror: preferMirror, progressHandler: progressHandler)
    }
}
