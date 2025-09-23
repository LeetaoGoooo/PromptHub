//
//  SearchWindowController.swift
//  prompthub
//
//  Created by leetao on 2025/4/5.
//

import AppKit
import SwiftUI
import SwiftData

class SearchWindowController: NSWindowController, NSWindowDelegate {
    private var modelContainer: ModelContainer
    
    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        let panel = ActivablePanel(
            contentRect: NSMakeRect(0, 0, 600, 400),
            styleMask: [.fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        super.init(window: panel)
        setupWindow()
    }
    
    override init(window: NSWindow?) {
        self.modelContainer = PreviewData.previewContainer
        super.init(window: window)
    }
    
    convenience init() {
        let panel = ActivablePanel(
            contentRect: NSMakeRect(0, 0, 600, 400),
            styleMask: [.fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        self.init(window: panel)
        setupWindow()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        setupWindow()
    }
    
    private func setupWindow() {
        guard let panel = window as? ActivablePanel else { return }
        
        panel.styleMask = [.titled, .fullSizeContentView]
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.delegate = self
        panel.hidesOnDeactivate = false
        panel.acceptsMouseMovedEvents = true
    }
    
    func showWindow() {
        guard let panel = window as? ActivablePanel else { return }

        // This may not be necessary every time, but is safe.
        updateContentView()

        // Use the modern, correct way to activate the app.
        if #available(macOS 14.0, *) {
            NSRunningApplication.current.activate()
        } else {
            NSRunningApplication.current.activate(options: .activateIgnoringOtherApps)
        }
        
        // Now make the window key and bring it to the front.
        panel.makeKeyAndOrderFront(nil)
        
        // And finally, give focus to the content.
        // Defer to the next runloop to ensure the panel is already key.
        if let view = contentViewController?.view {
            DispatchQueue.main.async {
                panel.makeFirstResponder(view)
            }
        }
        
        // Center it on the screen.
        panel.center()
        
        // Prefer checking the window state instead of NSApp.isActive for menu-bar style apps.
        print("Window shown. isKeyWindow=\(panel.isKeyWindow), isMainWindow=\(panel.isMainWindow), appActive=\(NSApp.isActive)")
    }
    
    private func updateContentView() {
        print("Updating content view")
        // 创建 SwiftUI 视图
        let searchView = SearchView(onClose: { [weak self] in
            self?.closeWindow()
        })
        .modelContainer(modelContainer)
        
        // 创建托管视图
        let hostingController = NSHostingController(rootView: searchView)
        
        // 设置内容视图
        contentViewController = hostingController
        
        // 设置窗口大小
        guard let panel = window as? ActivablePanel else { 
            print("Failed to get panel in updateContentView")
            return 
        }
        panel.setContentSize(NSSize(width: 600, height: 400))
        print("Content view updated")
    }
    
    private func closeWindow() {
        guard let panel = window as? ActivablePanel else { return }
        panel.orderOut(nil)
    }
    
    // MARK: - NSWindowDelegate
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // 隐藏而不是关闭窗口，以便重复使用
        sender.orderOut(nil)
        return false
    }
}
