import Foundation
import Combine

/// Real-time directory observer that triggers callbacks when folder contents change
public final class DirectoryWatcher: @unchecked Sendable {
    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1
    private let queue = DispatchQueue(label: "com.oxfinder.directorywatcher", qos: .utility)
    private var debounceTimer: DispatchSourceTimer?
    private let debounceInterval: TimeInterval

    public var onChange: (@Sendable () -> Void)?

    public init(debounceInterval: TimeInterval = 0.25) {
        self.debounceInterval = debounceInterval
    }

    deinit {
        stop()
    }

    /// Start watching the directory at the given URL
    public func start(watching url: URL) {
        stop()

        let descriptor = open(url.path, O_EVTONLY)
        guard descriptor >= 0 else { return }
        self.fileDescriptor = descriptor

        let newSource = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .delete, .rename, .extend, .attrib],
            queue: queue
        )

        newSource.setEventHandler { [weak self] in
            self?.scheduleDebouncedCallback()
        }

        newSource.setCancelHandler { [descriptor] in
            close(descriptor)
        }

        self.source = newSource
        newSource.resume()
    }

    /// Stop watching the current directory
    public func stop() {
        debounceTimer?.cancel()
        debounceTimer = nil

        if let src = source {
            src.cancel()
            source = nil
            fileDescriptor = -1
        }
    }

    private func scheduleDebouncedCallback() {
        debounceTimer?.cancel()

        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + debounceInterval)
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            self.debounceTimer?.cancel()
            self.debounceTimer = nil
            self.onChange?()
        }
        self.debounceTimer = timer
        timer.resume()
    }
}
