//
//  Created by Feldmaus on 09.07.17.
//  Copyright © 2017 ischlecken. All rights reserved.
//

import UIKit
import CoreData
import CeleturKit

class TresorDocumentViewController: UITableViewController {
  
  var tresor: Tresor?
  var tresorAppState: TresorAppState?
  
  override func viewDidLoad() {
    super.viewDidLoad()
    // Do any additional setup after loading the view, typically from a nib.
    navigationItem.leftBarButtonItem = editButtonItem
    
    let addButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(insertNewObject(_:)))
    navigationItem.rightBarButtonItem = addButton
  }
  
  override func viewWillAppear(_ animated: Bool) {
    clearsSelectionOnViewWillAppear = splitViewController!.isCollapsed
    super.viewWillAppear(animated)
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
  
  @objc
  func insertNewObject(_ sender: Any) {
    do {
      let tresorDocument = try self.tresorAppState?.tresorDataModel.createTresorDocument(tresor: self.tresor!)
      
      try self.tresorAppState?.tresorDataModel.createTresorDocumentItem(tresorDocument: tresorDocument!,masterKey: (self.tresorAppState?.masterKey)!)
      
      self.tableView.reloadData()
    } catch let celeturKitError as CeleturKitError {
      celeturLogger.error("CeleturKitError while creating tresor document",error:celeturKitError)
    } catch {
      celeturLogger.error("Error while creating tresor  document",error:error)
    }
  }
  
  // MARK: - Segues
  
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    if segue.identifier == "showTresorDocumentItem" {
      if let indexPath = tableView.indexPathForSelectedRow {
        let object = self.tresor?.documents?.allObjects[indexPath.row]
        let controller = segue.destination as! TresorDocumentItemViewController
        
        controller.tresorAppState = self.tresorAppState
        controller.tresorDocument = object as? TresorDocument
        
        controller.navigationItem.leftBarButtonItem = splitViewController?.displayModeButtonItem
        controller.navigationItem.leftItemsSupplementBackButton = true
      }
    }
  }
  
  // MARK: - Table View
  
  override func numberOfSections(in tableView: UITableView) -> Int {
    return self.tresor?.documents?.count ?? 0
  }
  
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return 1
  }
  
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "tresorDocumentCell", for: indexPath)
    let event = self.tresor?.documents?.allObjects[indexPath.row] as? TresorDocument
    
    configureCell(cell, withTresorDocument: event)
    
    return cell
  }
  
  override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
    // Return false if you do not want the specified item to be editable.
    return true
  }
  
  override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
    if editingStyle == .delete {
      let tresorDocument = self.tresor?.documents?.allObjects[indexPath.row] as? TresorDocument
      let context = self.tresorAppState?.persistentContainer.context
      
      context?.delete(tresorDocument!)
      
      do {
        try context?.save()
        
        self.tableView.reloadData()
      } catch {
        celeturLogger.error("Error while deleting TresorDocument", error: error)
      }
    }
  }
  
  func configureCell(_ cell: UITableViewCell, withTresorDocument tresorDocument: TresorDocument?) {
    cell.textLabel!.text = tresorDocument?.createts!.description
    cell.detailTextLabel!.text = tresorDocument?.id
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
      configureCell(tableView.cellForRow(at: indexPath!)!, withTresorDocument: anObject as? TresorDocument)
    case .move:
      configureCell(tableView.cellForRow(at: indexPath!)!, withTresorDocument: anObject as? TresorDocument)
      tableView.moveRow(at: indexPath!, to: newIndexPath!)
    }
  }
  
  func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
    tableView.endUpdates()
  }
  
}

