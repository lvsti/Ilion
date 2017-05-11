//
//  String+FormatTypes.swift
//  Ilion
//
//  Created by Tamas Lustyik on 2017. 04. 30..
//
//  Copyright © 2017. Tamas Lustyik
//  Portions Copyright (c) 2017 SwiftGen
//  MIT License

import Foundation

enum FormatDescriptorError: Error {
    case ambiguousVariableTypes(position: Int, typeA: String, typeB: String)
    case unspecifiedVariable(position: Int)
}

struct FormatDescriptor {
    let placeholders: [Int: String]

    init(format: String) throws {
        let range = NSRange(location: 0, length: (format as NSString).length)
        let matches = FormatDescriptor.formatTypesRegex.matches(in: format, options: [], range: range)
        
        var unusedIndex = 0
        var placeholderTypes: [Int: String] = [:]
        
        try matches.forEach { match in
            let range: NSRange
            if match.rangeAt(3).location != NSNotFound {
                // [dioux] are in range #3 because in #2 there may be length modifiers (like in "lld")
                range = match.rangeAt(3)
            } else {
                // otherwise, no length modifier, the conversion specifier is in #2
                range = match.rangeAt(2)
            }
            let char = (format as NSString).substring(with: range)
            
            let posRange = match.rangeAt(1)
            let pair: (String, Int)
            
            if posRange.location == NSNotFound {
                // No positional specifier
                unusedIndex += 1
                pair = (char, unusedIndex)
            } else {
                // Remove the "$" at the end of the positional specifier, and convert to Int
                let posRange1 = NSRange(location: posRange.location, length: posRange.length-1)
                let pos = (format as NSString).substring(with: posRange1)
                pair = (char, Int(pos)!)
            }
            
            if let type = placeholderTypes[pair.1] {
                if type != pair.0 {
                    throw FormatDescriptorError.ambiguousVariableTypes(position: pair.1,
                                                                       typeA: pair.0,
                                                                       typeB: type)
                }
            }
            
            placeholderTypes[pair.1] = pair.0
        }
        
        self.placeholders = placeholderTypes
    }
    
    private init(placeholders: [Int: String]) {
        self.placeholders = placeholders
    }
    
    func validateAsSubstitute(for other: FormatDescriptor) throws {
        // check whether the argument types match up
        for (position, type) in placeholders {
            guard let otherType = other.placeholders[position] else {
                throw FormatDescriptorError.unspecifiedVariable(position: position)
            }
            
            guard type == otherType else {
                throw FormatDescriptorError.ambiguousVariableTypes(position: position,
                                                                   typeA: otherType,
                                                                   typeB: type)
            }
        }
    }
    
    static func merge(_ descriptors: [FormatDescriptor]) throws -> FormatDescriptor {
        var mergedPlaceholders: [Int: String] = [:]

        for descriptor in descriptors {
            for (position, type) in descriptor.placeholders {
                if let mergedType = mergedPlaceholders[position], type != mergedType {
                    throw FormatDescriptorError.ambiguousVariableTypes(position: position,
                                                                       typeA: mergedType,
                                                                       typeB: type)
                }
                mergedPlaceholders[position] = type
            }
        }
        
        return FormatDescriptor(placeholders: mergedPlaceholders)
    }
    
    // extracted from: https://github.com/SwiftGen/SwiftGenKit/blob/master/Sources/Parsers/StringsFileParser.swift
    private static let formatTypesRegex: NSRegularExpression = {
        // %d/%i/%o/%u/%x with their optional length modifiers like in "%lld"
        let pattern_int = "(?:h|hh|l|ll|q|z|t|j)?([dioux])"
        // valid flags for float
        let pattern_float = "[aefg]"
        // like in "%3$" to make positional specifiers
        let position = "([1-9]\\d*\\$)?"
        // precision like in "%1.2f"
        let precision = "[-+]?\\d?(?:\\.\\d)?"
        
        return try! NSRegularExpression(
            pattern: "(?:^|[^%]|(?<!%)(?:%%)+)%\(position)\(precision)(@|\(pattern_int)|\(pattern_float)|[csp])",
            options: [.caseInsensitive]
        )
    }()

}

