import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    
    /// Tracks whether we are in the process of a real quit (force quit) or
    /// just hiding the window when menuBarOnlyMode is active.
    var isReallyQuitting = false
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Desactivar agrupación automática en pestañas para evitar pestañas duplicadas al reabrir
        NSWindow.allowsAutomaticWindowTabbing = false
        
        // Cargar icono de la aplicación explícitamente para el Dock
        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let iconImage = NSImage(contentsOf: iconURL) {
            NSApp.applicationIconImage = iconImage
        }
        
        // Apply initial activation policy based on saved preference
        applyActivationPolicy()
    }
    
    /// Applies the correct NSApplication activation policy based on current settings.
    /// - `.accessory`: No Dock icon, no task switcher entry — menu bar only.
    /// - `.regular`: Normal app with Dock icon and task switcher entry.
    func applyActivationPolicy() {
        let menuBarOnly = UserDefaults.standard.bool(forKey: "menuBarOnlyMode")
        let showMenuBar  = UserDefaults.standard.bool(forKey: "showMenuBarIcon")
        
        if menuBarOnly && showMenuBar {
            NSApp.setActivationPolicy(.accessory)
        } else {
            NSApp.setActivationPolicy(.regular)
            // Re-attach Dock icon so it re-appears correctly
            if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
               let iconImage = NSImage(contentsOf: iconURL) {
                NSApp.applicationIconImage = iconImage
            }
        }
    }
    
    // MARK: - Cmd+Q interception for Menu Bar Only Mode
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let menuBarOnly = UserDefaults.standard.bool(forKey: "menuBarOnlyMode")
        let showMenuBar  = UserDefaults.standard.bool(forKey: "showMenuBarIcon")
        
        // If the user triggered a "real" quit via the menu bar item, let it through
        if isReallyQuitting {
            return .terminateNow
        }
        
        if menuBarOnly && showMenuBar {
            // Instead of quitting, hide all windows and switch to accessory mode
            NSApp.setActivationPolicy(.accessory)
            for window in sender.windows {
                window.orderOut(nil)
            }
            return .terminateCancel
        }
        
        return .terminateNow
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        let menuBarOnly = UserDefaults.standard.bool(forKey: "menuBarOnlyMode")
        
        // When clicked in Dock (if visible) or relaunched, restore the window
        if !flag {
            // Switch back to regular so Dock icon appears
            if !menuBarOnly {
                NSApp.setActivationPolicy(.regular)
            }
            for window in sender.windows where window.canBecomeMain && !(window is NSPanel) {
                window.makeKeyAndOrderFront(self)
                NSApp.activate(ignoringOtherApps: true)
                return true
            }
        }
        return true
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Stop the server only if this app started it; one launched from a terminal
        // or script keeps running. Always release memory.
        let service = SplashService.shared
        if service.shouldStopServerOnQuit {
            service.stopActiveServerSync()
        }
        service.resetState()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        let showMenuBar  = UserDefaults.standard.bool(forKey: "showMenuBarIcon")
        let menuBarOnly  = UserDefaults.standard.bool(forKey: "menuBarOnlyMode")
        
        if menuBarOnly && showMenuBar {
            // Switch to accessory (hide Dock icon) instead of quitting
            NSApp.setActivationPolicy(.accessory)
            return false
        }
        
        // If menu bar icon is active, keep app running when window is closed
        return !showMenuBar
    }
}

@main
struct SplashMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var service = SplashService.shared
    @StateObject private var loc = Localization.shared
    @AppStorage("showMenuBarIcon") private var showMenuBarIcon: Bool = true
    @AppStorage("menuBarOnlyMode") private var menuBarOnlyMode: Bool = false
    
    var body: some Scene {
        WindowGroup("Splash Monitor", id: "main") {
            MainWindowView(service: service)
                .frame(minWidth: 850, minHeight: 600)
                .onChange(of: menuBarOnlyMode) { _ in
                    appDelegate.applyActivationPolicy()
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button(loc.isSpanish ? "Acerca de Splash Monitor" : "About Splash Monitor") {
                    NotificationCenter.default.post(name: NSNotification.Name("ShowAboutView"), object: nil)
                    NSApp.activate(ignoringOtherApps: true)
                    for window in NSApp.windows where window.canBecomeMain {
                        window.makeKeyAndOrderFront(nil)
                    }
                }
            }
            
            // Menú Ver / View (Zoom In, Zoom Out, Reset Zoom) estilo macOS / VS Code
            CommandGroup(after: .toolbar) {
                Menu(loc.isSpanish ? "Apariencia" : "Appearance") {
                    Button(loc.isSpanish ? "Aumentar tamaño de letra" : "Zoom In") {
                        TextZoomManager.shared.zoomIn()
                    }
                    .keyboardShortcut("=", modifiers: .command)
                    
                    Button(loc.isSpanish ? "Reducir tamaño de letra" : "Zoom Out") {
                        TextZoomManager.shared.zoomOut()
                    }
                    .keyboardShortcut("-", modifiers: .command)
                    
                    Button(loc.isSpanish ? "Restablecer tamaño (100%)" : "Reset Zoom") {
                        TextZoomManager.shared.resetZoom()
                    }
                    .keyboardShortcut("0", modifiers: .command)
                }
            }
            // Override the standard Quit menu item to support Menu Bar Only mode
            CommandGroup(replacing: .appTermination) {
                Button(loc.isSpanish ? "Salir de Splash Monitor" : "Quit Splash Monitor") {
                    if menuBarOnlyMode && showMenuBarIcon {
                        // Hide to menu bar instead of quitting
                        NSApp.setActivationPolicy(.accessory)
                        for window in NSApp.windows {
                            window.orderOut(nil)
                        }
                    } else {
                        appDelegate.isReallyQuitting = true
                        NSApp.terminate(nil)
                    }
                }
                .keyboardShortcut("q", modifiers: .command)
                
                if menuBarOnlyMode && showMenuBarIcon {
                    Divider()
                    Button(loc.isSpanish ? "Salir completamente" : "Quit Completely") {
                        appDelegate.isReallyQuitting = true
                        NSApp.terminate(nil)
                    }
                    .keyboardShortcut("q", modifiers: [.command, .option])
                }
            }
        }
        
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
