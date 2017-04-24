//
//  L10nEditorCoordinator.swift
//  Visual10n
//
//  Created by Tamas Lustyik on 2017. 03. 15..
//  Copyright © 2017. Tamas Lustyik. All rights reserved.
//

import Foundation

public protocol IlionDelegate: class {
    func ilionDidTerminate(_ sender: Ilion)
}

public final class Ilion {
    fileprivate var browserWindowController: IlionBrowserWindowController? = nil
    fileprivate var editPanelController: IlionEditPanelController? = nil
    
    public weak var delegate: IlionDelegate? = nil
    
    public init() {
    }
    
    public func start() {
        browserWindowController = IlionBrowserWindowController()
        browserWindowController?.delegate = self
        browserWindowController?.window?.makeKeyAndOrderFront(self)
        
        browserWindowController?.configure(with: [StringsEntry](StringsManager.defaultManager.strings.values))
    }
    
}

extension Ilion: IlionBrowserWindowControllerDelegate {
    
    func browserWindow(_ sender: IlionBrowserWindowController,
                       willStartEditingEntry entry: StringsEntry) {
        guard editPanelController == nil else {
            return
        }
        
        editPanelController = IlionEditPanelController()
        editPanelController?.configure(with: entry)
        editPanelController?.delegate = self
        
        browserWindowController?.window?.beginSheet(editPanelController!.window!)
    }
    
    func browserWindow(_ sender: IlionBrowserWindowController,
                       didRemoveOverrideForEntry entry: StringsEntry) {
        StringsManager.defaultManager.removeOverride(for: entry.locKey)
        sender.configure(with: [StringsEntry](StringsManager.defaultManager.strings.values))
    }
    
    func browserWindowDidResetOverrides(_ sender: IlionBrowserWindowController) {
        StringsManager.defaultManager.removeAllOverrides()
        sender.configure(with: [StringsEntry](StringsManager.defaultManager.strings.values))
    }

    func browserWindowWillClose(_ sender: IlionBrowserWindowController) {
        browserWindowController = nil
        delegate?.ilionDidTerminate(self)
    }
    
}

extension Ilion: IlionEditPanelControllerDelegate {
    
    func editPanelController(_ sender: IlionEditPanelController,
                             didCancelTranslationFor keyPath: LocKeyPath) {
        browserWindowController?.window?.endSheet(sender.window!)
        editPanelController = nil
    }
    
    func editPanelController(_ sender: IlionEditPanelController,
                             didCommitTranslation translation: String,
                             for keyPath: LocKeyPath) {
        browserWindowController?.window?.endSheet(sender.window!)
        editPanelController = nil
        
        StringsManager.defaultManager.addOverride(translation, for: keyPath)
        browserWindowController?.configure(with: StringsManager.defaultManager.db)
    }
    
}

