import AppKit

public struct AppLogoHelper {
    public static var logoImage: NSImage? {
        if let resourcesURL = Bundle.main.resourceURL {
            let icns = resourcesURL.appendingPathComponent("AppIcon.icns")
            if FileManager.default.fileExists(atPath: icns.path), let img = NSImage(contentsOf: icns) {
                return img
            }
            let png = resourcesURL.appendingPathComponent("AppIcon.png")
            if FileManager.default.fileExists(atPath: png.path), let img = NSImage(contentsOf: png) {
                return img
            }
        }
        // Development fallback
        let devIcon = URL(fileURLWithPath: #file)
            .deletingLastPathComponent() // Services
            .deletingLastPathComponent() // OXFinder
            .deletingLastPathComponent() // Sources
            .appendingPathComponent("Resources/AppIcon.png")
        if FileManager.default.fileExists(atPath: devIcon.path), let img = NSImage(contentsOf: devIcon) {
            return img
        }
        return nil
    }
}
