//
//  L10nEditPanelController.swift
//  Visual10n
//
//  Created by Tamas Lustyik on 2017. 03. 15..
//  Copyright © 2017. Tamas Lustyik. All rights reserved.
//

import Cocoa

protocol IlionEditPanelControllerDelegate: class {
    func editPanelController(_ sender: IlionEditPanelController, didSubmitTranslation: String, forKey key: String)
    func editPanelController(_ sender: IlionEditPanelController, didCancelTranslationForKey key: String)
}

class IlionEditPanelController: NSWindowController {
    @IBOutlet private weak var resourceLabel: NSTextField!
    @IBOutlet private weak var keyLabel: NSTextField!
    @IBOutlet private weak var sourceTextLabel: NSTextField!
    @IBOutlet private weak var translatedTextLabel: NSTextField!
    @IBOutlet private weak var overrideTextLabel: NSTextField!
    
    weak var delegate: IlionEditPanelControllerDelegate? = nil
    
    var entry: StringsEntry! {
        didSet {
            guard resourceLabel != nil else {
                return
            }
            updateLabels()
        }
    }
    
    override var windowNibName: String? {
        return "IlionEditPanel"
    }
    
    override func awakeFromNib() {
        updateLabels()
    }
    
    func configure(with entry: StringsEntry) {
        self.entry = entry
    }
    
    func updateLabels() {
        resourceLabel.stringValue = entry.resourceName
        keyLabel.stringValue = entry.locKey
        sourceTextLabel.stringValue = entry.sourceText
        translatedTextLabel.stringValue = entry.translatedText
        overrideTextLabel.stringValue = entry.overrideText ?? ""
    }
    
    @IBAction func applyClicked(_ sender: Any) {
        delegate?.editPanelController(self, didSubmitTranslation: overrideTextLabel.stringValue, forKey: entry.locKey)
    }
    
    @IBAction func cancelClicked(_ sender: Any) {
        delegate?.editPanelController(self, didCancelTranslationForKey: entry.locKey)
    }
    
}
