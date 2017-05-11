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


enum PluralRule: String {
    case zero, one, two, few, many, other
    
    static let allValues: [PluralRule] = [.zero, .one, .two, .few, .many, .other]
}

struct VariableSpec {
    var valueType: String
    var ruleSpecs: [PluralRule: String]
}

struct LocalizedFormat {
    var baseFormat: String
    var variableSpecs: [String: VariableSpec]
    
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
                
                let rulePairs = PluralRule.allValues
                    .map { ($0, rules[$0.rawValue] ?? "") }
                    .filter { !$0.1.isEmpty }
                
                return (varName, VariableSpec(valueType: valueType, ruleSpecs: Dictionary(pairs: rulePairs)))
            }

        self.baseFormat = format
        self.variableSpecs = Dictionary(pairs: varSpecPairs)
    }
    
    func toStringsDictEntry() -> [String: Any] {
        var config: [String: Any] = ["NSStringLocalizedFormatKey": baseFormat]
        
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

    private static let localizedVarRegex = try! NSRegularExpression(pattern: "%(?:|[1-9]\\d*\\$)#@([a-zA-Z_0-9]+)@", options: [])
    
    private static func variableNames(from format: String) -> [String] {
        let matches = localizedVarRegex.matches(in: format,
                                                options: [],
                                                range: format.fullRange)
        return matches
            .map { match in
                let range = match.rangeAt(1)
                return (format as NSString).substring(with: range)
            }
    }

}

