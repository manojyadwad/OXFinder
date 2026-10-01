import Foundation
import AppKit

/// Real-time observer for mounted volumes, external drives, and USB pen drives
public final class VolumeWatcher: @unchecked Sendable {
    private var volumeSource: DispatchSourceFileSystemObject?
    private var volumeFileDescriptor: Int32 = -1
    private let queue = DispatchQueue(label: "com.oxfinder.volumewatcher", qos: .utility)
    private var debounceTimer: DispatchSourceTimer?
    private let debounceInterval: TimeInterval = 0.25

    private var observers: [NSObjectProtocol] = []

    public var onVolumeChange: (@Sendable () -> Void)?

    public init() {
        start()
    }

    deinit {
        stop()
    }

    /// Start listening for volume mount/unmount notifications and observing /Volumes
    public func start() {
        stop()

        // 1. Observe NSWorkspace mount & unmount notifications
        let center = NSWorkspace.shared.notificationCenter

        let mountObserver = center.addObserver(
            forName: NSWorkspace.didMountNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.scheduleDebouncedCallback()
        }
        observers.append(mountObserver)

        let unmountObserver = center.addObserver(
            forName: NSWorkspace.didUnmountNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.scheduleDebouncedCallback()
        }
        observers.append(unmountObserver)

        let renameObserver = center.addObserver(
            forName: NSWorkspace.didRenameVolumeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.scheduleDebouncedCallback()
        }
        observers.append(renameObserver)

        // 2. Kernel file descriptor watcher on /Volumes
        let volumesPath = "/Volumes"
        let descriptor = open(volumesPath, O_EVTONLY)
        if descriptor >= 0 {
            self.volumeFileDescriptor = descriptor
            let src = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: descriptor,
                eventMask: [.write, .extend, .attrib, .rename, .delete],
                queue: queue
            )

            src.setEventHandler { [weak self] in
                self?.scheduleDebouncedCallback()
            }

            src.setCancelHandler { [descriptor] in
                close(descriptor)
            }

            self.volumeSource = src
            src.resume()
        }
    }

    /// Stop observing volume events
    public func stop() {
        debounceTimer?.cancel()
        debounceTimer = nil

        let center = NSWorkspace.shared.notificationCenter
        for observer in observers {
            center.removeObserver(observer)
        }
        observers.removeAll()

        if let src = volumeSource {
            src.cancel()
            volumeSource = nil
            volumeFileDescriptor = -1
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
            self.onVolumeChange?()
        }
        self.debounceTimer = timer
        timer.resume()
    }
}
