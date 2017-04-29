//
//  StringsManager.swift
//  Ilion
//
//  Created by Tamas Lustyik on 2017. 03. 15..
//  Copyright © 2017. Tamas Lustyik. All rights reserved.
//

import Foundation

struct StringsEntry {
    var locKey: LocKey
    var sourceText: String
    var translatedText: String
    var overrideText: String?
}

typealias StringsDB = [BundleURI: [ResourceURI: [LocKey: StringsEntry]]]

@objc final class StringsManager: NSObject {
    
    private let storedOverridesKey = "Ilion.TranslationOverrides"

    private let userDefaults: UserDefaults
    
    private let locRegex: NSRegularExpression
    
    private(set) var db: StringsDB
    private var overriddenKeyPaths: Set<LocKeyPath>
    
    static let defaultManager = StringsManager(userDefaults: .standard)
    
    private init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
        
        db = [:]
        overriddenKeyPaths = []
        locRegex = try! NSRegularExpression(pattern: "^\\s*\"([^\"]+)\"\\s*=\\s*\"(.*)\"\\s*;\\s*$", options: [])
        
        super.init()

        loadStringsFilesInBundle(Bundle.main)
    }
    
    // MARK: - ObjC API
    
    @objc func loadStringsFilesInBundle(_ bundle: Bundle) {
        guard let rootPath = bundle.resourcePath else {
            return
        }
        let bundleURI = self.bundleURI(for: bundle)
        
        let unlocalizedURLs = bundle.urls(forResourcesWithExtension: "strings",
                                          subdirectory: nil,
                                          localization: nil)!
        let localizedURLs = bundle.localizations
            .flatMap { localizationName in
                return bundle.urls(forResourcesWithExtension: "strings",
                                   subdirectory: nil,
                                   localization: localizationName)!
            }
        let uniqueURLs = Set<URL>(localizedURLs + unlocalizedURLs)
        
        var resources: [ResourceURI: [LocKey: StringsEntry]] = [:]
        
        for url in uniqueURLs {
            let translations = readLocalizedStringsFile(atPath: url.path)
            var strings: [LocKey: StringsEntry] = [:]
            
            for (sKey, sValue) in translations {
                let entry = StringsEntry(locKey: sKey,
                                         sourceText: "",
                                         translatedText: sValue,
                                         overrideText: nil)
                strings[sKey] = entry
            }
            
            let resourceURI = url.path.relativePath(toParent: rootPath)!
            resources[resourceURI] = strings
        }
        
        db[bundleURI] = resources
        
        applyOverrides(for: bundle)
    }

    @objc(localizedStringForKey:value:table:bundle:)
    func localizedString(_ key: String, value: String?, table: String? = nil, bundle: Bundle? = nil) -> String {
        let bundleURI = self.bundleURI(for: bundle ?? .main)
        
        guard
            let resourceURI = self.resourceURI(for: (table ?? "Localizable") + ".strings",
                                               in: bundle ?? .main),
            let entry = db[bundleURI]?[resourceURI]?[key]
        else {
            return (value?.isEmpty ?? true) ? key : value!
        }
        
        return entry.overrideText ?? entry.translatedText
    }
    
    // MARK: - internal Swift API
    
    func entry(for keyPath: LocKeyPath) -> StringsEntry? {
        return db[keyPath.bundleURI]?[keyPath.resourceURI]?[keyPath.locKey]
    }
    
    func setEntry(_ entry: StringsEntry, for keyPath: LocKeyPath) {
        db[keyPath.bundleURI]?[keyPath.resourceURI]?[keyPath.locKey] = entry
    }
    
    func addOverride(_ string: String, for keyPath: LocKeyPath) {
        guard var entry = self.entry(for: keyPath) else {
            return
        }
        
        entry.overrideText = string
        setEntry(entry, for: keyPath)
        
        overriddenKeyPaths.insert(keyPath)
        
        var storedOverrides = userDefaults.dictionary(forKey: storedOverridesKey) ?? [:]
        storedOverrides[keyPath.description] = string
        userDefaults.setValue(storedOverrides, forKey: storedOverridesKey)
    }
    
    func removeOverride(for keyPath: LocKeyPath) {
        guard var entry = self.entry(for: keyPath) else {
            return
        }

        entry.overrideText = nil
        setEntry(entry, for: keyPath)

        overriddenKeyPaths.remove(keyPath)

        var storedOverrides = userDefaults.dictionary(forKey: storedOverridesKey) ?? [:]
        storedOverrides[keyPath.description] = nil
        userDefaults.setValue(storedOverrides, forKey: storedOverridesKey)
    }
    
    func removeAllOverrides() {
        for keyPath in overriddenKeyPaths {
            if var entry = self.entry(for: keyPath) {
                entry.overrideText = nil
                setEntry(entry, for: keyPath)
            }
        }
        
        userDefaults.setValue([:], forKey: storedOverridesKey)
    }

    func hasOverride(for keyPath: LocKeyPath) -> Bool {
        return overriddenKeyPaths.contains(keyPath)
    }
    
    // MARK: - private methods

    private func readLocalizedStringsFile(atPath path: String) -> [String: String] {
        guard let stringsFile = try? String(contentsOfFile: path) else {
            return [:]
        }
        
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
    
    private func applyOverrides(for bundle: Bundle) {
        let bundleURI = self.bundleURI(for: bundle)
        let storedOverrides: [String: String] = userDefaults.dictionary(forKey: storedOverridesKey) as? [String: String] ?? [:]
        
        for override in storedOverrides {
            if let keyPath = LocKeyPath(string: override.key),
                keyPath.bundleURI == bundleURI {
                
                overriddenKeyPaths.insert(keyPath)
                if var entry = self.entry(for: keyPath) {
                    entry.overrideText = override.value
                    setEntry(entry, for: keyPath)
                }
            }
        }
    }
    
    private func bundleURI(for bundle: Bundle) -> BundleURI {
        let rootName = Bundle.main.bundleURL.lastPathComponent
        if bundle == Bundle.main {
            return rootName
        }
        
        if let relativePath = bundle.resourcePath!.relativePath(toParent: Bundle.main.resourcePath!) {
            let uri = rootName + ":" + relativePath.replacingOccurrences(of: "/Contents/Resources", with: ":")
            return uri.hasSuffix(":") ? uri.substring(to: uri.index(before: uri.endIndex)) : uri
        }
        return bundle.bundlePath
    }
    
    private func resourceURI(for resourceName: String, in bundle: Bundle) -> ResourceURI? {
        guard
            bundle.resourcePath != nil,
            let resourcePath = bundle.path(forResource: resourceName, ofType: nil)
        else {
            return nil
        }
        
        return resourcePath.relativePath(toParent: bundle.resourcePath!)
    }
    
}

