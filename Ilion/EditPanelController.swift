//
//  EditPanelController.swift
//  Ilion
//
//  Created by Tamas Lustyik on 2017. 03. 15..
//  Copyright © 2017. Tamas Lustyik. All rights reserved.
//

import Cocoa


protocol EditPanelControllerDelegate: class {
    func editPanelController(_ sender: EditPanelController,
                             validateOverride override: Translation,
                             for keyPath: LocKeyPath) throws
    func editPanelController(_ sender: EditPanelController,
                             didCommitOverride override: Translation,
                             for keyPath: LocKeyPath)
    func editPanelController(_ sender: EditPanelController, didCancelOverrideFor keyPath: LocKeyPath)
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
            updateUI()
        }
    }
    private var keyPath: LocKeyPath!
    
    override var windowNibName: String? {
        return "EditPanel"
    }
    
    override func awakeFromNib() {
        updateUI()
    }
    
    func configure(with entry: StringsEntry, keyPath: LocKeyPath) {
        self.entry = entry
        self.keyPath = keyPath
    }
    
    private func updateUI() {
        resourceLabel.stringValue = keyPath.bundleURI + " > " + keyPath.resourceURI
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
        else if case .dynamic(let format) = entry.translation {
            dynamicBaseFormatLabel.stringValue = format.baseFormat
            dynamicVariableSelector.segmentCount = format.variableSpecs.count
            
            for item in format.variableSpecs.enumerated() {
                dynamicVariableSelector.setLabel(item.element.key, forSegment: item.offset)
            }
            
            updateVariablePanel()

            staticPanelHeight.priority = NSLayoutPriorityDefaultLow
            dynamicPanelHeight.priority = NSLayoutPriorityDefaultHigh
        }
    }
    
    private func updateVariablePanel() {
        guard
            case .dynamic(let format) = entry.translation,
            let varName = dynamicVariableSelector.label(forSegment: dynamicVariableSelector.selectedSegment),
            let varSpec = format.variableSpecs[varName]
        else {
            return
        }
        
        dynamicTokenNameLabel.stringValue = "Placeholder: %\(varSpec.valueType)"
        
        let menu = NSMenu(title: "Plural rules")
        varSpec.ruleSpecs.forEach { key, _ in
            let item = NSMenuItem(title: key.rawValue, action: #selector(pluralRuleChanged(_:)), keyEquivalent: "")
            menu.addItem(item)
        }
        dynamicPluralRulePopupButton.menu = menu
        
        updateVariableTranslation()
    }
    
    private func updateVariableTranslation() {
        guard
            case .dynamic(let format) = entry.translation,
            let varName = dynamicVariableSelector.label(forSegment: dynamicVariableSelector.selectedSegment),
            let varSpec = format.variableSpecs[varName],
            let ruleName = dynamicPluralRulePopupButton.selectedItem?.title,
            let rule = PluralRule(rawValue: ruleName)
        else {
            return
        }
        
        dynamicTranslatedTextLabel.stringValue = varSpec.ruleSpecs[rule] ?? ""

        if let override = entry.override, case .dynamic(let overrideFormat) = override {
            dynamicOverrideTextField.stringValue = overrideFormat.variableSpecs[varName]?.ruleSpecs[rule] ?? ""
        } else {
            dynamicOverrideTextField.stringValue = ""
        }

    }
    
    private func showAlert(for error: OverrideError) {
        let alert = NSAlert()
        alert.messageText = "Could not apply override"
        
        switch error {
        case .invalidOriginalFormat:
            alert.informativeText = "The original string has an invalid format."
        case .ambiguousVariableTypesInOverride(let pos, let typeA, let typeB):
            alert.informativeText = "Conflicting placeholder types for argument #\(pos): '\(typeA)' and '\(typeB)'."
        case .unspecifiedVariableInOverride(let pos):
            alert.informativeText = "One or more placeholders refer to argument #\(pos) but the original string doesn't specify that many."
        default:
            return
        }

        alert.addButton(withTitle: "Fix")
        alert.beginSheetModal(for: window!)
    }
    
    @IBAction private func applyClicked(_ sender: Any) {
        let override: Translation = .static(staticOverrideTextField.stringValue)
        do {
            try delegate?.editPanelController(self, validateOverride: override, for: keyPath)
            delegate?.editPanelController(self, didCommitOverride: override, for: keyPath)
        }
        catch let error as OverrideError {
            showAlert(for: error)
        }
        catch {
        }
    }
    
    @IBAction private func cancelClicked(_ sender: Any) {
        delegate?.editPanelController(self, didCancelOverrideFor: keyPath)
    }
    
    @IBAction private func variableChanged(_ sender: Any) {
        updateVariablePanel()
    }
    
    @IBAction private func pluralRuleChanged(_ sender: Any) {
        updateVariableTranslation()
    }
}
