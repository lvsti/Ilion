//
//  String+PseudoLanguage.swift
//  Ilion
//
//  Created by Tamas Lustyik on 2018. 10. 10..
//  Copyright © 2018. Tamas Lustyik. All rights reserved.
//

import Foundation

extension String {
    func applyingPseudoLanguageTransformation() -> String {
        let pseudoLatin = "αɓ¢ԃεƒϑჩℹ︎ʝҝƖოηфϸƪʀς†цγш×уƶΛßϚÐ€Ƒ₲ҤǀͿƘ£ℳИØ₱Ɋ®ʃƬЦƲШχ¥Ɀ"
        let combiningDiacriticalRange: Range<UInt32> = 0x300..<0x370
        let isBasicLatinLower: (UInt32) -> Bool = { (0x61...0x7A).contains($0) }
        let isBasicLatinUpper: (UInt32) -> Bool = { (0x41...0x5A).contains($0) }
        let isBasicLatin: (UInt32) -> Bool = { isBasicLatinLower($0) || isBasicLatinUpper($0) }
        
        var scalars = decomposedStringWithCanonicalMapping
            .flatMap { Array($0.unicodeScalars) }
            .map { $0.value }
        
        var insertions: [(Int, UInt32)] = []
        for (idx, scalar) in scalars.enumerated() where isBasicLatin(scalar) {
            // character replacement
            if Bool.random() {
                let offset = isBasicLatinLower(scalar) ? Int(scalar - 0x61) : Int(scalar - 0x41)
                let ch = pseudoLatin[pseudoLatin.index(pseudoLatin.startIndex, offsetBy: offset)]
                scalars[idx] = ch.unicodeScalars.first!.value
            }
            
            // diacritic decoration
            for _ in 0..<(1...4).randomElement()! {
                let diacritic = combiningDiacriticalRange.randomElement()!
                insertions.append((idx + 1, diacritic))
            }
        }
        
        for insertion in insertions.reversed() {
            scalars.insert(insertion.1, at: insertion.0)
        }
        
        return String(String.UnicodeScalarView(scalars.map { Unicode.Scalar($0)! }))
    }
}
