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
    @IBOutlet private weak var commentLabel: NSTextField!
    @IBOutlet private weak var translatedTextView: NSTextView!
    @IBOutlet private weak var translatedTextViewAlignToTop: NSLayoutConstraint!
    @IBOutlet private weak var translatedTextPluralRuleSelector: NSSegmentedControl!

    @IBOutlet private weak var overridePluralRuleView: NSView!
    @IBOutlet fileprivate weak var overrideTextView: NSTextView!
    @IBOutlet private weak var overrideTextViewAlignToRight: NSLayoutConstraint!
    @IBOutlet private weak var overrideTextViewAlignToTop: NSLayoutConstraint!
    @IBOutlet private weak var overridePluralRuleSelector: NSSegmentedControl!
    @IBOutlet private weak var overrideAddPluralRuleButton: NSPopUpButton!
    @IBOutlet private weak var overrideRemovePluralRuleButton: NSButton!
    
    fileprivate var viewModel: EditPanelViewModel!
    
    weak var delegate: EditPanelControllerDelegate? = nil
    
    override var windowNibName: String? {
        return "EditPanel"
    }
    
    override func awakeFromNib() {
        translatedTextView.textContainerInset = NSSize(width: 0, height: 1)
        translatedTextView.textContainer?.lineFragmentPadding = 0
        
        overrideTextView.textContainerInset = NSSize(width: 0, height: 3)
        overrideTextView.textStorage?.delegate = self
        
        if viewModel != nil {
            updateUI()
        }
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        overrideTextView.selectAll(self)
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
        commentLabel.stringValue = viewModel.commentText
        
        updateTranslationUI()
        updateOverrideUI()
    }
    
    fileprivate func updateTranslationUI() {
        let range = NSRange(location: 0, length: (translatedTextView.string ?? "").length)
        let formattedText = NSAttributedString(string: viewModel.translatedText).applyingTokenMarkup
        translatedTextView.textStorage?.replaceCharacters(in: range, with: formattedText)
        
        translatedTextPluralRuleSelector.isHidden = !viewModel.showsTranslationPlurals
        translatedTextViewAlignToTop.priority = viewModel.showsTranslationPlurals ?
            NSLayoutPriorityDefaultLow : NSLayoutPriorityDefaultHigh

        translatedTextPluralRuleSelector.segmentCount = viewModel.translationPluralRuleNames.count
        for item in viewModel.translationPluralRuleNames.enumerated() {
            translatedTextPluralRuleSelector.setLabel(item.element, forSegment: item.offset)
        }
        translatedTextPluralRuleSelector.selectedSegment = viewModel.translationPluralRulesSelectedIndex
    }
    
    fileprivate func updateOverrideUI() {
        setOverridePluralsVisible(viewModel.showsOverridePlurals)

        let range = NSRange(location: 0, length: (overrideTextView.string ?? "").length)
        let formattedText = NSAttributedString(string: viewModel.overrideText).applyingTokenMarkup
        overrideTextView.textStorage?.replaceCharacters(in: range, with: formattedText)
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
            overrideTextViewAlignToTop.priority = NSLayoutPriorityDefaultLow
            overrideTextViewAlignToRight.priority = NSLayoutPriorityDefaultLow
        }
        else {
            overrideTextViewAlignToTop.priority = NSLayoutPriorityDefaultHigh
            overrideTextViewAlignToRight.priority = NSLayoutPriorityDefaultHigh
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
        overrideTextView.selectAll(self)
    }

    @IBAction private func removeOverridePluralRuleClicked(_ sender: Any) {
        viewModel.removeSelectedOverridePluralRule()
    }
    
}

extension EditPanelController: NSTextViewDelegate {
    
    func textDidChange(_ obj: Notification) {
        guard
            let control = obj.object as? NSTextView,
            control == overrideTextView
        else {
            return
        }
        
        viewModel.updateOverrideText(overrideTextView.textStorage?.removingTokenMarkup.string ?? "")
    }

    func textView(_ view: NSTextView, writablePasteboardTypesFor cell: NSTextAttachmentCellProtocol, at charIndex: Int) -> [String] {
        return [NSFileContentsPboardType]
    }
    
    func textView(_ view: NSTextView, write cell: NSTextAttachmentCellProtocol, at charIndex: Int, to pboard: NSPasteboard, type: String) -> Bool {
        if type == NSFileContentsPboardType, let wrapper = cell.attachment?.fileWrapper {
            pboard.write(wrapper)
        }
        return true
    }

}

extension EditPanelController: NSTextStorageDelegate {
    
    override func textStorageWillProcessEditing(_ notification: Notification) {
        guard let textStorage = notification.object as? NSTextStorage else {
            return
        }
        
        textStorage.applyTokenMarkup()
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
