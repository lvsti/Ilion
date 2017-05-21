//
//  StringsFileParser.swift
//  Ilion
//
//  Created by Tamas Lustyik on 2017. 05. 19..
//  Copyright © 2017. Tamas Lustyik. All rights reserved.
//

import Foundation

struct StringsFileEntry {
    let keyRange: NSRange
    let valueRange: NSRange
    let commentRange: NSRange?
}

struct StringsFile {
    let content: NSString
    let encoding: String.Encoding
    let entries: [LocKey: StringsFileEntry]
    
    func value(for key: LocKey) -> String? {
        guard let valueRange = entries[key]?.valueRange else {
            return nil
        }
        return content.substring(with: valueRange)
    }
    
    func comment(for key: LocKey) -> String? {
        guard let commentRange = entries[key]?.commentRange else {
            return nil
        }
        return content.substring(with: commentRange)
    }

}

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
    
    func readStringsFile(at path: String) -> StringsFile? {
        var encoding: String.Encoding = .utf8
        guard let content = try? String(contentsOfFile: path, usedEncoding: &encoding) else {
            return nil
        }
        
        var entries: [LocKey: StringsFileEntry] = [:]
        
        let matches = StringsFileParser.stringsRegex.matches(in: content,
                                                             options: [],
                                                             range: NSRange(location: 0, length: content.length))
        
        for match in matches {
            let commentRange: NSRange?
            let range = match.rangeAt(1)
            
            if range.location != NSNotFound {
                let rawComment = (content as NSString).substring(with: range)
                let slackChars = CharacterSet(charactersIn: "/*").union(.whitespaces)
                let comment = rawComment.trimmingCharacters(in: slackChars)
                if !comment.isEmpty {
                    commentRange = NSRange(location: range.location + (rawComment as NSString).range(of: comment).location,
                                           length: comment.length)
                }
                else {
                    commentRange = nil
                }
            }
            else {
                commentRange = nil
            }
            
            let entry = StringsFileEntry(keyRange: match.rangeAt(2),
                                         valueRange: match.rangeAt(3),
                                         commentRange: commentRange)
            let key = (content as NSString).substring(with: entry.keyRange)
            entries[key] = entry
        }
        
        return StringsFile(content: content as NSString,
                           encoding: encoding,
                           entries: entries)
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
