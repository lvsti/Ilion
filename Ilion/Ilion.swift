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

public final class Ilion {
    fileprivate var browserWindowController: BrowserWindowController? = nil
    fileprivate var editPanelController: EditPanelController? = nil
    
    private var observer: NSObjectProtocol? = nil
    
    public weak var delegate: IlionDelegate? = nil

    public init() {
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
                             didCancelTranslationFor keyPath: LocKeyPath) {
        browserWindowController?.window?.endSheet(sender.window!)
        editPanelController = nil
    }
    
    func editPanelController(_ sender: EditPanelController,
                             didCommitTranslation translation: String,
                             for keyPath: LocKeyPath) {
        browserWindowController?.window?.endSheet(sender.window!)
        editPanelController = nil
        
        StringsManager.defaultManager.addOverride(translation, for: keyPath)
        browserWindowController?.configure(with: StringsManager.defaultManager.db)
    }
    
}

