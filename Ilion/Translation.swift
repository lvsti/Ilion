//
//  Translation.swift
//  Ilion
//
//  Created by Tamas Lustyik on 2018. 10. 10..
//  Copyright © 2018. Tamas Lustyik. All rights reserved.
//

import Foundation

enum Translation {
    case `static`(String)
    case `dynamic`(LocalizedFormat)
    
    func toString() -> String {
        switch self {
        case .static(let text): return text
        case .dynamic(let format):
            let config = format.toStringsDictEntry()
            let nsFormat = format.baseFormat as NSString
            let locFormat = nsFormat.perform(NSSelectorFromString("_copyFormatStringWithConfiguration:"), with: config)
                .takeUnretainedValue()
            return locFormat as! String
        }
    }
}

extension Translation {
    func addingStartEndMarkers() -> Translation {
        switch self {
        case .static(let text): return .static("[\(text)]")
        case .dynamic(let format): return .dynamic(format.prepending("[").appending("]"))
        }
    }
    
    func applyingPseudoLocalization() -> Translation {
        switch self {
        case .static(let text):
            return .static(text.applyingPseudoLanguageTransformation())
            
        case .dynamic(let format):
            let transformedFormat = format.applyingTransform { slices in
                slices.map { $0.applyingPseudoLanguageTransformation() }
            }
            return .dynamic(transformedFormat)
        }
    }
    
    func simulatingExpansion(by factor: Double) -> Translation {
        func paddingText(forLength length: Int) -> String {
            let growth = Int(floor(Double(length) * factor)) - length
            let pattern = "lorem ipsum dolor sit amet consectetur adipiscing elit "
            let paddingSource = String(repeating: pattern, count: (growth / pattern.count) + 1)
            let padding = paddingSource[paddingSource.startIndex ..< paddingSource.index(paddingSource.startIndex, offsetBy: growth)]
            return "{\(padding)}"
        }
        
        switch self {
        case .static(let text):
            let padding = paddingText(forLength: text.count)
            return .static(text.appending(padding))
            
        case .dynamic(let format):
            let transformedFormat = format.applyingTransform { slices in
                let charCount = slices.map { $0.count }.reduce(0, +)
                let padding = paddingText(forLength: charCount)
                
                var slices = slices
                slices[slices.count - 1] = slices.last!.appending(padding)
                return slices
            }
            return .dynamic(transformedFormat)
        }
    }
}
