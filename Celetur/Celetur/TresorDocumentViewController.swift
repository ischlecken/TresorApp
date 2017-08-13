//
//  Created by Feldmaus on 09.07.17.
//  Copyright © 2017 ischlecken. All rights reserved.
//

import UIKit
import CoreData
import CeleturKit

class TresorDocumentViewController: UITableViewController, NSFetchedResultsControllerDelegate {

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
        let object = fetchedResultsController.object(at: indexPath)
            let controller = segue.destination as! TresorDocumentItemViewController
          
            controller.tresorAppState = self.tresorAppState
            controller.tresorDocument = object
          
            controller.navigationItem.leftBarButtonItem = splitViewController?.displayModeButtonItem
            controller.navigationItem.leftItemsSupplementBackButton = true
        }
    }
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
    let cell = tableView.dequeueReusableCell(withIdentifier: "tresorDocumentCell", for: indexPath)
    let event = fetchedResultsController.object(at: indexPath)
    configureCell(cell, withEvent: event)
    return cell
  }

  override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
    // Return false if you do not want the specified item to be editable.
    return true
  }

  override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
    if editingStyle == .delete {
        let context = fetchedResultsController.managedObjectContext
        context.delete(fetchedResultsController.object(at: indexPath))
            
        do {
            try context.save()
        } catch {
            // Replace this implementation with code to handle the error appropriately.
            // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            let nserror = error as NSError
            fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
        }
    }
  }

  func configureCell(_ cell: UITableViewCell, withEvent event: TresorDocument) {
    cell.textLabel!.text = event.createts!.description
    cell.detailTextLabel!.text = event.id
    
  }

  // MARK: - Fetched results controller

  var fetchedResultsController: NSFetchedResultsController<TresorDocument> {
      if _fetchedResultsController != nil {
          return _fetchedResultsController!
      }
    
      do {
        try _fetchedResultsController = self.tresorAppState?.tresorDataModel.createAndFetchTresorDocumentFetchedResultsController()
        
        _fetchedResultsController?.delegate = self
      } catch {
        celeturLogger.error("CeleturKitError while creating FetchedResultsController",error:error)
      }
      
      return _fetchedResultsController!
  }    
  var _fetchedResultsController: NSFetchedResultsController<TresorDocument>? = nil

  
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
              configureCell(tableView.cellForRow(at: indexPath!)!, withEvent: anObject as! TresorDocument)
          case .move:
              configureCell(tableView.cellForRow(at: indexPath!)!, withEvent: anObject as! TresorDocument)
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

