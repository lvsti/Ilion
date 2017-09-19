//
//  String+RelativePath.swift
//  Ilion
//
//  Created by Tamas Lustyik on 2017. 04. 24..
//  Copyright © 2017. Tamas Lustyik. All rights reserved.
//

import Foundation

extension String {
    
    func relativePath(toParent parentPath: String) -> String? {
        if self == parentPath {
            return ""
        }
        guard hasPrefix(parentPath) else {
            return nil
        }
        let tailIndex = index(startIndex, offsetBy: parentPath.length)
        let tail = self[tailIndex...]
        return tail.hasPrefix("/") ? String(tail[tail.index(after: tail.startIndex)...]) : String(tail)
    }
    
}
