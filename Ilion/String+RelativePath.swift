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
        let tailIndex = index(startIndex, offsetBy: parentPath.distance(from: parentPath.startIndex, to: parentPath.endIndex))
        let tail = substring(from: tailIndex)
        return tail.hasPrefix("/") ? tail.substring(from: tail.index(after: tail.startIndex)) : tail
    }
    
}
