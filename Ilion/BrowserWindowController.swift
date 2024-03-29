//
//  BrowserWindowController.swift
//  Ilion
//
//  Created by Tamas Lustyik on 2017. 03. 15..
//  Copyright © 2017. Tamas Lustyik. All rights reserved.
//

import Cocoa

protocol BrowserWindowControllerDelegate: AnyObject {
    func browserWindow(_ sender: BrowserWindowController,
                       willStartEditingEntryFor keyPath: LocKeyPath)
    func browserWindowDidResetOverrides(_ sender: BrowserWindowController)
    func browserWindow(_ sender: BrowserWindowController,
                       didRemoveOverrideFor keyPath: LocKeyPath)
    func browserWindowDidExportOverrides(_ sender: BrowserWindowController)
    func browserWindowDidInvokeTools(_ sender: BrowserWindowController)
    func browserWindowWillClose(_ sender: BrowserWindowController)
}

enum ResourceType {
    case unlocalized
    case base
    case localized(identifier: String)
    
    init?(resourceURI: ResourceURI) {
        guard !resourceURI.isEmpty else {
            return nil
        }
        
        let comps = resourceURI.components(separatedBy: "/")
        if comps.count == 1 {
            self = .unlocalized
            return
        }
        
        let folder = comps[comps.count - 2]
        if !folder.hasSuffix(".lproj") {
            self = .unlocalized
        }
        else {
            let localizationID = (folder as NSString).deletingPathExtension
            if localizationID == "Base" {
                self = .base
            } else {
                self = .localized(identifier: localizationID)
            }
        }
    }
}

enum BrowserItemKind {
    case bundle(uri: BundleURI)
    case resource(bundleURI: BundleURI, resourceURI: ResourceURI, type: ResourceType)
    case string(keyPath: LocKeyPath, isOverridden: Bool)
}

struct BrowserItem {
    let title: String
    let value: String?
    let children: [BrowserItem]
    let kind: BrowserItemKind
}

enum ModifiedFilter {
    case all, modifiedOnly, unmodifiedOnly
}

struct SearchDescriptor {
    let modifiedFilter: ModifiedFilter
    let searchTerm: String
}

extension SearchDescriptor: Equatable {
    static func ==(lhs: SearchDescriptor, rhs: SearchDescriptor) -> Bool {
        return lhs.modifiedFilter == rhs.modifiedFilter && lhs.searchTerm == rhs.searchTerm
    }
}

final class BrowserWindowController: NSWindowController {
    @IBOutlet private weak var searchField: NSSearchField!
    @IBOutlet private weak var modifiedFilterControl: NSSegmentedControl!
    @IBOutlet private weak var outlineView: NSOutlineView!
    
    fileprivate var appIcon: NSImage!
    fileprivate var bundleIcon: NSImage!
    fileprivate var resourceIcon: NSImage!
    private var lastSearch: SearchDescriptor?
    private var searchThrottleTimer: Timer?
    
    fileprivate var db: StringsDB = [:] {
        didSet {
            updateFilteredDB(forcibly: true)
        }
    }
    fileprivate var filteredDB: StringsDB = [:] {
        didSet {
            updateItems()
        }
    }
    fileprivate var items: [BrowserItem] = [] {
        didSet {
            guard outlineView != nil else {
                return
            }
            
            outlineView.reloadData()
            outlineView.expandItem(nil, expandChildren: true)
        }
    }
    
    weak var delegate: BrowserWindowControllerDelegate? = nil
    
    override var windowNibName: NSNib.Name? {
        return NSNib.Name("BrowserWindow")
    }

    override func awakeFromNib() {
        appIcon = NSWorkspace.shared.icon(forFileType: kUTTypeApplicationBundle as String)
        bundleIcon = NSWorkspace.shared.icon(forFileType: kUTTypeBundle as String)
        resourceIcon = NSWorkspace.shared.icon(forFileType: kUTTypePlainText as String)
    }

    func configure(with db: StringsDB) {
        self.db = db
    }
    
    @IBAction func changeModifiedFilter(_ sender: AnyObject) {
        updateFilteredDB()
    }
    
    @IBAction func editEntry(_ sender: AnyObject) {
        guard
            let item = outlineView.item(atRow: outlineView.clickedRow) as? BrowserItem,
            case .string(let keyPath, _) = item.kind
        else {
            return
        }
        delegate?.browserWindow(self, willStartEditingEntryFor: keyPath)
    }

    @IBAction func resetOverrides(_ sender: AnyObject) {
        delegate?.browserWindowDidResetOverrides(self)
    }
    
    @IBAction func exportOverrides(_ sender: AnyObject) {
        delegate?.browserWindowDidExportOverrides(self)
    }
    
    @IBAction func openToolsPanel(_ sender: Any) {
        delegate?.browserWindowDidInvokeTools(self)
    }
    
    func controlTextDidChange(_ obj: Notification) {
        guard let field = obj.object as? NSObject, field == searchField else {
            return
        }
        
        if let timer = searchThrottleTimer {
            timer.invalidate()
        }
        
        searchThrottleTimer = Timer.scheduledTimer(timeInterval: 0.25,
                                                   target: self,
                                                   selector: #selector(performSearch),
                                                   userInfo: nil,
                                                   repeats: false)
    }
    
    @objc private func performSearch() {
        updateFilteredDB()
    }
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 0x33 {
            // backspace on selection
            guard
                outlineView.selectedRow != -1,
                let item = outlineView.item(atRow: outlineView.selectedRow) as? BrowserItem,
                case .string(let keyPath, true) = item.kind
            else {
                return
            }
            
            delegate?.browserWindow(self, didRemoveOverrideFor: keyPath)
        } else if event.keyCode == 0x24 {
            // enter on selection
            guard
                outlineView.selectedRow != -1,
                let item = outlineView.item(atRow: outlineView.selectedRow) as? BrowserItem,
                case .string(let keyPath, _) = item.kind
            else {
                return
            }
            
            delegate?.browserWindow(self, willStartEditingEntryFor: keyPath)
        }
    }
    
    private func updateFilteredDB(forcibly: Bool = false) {
        let filterForIndex: [ModifiedFilter] = [.all, .modifiedOnly, .unmodifiedOnly]
        let search = SearchDescriptor(modifiedFilter: filterForIndex[modifiedFilterControl.selectedSegment],
                                      searchTerm: searchField.stringValue)
        guard lastSearch == nil || search != lastSearch! || forcibly else {
            return
        }

        let isMatching: (String) -> Bool = {
            $0.range(of: search.searchTerm, options: [.caseInsensitive]) != nil
        }

        let matchesModifiedState: (StringsEntry) -> Bool = {
            search.modifiedFilter == .all ||
            search.modifiedFilter == .modifiedOnly && $0.override != nil ||
            search.modifiedFilter == .unmodifiedOnly && $0.override == nil
        }
        
        let matchesSearchTerm: (StringsEntry) -> Bool = {
            isMatching($0.locKey) ||
            {
                switch $0.translation {
                case .static(let text): return isMatching(text)
                case .dynamic(let format):
                    return format.variableSpecs.reduce(false) { acc, pair in
                        return acc || pair.value.ruleSpecs.values.reduce(false) {
                            acc, str in acc || isMatching(str)
                        }
                    }
                }
            }($0) ||
            $0.override != nil && {
                switch $0.override! {
                case .static(let text): return isMatching(text)
                case .dynamic(let format):
                    return format.variableSpecs.reduce(false) { acc, pair in
                        return acc || pair.value.ruleSpecs.values.reduce(false) {
                            acc, str in acc || isMatching(str)
                        }
                    }
                }
            }($0)
        }
        
        filteredDB = db
            .fmap { bundleURI, tables in
                return tables
                    .fmap { resourceURI, entries in
                        return entries.filter { key, entry in
                            matchesModifiedState(entry) &&
                            (search.searchTerm.isEmpty || matchesSearchTerm(entry))
                        }
                    }
                    .filter { (resourceURI: ResourceURI, entries: [LocKey: StringsEntry]) in !entries.isEmpty }
            }
            .filter { (bundleURI: BundleURI, tables: [ResourceURI: [LocKey: StringsEntry]]) in !tables.isEmpty }
        
        lastSearch = search
    }
    
    private func updateItems() {
        let bundleItems: [BrowserItem] = filteredDB
            .sorted { $0.key < $1.key }
            .map { bundleURI, tables in
                let tableItems: [BrowserItem] = tables
                    .sorted  { $0.key < $1.key }
                    .map { resourceURI, entries in
                        let entryItems: [BrowserItem] = entries
                            .sorted { $0.key < $1.key }
                            .map { locKey, entry in
                                let keyPath = LocKeyPath(bundleURI: bundleURI,
                                                         resourceURI: resourceURI,
                                                         locKey: locKey)
                                var value = locKey

                                let translation = entry.override ?? entry.translation
                                if case .static(let text) = translation {
                                    value = text
                                } else if case .dynamic(let format) = translation {
                                    value = format.mergedPluralForms[.other]!
                                }
                                
                                return BrowserItem(title: locKey,
                                                   value: value,
                                                   children: [],
                                                   kind: .string(keyPath: keyPath,
                                                                 isOverridden: entry.override != nil))
                            }
                        
                        return BrowserItem(title: resourceURI,
                                           value: nil,
                                           children: entryItems,
                                           kind: .resource(bundleURI: bundleURI,
                                                           resourceURI: resourceURI,
                                                           type: ResourceType(resourceURI: resourceURI)!))
                    }

                return BrowserItem(title: bundleURI,
                                   value: nil,
                                   children: tableItems,
                                   kind: .bundle(uri: bundleURI))
            }
        
        items = bundleItems
    }
    
}


extension BrowserWindowController: NSOutlineViewDelegate {

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let columnID = tableColumn?.identifier else {
            return nil
        }
        
        guard let item = item as? BrowserItem else {
            return nil
        }

        let cell: NSTableCellView = outlineView.makeView(withIdentifier: columnID, owner: nil) as! NSTableCellView
        
        if columnID.rawValue == "outline" {
            cell.textField?.stringValue = item.title
            switch item.kind {
            case .bundle(let uri):
                cell.imageView?.image = uri.hasSuffix("app") ? appIcon : bundleIcon
            case .resource(_, _, let type):
                cell.imageView?.image = resourceIcon
                let prefix: String
                switch type {
                case .base: prefix = "[Base] "
                case .unlocalized: prefix = "[Unlocalized] "
                case .localized(let identifier): prefix = "[\(identifier)] "
                }
                cell.textField?.stringValue = prefix + (item.title as NSString).lastPathComponent
            case .string:
                cell.imageView?.image = nil
            }
        } else {
            cell.textField?.stringValue = item.value ?? ""
            cell.imageView?.image = nil
        }
        
        if case .string(_, true) = item.kind {
            cell.textField?.font = .boldSystemFont(ofSize: 13)
        }
        else {
            cell.textField?.font = .systemFont(ofSize: 13)
        }

        return cell
    }

}

extension BrowserWindowController: NSOutlineViewDataSource {
    
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        guard let item = item else {
            return items.count
        }
        
        return (item as! BrowserItem).children.count
    }
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        guard let item = item as? BrowserItem else {
            return false
        }
        return !item.children.isEmpty
    }
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        guard let item = item else {
            return items[index]
        }
        
        return (item as! BrowserItem).children[index]
    }

}

extension BrowserWindowController: NSWindowDelegate {
    
    func windowWillClose(_ notification: Notification) {
        delegate?.browserWindowWillClose(self)
    }
    
}


