//
//  Created by Feldmaus on 09.07.17.
//  Copyright © 2017 ischlecken. All rights reserved.
//

import UIKit
import CoreData
import CeleturKit

class TresorDocumentItemViewController: UITableViewController {
  
  var tresorDocument: TresorDocument?
  var tresorAppState: TresorAppState?
  
  
  override func viewDidLoad() {
    super.viewDidLoad()
    // Do any additional setup after loading the view, typically from a nib.
    navigationItem.leftBarButtonItem = editButtonItem
    
    let addButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(insertNewObject(_:)))
    navigationItem.rightBarButtonItem = addButton
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
  
  @objc
  func insertNewObject(_ sender: Any) {
    
    do {
      try self.tresorAppState?.tresorDataModel.createTresorDocumentItem(tresorDocument:tresorDocument!,masterKey: (self.tresorAppState?.masterKey!)!) {
        self.tableView.reloadData()
      }
    } catch let celeturKitError as CeleturKitError {
      celeturLogger.error("CeleturKitError while creating tresor document item",error:celeturKitError)
    } catch {
      celeturLogger.error("Error while creating tresor document item",error:error)
    }
    
  }
  
  // MARK: - Segues
  
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    if segue.identifier == "showTresorDocumentItemDetail" {
      if let indexPath = tableView.indexPathForSelectedRow {
        let object = self.tresorDocument?.items?.allObjects[indexPath.row] as? TresorDocumentItem
        let controller = (segue.destination as! UINavigationController).topViewController as! DetailViewController
        controller.tresorAppState = self.tresorAppState
        controller.tresorDocumentItem = object
        controller.navigationItem.leftBarButtonItem = splitViewController?.displayModeButtonItem
        controller.navigationItem.leftItemsSupplementBackButton = true
      }
    }
  }
  
  // MARK: - Table View
  
  override func numberOfSections(in tableView: UITableView) -> Int {
    return self.tresorDocument?.items?.count ?? 0
  }
  
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return 1
  }
  
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "tresorDocumentItemCell", for: indexPath)
    
    let event = self.tresorDocument?.items?.allObjects[indexPath.row] as? TresorDocumentItem
    
    configureCell(cell, withTresorDocumentItem: event)
    
    return cell
  }
  
  override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
    // Return false if you do not want the specified item to be editable.
    return true
  }
  
  override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
    if editingStyle == .delete {
      let context = self.tresorAppState?.persistentContainer.context
      let object = self.tresorDocument?.items?.allObjects[indexPath.row] as? TresorDocumentItem
      
      context?.delete(object!)
      
      do {
        try context?.save()
        
        self.tableView.reloadData()
      } catch {
        celeturLogger.error("Error while deleting TresorDocumentItem", error: error)
      }
    }
  }
  
  func configureCell(_ cell: UITableViewCell, withTresorDocumentItem tresorDocumentItem: TresorDocumentItem?) {
    cell.textLabel!.text = tresorDocumentItem?.createts!.description
    cell.detailTextLabel!.text = tresorDocumentItem?.id
    
  }
  
  
  func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
    tableView.beginUpdates()
  }
  
  func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
    switch type {
    case .insert:
      tableView.insertSections(IndexSet(integer: sectionIndex), with: .fade)
    case .delete:
      tableView.deleteSections(IndexSet(integer: sectionIndex), with: .fade)
    default:
      return
    }
  }
  
  func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
    switch type {
    case .insert:
      tableView.insertRows(at: [newIndexPath!], with: .fade)
    case .delete:
      tableView.deleteRows(at: [indexPath!], with: .fade)
    case .update:
      configureCell(tableView.cellForRow(at: indexPath!)!, withTresorDocumentItem: anObject as? TresorDocumentItem)
    case .move:
      configureCell(tableView.cellForRow(at: indexPath!)!, withTresorDocumentItem: anObject as? TresorDocumentItem)
      tableView.moveRow(at: indexPath!, to: newIndexPath!)
    }
  }
  
  func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
    tableView.endUpdates()
  }
  
}

