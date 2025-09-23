//
//  ActivablePanel.swift
//  prompthub
//
//  Created by leetao on 2025/4/5.
//

import AppKit

/// A custom NSPanel subclass that can become key window even when the app is not active.
/// This is especially useful for menu bar apps (LSUIElement=true) that need to show
/// windows that can receive keyboard focus.
class ActivablePanel: NSPanel {
    // Override this property to allow the panel to become key window
    // even when the app is inactive
    override var canBecomeKey: Bool {
        return true
    }
    
    // Override this property to allow the panel to become main window
    override var canBecomeMain: Bool {
        return true
    }
}