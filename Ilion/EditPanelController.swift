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
    @IBOutlet private weak var translatedTextLabel: NSTextField!
    @IBOutlet private weak var translatedTextLabelAlignToTop: NSLayoutConstraint!
    @IBOutlet private weak var translatedTextPluralRuleSelector: NSSegmentedControl!

    @IBOutlet private weak var overridePluralRuleView: NSView!
    @IBOutlet fileprivate weak var overrideTextField: NSTextField!
    @IBOutlet private weak var overrideTextFieldAlignToRight: NSLayoutConstraint!
    @IBOutlet private weak var overrideTextFieldAlignToTop: NSLayoutConstraint!
    @IBOutlet private weak var overridePluralRuleSelector: NSSegmentedControl!
    @IBOutlet private weak var overrideAddPluralRuleButton: NSPopUpButton!
    @IBOutlet private weak var overrideRemovePluralRuleButton: NSButton!
    
    fileprivate var viewModel: EditPanelViewModel!
    
    weak var delegate: EditPanelControllerDelegate? = nil
    
    override var windowNibName: String? {
        return "EditPanel"
    }
    
    override func awakeFromNib() {
        if viewModel != nil {
            updateUI()
        }
    }
    
    func configure(with entry: StringsEntry, keyPath: LocKeyPath) {
        viewModel = EditPanelViewModel(entry: entry, keyPath: keyPath)
        viewModel.delegate = self
        
        guard resourceLabel != nil else {
            return
        }
        updateUI()
    }
    
    private func updateUI() {
        resourceLabel.stringValue = viewModel.resourceName
        keyLabel.stringValue = viewModel.keyName
        
        updateTranslationUI()
        updateOverrideUI()
    }
    
    fileprivate func updateTranslationUI() {
        translatedTextLabel.stringValue = viewModel.translatedText
        
        translatedTextPluralRuleSelector.isHidden = !viewModel.showsTranslationPlurals
        translatedTextLabelAlignToTop.priority = viewModel.showsTranslationPlurals ?
            NSLayoutPriorityDefaultLow : NSLayoutPriorityDefaultHigh

        translatedTextPluralRuleSelector.segmentCount = viewModel.translationPluralRuleNames.count
        for item in viewModel.translationPluralRuleNames.enumerated() {
            translatedTextPluralRuleSelector.setLabel(item.element, forSegment: item.offset)
        }
        translatedTextPluralRuleSelector.selectedSegment = viewModel.translationPluralRulesSelectedIndex
    }
    
    fileprivate func updateOverrideUI() {
        setOverridePluralsVisible(viewModel.showsOverridePlurals)
        overrideTextField.stringValue = viewModel.overrideText
        overrideRemovePluralRuleButton.isEnabled = viewModel.canRemoveSelectedOverridePluralRule
        
        overridePluralRuleSelector.segmentCount = viewModel.overridePluralRuleNames.count
        for item in viewModel.overridePluralRuleNames.enumerated() {
            overridePluralRuleSelector.setLabel(item.element, forSegment: item.offset)
        }
        overridePluralRuleSelector.selectedSegment = viewModel.overridePluralRulesSelectedIndex
        
        overrideAddPluralRuleButton.isEnabled = !viewModel.remainingPluralRuleNames.isEmpty
        
        let menu = NSMenu(title: "Plural rules")

        let menuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        menuItem.image = NSImage(named: NSImageNameAddTemplate)
        menu.addItem(menuItem)

        for item in viewModel.remainingPluralRuleNames.enumerated() {
            let menuItem = NSMenuItem(title: item.element, action: #selector(overridePluralRuleAdded(_:)), keyEquivalent: "")
            menuItem.tag = item.offset
            menu.addItem(menuItem)
        }
        overrideAddPluralRuleButton.cell?.menu = menu
    }
    
    private func setOverridePluralsVisible(_ isVisible: Bool) {
        overridePluralRuleView.isHidden = !isVisible
        overrideRemovePluralRuleButton.isHidden = !isVisible
        
        if isVisible {
            overrideTextFieldAlignToTop.priority = NSLayoutPriorityDefaultLow
            overrideTextFieldAlignToRight.priority = NSLayoutPriorityDefaultLow
        }
        else {
            overrideTextFieldAlignToTop.priority = NSLayoutPriorityDefaultHigh
            overrideTextFieldAlignToRight.priority = NSLayoutPriorityDefaultHigh
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

        alert.addButton(withTitle: "OK")
        alert.beginSheetModal(for: window!)
    }
    
    @IBAction private func applyClicked(_ sender: Any) {
        do {
            let override = try viewModel.validatedOverride()
            delegate?.editPanelController(self, didCommitOverride: override, for: viewModel.keyPath)
        }
        catch let error as OverrideError {
            showAlert(for: error)
        }
        catch {
        }
    }
    
    @IBAction private func cancelClicked(_ sender: Any) {
        delegate?.editPanelController(self, didCancelOverrideFor: viewModel.keyPath)
    }
    
    @IBAction private func translationPluralRuleChanged(_ sender: Any) {
        viewModel.setTranslationPluralRulesSelectedIndex(translatedTextPluralRuleSelector.selectedSegment)
    }

    @IBAction private func overridePluralRuleChanged(_ sender: Any) {
        viewModel.setOverridePluralRulesSelectedIndex(overridePluralRuleSelector.selectedSegment)
    }

    @IBAction private func overridePluralRuleAdded(_ sender: NSMenuItem) {
        viewModel.addRemainingOverridePluralRule(at: sender.tag)
        overrideTextField.selectText(self)
    }

    @IBAction private func removeOverridePluralRuleClicked(_ sender: Any) {
        viewModel.removeSelectedOverridePluralRule()
    }
    
}

extension EditPanelController: NSTextFieldDelegate {
    
    override func controlTextDidChange(_ obj: Notification) {
        guard
            let control = obj.object as? NSTextField,
            control == overrideTextField
        else {
            return
        }
        
        viewModel.updateOverrideText(overrideTextField.stringValue)
    }
    
}

extension EditPanelController: EditPanelViewModelDelegate {
    
    func viewModelDidUpdateTranslation(_ sender: EditPanelViewModel) {
        updateTranslationUI()
    }
    
    func viewModelDidUpdateOverride(_ sender: EditPanelViewModel) {
        updateOverrideUI()
    }
    
}
