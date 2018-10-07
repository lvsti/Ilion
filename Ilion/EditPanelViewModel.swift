//
//  EditPanelViewModel.swift
//  Ilion
//
//  Created by Tamas Lustyik on 2017. 05. 13..
//  Copyright © 2017. Tamas Lustyik. All rights reserved.
//

import Foundation

protocol EditPanelViewModelDelegate: class {
    func viewModelDidUpdateTranslation(_ sender: EditPanelViewModel)
    func viewModelDidUpdateOverride(_ sender: EditPanelViewModel)
}


class EditPanelViewModel {

    private(set) var entry: StringsEntry
    private(set) var keyPath: LocKeyPath

    // outputs
    private(set) var resourceName: String = ""
    private(set) var keyName: String = ""
    private(set) var commentText: String = ""
    
    var showsTranslationPlurals: Bool {
        if case .static = entry.translation {
            return false
        }
        return true
    }
    var translationPluralRuleNames: [String] { return translationPluralRules.map { $0.rawValue } }
    private(set) var translationPluralRulesSelectedIndex: Int = 0
    private(set) var translatedText: String = ""
    
    private(set) var showsOverridePlurals: Bool = false
    private(set) var canRemoveSelectedOverridePluralRule: Bool = false
    var overridePluralRuleNames: [String] { return overridePluralRules.map { $0.rawValue } }
    private(set) var overridePluralRulesSelectedIndex: Int = 0
    private(set) var overrideText: String = ""
    var remainingPluralRuleNames: [String] { return remainingPluralRules.map { $0.rawValue } }

    // private
    private var overrideTexts: [PluralRule: String] = [:]
    private let pluralRuleSort: (PluralRule, PluralRule) -> Bool = {
        PluralRule.allCases.firstIndex(of: $0)! < PluralRule.allCases.firstIndex(of: $1)!
    }

    private var translationPluralRules: [PluralRule] {
        switch entry.translation {
        case .static: return [.other]
        case .dynamic(let format): return format.usedPluralRules.sorted(by: pluralRuleSort)
        }
    }
    
    private var overridePluralRules: [PluralRule] {
        return overrideTexts.keys.sorted(by: pluralRuleSort)
    }
    
    private var remainingPluralRules: [PluralRule] {
        return Set(PluralRule.allCases).subtracting(overridePluralRules).sorted(by: pluralRuleSort)
    }
    
    weak var delegate: EditPanelViewModelDelegate? = nil
    
    init(entry: StringsEntry, keyPath: LocKeyPath) {
        self.entry = entry
        self.keyPath = keyPath
        
        setUp()
    }
    
    // MARK: - state update:
    
    private func setUp() {
        resourceName = keyPath.bundleURI + " > " + keyPath.resourceURI
        keyName = entry.locKey
        commentText = entry.comment ?? ""

        if let override = entry.override {
            switch override {
            case .static(let text):
                overrideTexts = [.other: text]
            case .dynamic(let format):
                if let varName = LocalizedFormat.variableNames(from: format.baseFormat).first {
                    overrideTexts = format.variableSpecs[varName]!.ruleSpecs
                }
            }
        }
        else {
            overrideTexts = [.other: ""]
        }
        
        showsOverridePlurals = translationCanHavePlurals(entry.translation)

        updateTranslation()
        updateOverride()
    }
    
    private func updateTranslation() {
        switch entry.translation {
        case .static(let text):
            translatedText = text
        case .dynamic(let format):
            let plurals = format.mergedPluralForms
            translatedText = plurals[translationPluralRules[translationPluralRulesSelectedIndex]]!
        }
        
        delegate?.viewModelDidUpdateTranslation(self)
    }
    
    private func updateOverride() {
        let selectedRule = overridePluralRules[overridePluralRulesSelectedIndex]
        overrideText = overrideTexts[selectedRule]!
        canRemoveSelectedOverridePluralRule = selectedRule != .other
        
        delegate?.viewModelDidUpdateOverride(self)
    }
    
    // MARK: - actions:
    
    func setTranslationPluralRulesSelectedIndex(_ index: Int) {
        guard index != translationPluralRulesSelectedIndex else {
            return
        }
        
        translationPluralRulesSelectedIndex = index
        
        updateTranslation()
    }

    func setOverridePluralRulesSelectedIndex(_ index: Int) {
        guard index != overridePluralRulesSelectedIndex else {
            return
        }
        
        overridePluralRulesSelectedIndex = index
        
        updateOverride()
    }
    
    func addRemainingOverridePluralRule(at index: Int) {
        let ruleToAdd = remainingPluralRules[index]
        overrideTexts[ruleToAdd] = overrideTexts[.other]
        overridePluralRulesSelectedIndex = overridePluralRules.index(of: ruleToAdd)!
        
        updateOverride()
    }
    
    func removeSelectedOverridePluralRule() {
        guard overridePluralRules[overridePluralRulesSelectedIndex] != .other else {
            fatalError("other rule cannot be removed")
        }

        let selectedRule = overridePluralRules[overridePluralRulesSelectedIndex]
        overrideTexts[selectedRule] = nil
        overridePluralRulesSelectedIndex = 0
        
        updateOverride()
    }
    
    func updateOverrideText(_ text: String) {
        let selectedRule = overridePluralRules[overridePluralRulesSelectedIndex]
        overrideTexts[selectedRule] = text
        overrideText = text
    }
    
    func validatedOverride() throws -> Translation {
        guard let entry = StringsManager.defaultManager.entry(for: keyPath) else {
            throw OverrideError.invalidKeyPath
        }
        
        let override: Translation
        if overrideTexts.count == 1 {
            override = .static(overrideTexts.first!.value)
        }
        else {
            let valueType: String
            switch entry.translation {
            case .static(let text):
                do {
                    let fd = try FormatDescriptor(format: text)
                    valueType = fd.placeholders[0] ?? fd.placeholders.first!.value
                }
                catch {
                    throw OverrideError.invalidOriginalFormat
                }
            case .dynamic(let format):
                let varName = LocalizedFormat.variableNames(from: format.baseFormat).first!
                valueType = format.variableSpecs[varName]!.valueType
            }

            let format = LocalizedFormat(formats: overrideTexts, valueType: valueType)
            override = .dynamic(format)
        }
        
        try StringsManager.defaultManager.validateOverride(override, for: entry.translation)
        
        return override
    }
    
    private func translationCanHavePlurals(_ translation: Translation) -> Bool {
        switch translation {
        case .static(let text):
            return !((try? FormatDescriptor(format: text))?.placeholders.isEmpty ?? true)
        case .dynamic(let format):
            return !format.variableSpecs.isEmpty
        }
    }
    
}
