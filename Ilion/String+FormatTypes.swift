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

// extracted from: https://github.com/SwiftGen/SwiftGenKit/blob/master/Sources/Parsers/StringsFileParser.swift
extension String {
    
    private enum FormatStringError: Error {
        case unknown
    }
    
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
    
    var formatPlaceholderTypes: [Int: String]? {
        let range = NSRange(location: 0, length: (self as NSString).length)
        let matches = String.formatTypesRegex.matches(in: self, options: [], range: range)
        
        do {
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
                let char = (self as NSString).substring(with: range)
                
                let posRange = match.rangeAt(1)
                let pair: (String, Int)
                
                if posRange.location == NSNotFound {
                    // No positional specifier
                    unusedIndex += 1
                    pair = (char, unusedIndex)
                } else {
                    // Remove the "$" at the end of the positional specifier, and convert to Int
                    let posRange1 = NSRange(location: posRange.location, length: posRange.length-1)
                    let pos = (self as NSString).substring(with: posRange1)
                    pair = (char, Int(pos)!)
                }
                
                if let type = placeholderTypes[pair.1] {
                    if type != pair.0 {
                        throw FormatStringError.unknown
                    }
                }
                
                placeholderTypes[pair.1] = pair.0
            }
            return placeholderTypes
        }
        catch {
            return nil
        }
    }
    
}
