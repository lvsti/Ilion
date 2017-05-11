//
//  Ilion.swift
//  Ilion
//
//  Created by Tamas Lustyik on 2017. 03. 15..
//  Copyright © 2017. Tamas Lustyik. All rights reserved.
//

import Foundation

public protocol IlionDelegate: class {
    func ilionDidTerminate(_ sender: Ilion)
}

@objc public final class Ilion: NSObject {
    fileprivate var browserWindowController: BrowserWindowController? = nil
    fileprivate var editPanelController: EditPanelController? = nil
    
    private var observer: NSObjectProtocol? = nil
    
    public weak var delegate: IlionDelegate? = nil

    public static let shared = Ilion()
    
    private override init() {
        super.init()
        let notifName = Notification.Name(rawValue: "IlionDidRegisterBundle")
        observer = NotificationCenter.default.addObserver(forName: notifName, object: nil, queue: nil) { [weak self] _ in
            self?.browserWindowController?.configure(with: StringsManager.defaultManager.db)
        }
    }
    
    public func start() {
        browserWindowController = BrowserWindowController()
        browserWindowController?.delegate = self
        browserWindowController?.window?.makeKeyAndOrderFront(self)
        
        browserWindowController?.configure(with: StringsManager.defaultManager.db)
    }
    
}

extension Ilion: BrowserWindowControllerDelegate {
    
    func browserWindow(_ sender: BrowserWindowController,
                       willStartEditingEntryFor keyPath: LocKeyPath) {
        guard editPanelController == nil else {
            return
        }
        
        editPanelController = EditPanelController()
        editPanelController?.configure(with: StringsManager.defaultManager.entry(for: keyPath)!,
                                       keyPath: keyPath)
        editPanelController?.delegate = self
        
        browserWindowController?.window?.beginSheet(editPanelController!.window!)
    }
    
    func browserWindow(_ sender: BrowserWindowController,
                       didRemoveOverrideFor keyPath: LocKeyPath) {
        StringsManager.defaultManager.removeOverride(for: keyPath)
        sender.configure(with: StringsManager.defaultManager.db)
    }
    
    func browserWindowDidResetOverrides(_ sender: BrowserWindowController) {
        StringsManager.defaultManager.removeAllOverrides()
        sender.configure(with: StringsManager.defaultManager.db)
    }

    func browserWindowWillClose(_ sender: BrowserWindowController) {
        browserWindowController = nil
        delegate?.ilionDidTerminate(self)
    }
    
}

extension Ilion: EditPanelControllerDelegate {
    
    func editPanelController(_ sender: EditPanelController,
                             validateOverride override: Translation,
                             for keyPath: LocKeyPath) throws {
        guard let entry = StringsManager.defaultManager.entry(for: keyPath) else {
            throw OverrideError.invalidKeyPath
        }

        try StringsManager.defaultManager.validateOverride(override, for: entry.translation)
    }
    
    func editPanelController(_ sender: EditPanelController,
                             didCancelOverrideFor keyPath: LocKeyPath) {
        browserWindowController?.window?.endSheet(sender.window!)
        editPanelController = nil
    }
    
    func editPanelController(_ sender: EditPanelController,
                             didCommitOverride override: Translation,
                             for keyPath: LocKeyPath) {
        browserWindowController?.window?.endSheet(sender.window!)
        editPanelController = nil
        
        try! StringsManager.defaultManager.addOverride(override, for: keyPath)
        browserWindowController?.configure(with: StringsManager.defaultManager.db)
    }
    
}

