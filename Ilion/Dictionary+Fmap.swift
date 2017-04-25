//
//  Dictionary+Fmap.swift
//  Ilion
//
//  Created by Tamas Lustyik on 2017. 04. 24..
//  Copyright © 2017. Tamas Lustyik. All rights reserved.
//

import Foundation

extension Dictionary {
    
    func fmap<T>(transform: (Key, Value) -> T) -> Dictionary<Key, T> {
        let pairs = map({ ($0.key, transform($0.key, $0.value)) })
        return Dictionary<Key, T>(pairs: pairs)
    }
    
    init(pairs: [(Key, Value)]) {
        self.init(minimumCapacity: pairs.count)
        pairs.forEach { key, value in
            self[key] = value
        }
    }
    
}

