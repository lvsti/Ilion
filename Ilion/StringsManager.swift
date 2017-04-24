//
//  StringsManager.swift
//  Visual10n
//
//  Created by Tamas Lustyik on 2017. 03. 15..
//  Copyright © 2017. Tamas Lustyik. All rights reserved.
//

import Foundation

typealias BundleURI = String
typealias ResourceURI = String
typealias LocKey = String

struct LocKeyPath {
    static let separator = "|"
    
    let bundleURI: BundleURI
    let resourceURI: ResourceURI
    let locKey: LocKey
    
    init(bundleURI: BundleURI, resourceURI: ResourceURI, locKey: LocKey) {
        self.bundleURI = bundleURI
        self.resourceURI = resourceURI
        self.locKey = locKey
    }
    
    init?(string: String) {
        let comps = string.components(separatedBy: LocKeyPath.separator)
        guard comps.count >= 3 else {
            return nil
        }
        
        self.init(bundleURI: comps[0],
                  resourceURI: comps[1],
                  locKey: Array(comps[2..<comps.count-1]).joined(separator: LocKeyPath.separator))
    }
}

extension LocKeyPath: Equatable {
    static func ==(lhs: LocKeyPath, rhs: LocKeyPath) -> Bool {
        return lhs.bundleURI == rhs.bundleURI &&
            lhs.resourceURI == rhs.resourceURI &&
            lhs.locKey == rhs.locKey
    }
}

extension LocKeyPath: Hashable {
    var hashValue: Int {
        return (bundleURI + resourceURI + locKey).hashValue
    }
}

extension LocKeyPath: CustomStringConvertible {
    var description: String {
        return [bundleURI, resourceURI, locKey].joined(separator: LocKeyPath.separator)
    }
}

struct StringsEntry {
    var locKey: String
    var sourceText: String
    var translatedText: String
    var overrideText: String?
    var resourceName: String
}

@objc class StringsManager: NSObject {

    private let storedOverridesKey = "Ilion.TranslationOverrides"

    private let userDefaults: UserDefaults
    
    private var stringsFiles: [URL: [String: String]]
    private let locRegex: NSRegularExpression
    private var overriddenKeys: Set<String>
    
    private(set) var strings: [String: StringsEntry]
    
    static let defaultManager = StringsManager(userDefaults: UserDefaults.standard)
    
    private init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
        
        stringsFiles = [:]
        overriddenKeys = []
        strings = [:]
        locRegex = try! NSRegularExpression(pattern: "^\\s*\"([^\"]+)\"\\s*=\\s*\"(.*)\"\\s*;\\s*$", options: [])
        
        super.init()

        loadStringsFilesInBundle(Bundle.main)
        
        let storedOverrides: [String: String] = userDefaults.dictionary(forKey: storedOverridesKey) as? [String: String] ?? [:]
        overriddenKeys = Set<String>(storedOverrides.keys)
        for override in storedOverrides {
            strings[override.key]?.overrideText = override.value
        }
    }
    
    @objc func loadStringsFilesInBundle(_ bundle: Bundle) {
        let urls = bundle.urls(forResourcesWithExtension: "strings", subdirectory: nil, localization: "es")!
        
        for url in urls {
            let translations = readLocalizedStringsFile(atPath: url.path)
            for (sKey, sValue) in translations {
                let entry = StringsEntry(locKey: sKey,
                                         sourceText: "",
                                         translatedText: sValue,
                                         overrideText: nil,
                                         resourceName: url.lastPathComponent)
                strings[sKey] = entry
            }
            stringsFiles[url] = translations
        }
    }

    private func readLocalizedStringsFile(atPath path: String) -> [String: String] {
        let stringsFile = try! NSString(contentsOfFile: path, encoding: String.Encoding.utf8.rawValue)
        var translations: [String: String] = [:]
        
        stringsFile.enumerateLines { line, stop in
            let nsLine = line as NSString
            if let match = self.locRegex.firstMatch(in: line, options: [], range: NSMakeRange(0, nsLine.length)) {
                let key = nsLine.substring(with: match.rangeAt(1))
                let value = nsLine.substring(with: match.rangeAt(2))
                translations[key] = value
            }
        }
        
        return translations
    }
    
    func addOverride(_ string: String, for key: String) {
        overriddenKeys.insert(key)
        strings[key]?.overrideText = string
        
        var storedOverrides = userDefaults.dictionary(forKey: storedOverridesKey) ?? [:]
        storedOverrides[key] = string
        userDefaults.setValue(storedOverrides, forKey: storedOverridesKey)
    }
    
    func removeOverride(for key: String) {
        overriddenKeys.remove(key)
        strings[key]?.overrideText = nil

        var storedOverrides = userDefaults.dictionary(forKey: storedOverridesKey) ?? [:]
        storedOverrides[key] = nil
        userDefaults.setValue(storedOverrides, forKey: storedOverridesKey)
    }
    
    func removeAllOverrides() {
        for key in overriddenKeys {
            strings[key]?.overrideText = nil
        }
        overriddenKeys.removeAll()
        
        userDefaults.setValue([:], forKey: storedOverridesKey)
    }
    
    func hasOverride(for key: String) -> Bool {
        return strings[key]?.overrideText != nil
    }

    @objc(localizedStringForKey:value:table:bundle:)
    func localizedString(_ key: String, value: String?, table: String? = nil, bundle: Bundle? = nil) -> String {
        guard let entry = strings[key] else {
            return value?.isEmpty ?? true ? key : value!
        }
        
        return entry.overrideText ?? entry.translatedText
    }
    
}

