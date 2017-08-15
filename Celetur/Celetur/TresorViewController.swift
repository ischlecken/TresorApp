//
//  Created by Feldmaus on 09.07.17.
//  Copyright © 2017 ischlecken. All rights reserved.
//

import UIKit
import CoreData
import CeleturKit

class TresorViewController: UITableViewController, NSFetchedResultsControllerDelegate {
  
  var tresorAppState: TresorAppState?
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    self.tableView.register(UINib(nibName:"TresorCell",bundle:nil),forCellReuseIdentifier:"tresorCell")
  }
  
  override func viewWillAppear(_ animated: Bool) {
    clearsSelectionOnViewWillAppear = splitViewController!.isCollapsed
    super.viewWillAppear(animated)
  }
  
  
  // MARK: - Segues
  
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    if let ident = segue.identifier {
      switch ident {
      case "showTresorDocument":
        if let indexPath = tableView.indexPathForSelectedRow {
          let object = fetchedResultsController.object(at: indexPath)
          let controller = segue.destination as! TresorDocumentViewController
          
          controller.tresorAppState = self.tresorAppState
          controller.tresor = object
          controller.navigationItem.leftBarButtonItem = splitViewController?.displayModeButtonItem
          controller.navigationItem.leftItemsSupplementBackButton = true
        }
        
      case "showEditTresor":
        let controller = (segue.destination as! UINavigationController).topViewController as! EditTresorViewController
        controller.tresorAppState = self.tresorAppState
        
        if let t = sender as? Tresor {
          controller.tresor = t
        }
      
      default: break
      }
    }
    
    
  }
  
  @IBAction func unwindToTresor(segue: UIStoryboardSegue) {
    print("unwindToTresor:\(String(describing: segue.identifier))")
    
    
  }
  
  // MARK: - Table View
  
  override func numberOfSections(in tableView: UITableView) -> Int {
    return fetchedResultsController.sections?.count ?? 0
  }
  
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    let sectionInfo = fetchedResultsController.sections![section]
    return sectionInfo.numberOfObjects
  }
  
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "tresorCell", for: indexPath) as? TresorTableViewCell
    let event = fetchedResultsController.object(at: indexPath)
    
    configureCell(cell!, withEvent: event)
    
    return cell!
  }
  
  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    self.performSegue(withIdentifier: "showTresorDocument", sender: self)
  }
  
  override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
    // Return false if you do not want the specified item to be editable.
    return true
  }
  
  override func tableView(_ tableView: UITableView, editActionsForRowAt: IndexPath) -> [UITableViewRowAction]? {
    
    let editAction = UITableViewRowAction(style: .normal, title: "Edit") { action, index in
      print("edit button tapped")
      self.performSegue(withIdentifier: "showEditTresor", sender: self.fetchedResultsController.object(at: editActionsForRowAt))
    }
    editAction.backgroundColor = .orange
    
    let deleteAction = UITableViewRowAction(style: .destructive, title: "Delete") { action, index in
      let context = self.tresorAppState?.persistentContainer.context
      
      context?.delete(self.fetchedResultsController.object(at: index))
      
      do {
        try context?.save()
      } catch {
        celeturLogger.error("Error while deleting tresor object",error:error)
        
        self.tresorAppState?.tresorDataModel.flushFetchedResultsControllerCache()
        do {
          try self._fetchedResultsController?.performFetch()
          self.tableView.reloadData()
        } catch {
          celeturLogger.error("Error while refreshing fetchedResultsController", error: error)
        }
        
      }
    }
    
    return [editAction, deleteAction]
  }
  
  override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
    if editingStyle == .delete {
      
    }
  }
  
  func configureCell(_ cell: TresorTableViewCell, withEvent event: Tresor) {
    
    if let t = event.changets {
      cell.createdLabel!.text = t.description
      
    } else {
      cell.createdLabel!.text = event.createts!.description
    }
    
    cell.nameLabel!.text = event.name
    cell.descriptionLabel!.text = event.tresordescription
    
  }
  
  // MARK: - Fetched results controller
  
  var fetchedResultsController: NSFetchedResultsController<Tresor> {
    if _fetchedResultsController != nil {
      return _fetchedResultsController!
    }
    
    do {
      try _fetchedResultsController = self.tresorAppState?.tresorDataModel.createAndFetchTresorFetchedResultsController()
      
      _fetchedResultsController?.delegate = self
    } catch {
      celeturLogger.error("CeleturKitError while creating FetchedResultsController",error:error)
    }
    
    return _fetchedResultsController!
  }
  var _fetchedResultsController: NSFetchedResultsController<Tresor>? = nil
  
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
      let cell = tableView.cellForRow(at: indexPath!) as? TresorTableViewCell
      
      configureCell(cell!, withEvent: anObject as! Tresor)
    case .move:
      let cell = tableView.cellForRow(at: indexPath!) as? TresorTableViewCell
      
      configureCell(cell!, withEvent: anObject as! Tresor)
      tableView.moveRow(at: indexPath!, to: newIndexPath!)
    }
  }
  
  func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
    tableView.endUpdates()
  }
  
  /*
   // Implementing the above methods to update the table view in response to individual changes may have performance implications if a large number of changes are made simultaneously. If this proves to be an issue, you can instead just implement controllerDidChangeContent: which notifies the delegate that all section and object changes have been processed.
   
   func controllerDidChangeContent(controller: NSFetchedResultsController) {
   // In the simplest, most efficient, case, reload the table view.
   tableView.reloadData()
   }
   */
  
}

