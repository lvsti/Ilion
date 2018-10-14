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
}
