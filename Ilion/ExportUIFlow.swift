//
//  ExportUIFlow.swift
//  Ilion
//
//  Created by Tamas Lustyik on 2017. 05. 19..
//  Copyright © 2017. Tamas Lustyik. All rights reserved.
//

import Cocoa

class ExportUIFlow {

    enum State {
        case idle, choosingDestination, exporting
    }
    
    private var state: State = .idle
    private var window: NSWindow!
    private(set) var destinationURL: URL!
    
    var isActive: Bool {
        return state != .idle
    }
    
    var onDestinationSelected: (() -> Void)?
    var onExportStarted: (() -> Void)?
    var onExportFailed: (() -> Void)?
    var onExportFinished: (() -> Void)?
    
    func start(with window: NSWindow) {
        guard state == .idle else {
            return
        }
        
        state = .choosingDestination
        self.window = window
        
        showDestinationSelectionDialog()
    }
    
    func reportExportResult(success: Bool) {
        guard state == .exporting else {
            return
        }
        
        if success {
            onExportFinished?()
        }
        else {
            onExportFailed?()
        }
        
        reset()
    }
    
    private func reset() {
        state = .idle
        destinationURL = nil
        window = nil
    }
    
    private func showDestinationSelectionDialog() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "Choose"
        
        panel.beginSheetModal(for: window!) { response in
            if response == NSFileHandlingPanelOKButton {
                self.destinationURL = panel.url!
                self.state = .exporting
                self.onExportStarted?()
            }
            
            self.reset()
        }
    }
    
    private func showExportFailedDialog() {
        let alert = NSAlert()
        alert.messageText = "Export failed"
        alert.informativeText = "An unknown error has occurred. Please check whether you have write permissions to the selected directory."
        alert.addButton(withTitle: "OK")
        alert.buttons.last!.keyEquivalent = "\u{1b}"
        
        alert.beginSheetModal(for: window!)
    }
    
}

