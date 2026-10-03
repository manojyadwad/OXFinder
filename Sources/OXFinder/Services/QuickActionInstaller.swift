import Foundation
import AppKit

/// Helper service to install and register the macOS Finder context menu Quick Action ("Open in OX Finder")
public enum QuickActionInstaller {
    private static let serviceName = "Open in OX Finder.workflow"
    private static var servicesDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library")
            .appendingPathComponent("Services")
    }

    /// Install the Quick Action into ~/Library/Services if missing or needs update
    public static func installQuickActionIfNeeded() {
        DispatchQueue.global(qos: .utility).async {
            installQuickAction()
        }
    }

    /// Directly install the Quick Action workflow
    @discardableResult
    public static func installQuickAction() -> Bool {
        let destURL = servicesDirectory.appendingPathComponent(serviceName)
        let contentsURL = destURL.appendingPathComponent("Contents")
        let fm = FileManager.default

        do {
            try fm.createDirectory(at: contentsURL, withIntermediateDirectories: true, attributes: nil)

            // 1. Write Info.plist
            let infoPlistContent = """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0">
            <dict>
            \t<key>NSIconPath</key>
            \t<string>AppIcon.icns</string>
            \t<key>NSServices</key>
            \t<array>
            \t\t<dict>
            \t\t\t<key>NSBackgroundColorName</key>
            \t\t\t<string>background</string>
            \t\t\t<key>NSBackgroundMode</key>
            \t\t\t<integer>0</integer>
            \t\t\t<key>NSIconName</key>
            \t\t\t<string>NSActionTemplate</string>
            \t\t\t<key>NSMenuItem</key>
            \t\t\t<dict>
            \t\t\t\t<key>default</key>
            \t\t\t\t<string>Open in OX Finder</string>
            \t\t\t</dict>
            \t\t\t<key>NSMessage</key>
            \t\t\t<string>runWorkflowAsService</string>
            \t\t\t<key>NSRequiredContext</key>
            \t\t\t<dict>
            \t\t\t\t<key>NSApplicationIdentifier</key>
            \t\t\t\t<string>com.apple.finder</string>
            \t\t\t</dict>
            \t\t\t<key>NSSendFileTypes</key>
            \t\t\t<array>
            \t\t\t\t<string>public.item</string>
            \t\t\t</array>
            \t\t</dict>
            \t</array>
            </dict>
            </plist>
            """
            let infoPlistURL = contentsURL.appendingPathComponent("Info.plist")
            try infoPlistContent.write(to: infoPlistURL, atomically: true, encoding: .utf8)

            // 2. Write document.wflow
            let wflowContent = """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0">
            <dict>
            \t<key>AMApplicationBuild</key>
            \t<string>526</string>
            \t<key>AMApplicationVersion</key>
            \t<string>2.10</string>
            \t<key>AMDocumentVersion</key>
            \t<string>2</string>
            \t<key>actions</key>
            \t<array>
            \t\t<dict>
            \t\t\t<key>action</key>
            \t\t\t<dict>
            \t\t\t\t<key>AMAccepts</key>
            \t\t\t\t<dict>
            \t\t\t\t\t<key>Container</key>
            \t\t\t\t\t<string>List</string>
            \t\t\t\t\t<key>Optional</key>
            \t\t\t\t\t<true/>
            \t\t\t\t\t<key>Types</key>
            \t\t\t\t\t<array>
            \t\t\t\t\t\t<string>com.apple.cocoa.string</string>
            \t\t\t\t\t</array>
            \t\t\t\t</dict>
            \t\t\t\t<key>AMActionVersion</key>
            \t\t\t\t<string>2.0.3</string>
            \t\t\t\t<key>AMApplication</key>
            \t\t\t\t<array>
            \t\t\t\t\t<string>Automator</string>
            \t\t\t\t</array>
            \t\t\t\t<key>ActionBundlePath</key>
            \t\t\t\t<string>/System/Library/Automator/Run Shell Script.action</string>
            \t\t\t\t<key>ActionName</key>
            \t\t\t\t<string>Run Shell Script</string>
            \t\t\t\t<key>ActionParameters</key>
            \t\t\t\t<dict>
            \t\t\t\t\t<key>COMMAND_STRING</key>
            \t\t\t\t\t<string>for f in "$@"; do
                open -a "OX Finder" "$f"
            done</string>
            \t\t\t\t\t<key>CheckedForUserDefaultShell</key>
            \t\t\t\t\t<true/>
            \t\t\t\t\t<key>inputMethod</key>
            \t\t\t\t\t<integer>1</integer>
            \t\t\t\t\t<key>shell</key>
            \t\t\t\t\t<string>/bin/zsh</string>
            \t\t\t\t\t<key>source</key>
            \t\t\t\t\t<string></string>
            \t\t\t\t</dict>
            \t\t\t\t<key>BundleIdentifier</key>
            \t\t\t\t<string>com.apple.RunShellScript</string>
            \t\t\t\t<key>CFBundleVersion</key>
            \t\t\t\t<string>2.0.3</string>
            \t\t\t\t<key>CanShowSelectedItemsWhenRun</key>
            \t\t\t\t<false/>
            \t\t\t\t<key>CanShowWhenRun</key>
            \t\t\t\t<true/>
            \t\t\t\t<key>Category</key>
            \t\t\t\t<array>
            \t\t\t\t\t<string>AMCategoryUtilities</string>
            \t\t\t\t</array>
            \t\t\t\t<key>Class Name</key>
            \t\t\t\t<string>RunShellScriptAction</string>
            \t\t\t\t<key>InputUUID</key>
            \t\t\t\t<string>0A0A0A0A-0000-0000-0000-000000000001</string>
            \t\t\t\t<key>Keywords</key>
            \t\t\t\t<array>
            \t\t\t\t\t<string>Shell</string>
            \t\t\t\t\t<string>Script</string>
            \t\t\t\t\t<string>Command</string>
            \t\t\t\t\t<string>Run</string>
            \t\t\t\t\t<string>Unix</string>
            \t\t\t\t</array>
            \t\t\t\t<key>OutputUUID</key>
            \t\t\t\t<string>0A0A0A0A-0000-0000-0000-000000000002</string>
            \t\t\t\t<key>UUID</key>
            \t\t\t\t<string>0A0A0A0A-0000-0000-0000-000000000003</string>
            \t\t\t\t<key>UnlocalizedApplications</key>
            \t\t\t\t<array>
            \t\t\t\t\t<string>Automator</string>
            \t\t\t\t</array>
            \t\t\t\t<key>arguments</key>
            \t\t\t\t<dict>
            \t\t\t\t\t<key>0</key>
            \t\t\t\t\t<dict>
            \t\t\t\t\t\t<key>default value</key>
            \t\t\t\t\t\t<integer>0</integer>
            \t\t\t\t\t\t<key>name</key>
            \t\t\t\t\t\t<string>inputMethod</string>
            \t\t\t\t\t\t<key>required</key>
            \t\t\t\t\t\t<string>0</string>
            \t\t\t\t\t\t<key>type</key>
            \t\t\t\t\t\t<string>0</string>
            \t\t\t\t\t\t<key>value</key>
            \t\t\t\t\t\t<integer>1</integer>
            \t\t\t\t\t</dict>
            \t\t\t\t\t<key>1</key>
            \t\t\t\t\t<dict>
            \t\t\t\t\t\t<key>default value</key>
            \t\t\t\t\t\t<string></string>
            \t\t\t\t\t\t<key>name</key>
            \t\t\t\t\t\t<string>source</string>
            \t\t\t\t\t\t<key>required</key>
            \t\t\t\t\t\t<string>0</string>
            \t\t\t\t\t\t<key>type</key>
            \t\t\t\t\t\t<string>0</string>
            \t\t\t\t\t\t<key>value</key>
            \t\t\t\t\t\t<string></string>
            \t\t\t\t\t</dict>
            \t\t\t\t\t<key>2</key>
            \t\t\t\t\t<dict>
            \t\t\t\t\t\t<key>default value</key>
            \t\t\t\t\t\t<false/>
            \t\t\t\t\t\t<key>name</key>
            \t\t\t\t\t\t<string>CheckedForUserDefaultShell</string>
            \t\t\t\t\t\t<key>required</key>
            \t\t\t\t\t\t<string>0</string>
            \t\t\t\t\t\t<key>type</key>
            \t\t\t\t\t\t<string>0</string>
            \t\t\t\t\t\t<key>value</key>
            \t\t\t\t\t\t<true/>
            \t\t\t\t\t</dict>
            \t\t\t\t\t<key>3</key>
            \t\t\t\t\t<dict>
            \t\t\t\t\t\t<key>default value</key>
            \t\t\t\t\t\t<string></string>
            \t\t\t\t\t\t<key>name</key>
            \t\t\t\t\t\t<string>COMMAND_STRING</string>
            \t\t\t\t\t\t<key>required</key>
            \t\t\t\t\t\t<string>0</string>
            \t\t\t\t\t\t<key>type</key>
            \t\t\t\t\t\t<string>0</string>
            \t\t\t\t\t\t<key>value</key>
            \t\t\t\t\t\t<string>for f in "$@"; do
                open -a "OX Finder" "$f"
            done</string>
            \t\t\t\t\t</dict>
            \t\t\t\t\t<key>4</key>
            \t\t\t\t\t<dict>
            \t\t\t\t\t\t<key>default value</key>
            \t\t\t\t\t\t<string>/bin/sh</string>
            \t\t\t\t\t\t<key>name</key>
            \t\t\t\t\t\t<string>shell</string>
            \t\t\t\t\t\t<key>required</key>
            \t\t\t\t\t\t<string>0</string>
            \t\t\t\t\t\t<key>type</key>
            \t\t\t\t\t\t<string>0</string>
            \t\t\t\t\t\t<key>value</key>
            \t\t\t\t\t\t<string>/bin/zsh</string>
            \t\t\t\t\t</dict>
            \t\t\t\t</dict>
            \t\t\t\t<key>isViewVisible</key>
            \t\t\t\t<integer>1</integer>
            \t\t\t\t<key>location</key>
            \t\t\t\t<string>309.000000:305.000000</string>
            \t\t\t\t<key>nibPath</key>
            \t\t\t\t<string>/System/Library/Automator/Run Shell Script.action/Contents/Resources/Base.lproj/main.nib</string>
            \t\t\t</dict>
            \t\t\t<key>isViewVisible</key>
            \t\t\t<integer>1</integer>
            \t\t</dict>
            \t</array>
            \t<key>connectors</key>
            \t<dict/>
            \t<key>workflowMetaData</key>
            \t<dict>
            \t\t<key>applicationBundleIDsByPath</key>
            \t\t<dict/>
            \t\t<key>applicationPaths</key>
            \t\t<array/>
            \t\t<key>inputTypeIdentifier</key>
            \t\t<string>com.apple.Automator.fileSystemObject</string>
            \t\t<key>outputTypeIdentifier</key>
            \t\t<string>com.apple.Automator.nothing</string>
            \t\t<key>presentationMode</key>
            \t\t<integer>15</integer>
            \t\t<key>processesInput</key>
            \t\t<false/>
            \t\t<key>serviceApplicationBundleID</key>
            \t\t<string>com.apple.finder</string>
            \t\t<key>serviceApplicationPath</key>
            \t\t<string>/System/Library/CoreServices/Finder.app</string>
            \t\t<key>serviceInputTypeIdentifier</key>
            \t\t<string>com.apple.Automator.fileSystemObject</string>
            \t\t<key>serviceOutputTypeIdentifier</key>
            \t\t<string>com.apple.Automator.nothing</string>
            \t\t<key>serviceProcessesInput</key>
            \t\t<false/>
            \t\t<key>systemImageName</key>
            \t\t<string>NSActionTemplate</string>
            \t\t<key>useAutomaticInputType</key>
            \t\t<false/>
            \t\t<key>workflowTypeIdentifier</key>
            \t\t<string>com.apple.Automator.servicesMenu</string>
            \t</dict>
            </dict>
            </plist>
            """
            let wflowURL = contentsURL.appendingPathComponent("document.wflow")
            try wflowContent.write(to: wflowURL, atomically: true, encoding: .utf8)

            // 3. Register with LaunchServices
            let lsregister = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
            if fm.fileExists(atPath: lsregister) {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: lsregister)
                process.arguments = ["-f", destURL.path]
                try? process.run()
                process.waitUntilExit()
            }

            return true
        } catch {
            print("QuickActionInstaller error: \(error)")
            return false
        }
    }
}
