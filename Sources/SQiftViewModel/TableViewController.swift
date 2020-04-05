//
//  TableViewController.swift
//  ATMFinder_SQLite
//
//  Created by Jobe, Jason on 3/13/20.
//  Copyright © 2020 Jobe, Jason. All rights reserved.
//
//
import UIKit

public class TableViewController: UITableViewController {

    @IBInspectable
    var selectionKey: String?

    @IBInspectable
    var filter: String?

    @IBInspectable
    var cellIdentifier: String = "main"

    var dbids: [Int] = []

    public override func refresh(from model: ViewModel) {
        guard let table = modelId else { return }
        dbids = model.indentifiers(for: table, filter: filter)
        tableView.reloadData()
    }

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let viewModel = viewModel {
            refresh(from: viewModel)
        }
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem
    }

    // MARK: - Table view data source

    override public func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dbids.count
    }

    override public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath)
        return cell
    }

    public override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath)
    {
        // Configure the cell...
        guard let table = modelId else { return }
        let id = dbids[indexPath.row]
        viewModel?.refresh(view: cell, from: table, id: id)
    }

    /*
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */


    public override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let selectionKey = selectionKey else { return }
        try? viewModel?.set(env: "selected.\(selectionKey)", to: dbids[indexPath.row])
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override public func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let cell = sender as? UITableViewCell,
           let selectionKey = selectionKey,
           let ndx = self.tableView.indexPath(for: cell) {
            try? viewModel?.set(env: "selected.\(selectionKey)", to: dbids[ndx.row])
        }
    }

}
