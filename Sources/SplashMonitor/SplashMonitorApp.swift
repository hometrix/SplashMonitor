import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // If menu bar icon is active, keep app running when window is closed
        let showMenuBar = UserDefaults.standard.bool(forKey: "showMenuBarIcon")
        return !showMenuBar
    }
}

@main
struct SplashMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var service = SplashService.shared
    @StateObject private var loc = Localization.shared
    @AppStorage("showMenuBarIcon") private var showMenuBarIcon: Bool = true
    
    var body: some Scene {
        WindowGroup("Splash Monitor") {
            MainWindowView(service: service)
                .frame(minWidth: 850, minHeight: 600)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        
        MenuBarExtra(isInserted: $showMenuBarIcon) {
            MenuBarView(service: service)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: service.isRunning ? "bolt.fill" : "bolt.slash")
                
                if service.isRunning {
                    switch service.menuBarDisplayMode {
                    case "speed":
                        Text("\(service.formattedDecodeSpeed) t/s")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                    case "tokens":
                        Text("\(service.formattedTokensDecode) tok")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                    case "model":
                        let short = service.activeModel.components(separatedBy: "/").last ?? service.activeModel
                        Text(short.replacingOccurrences(of: "-Splash", with: ""))
                            .font(.system(size: 11, weight: .medium))
                    default:
                        EmptyView()
                    }
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
}
