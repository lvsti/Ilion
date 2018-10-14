//
//  LocalizedFormat.swift
//  Ilion
//
//  Created by Tamas Lustyik on 2017. 05. 08..
//  Copyright © 2017. Tamas Lustyik. All rights reserved.
//

import Foundation

enum LocalizedFormatParseError: Error {
    case syntaxError
    case missingFormat
    case unspecifiedVariable
    case missingSpecType(varName: String)
    case unrecognizedSpecType(varName: String, type: String)
    case missingOtherRule(varName: String)
}


enum PluralRule: String, CaseIterable {
    case zero, one, two, few, many, other
}

extension PluralRule: Comparable {
    public static func <(lhs: PluralRule, rhs: PluralRule) -> Bool {
        return lhs.hashValue < rhs.hashValue
    }
}

struct VariableSpec {
    let valueType: String
    let ruleSpecs: [PluralRule: String]
}

struct LocalizedFormat {
    let baseFormat: String
    let variableSpecs: [String: VariableSpec]
    
    init(config: [String: Any]) throws {
        guard let format = config["NSStringLocalizedFormatKey"] as? String else {
            throw LocalizedFormatParseError.missingFormat
        }
        
        let formatVars = Set(LocalizedFormat.variableNames(from: format))
        let ruleVars = Set(config.keys.filter({ $0 != "NSStringLocalizedFormatKey" }))
        
        guard formatVars.subtracting(ruleVars).isEmpty else {
            throw LocalizedFormatParseError.unspecifiedVariable
        }

        let varSpecPairs = try ruleVars
            .map { (varName: String) -> (String, VariableSpec) in
                guard let rules = config[varName] as? [String: String] else {
                    throw LocalizedFormatParseError.syntaxError
                }
                
                guard let specType = rules["NSStringFormatSpecTypeKey"] else {
                    throw LocalizedFormatParseError.missingSpecType(varName: varName)
                }
                
                guard specType == "NSStringPluralRuleType" else {
                    throw LocalizedFormatParseError.unrecognizedSpecType(varName: varName, type: specType)
                }
                
                // according to https://developer.apple.com/library/content/releasenotes/Foundation/RN-Foundation-older-but-post-10.8/
                // if the value type is missing, it's assumed to be '@'
                let valueType = rules["NSStringFormatValueTypeKey"] ?? "@"
                
                guard rules[PluralRule.other.rawValue] != nil else {
                    throw LocalizedFormatParseError.missingOtherRule(varName: varName)
                }
                
                let rulePairs = PluralRule.allCases
                    .map { ($0, rules[$0.rawValue] ?? "") }
                    .filter { !$0.1.isEmpty }
                
                return (varName, VariableSpec(valueType: valueType, ruleSpecs: Dictionary(pairs: rulePairs)))
            }

        self.baseFormat = format
        self.variableSpecs = Dictionary(pairs: varSpecPairs)
    }
    
    init(formats: [PluralRule: String], valueType: String) {
        self.baseFormat = "%#@format@"
        self.variableSpecs = [
            "format": VariableSpec(valueType: valueType, ruleSpecs: formats)
        ]
    }
    
    private init(baseFormat: String, variableSpecs: [String: VariableSpec]) {
        self.baseFormat = baseFormat
        self.variableSpecs = variableSpecs
    }
    
    func appending(_ string: String) -> LocalizedFormat {
        return LocalizedFormat(baseFormat: string.appending(baseFormat), variableSpecs: variableSpecs)
    }

    func prepending(_ string: String) -> LocalizedFormat {
        return LocalizedFormat(baseFormat: baseFormat.appending(string), variableSpecs: variableSpecs)
    }
    
    func applyingTransform(_ transform: ([String]) -> [String]) -> LocalizedFormat {
        var config = toStringsDictEntry()
        let ruleNames = Set(PluralRule.allCases.map({ $0.rawValue }))

        func slice(_ str: String, by indices: IndexSet) -> [String] {
            return indices.rangeView.map { range in
                let sliceStart = str.index(str.startIndex, offsetBy: range.startIndex)
                let sliceEnd = str.index(str.startIndex, offsetBy: range.endIndex)
                return String(str[sliceStart..<sliceEnd])
            }
        }

        var updatedConfig = config
        
        for (varName, varConfig) in config where varName != "NSStringLocalizedFormatKey" {
            let originalVarConfig = varConfig as! [String: String]
            var updatedVarConfig = originalVarConfig
            
            for (ruleName, format) in originalVarConfig where ruleNames.contains(ruleName) {
                let variableIndices = FormatDescriptor.variableRanges(in: format)
                    .map { IndexSet(integersIn: Range($0)!) }
                    .reduce(IndexSet()) { acc, next in
                        acc.union(next)
                    }
                
                let literalIndices = IndexSet(integersIn: 0..<format.count).subtracting(variableIndices)
                let literalSlices = slice(format, by: literalIndices)
                let transformedLiteralSlices = transform(literalSlices)

                let variableSlices = slice(format, by: variableIndices)
                let startsWithVariable = variableIndices.contains(0)
                
                let firstSource = startsWithVariable ? variableSlices : transformedLiteralSlices
                let secondSource = startsWithVariable ? transformedLiteralSlices : variableSlices
                
                let transformedFormat = zip(firstSource, secondSource + [""]).reduce(String()) { acc, next in
                    acc.appending(next.0).appending(next.1)
                }

                updatedVarConfig[ruleName] = transformedFormat
            }
            
            updatedConfig[varName] = originalVarConfig.merging(updatedVarConfig, uniquingKeysWith: { $1 })
        }
        
        config.merge(updatedConfig, uniquingKeysWith: { $1 })
        
        return try! LocalizedFormat(config: config)
    }

    func toStringsDictEntry() -> [String: Any] {
        var config: [String: Any] = [
            "NSStringLocalizedFormatKey": baseFormat
        ]
        
        for (varName, varSpec) in variableSpecs {
            var varConfig = [
                "NSStringFormatSpecTypeKey": "NSStringPluralRuleType",
                "NSStringFormatValueTypeKey": varSpec.valueType
            ]
            
            for (rule, format) in varSpec.ruleSpecs {
                varConfig[rule.rawValue] = format
            }
            
            config[varName] = varConfig
        }
        
        return config
    }
    
    var usedPluralRules: Set<PluralRule> {
        return Set(variableSpecs.flatMap { $0.value.ruleSpecs.keys })
    }
    
    var mergedPluralForms: [PluralRule: String] {
        // initialize all referenced rules with baseFormat
        let formPairs = usedPluralRules.map { ($0, baseFormat) }

        var forms: [PluralRule: String] = Dictionary(pairs: formPairs)
        var updatedForms: [PluralRule: String] = forms
        var didUpdate = true
        
        // iterate through all variables and replace them using the appropriate rule
        while didUpdate {
            forms = updatedForms
            updatedForms.removeAll()
            didUpdate = false
            
            for (rule, format) in forms {
                guard
                    let match = LocalizedFormat.localizedVarRegex.firstMatch(in: format,
                                                                             options: [],
                                                                             range: format.fullRange)
                else {
                    updatedForms[rule] = forms[rule]
                    continue
                }
                
                let varName = (format as NSString).substring(with: match.range(at: 1))
                let varRange = match.range
                let ruleSpecs = variableSpecs[varName]!.ruleSpecs
                let replacement = ruleSpecs[rule] ?? ruleSpecs[.other]!
                
                let updatedFormat = (format as NSString).replacingCharacters(in: varRange, with: replacement)
                updatedForms[rule] = updatedFormat
                didUpdate = true
            }
        }
        
        return forms
    }

    private static let localizedVarRegex = try! NSRegularExpression(pattern: "%(?:|[1-9]\\d*\\$)#@([a-zA-Z_0-9]+)@", options: [])
    
    static func variableNames(from format: String) -> [String] {
        let matches = localizedVarRegex.matches(in: format,
                                                options: [],
                                                range: format.fullRange)
        return matches
            .map { match in
                let range = match.range(at: 1)
                return (format as NSString).substring(with: range)
            }
    }

}

