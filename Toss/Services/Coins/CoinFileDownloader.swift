import Foundation

enum CoinFileDownloadProgress: Equatable, Sendable {
    case connecting
    case downloading(percent: Int)
    case verifying

    static func phase(receivedBytes: Int64, expectedBytes: Int64) -> Self {
        guard receivedBytes > 0, expectedBytes > 0 else { return .connecting }
        let percentage = min(100, max(0, Int((receivedBytes * 100) / expectedBytes)))
        return .downloading(percent: percentage)
    }
}

struct CoinFileDownloadPolicy: Sendable {
    let inactivityInterval: Duration

    static let live = Self(inactivityInterval: .seconds(60))
}

enum CoinFileDownloadRecoveryError: Error, Sendable {
    case connectionLost(resumeData: Data?)
    case noProgress(resumeData: Data?)

    var resumeData: Data? {
        switch self {
        case let .connectionLost(resumeData), let .noProgress(resumeData):
            return resumeData
        }
    }
}

struct CoinFileDownloadResponse: Sendable {
    let statusCode: Int
}

protocol CoinFileDownloadAttempting: Sendable {
    func download(
        from source: URL,
        to destination: URL,
        resumeData: Data?,
        expectedByteCount: Int64,
        policy: CoinFileDownloadPolicy,
        progress: @escaping @Sendable (CoinFileDownloadProgress) -> Void
    ) async throws -> CoinFileDownloadResponse
}

protocol CoinFileDownloading: Sendable {
    func download(
        from source: URL,
        to destination: URL,
        expectedByteCount: Int64,
        progress: @escaping @Sendable (CoinFileDownloadProgress) -> Void
    ) async throws -> CoinFileDownloadResponse
}

actor CoinFileDownloader: CoinFileDownloading {
    private let attempt: any CoinFileDownloadAttempting
    private let policy: CoinFileDownloadPolicy

    init(
        attempt: any CoinFileDownloadAttempting,
        policy: CoinFileDownloadPolicy = .live
    ) {
        self.attempt = attempt
        self.policy = policy
    }

    func download(
        from source: URL,
        to destination: URL,
        expectedByteCount: Int64,
        progress: @escaping @Sendable (CoinFileDownloadProgress) -> Void
    ) async throws -> CoinFileDownloadResponse {
        var hasRecovered = false
        var resumeData: Data?
        progress(.connecting)

        while true {
            do {
                return try await attempt.download(
                    from: source,
                    to: destination,
                    resumeData: resumeData,
                    expectedByteCount: expectedByteCount,
                    policy: policy,
                    progress: progress
                )
            } catch let recovery as CoinFileDownloadRecoveryError where !hasRecovered {
                hasRecovered = true
                resumeData = recovery.resumeData
            } catch let error as URLError where Self.isRecoverableTransportError(error) && !hasRecovered {
                hasRecovered = true
                resumeData = nil
            } catch {
                throw error
            }
        }
    }
}

final class URLSessionCoinFileDownloadAttempt: NSObject, CoinFileDownloadAttempting, @unchecked Sendable {
    func download(
        from source: URL,
        to destination: URL,
        resumeData: Data?,
        expectedByteCount: Int64,
        policy: CoinFileDownloadPolicy,
        progress: @escaping @Sendable (CoinFileDownloadProgress) -> Void
    ) async throws -> CoinFileDownloadResponse {
        let operation = URLSessionCoinFileDownloadOperation(
            source: source,
            destination: destination,
            resumeData: resumeData,
            expectedByteCount: expectedByteCount,
            inactivityInterval: policy.inactivityInterval,
            progress: progress
        )
        return try await operation.start()
    }
}

private final class URLSessionCoinFileDownloadOperation: NSObject, URLSessionDownloadDelegate, URLSessionTaskDelegate, @unchecked Sendable {
    private let source: URL
    private let destination: URL
    private let resumeData: Data?
    private let expectedByteCount: Int64
    private let inactivityInterval: Duration
    private let progress: @Sendable (CoinFileDownloadProgress) -> Void
    private let lock = NSLock()
    private var continuation: CheckedContinuation<CoinFileDownloadResponse, Error>?
    private var session: URLSession?
    private var task: URLSessionDownloadTask?
    private var watchdog: Task<Void, Never>?
    private var lastProgressDate = Date()
    private var receivedBytes: Int64 = 0
    private var statusCode = 0
    private var fileError: Error?
    private var cancelledForInactivity = false
    private var producedResumeData: Data?

    init(
        source: URL,
        destination: URL,
        resumeData: Data?,
        expectedByteCount: Int64,
        inactivityInterval: Duration,
        progress: @escaping @Sendable (CoinFileDownloadProgress) -> Void
    ) {
        self.source = source
        self.destination = destination
        self.resumeData = resumeData
        self.expectedByteCount = expectedByteCount
        self.inactivityInterval = inactivityInterval
        self.progress = progress
    }

    func start() async throws -> CoinFileDownloadResponse {
        try await withCheckedThrowingContinuation { continuation in
            lock.withLock {
                self.continuation = continuation
                let configuration = URLSessionConfiguration.default
                let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
                self.session = session
                let task = if let resumeData {
                    session.downloadTask(withResumeData: resumeData)
                } else {
                    session.downloadTask(with: source)
                }
                self.task = task
                task.resume()
                startWatchdog()
            }
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let received = lock.withLock { () -> Int64 in
            guard totalBytesWritten > receivedBytes else { return receivedBytes }
            receivedBytes = totalBytesWritten
            lastProgressDate = Date()
            return receivedBytes
        }
        progress(.phase(receivedBytes: received, expectedBytes: expectedByteCount))
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        do {
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.copyItem(at: location, to: destination)
            let code = (downloadTask.response as? HTTPURLResponse)?.statusCode ?? 0
            lock.withLock { statusCode = code }
        } catch {
            lock.withLock { fileError = error }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let result: Result<CoinFileDownloadResponse, Error> = lock.withLock {
            watchdog?.cancel()
            let resume = producedResumeData ?? Self.resumeData(from: error)
            if cancelledForInactivity {
                return .failure(CoinFileDownloadRecoveryError.noProgress(resumeData: resume))
            }
            if let urlError = error as? URLError, CoinFileDownloader.isRecoverableTransportError(urlError) {
                return .failure(CoinFileDownloadRecoveryError.connectionLost(resumeData: resume))
            }
            if let error { return .failure(error) }
            if let fileError { return .failure(fileError) }
            return .success(.init(statusCode: statusCode))
        }
        finish(result)
    }

    private func startWatchdog() {
        watchdog = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: inactivityInterval)
                guard !Task.isCancelled else { return }
                if self.cancelForInactivityIfNeeded() {
                    return
                }
            }
        }
    }

    private func cancelForInactivityIfNeeded() -> Bool {
        let task: URLSessionDownloadTask? = lock.withLock {
            guard Date().timeIntervalSince(lastProgressDate) >= inactivityInterval.timeInterval else { return nil }
            cancelledForInactivity = true
            return self.task
        }
        task?.cancel(byProducingResumeData: { [weak self] data in
            self?.lock.withLock { self?.producedResumeData = data }
        })
        return task != nil
    }

    private func finish(_ result: Result<CoinFileDownloadResponse, Error>) {
        let continuation = lock.withLock { () -> CheckedContinuation<CoinFileDownloadResponse, Error>? in
            defer {
                self.continuation = nil
                self.session?.invalidateAndCancel()
                self.session = nil
                self.task = nil
            }
            return self.continuation
        }
        switch result {
        case let .success(response): continuation?.resume(returning: response)
        case let .failure(error): continuation?.resume(throwing: error)
        }
    }

    private static func resumeData(from error: Error?) -> Data? {
        let nsError = error as NSError?
        return nsError?.userInfo[NSURLSessionDownloadTaskResumeData] as? Data
    }
}

private extension CoinFileDownloader {
    static func isRecoverableTransportError(_ error: URLError) -> Bool {
        error.code == .networkConnectionLost || error.code == .timedOut
    }
}

private extension Duration {
    var timeInterval: TimeInterval {
        let components = components
        return Double(components.seconds) + Double(components.attoseconds) / 1_000_000_000_000_000_000
    }
}
