//
//  BrowserWindowController.swift
//  Ilion
//
//  Created by Tamas Lustyik on 2017. 03. 15..
//  Copyright © 2017. Tamas Lustyik. All rights reserved.
//

import Cocoa

protocol BrowserWindowControllerDelegate: class {
    func browserWindow(_ sender: BrowserWindowController,
                       willStartEditingEntryFor keyPath: LocKeyPath)
    func browserWindowDidResetOverrides(_ sender: BrowserWindowController)
    func browserWindow(_ sender: BrowserWindowController,
                       didRemoveOverrideFor keyPath: LocKeyPath)
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
    
    override var windowNibName: String? {
        return "BrowserWindow"
    }

    override func awakeFromNib() {
        appIcon = NSWorkspace.shared().icon(forFileType: kUTTypeApplicationBundle as String)
        bundleIcon = NSWorkspace.shared().icon(forFileType: kUTTypeBundle as String)
        resourceIcon = NSWorkspace.shared().icon(forFileType: kUTTypePlainText as String)
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
    
    override func controlTextDidChange(_ obj: Notification) {
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

        let isMatching: (String) -> Bool = { [unowned self] in
            $0.range(of: self.searchField.stringValue, options: [.caseInsensitive]) != nil
        }

        let bundlePairs = db
            .fmap { bundleURI, tables in
                let tablePairs = tables
                    .fmap { resourceURI, entries in
                        let entryPairs = entries.filter { key, entry in
                            // modified state condition
                            (search.modifiedFilter == .all ||
                             search.modifiedFilter == .modifiedOnly && entry.overrideText != nil ||
                             search.modifiedFilter == .unmodifiedOnly && entry.overrideText == nil) &&
                            // string matching condition
                            (search.searchTerm.isEmpty ||
                             (isMatching(entry.locKey) ||
                              isMatching(entry.sourceText) ||
                              isMatching(entry.translatedText) ||
                              entry.overrideText != nil && isMatching(entry.overrideText!)))
                        }
                        return Dictionary(pairs: entryPairs)
                    }
                    .filter { (resourceURI: ResourceURI, entries: [LocKey: StringsEntry]) in !entries.isEmpty }
                return Dictionary(pairs: tablePairs)
            }
            .filter { (bundleURI: BundleURI, tables: [ResourceURI: [LocKey: StringsEntry]]) in !tables.isEmpty }
        
        filteredDB = Dictionary(pairs: bundlePairs)
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
                                return BrowserItem(title: locKey,
                                                   value: entry.overrideText ?? entry.translatedText,
                                                   children: [],
                                                   kind: .string(keyPath: keyPath,
                                                                 isOverridden: entry.overrideText != nil))
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

        let cell: NSTableCellView = outlineView.make(withIdentifier: columnID, owner: nil) as! NSTableCellView
        
        if columnID == "outline" {
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


