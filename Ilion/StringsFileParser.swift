//
//  StringsFileParser.swift
//  Ilion
//
//  Created by Tamas Lustyik on 2017. 05. 19..
//  Copyright © 2017. Tamas Lustyik. All rights reserved.
//

import Foundation

class StringsFileParser {
    
    private static let stringsRegex: NSRegularExpression = {
        let comment = "(\\/\\*(?:[^*]|[\\r\\n]|(?:\\*+(?:[^*\\/]|[\\r\\n])))*\\*+\\/.*|\\/\\/.*)?"
        let lineBreak = "[\\r\\n][\\t ]*"
        let key = "\"((?:.|[\\r\\n])+?)(?<!\\\\)\""
        let assignment = "\\s*=\\s*"
        let value = "\"((?:.|[\\r\\n])*?)(?<!\\\\)\""
        let trailing = "\\s*;"
        return try! NSRegularExpression(pattern: comment + lineBreak + key + assignment + value + trailing,
                                        options: [])
    }()
    
    func readStringsFile(at path: String) -> [String: (value: String, comment: String?)] {
        guard let stringsFile = try? String(contentsOfFile: path) as NSString else {
            return [:]
        }
        
        var translations: [String: (String, String?)] = [:]
        
        let matches = StringsFileParser.stringsRegex.matches(in: stringsFile as String,
                                                             options: [],
                                                             range: NSMakeRange(0, stringsFile.length))
        
        for match in matches {
            let comment: String?
            if match.rangeAt(1).location != NSNotFound {
                comment = stringsFile.substring(with: match.rangeAt(1)).trimmingCharacters(in: .whitespaces)
            }
            else {
                comment = nil
            }
            
            let key = stringsFile.substring(with: match.rangeAt(2))
            let value = stringsFile.substring(with: match.rangeAt(3))
            translations[key] = (value, comment)
        }
        
        return translations
    }
    
    func readStringsDictFile(at path: String) -> [String: LocalizedFormat] {
        guard let stringsDict = NSDictionary(contentsOfFile: path) as? [String: Any] else {
            return [:]
        }
        
        let formatPairs: [(String, LocalizedFormat)]? = try? stringsDict
            .map { (key, value) in
                guard
                    let config = value as? [String: Any],
                    let format = try? LocalizedFormat(config: config)
                    else {
                        throw StringsDictParseError.invalidFormat
                }
                return (key, format)
        }
        
        if let formatPairs = formatPairs {
            return Dictionary(pairs: formatPairs)
        }
        
        return [:]
    }

}
