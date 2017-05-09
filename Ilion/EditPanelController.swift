//
//  EditPanelController.swift
//  Ilion
//
//  Created by Tamas Lustyik on 2017. 03. 15..
//  Copyright © 2017. Tamas Lustyik. All rights reserved.
//

import Cocoa


enum OverrideValidationError: Error {
    case invalidSourceFormat
    case ambiguousTypes
    case argumentNotFound(position: Int)
    case argumentTypeMismatch(position: Int, expected: String, got: String)
}

protocol EditPanelControllerDelegate: class {
    func editPanelController(_ sender: EditPanelController, didCommitTranslation: String, for keyPath: LocKeyPath)
    func editPanelController(_ sender: EditPanelController, didCancelTranslationFor keyPath: LocKeyPath)
}

final class EditPanelController: NSWindowController {
    @IBOutlet private weak var resourceLabel: NSTextField!
    @IBOutlet private weak var keyLabel: NSTextField!
    
    // static panel
    @IBOutlet weak var staticTranslatedTextLabel: NSTextField!
    @IBOutlet weak var staticOverrideTextField: NSTextField!
    @IBOutlet weak var staticPanelHeight: NSLayoutConstraint!
    
    // dynamic panel
    @IBOutlet weak var dynamicBaseFormatLabel: NSTextField!
    @IBOutlet weak var dynamicVariableSelector: NSSegmentedControl!
    @IBOutlet weak var dynamicPluralRulePopupButton: NSPopUpButton!
    @IBOutlet weak var dynamicTokenNameLabel: NSTextField!
    @IBOutlet weak var dynamicTranslatedTextLabel: NSTextField!
    @IBOutlet weak var dynamicOverrideTextField: NSTextField!
    @IBOutlet weak var dynamicPanelHeight: NSLayoutConstraint!
    
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
        return "EditPanel"
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
        
        if case .static(let translatedText) = entry.translation {
            staticTranslatedTextLabel.stringValue = translatedText
            if let override = entry.override, case .static(let overrideText) = override {
                staticOverrideTextField.stringValue = overrideText
            } else {
                staticOverrideTextField.stringValue = ""
            }
            staticPanelHeight.priority = NSLayoutPriorityDefaultHigh
            dynamicPanelHeight.priority = NSLayoutPriorityDefaultLow
        }
    }
    
    private func validateOverride() throws {
        guard let originalTypes = staticTranslatedTextLabel.stringValue.formatPlaceholderTypes else {
            throw OverrideValidationError.invalidSourceFormat
        }

        guard let overrideTypes = staticOverrideTextField.stringValue.formatPlaceholderTypes else {
            throw OverrideValidationError.ambiguousTypes
        }
        
        for (key, value) in overrideTypes {
            guard let originalValue = originalTypes[key] else {
                throw OverrideValidationError.argumentNotFound(position: key)
            }
            if value != originalValue {
                throw OverrideValidationError.argumentTypeMismatch(position: key,
                                                                   expected: originalValue,
                                                                   got: value)
            }
        }
    }
    
    private func showAlert(for error: OverrideValidationError) {
        let alert = NSAlert()
        alert.messageText = "The override string is invalid"
        
        switch error {
        case .invalidSourceFormat:
            return
        case .ambiguousTypes:
            alert.informativeText = "The placeholder types are ambiguous."
        case .argumentNotFound(let pos):
            alert.informativeText = "One or more placeholders refer to argument #\(pos) but the original string doesn't specify that many."
        case .argumentTypeMismatch(let pos, let expected, let got):
            alert.informativeText = "The placeholder type for argument #\(pos) is given as '\(got)' but it is '\(expected)' the original string."
        }

        alert.addButton(withTitle: "Fix")
        alert.beginSheetModal(for: window!)
    }
    
    @IBAction private func applyClicked(_ sender: Any) {
        do {
            try validateOverride()
            delegate?.editPanelController(self, didCommitTranslation: staticOverrideTextField.stringValue, for: keyPath)
        }
        catch let error as OverrideValidationError {
            showAlert(for: error)
        }
        catch {
        }
    }
    
    @IBAction private func cancelClicked(_ sender: Any) {
        delegate?.editPanelController(self, didCancelTranslationFor: keyPath)
    }
    
}
