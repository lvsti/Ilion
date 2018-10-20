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
    var comment: String?
    var translation: Translation
    var override: Translation?
}

enum StringsDictParseError: Error {
    case invalidFormat
}

enum OverrideError: Error {
    case invalidKeyPath
    case invalidOriginalFormat
    case unspecifiedVariableInOverride(position: Int)
    case ambiguousVariableTypesInOverride(position: Int, typeA: String, typeB: String)
}

typealias StringsDB = [BundleURI: [ResourceURI: [LocKey: StringsEntry]]]

@objc final class StringsManager: NSObject {
    
    private let storedOverridesKey = "Ilion.TranslationOverrides"
    private let markersKey = "Ilion.InsertsStartEndMarkers"
    private let transformKey = "Ilion.TransformsCharacters"
    private let expansionFactorKey = "Ilion.SimulatedExpansionFactor"
    
    private let userDefaults: UserDefaults
    private let stringsFileParser: StringsFileParser
    
    private(set) var stringsFiles: [BundleURI: [ResourceURI: StringsFile]]
    private(set) var db: StringsDB
    private var overriddenKeyPaths: Set<LocKeyPath>
    
    var insertsStartEndMarkers: Bool = false {
        didSet {
            userDefaults.setValue(insertsStartEndMarkers, forKey: markersKey)
        }
    }

    var transformsCharacters: Bool = false {
        didSet {
            userDefaults.setValue(transformsCharacters, forKey: transformKey)
        }
    }

    var expansionFactor: Double? = nil {
        didSet {
            if let factor = expansionFactor {
                userDefaults.setValue(factor, forKey: expansionFactorKey)
            }
            else {
                userDefaults.removeObject(forKey: expansionFactorKey)
            }
        }
    }

    @objc static let defaultManager = StringsManager(userDefaults: .standard, stringsFileParser: StringsFileParser())
    
    private init(userDefaults: UserDefaults, stringsFileParser: StringsFileParser) {
        self.userDefaults = userDefaults
        self.stringsFileParser = stringsFileParser
        
        stringsFiles = [:]
        db = [:]
        overriddenKeyPaths = []
        insertsStartEndMarkers = userDefaults.value(forKey: markersKey) as? Bool ?? false
        transformsCharacters = userDefaults.value(forKey: transformKey) as? Bool ?? false
        if let factor = userDefaults.value(forKey: expansionFactorKey) as? Double {
            expansionFactor = min(max(factor, 1), 2)
        }

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
            guard let stringsFile = stringsFileParser.readStringsFile(at: url.path) else {
                continue
            }
            
            var strings: [LocKey: StringsEntry] = [:]
            
            for key in stringsFile.entries.keys {
                let entry = StringsEntry(locKey: key,
                                         comment: stringsFile.comment(for: key),
                                         translation: .static(stringsFile.value(for: key)!),
                                         override: nil)
                strings[key] = entry
            }
            
            let resourceURI = url.path.relativePath(toParent: rootPath)!
            resources[resourceURI] = strings
            
            var fileResources = stringsFiles[bundleURI] ?? [ResourceURI: StringsFile]()
            fileResources[resourceURI] = stringsFile
            stringsFiles[bundleURI] = fileResources
        }
        
        // stringsdict files
        let stringsDictURLs = fileURLs(forExtension: "stringsdict", in: bundle)
        
        for url in stringsDictURLs {
            let translations = stringsFileParser.readStringsDictFile(at: url.path)
            var strings: [LocKey: StringsEntry] = [:]
            
            for (sKey, sValue) in translations {
                let entry = StringsEntry(locKey: sKey,
                                         comment: nil,
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
            let stringsResourceURI = self.resourceURI(for: (table ?? "Localizable") + ".strings",
                                                      in: bundle ?? .main),
            let stringsDictResourceURI = self.resourceURI(for: (table ?? "Localizable") + ".stringsdict",
                                                          in: bundle ?? .main) ?? .some(""),
            let entry = db[bundleURI]?[stringsDictResourceURI]?[key] ?? db[bundleURI]?[stringsResourceURI]?[key]
        else {
            let baseCopy = (value?.isEmpty ?? true) ? key : value!
            return [Translation.static(baseCopy)]
                .map { transformsCharacters ? $0.applyingPseudoLocalization() : $0 }
                .map { expansionFactor != nil ? $0.simulatingExpansion(by: expansionFactor!) : $0 }
                .map { insertsStartEndMarkers ? $0.addingStartEndMarkers() : $0 }
                .first!
                .toString()
        }

        return [entry.override ?? entry.translation]
            .map { transformsCharacters ? $0.applyingPseudoLocalization() : $0 }
            .map { expansionFactor != nil ? $0.simulatingExpansion(by: expansionFactor!) : $0 }
            .map { insertsStartEndMarkers ? $0.addingStartEndMarkers() : $0 }
            .first!
            .toString()
    }
    
    // MARK: - internal Swift API
    
    func entry(for keyPath: LocKeyPath) -> StringsEntry? {
        return db[keyPath.bundleURI]?[keyPath.resourceURI]?[keyPath.locKey]
    }
    
    func setEntry(_ entry: StringsEntry, for keyPath: LocKeyPath) {
        db[keyPath.bundleURI]?[keyPath.resourceURI]?[keyPath.locKey] = entry
    }
    
    func addOverride(_ override: Translation, for keyPath: LocKeyPath) throws {
        guard var entry = self.entry(for: keyPath) else {
            throw OverrideError.invalidKeyPath
        }
        
        try validateOverride(override, for: entry.translation)
        
        entry.override = override
        setEntry(entry, for: keyPath)
        
        overriddenKeyPaths.insert(keyPath)
        
        var storedOverrides = userDefaults.dictionary(forKey: storedOverridesKey) ?? [:]
        switch override {
        case .static(let string): storedOverrides[keyPath.description] = string
        case .dynamic(let format): storedOverrides[keyPath.description] = format.toStringsDictEntry()
        }
        
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
    
    func validateOverride(_ override: Translation, for original: Translation) throws {
        
        func validateText(_ overrideText: String, asSubstituteForFormat descriptor: FormatDescriptor) throws {
            do {
                let overrideDescriptor = try FormatDescriptor(format: overrideText)
                try overrideDescriptor.validateAsSubstitute(for: descriptor)
            }
            catch let error as FormatDescriptorError {
                // ignore override if it is not a valid format string or the types don't match up
                switch error {
                case .unspecifiedVariable(let pos):
                    throw OverrideError.unspecifiedVariableInOverride(position: pos)
                case .ambiguousVariableTypes(let pos, let typeA, let typeB):
                    throw OverrideError.ambiguousVariableTypesInOverride(position: pos, typeA: typeA, typeB: typeB)
                }
            }
        }
        
        // switch over 4 override scenarios:
        // - static text with static
        // - static text with dynamic format
        // - dynamic format with static text
        // - dynamic format with dynamic format
        switch original {
        case .static(let originalText):
            let originalDescriptor: FormatDescriptor
            do {
                originalDescriptor = try FormatDescriptor(format: originalText)
            }
            catch {
                // ignore override if the original string is not a valid format string
                throw OverrideError.invalidOriginalFormat
            }
            
            let overrideTextsToValidate: [String]
            switch override {
            case .static(let overrideText):
                overrideTextsToValidate = [overrideText]
            case .dynamic(let overrideLocFormat):
                overrideTextsToValidate = overrideLocFormat.variableSpecs
                    .flatMap { $0.value.ruleSpecs.values }
            }

            for overrideText in overrideTextsToValidate {
                try validateText(overrideText, asSubstituteForFormat: originalDescriptor)
            }

        case .dynamic(let originalLocFormat):
            let mergedDescriptor: FormatDescriptor
            
            do {
                let originalDescriptors = try originalLocFormat.variableSpecs
                    .flatMap { $0.value.ruleSpecs.values }
                    .map { try FormatDescriptor(format: $0) }
                mergedDescriptor = try FormatDescriptor.merge(originalDescriptors)
            }
            catch {
                // ignore override if any rule of the original string is not a valid format string,
                // or the format variable typed don't match up
                throw OverrideError.invalidOriginalFormat
            }
            
            switch override {
            case .static(let overrideText):
                try validateText(overrideText, asSubstituteForFormat: mergedDescriptor)
            case .dynamic(let overrideLocFormat):
                let overrideTextsToValidate = overrideLocFormat.variableSpecs
                    .flatMap { $0.value.ruleSpecs.values }
                
                for overrideText in overrideTextsToValidate {
                    try validateText(overrideText, asSubstituteForFormat: mergedDescriptor)
                }
            }
        } // switch original
    }
    
    func exportOverrides(to folderURL: URL) throws {
        for (bundleURI, resources) in db {
            var pluralizedKeys: [ResourceURI: Set<LocKey>] = [:]
            let nonDictResources = resources.filter({ !isStringsDictResourceURI($0.key) })
            
            for (resourceURI, entries) in nonDictResources {
                if let stringsFile = stringsFiles[bundleURI]?[resourceURI] {
                    let mutableContent = stringsFile.content.mutableCopy() as! NSMutableString
                    let reverseSortedStringsFileEntries = stringsFile.entries.sorted {
                        $0.value.keyRange.location > $1.value.keyRange.location
                    }
                    
                    for (key, stringsFileEntry) in reverseSortedStringsFileEntries {
                        if let override = entries[key]?.override {
                            switch override {
                            case .static(let text):
                                mutableContent.replaceCharacters(in: stringsFileEntry.valueRange,
                                                                 with: text)
                            case .dynamic:
                                if pluralizedKeys[resourceURI] == nil {
                                    pluralizedKeys[resourceURI] = []
                                }
                                pluralizedKeys[resourceURI]?.insert(key)
                            }
                        }
                    }
                    
                    let fileURL = exportURL(relativeTo: folderURL, bundleURI: bundleURI, resourceURI: resourceURI)
                    
                    try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                            withIntermediateDirectories: true,
                                                            attributes: nil)
                    try (mutableContent as String).write(to: fileURL,
                                                         atomically: false,
                                                         encoding: stringsFile.encoding)
                } // if let stringsFile
                
                let counterpartURI = stringsDictResourceURI(from: resourceURI)
                if !(pluralizedKeys[resourceURI]?.isEmpty ?? true) && db[bundleURI]?[counterpartURI] == nil {
                    // no stringsdict with the same name, we have to create one
                    var dict: [String: [String: Any]] = [:]
                    for key in pluralizedKeys[resourceURI]! {
                        guard let override = entries[key]?.override, case .dynamic(let format) = override else {
                            continue
                        }
                        
                        dict[key] = format.toStringsDictEntry()
                    }

                    let fileURL = exportURL(relativeTo: folderURL, bundleURI: bundleURI, resourceURI: counterpartURI)
                    try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                            withIntermediateDirectories: true,
                                                            attributes: nil)
                    
                    (dict as NSDictionary).write(to: fileURL, atomically: false)
                    
                    pluralizedKeys[resourceURI] = nil
                }
                
            } // for nonDictResources
            
            let dictResources = resources.filter({ isStringsDictResourceURI($0.key) })
            
            for (resourceURI, entries) in dictResources {
                var dict: [String: [String: Any]] = [:]

                for (key, entry) in entries {
                    guard case .dynamic(let originalFormat) = entry.translation else {
                        continue
                    }
                    
                    if let override = entry.override, case .dynamic(let format) = override {
                        dict[key] = format.toStringsDictEntry()
                    }
                    else {
                        dict[key] = originalFormat.toStringsDictEntry()
                    }
                }
                
                let counterpartURI = stringsResourceURI(from: resourceURI)
                for key in pluralizedKeys[counterpartURI] ?? [] {
                    guard
                        let pluralizedEntry = db[bundleURI]?[counterpartURI]?[key],
                        let override = pluralizedEntry.override,
                        case .dynamic(let format) = override
                    else {
                        continue
                    }

                    dict[key] = format.toStringsDictEntry()
                }
                
                let fileURL = exportURL(relativeTo: folderURL, bundleURI: bundleURI, resourceURI: resourceURI)
                try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                        withIntermediateDirectories: true,
                                                        attributes: nil)
                (dict as NSDictionary).write(to: fileURL, atomically: false)
                pluralizedKeys[resourceURI] = nil
            }

        } // for db
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
    
    private func applyOverrides(for bundle: Bundle) {
        let bundleURI = self.bundleURI(for: bundle)
        var storedOverrides: [String: Any] = userDefaults.dictionary(forKey: storedOverridesKey) ?? [:]
        var discardedOverrideKeys: [String] = []
        
        forEachOverride: for storedOverride in storedOverrides {
            guard
                let keyPath = LocKeyPath(string: storedOverride.key),
                keyPath.bundleURI == bundleURI
            else {
                continue
            }
            
            guard var entry = self.entry(for: keyPath) else {
                // ignore override if the key is not found
                discardedOverrideKeys.append(storedOverride.key)
                continue
            }
            
            let override: Translation
            if let overrideText = storedOverride.value as? String {
                override = .static(overrideText)
            }
            else if let config = storedOverride.value as? [String: Any],
                let overrideFormat = try? LocalizedFormat(config: config) {
                override = .dynamic(overrideFormat)
            }
            else {
                // ignore override if it has an invalid format
                discardedOverrideKeys.append(storedOverride.key)
                continue
            }
            
            guard ((try? validateOverride(override, for: entry.translation)) != nil) else {
                discardedOverrideKeys.append(storedOverride.key)
                continue forEachOverride
            }
            
            overriddenKeyPaths.insert(keyPath)
            entry.override = override
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
            return uri.hasSuffix(":") ? String(uri[..<uri.endIndex]) : uri
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

    private func stringsResourceURI(from resourceURI: ResourceURI) -> ResourceURI {
        return ((resourceURI as NSString).deletingPathExtension as NSString).appendingPathExtension("strings")!
    }

    private func stringsDictResourceURI(from resourceURI: ResourceURI) -> ResourceURI {
        return ((resourceURI as NSString).deletingPathExtension as NSString).appendingPathExtension("stringsdict")!
    }
    
    private func isStringsDictResourceURI(_ resourceURI: ResourceURI) -> Bool {
        return (resourceURI as NSString).pathExtension == "stringsdict"
    }
    
    private func exportURL(relativeTo url: URL, bundleURI: BundleURI, resourceURI: ResourceURI) -> URL {
        return url
            .appendingPathComponent(bundleURI.replacingOccurrences(of: ":", with: "-resources/").appending("-resources"))
            .appendingPathComponent(resourceURI)
    }
    
}

