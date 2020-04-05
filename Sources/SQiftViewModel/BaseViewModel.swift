//
//  BaseViewModel.swift
//  ATMFinder_SQLite
//
//  Created by Jobe, Jason on 3/10/20.
//  Copyright © 2020 Jobe, Jason. All rights reserved.
//
import Foundation
import SQift

// MARK: trace()
extension NSObject {
    func trace(line: Int = #line, file: String = #file, function: String = #function, _ msg: String = "") {
        let name = type(of: self)
        Swift.print("TRACE", line, name, function, msg)
    }
}

func trace(line: Int = #line, file: String = #file, function: String = #function, _ msg: String = "") {
    Swift.print("TRACE", line, function, msg)
}


public protocol FormValuesProvider {
    var namespace: String? { get }
    var modelId: String? { get }

    func formValues() -> [String:Any]
}

enum ViewModelError: String, Error {
    case MissingData, MissingBootFile, InvalidSerialization
}

@objc public protocol BaseViewModelDelegate: NSObjectProtocol {
    @objc optional func modelWillCommit(_ vm: BaseViewModel)
    @objc optional func modelDidUpdate(_ vm: BaseViewModel, info: BaseViewModel.DBUpdateInfo)
}

public class BaseViewModel: NSObject {
    
    @objc public class DBUpdateInfo: NSObject {
        var op: Connection.UpdateHookType
        var db: String
        var table: String
        var row: Int64 = 0
        
        @objc public override var description: String { "DBUpdate(\(op) \(db) \(table) \(row))" }
        
        init(op: Connection.UpdateHookType, db: String?, table: String?, row: Int64) {
            self.op = op
            self.db = db ?? "<db>"
            self.table = table ?? "<table>"
            self.row = row
        }
    }
    
    static var shared: BaseViewModel?
    
    public var db: AppDatabase
    public var delegate: BaseViewModelDelegate?
    
    init (storageLocation: StorageLocation = .inMemory) throws {

        db = try AppDatabase(storageLocation)
        super.init()
        try configureDatabase()
        if BaseViewModel.shared == nil {
            BaseViewModel.shared = self
        }
    }

    func didCommit() {
        delegate?.modelWillCommit?(self)
    }

    func didUpdate(_ log: DBUpdateInfo) {
        delegate?.modelDidUpdate?(self, info: log)
    }

    public func set(env: String, to value: Bindable) {
        try? db.set(env: env, to: value)
    }
    
    public func get<A>(env: String, default alt: A? = nil) -> A? {
        db.get(env: env) as? A ?? alt
    }
    
    var handleMissingResults: ((BaseViewModel, Any.Type, _ table: String, _ predicate: String?) -> Void)?
    
    func noResultsForFetch(of type: Any.Type, from table: String, where predicate: String?) {
        handleMissingResults?(self, type, table, predicate)
    }
    
    func fetch<T:ExpressibleByRow> (from table: String, filter: String? = nil, limit: Int? = nil) throws -> [T] {

        let test = filterPredicate(from: filter, asClause: true) ?? ""
        var limitClause = ""

        if let limit = limit  {
            limitClause = " LIMIT \(limit)"
        }
        let sql: SQL = "SELECT * from \(table) \(test)\(limitClause)"
        var results: [T] = []
        try fetch(sql, []) { row in
            if let item = try? T.init(row: row) {
                results.append(item)
            }
        }
        if results.isEmpty {
            noResultsForFetch(of: T.self, from: table, where: test)
        }
        return results
    }

    func sql_predicate(field: String?, search: String?) -> String? {
        guard let field = field, let search = search else { return nil }

        if let filter = db.get(env: search) as? String {
            guard !filter.isEmpty else { return nil }
            let keys = filter.split(separator: " ")
            var pred = ""
            let end = keys.count - 1
            for (ndx, key) in keys.enumerated() {
                pred += "\(field) LIKE '%\(key)%'"
                if ndx < end { pred += " AND " }
            }
            return pred
        }
        return nil
    }

    func filterPredicate(from text: String?, asClause: Bool = false) -> String? {
        guard let text = text else { return nil }
        let parts = text.components(separatedBy: CharacterSet(charactersIn: "./"))
        switch parts.count {
        case 1:
            return asClause ? "WHERE \(text)" : text
        case 2:
            if let test = sql_predicate(field: parts[1], search: parts[0]) {
                return asClause ? "WHERE \(test)" : test
            } else {
                return nil
            }
        default:
            return nil
        }
    }
        
    func configureDatabase() throws {

        try db.createApplicationDatabase()

        try db.executeWrite {
            $0.commitHook { [weak self] () -> Bool in
                guard let delegate = self?.delegate,
                    delegate.responds(to: #selector(BaseViewModelDelegate.modelWillCommit(_:)))
                else { return false }

                DispatchQueue.main.async {
                    self?.didCommit()
                }
                return false
            }

            $0.updateHook { [weak self] (op, database, table, row) in
                guard let delegate = self?.delegate,
                    delegate.responds(to: #selector(BaseViewModelDelegate.modelDidUpdate(_:info:)))
                else { return }
                
                let log = DBUpdateInfo(op: op, db: database, table: table, row: row)
                DispatchQueue.main.async {
                    self?.didUpdate(log)
                }
            }
        }
    }
    
    func load (_ name: String?, keypath: String? = nil, into table: String) throws {
        guard let name = name else { throw ViewModelError.MissingData }
        if name.starts(with: "http") {
            return try load (URL(string: name), keypath: keypath, into: table)
        }
        if name.starts(with: "file://") {
            return try load (URL(string: name), keypath: keypath, into: table)
        }
    }

    func load (_ url: URL?, keypath: String? = nil, into table: String) throws {
        guard let url = url else { throw ViewModelError.MissingData }
        if url.isFileURL {
            return try load(url.path, from: keypath, into: table) }
        else {
            return load(url: url, from: keypath, into: table)
        }
    }

    func load (url: URL, from key: String? = nil, into table: String) {

        URLSession.shared.dataTask(with: url) { (data, response, error) in
            if let error = error {
                Swift.print (error)
                return
            }
            guard let data = data else { return }
            do {
                if let package = try JSONSerialization.jsonObject(with: data, options: []) as? NSObject {
                    try self.load(json: package, from: key, into: table)
                }
            }
            catch {
                Swift.print ("ERROR loading \(url): \(error)")
            }
        }.resume()
    }
    
    func load (_ file: String, in bundle: Bundle = Bundle.main, from key: String? = nil, into table: String) throws {
        var path: String
        if FileManager().fileExists(atPath: file) {
            path = file
        } else if let rpath = bundle.path(forResource: file, ofType: "") {
            path = rpath
        }
        else { throw ViewModelError.MissingData }

        let url = URL(fileURLWithPath: path)
        let data = try Data(contentsOf: url)

        if let package = try JSONSerialization.jsonObject(with: data, options: []) as? NSObject {
            try load(json: package, from: key, into: table)
        } else { throw ViewModelError.InvalidSerialization }
    }
    
    /// This method is responsible for inserting the indicated Dictionary items into
    /// the database.
    func load(json: NSObject, from key: String? = nil, into table: String) throws {

        var plist: Any?

        if let key = key, !key.isEmpty {
            plist = json.value(forKeyPath: key)
        } else {
            plist = json
        }
        guard let items = plist as? [Any] else { throw ViewModelError.InvalidSerialization }
        
        try db.executeWrite {
            for item in items {
                guard let dict = item as? [String:Any] else { continue }
                try $0.insert(into: table, from: dict)
            }
        }
    }

}

// MARK: SQift Method Wrappers

extension BaseViewModel {

    func select(_ col: String, from table: String, id: Int) throws -> Any? {
        var result: Any?
        try db.executeRead {
            result = try $0.select(col, from: table, id: id)
        }
        if result == nil {
            noResultsForFetch(of: Any.self, from: table, where: "id = \(id)")
        }
        return result
    }

    func select(_ cols: [String], from table: String, where test: String? = nil) throws -> [[String:Any]] {
        var result: Any?
        try db.executeRead {
            result = try $0.select(cols, from: table, where: test)
        }
        if result == nil {
            noResultsForFetch(of: Any.self, from: table, where: test)
        }
        return result as? [[String:Any]] ?? []
    }

    func fetch (_ sql: SQift.SQL, _ parameters: [SQift.Bindable?], _ body: (Row) -> Void) throws {
        try db.executeRead {
            try $0.fetch(sql, parameters, body)
        }
    }

}

// MARK: UI Aware functions
import UIKit

@objc public protocol ViewModel: NSObjectProtocol {
    func refresh(view: UIView, from: String, id: Int)
}

extension ViewModel {
    
    func set(env: String, to value: Bindable) throws {
        try BaseViewModel.shared?.db.set(env: env, to: value)
    }

    func get<A>(env: String, default alt: A?) -> A? {
        BaseViewModel.shared?.db.get(env: env) as? A ?? alt
    }
        
    func indentifiers(for table: String, filter: String?) -> [Int] {
        BaseViewModel.shared?.indentifiers(for: table, filter: filter) ?? []
    }

    func fetch<T:ExpressibleByRow> (from table: String, filter: String? = nil, limit: Int? = nil) -> [T] {
        (try? BaseViewModel.shared?.fetch(from: table, filter: filter, limit: limit)) ?? []
    }
}

extension BaseViewModel: ViewModel {
    
    public func refresh(view: UIView, from uri: String, id: Int) {
        guard let mkey = ModelKey(uri) else { return }
        view.visit {
            guard let key = ModelKey($0.modelId) else { return }
            let value = try? select(key.column, from: mkey.table, id: id)
            $0.contentValue = value
        }
    }
    
    func indentifiers(for table: String, filter: String?) -> [Int] {
        var results: [Int64]?
        let test = filterPredicate(from: filter, asClause: false)
        try? db.executeRead { (c) in
            results = try? c.rowids(for: table, where: test)
        }
        guard let list = results, !list.isEmpty else {
            noResultsForFetch(of: [Int].self, from: table, where: test)
            return []
        }
        return list.map { Int($0) }
    }
}

extension UIViewController {
    @objc public func refresh(from model: ViewModel) {
    }
}

protocol ViewModelProvider {
    var baseViewModel: BaseViewModel { get }
}

extension UIResponder {
    var viewModel: ViewModel? {
        return (self as? ViewModel)
            ?? (self as? ViewModelProvider)?.baseViewModel
            ?? next?.viewModel
            ?? BaseViewModel.shared
    }
}
