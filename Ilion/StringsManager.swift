//
//  StringsManager.swift
//  Ilion
//
//  Created by Tamas Lustyik on 2017. 03. 15..
//  Copyright © 2017. Tamas Lustyik. All rights reserved.
//

import Foundation


enum Translation {
    case `static`(String)
    case `dynamic`(LocalizedFormat)
}

struct StringsEntry {
    var locKey: LocKey
    var translation: Translation
    var override: Translation?
}

enum StringsDictParseError: Error {
    case invalidFormat
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

        var resources: [ResourceURI: [LocKey: StringsEntry]] = [:]

        // strings files
        let stringsURLs = fileURLs(forExtension: "strings", in: bundle)
        
        for url in stringsURLs {
            let translations = readLocalizedStringsFile(atPath: url.path)
            var strings: [LocKey: StringsEntry] = [:]
            
            for (sKey, sValue) in translations {
                let entry = StringsEntry(locKey: sKey,
                                         translation: .static(sValue),
                                         override: nil)
                strings[sKey] = entry
            }
            
            let resourceURI = url.path.relativePath(toParent: rootPath)!
            resources[resourceURI] = strings
        }
        
        // stringsdict files
        let stringsDictURLs = fileURLs(forExtension: "stringsdict", in: bundle)
        
        for url in stringsDictURLs {
            let translations = readLocalizedStringsDictFile(atPath: url.path)
            var strings: [LocKey: StringsEntry] = [:]
            
            for (sKey, sValue) in translations {
                let entry = StringsEntry(locKey: sKey,
                                         translation: .dynamic(sValue),
                                         override: nil)
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
            let entry = db[bundleURI]?[resourceURI]?[key],
            case .static(let translatedText) = entry.translation
        else {
            return (value?.isEmpty ?? true) ? key : value!
        }
        
        if let override = entry.override, case .static(let overrideText) = override {
            return overrideText
        }
        
        return translatedText
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
        
        entry.override = .static(string)
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

        entry.override = nil
        setEntry(entry, for: keyPath)

        overriddenKeyPaths.remove(keyPath)

        var storedOverrides = userDefaults.dictionary(forKey: storedOverridesKey) ?? [:]
        storedOverrides[keyPath.description] = nil
        userDefaults.setValue(storedOverrides, forKey: storedOverridesKey)
    }
    
    func removeAllOverrides() {
        for keyPath in overriddenKeyPaths {
            if var entry = self.entry(for: keyPath) {
                entry.override = nil
                setEntry(entry, for: keyPath)
            }
        }
        
        userDefaults.setValue([:], forKey: storedOverridesKey)
    }

    func hasOverride(for keyPath: LocKeyPath) -> Bool {
        return overriddenKeyPaths.contains(keyPath)
    }
    
    // MARK: - private methods
    
    private func fileURLs(forExtension fileExt: String, in bundle: Bundle) -> Set<URL> {
        let unlocalizedURLs = bundle.urls(forResourcesWithExtension: fileExt,
                                          subdirectory: nil,
                                          localization: nil)!
        let localizedURLs = bundle.localizations
            .flatMap { localizationName in
                return bundle.urls(forResourcesWithExtension: fileExt,
                                   subdirectory: nil,
                                   localization: localizationName)!
        }
        return Set<URL>(localizedURLs + unlocalizedURLs)
    }

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
    
    private func readLocalizedStringsDictFile(atPath path: String) -> [String: LocalizedFormat] {
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
    
    private func applyOverrides(for bundle: Bundle) {
        let bundleURI = self.bundleURI(for: bundle)
        var storedOverrides: [String: String] = userDefaults.dictionary(forKey: storedOverridesKey) as? [String: String] ?? [:]
        var discardedOverrideKeys: [String] = []
        
        forEachOverride: for override in storedOverrides {
            guard
                let keyPath = LocKeyPath(string: override.key),
                keyPath.bundleURI == bundleURI
            else {
                continue
            }
            
            guard
                var entry = self.entry(for: keyPath),
                case .static(let translatedText) = entry.translation,
                let originalTypes = translatedText.formatPlaceholderTypes,
                let overrideTypes = override.value.formatPlaceholderTypes
            else {
                // ignore override if either that or the original string is not a valid format string
                discardedOverrideKeys.append(override.key)
                continue
            }

            // check whether the argument types match up
            for (position, type) in overrideTypes {
                guard
                    let originalType = originalTypes[position],
                    type == originalType
                else {
                    discardedOverrideKeys.append(override.key)
                    continue forEachOverride
                }
            }

            overriddenKeyPaths.insert(keyPath)
            entry.override = .static(override.value)
            setEntry(entry, for: keyPath)
        }
        
        if !discardedOverrideKeys.isEmpty {
            discardedOverrideKeys.forEach { storedOverrides.removeValue(forKey: $0) }
            userDefaults.setValue(storedOverrides, forKey: storedOverridesKey)
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

