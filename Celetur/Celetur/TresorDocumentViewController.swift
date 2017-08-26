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
  
  let dateFormatter = DateFormatter()
  
  var currentUserDevice: UserDevice?
  
  override func viewDidLoad() {
    super.viewDidLoad()
    // Do any additional setup after loading the view, typically from a nib.
    navigationItem.leftBarButtonItem = editButtonItem
    
    let addButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(insertNewObject(_:)))
    navigationItem.rightBarButtonItem = addButton
  
    self.title = tresor?.tresordescription
    self.dateFormatter.dateStyle = DateFormatter.Style.short
    self.dateFormatter.timeStyle = DateFormatter.Style.short
    
    self.currentUserDevice = self.tresorAppState?.tresorDataModel.getCurrentUserDevice()
  }
  
  override func viewWillAppear(_ animated: Bool) {
    clearsSelectionOnViewWillAppear = splitViewController!.isCollapsed
    super.viewWillAppear(animated)
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
  
  @IBAction func insertNewObject(_ sender: Any) {
    do {
      let _ = try self.tresorAppState?.tresorDataModel.createTresorDocument(tresor: self.tresor!,masterKey:self.tresorAppState?.masterKey)
      
      try self.tresorAppState?.tresorDataModel.saveContext()
    } catch let celeturKitError as CeleturKitError {
      celeturLogger.error("CeleturKitError while creating tresor document",error:celeturKitError)
    } catch {
      celeturLogger.error("Error while creating tresor  document",error:error)
    }
  }
  
  // MARK: - Segues
  
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    if segue.identifier == "showTresorDocumentItemDetail" {
      if let indexPath = tableView.indexPathForSelectedRow {
        let object = fetchedResultsController.object(at: indexPath)
        let controller = (segue.destination as! UINavigationController).topViewController as! TresorDocumentItemViewController
        controller.tresorAppState = self.tresorAppState
        controller.tresorDocumentItem = object
        controller.navigationItem.leftBarButtonItem = splitViewController?.displayModeButtonItem
        controller.navigationItem.leftItemsSupplementBackButton = true
      }
    }
  }
  
  // MARK: - Table View
  
  override func numberOfSections(in tableView: UITableView) -> Int {
    return  fetchedResultsController.sections?.count ?? 0
  }
  
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    let sectionInfo = fetchedResultsController.sections![section]
    
    return sectionInfo.numberOfObjects
  }
  
  override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    if let sections = fetchedResultsController.sections {
      let currentSection = sections[section]
      return currentSection.name
    }
    
    return nil
  }
  
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "tresorDocumentCell", for: indexPath)
    let tresorDocumentItem = fetchedResultsController.object(at: indexPath)
    
    configureCell(cell, withTresorDocumentItem: tresorDocumentItem)
    
    return cell
  }
  
  override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
    // Return false if you do not want the specified item to be editable.
    return true
  }
  
  override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
    if editingStyle == .delete {
      let tresorDocumentItem = fetchedResultsController.object(at: indexPath)
      let context = self.tresorAppState?.persistentContainer.context
      
      context?.delete(tresorDocumentItem)
      
      do {
        try context?.save()
      } catch {
        celeturLogger.error("Error while deleting TresorDocument", error: error)
      }
    }
  }
  
  func configureCell(_ cell: UITableViewCell, withTresorDocumentItem tresorDocumentItem: TresorDocumentItem) {
    cell.textLabel!.text = "Id:\(tresorDocumentItem.id!)"
    
    cell.textLabel?.textColor = tresorDocumentItem.status == "encrypted" ? UIColor.black : UIColor.red
    
    let tdiUserDevice = tresorDocumentItem.userdevice
    
    if tdiUserDevice?.id == self.currentUserDevice?.id && tresorDocumentItem.status == "encrypted" {
      cell.textLabel?.textColor = UIColor.blue
    }
    
    let formatedCreatets = self.dateFormatter.string(from: tresorDocumentItem.createts!)
    cell.detailTextLabel!.text = "Device:"+(tresorDocumentItem.userdevice?.devicename ?? "-") + " " + formatedCreatets
  }
  
  
  // MARK: - Fetched results controller
  
  var fetchedResultsController: NSFetchedResultsController<TresorDocumentItem> {
    if _fetchedResultsController != nil {
      return _fetchedResultsController!
    }
    
    do {
      try _fetchedResultsController = self.tresorAppState?.tresorDataModel.createAndFetchTresorDocumentItemFetchedResultsController(tresor: tresor)
      
      _fetchedResultsController?.delegate = self
    } catch {
      celeturLogger.error("CeleturKitError while creating FetchedResultsController",error:error)
    }
    
    return _fetchedResultsController!
  }
  var _fetchedResultsController: NSFetchedResultsController<TresorDocumentItem>? = nil
  
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
      let cell = tableView.cellForRow(at: indexPath!)
      configureCell(cell!, withTresorDocumentItem: (anObject as? TresorDocumentItem)!)
    case .move:
     let cell = tableView.cellForRow(at: indexPath!)
       
     configureCell(cell!, withTresorDocumentItem: (anObject as? TresorDocumentItem)!)
      tableView.moveRow(at: indexPath!, to: newIndexPath!)
    }
  }
  
  func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
    tableView.endUpdates()
  }
  
}

