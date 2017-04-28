//
//  EditPanelController.swift
//  Ilion
//
//  Created by Tamas Lustyik on 2017. 03. 15..
//  Copyright © 2017. Tamas Lustyik. All rights reserved.
//

import Cocoa

protocol EditPanelControllerDelegate: class {
    func editPanelController(_ sender: EditPanelController, didCommitTranslation: String, for keyPath: LocKeyPath)
    func editPanelController(_ sender: EditPanelController, didCancelTranslationFor keyPath: LocKeyPath)
}

class EditPanelController: NSWindowController {
    @IBOutlet private weak var resourceLabel: NSTextField!
    @IBOutlet private weak var keyLabel: NSTextField!
    @IBOutlet private weak var sourceTextLabel: NSTextField!
    @IBOutlet private weak var translatedTextLabel: NSTextField!
    @IBOutlet private weak var overrideTextLabel: NSTextField!
    
    weak var delegate: EditPanelControllerDelegate? = nil
    
    private var entry: StringsEntry! {
        didSet {
            guard resourceLabel != nil else {
                return
            }
            updateLabels()
        }
    }
    private var keyPath: LocKeyPath!
    
    override var windowNibName: String? {
        return "IlionEditPanel"
    }
    
    override func awakeFromNib() {
        updateLabels()
    }
    
    func configure(with entry: StringsEntry, keyPath: LocKeyPath) {
        self.entry = entry
        self.keyPath = keyPath
    }
    
    private func updateLabels() {
        resourceLabel.stringValue = keyPath.bundleURI + " / " + keyPath.resourceURI
        keyLabel.stringValue = entry.locKey
        sourceTextLabel.stringValue = entry.sourceText
        translatedTextLabel.stringValue = entry.translatedText
        overrideTextLabel.stringValue = entry.overrideText ?? ""
    }
    
    @IBAction private func applyClicked(_ sender: Any) {
        delegate?.editPanelController(self, didCommitTranslation: overrideTextLabel.stringValue, for: keyPath)
    }
    
    @IBAction private func cancelClicked(_ sender: Any) {
        delegate?.editPanelController(self, didCancelTranslationFor: keyPath)
    }
    
}
