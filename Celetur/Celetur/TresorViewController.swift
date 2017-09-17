//
//  Created by Feldmaus on 09.07.17.
//  Copyright © 2017 ischlecken. All rights reserved.
//

import UIKit
import CoreData
import CeleturKit

class TresorViewController: UITableViewController, NSFetchedResultsControllerDelegate {
  
  var tresorAppState: TresorAppModel?
  let dateFormatter = DateFormatter()
  var editScratchpadContext : NSManagedObjectContext?
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    self.dateFormatter.dateStyle = DateFormatter.Style.short
    self.dateFormatter.timeStyle = DateFormatter.Style.short
    
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
        
        do {
          self.editScratchpadContext = self.tresorAppState?.tresorModel.privateChildManagedContext
          if let t = sender as? Tresor {
            controller.tresor = self.editScratchpadContext?.object(with: t.objectID) as? Tresor
          } else {
            controller.tresor = try Tresor.createTempTresor(context: self.editScratchpadContext!)
          }
        } catch {
          celeturLogger.error("Error creating temp tresor object",error:error)
        }
        
      case "showSettings":
        let controller = (segue.destination as! UINavigationController).topViewController as! SettingsViewController
        controller.tresorAppState = self.tresorAppState
        
      
      default: break
      }
    }
  }
  
  @IBAction func unwindToTresor(segue: UIStoryboardSegue) {
    celeturLogger.debug("unwindToTresor:\(String(describing: segue.identifier))")
    
    if segue.identifier == "saveUnwindToTresor" {
        let controller = segue.source as! EditTresorViewController
       
        if let esc = self.editScratchpadContext {
          let _ = controller.getUpdatedModel()
          
          esc.perform {
            do {
              try esc.save()
              
            } catch {
              celeturLogger.error("Error while saving tresor object",error:error)
            }
          }
        }
    } else if segue.identifier == "settingsUnwindToTresor" {
    }
    
    self.editScratchpadContext = nil
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
    let tresor = fetchedResultsController.object(at: indexPath)
    
    configureCell(cell!, withTresor: tresor)
    
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
      celeturLogger.debug("edit button tapped")
      self.performSegue(withIdentifier: "showEditTresor", sender: self.fetchedResultsController.object(at: editActionsForRowAt))
    }
    editAction.backgroundColor = .orange
    
    let deleteAction = UITableViewRowAction(style: .destructive, title: "Delete") { action, index in
      let context = self.tresorAppState?.mainManagedContext()
      
      context?.delete(self.fetchedResultsController.object(at: index))
      
      do {
        try context?.save()
      } catch {
        celeturLogger.error("Error while deleting tresor object",error:error)
        
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
  
  func configureCell(_ cell: TresorTableViewCell, withTresor tresor: Tresor) {
    
    if let t = tresor.changets {
      cell.createdLabel!.text = self.dateFormatter.string(from: t)
      
    } else {
      cell.createdLabel!.text = self.dateFormatter.string(from: tresor.createts!)
    }
    
    cell.nameLabel!.text = tresor.name
    cell.descriptionLabel!.text = tresor.tresordescription
    
  }
  
  // MARK: - Fetched results controller
  
  var fetchedResultsController: NSFetchedResultsController<Tresor> {
    if _fetchedResultsController != nil {
      return _fetchedResultsController!
    }
    
    do {
      try _fetchedResultsController = self.tresorAppState?.tresorModel.createAndFetchTresorFetchedResultsController()
      
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
      
      configureCell(cell!, withTresor: anObject as! Tresor)
    case .move:
      let cell = tableView.cellForRow(at: indexPath!) as? TresorTableViewCell
      
      configureCell(cell!, withTresor: anObject as! Tresor)
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

