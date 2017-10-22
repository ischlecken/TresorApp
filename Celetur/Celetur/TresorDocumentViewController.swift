//
//  Created by Feldmaus on 09.07.17.
//  Copyright © 2017 ischlecken. All rights reserved.
//

import UIKit
import CoreData
import CeleturKit

class TresorDocumentViewController: UITableViewController, NSFetchedResultsControllerDelegate {
  
  var tresor: Tresor?
  var tresorAppState: TresorAppModel?
  
  let dateFormatter = DateFormatter()
  
  var currentUserDevice: TresorUserDevice?
  
  override func viewDidLoad() {
    super.viewDidLoad()
    // Do any additional setup after loading the view, typically from a nib.
    //navigationItem.leftBarButtonItem = editButtonItem
    
    let addButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(insertNewObject(_:)))
    navigationItem.rightBarButtonItem = addButton
    
    self.refreshControl = UIRefreshControl()
    self.refreshControl?.addTarget(self, action: #selector(refreshTable(_:)), for: .valueChanged)
    
    self.title = tresor?.tresordescription
    self.dateFormatter.dateStyle = DateFormatter.Style.short
    self.dateFormatter.timeStyle = DateFormatter.Style.short
    
    self.currentUserDevice = self.tresorAppState?.tresorModel.currentTresorUserDevice
  }
  
  @objc
  private func refreshTable(_ sender: Any) {
    self.tresorAppState?.fetchChanges(in: .private, completion: {
      DispatchQueue.main.async {
        self.refreshControl?.endRefreshing()
      }
    })
  }
  
  
  override func viewWillAppear(_ animated: Bool) {
    clearsSelectionOnViewWillAppear = splitViewController!.isCollapsed
    super.viewWillAppear(animated)
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
  
  @IBAction
  func insertNewObject(_ sender: Any) {
    do {
      let plainText = "{ \"title\": \"gmx.de\",\"user\":\"bla@fasel.de\",\"password\":\"hugo\"}"
      
      let _ = try self.tresorAppState?.tresorModel.createTresorDocument(tresor: self.tresor!,
                                                                        plainText: plainText,
                                                                        masterKey:self.tresorAppState?.masterKey)
      
    } catch {
      celeturLogger.error("Error while creating tresor  document",error:error)
    }
  }
  
  // MARK: - Segues
  
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    if segue.identifier == "showTresorDocumentItemDetail" {
      if let indexPath = tableView.indexPathForSelectedRow {
        
        let newIndexPath = IndexPath(row: indexPath.row-1, section: indexPath.section)
        
        let object = fetchedResultsController.object(at: newIndexPath)
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
    
    return sectionInfo.numberOfObjects + 1
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
    
    if indexPath.row == 0 {
      let tresorDocumentItem = fetchedResultsController.object(at: indexPath)
      let tresorDocument = tresorDocumentItem.document
      
      configureCellForTresorDocument(cell,withTresorDocument: tresorDocument)
    } else {
      let newIndexPath = IndexPath(row: indexPath.row-1, section: indexPath.section)
      let tresorDocumentItem = fetchedResultsController.object(at: newIndexPath)
      
      configureCell(cell, withTresorDocumentItem: tresorDocumentItem)
    }
    
    return cell
  }
  
  override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
    
    return true
  }
  
  override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
    if editingStyle == .delete {
      if let context = self.tresorAppState?.tresorModel.tresorCoreDataManager?.mainManagedObjectContext {
        
        if indexPath.row == 0 {
          if let tresorDocument = fetchedResultsController.object(at: indexPath).document {
            self.tresorAppState?.tresorModel.deleteTresorDocument(context: context, tresorDocument: tresorDocument)
          }
        } else {
          let newIndexPath = IndexPath(row: indexPath.row-1, section: indexPath.section)
          let tresorDocumentItem = fetchedResultsController.object(at: newIndexPath)
          
          if tresorDocumentItem.document?.documentitems?.count == 1 {
            self.tresorAppState?.tresorModel.deleteTresorDocument(context: context, tresorDocument: tresorDocumentItem.document!)
          } else {
            context.delete(tresorDocumentItem)
          }
        }
        
        do {
          try context.save()
          
          self.tresorAppState?.tresorModel.saveChanges()
        } catch {
          celeturLogger.error("Error while deleting tresor object",error:error)
        }
      }
    }
  }
  
  func configureCellForTresorDocument(_ cell: UITableViewCell, withTresorDocument tresorDocument: TresorDocument?) {
    cell.textLabel!.text = "Document"
    
    cell.textLabel?.textColor = UIColor.black
    
    var formatedCreatets = "-"
    
    if let createts = tresorDocument?.createts {
      formatedCreatets = self.dateFormatter.string(from: createts)
    }
    
    cell.detailTextLabel!.text = "created at " + formatedCreatets
    cell.indentationLevel = 0
  }
  
  func configureCell(_ cell: UITableViewCell, withTresorDocumentItem tresorDocumentItem: TresorDocumentItem) {
    cell.textLabel!.text = "Id:\(tresorDocumentItem.id!)"
    
    cell.textLabel?.textColor = tresorDocumentItem.status == "encrypted" ? UIColor.black : UIColor.red
    cell.textLabel?.font = UIFont.systemFont(ofSize: UIFont.systemFontSize)
    
    let tdiUserDevice = tresorDocumentItem.userdevice
    
    if tdiUserDevice?.id == self.currentUserDevice?.id && tresorDocumentItem.status == "encrypted" {
      cell.textLabel?.textColor = UIColor.blue
    }
    
    let formatedCreatets = self.dateFormatter.string(from: tresorDocumentItem.createts!)
    cell.detailTextLabel!.text = "Device:"+(tresorDocumentItem.userdevice?.devicename ?? "-") + " " + formatedCreatets
    
    cell.indentationLevel = 1
  }
  
  
  // MARK: - Fetched results controller
  
  var fetchedResultsController: NSFetchedResultsController<TresorDocumentItem> {
    if _fetchedResultsController != nil {
      return _fetchedResultsController!
    }
    
    do {
      try _fetchedResultsController = self.tresorAppState?.tresorModel.createAndFetchTresorDocumentItemFetchedResultsController(tresor: tresor)
      
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
  
  func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>,
                  didChange sectionInfo: NSFetchedResultsSectionInfo,
                  atSectionIndex sectionIndex: Int,
                  for type: NSFetchedResultsChangeType) {
    switch type {
    case .insert:
      tableView.insertSections(IndexSet(integer: sectionIndex), with: .fade)
    case .delete:
      tableView.deleteSections(IndexSet(integer: sectionIndex), with: .fade)
    default:
      return
    }
  }
  
  func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>,
                  didChange anObject: Any,
                  at indexPath: IndexPath?,
                  for type: NSFetchedResultsChangeType,
                  newIndexPath: IndexPath?) {
    switch type {
    case .insert:
    
      let newIndexPath1 = IndexPath(row:newIndexPath!.row+1,section:newIndexPath!.section)
      tableView.insertRows(at: [newIndexPath1], with: .fade)
    
    case .delete:
      let indexPath1 = IndexPath(row:indexPath!.row+1,section:indexPath!.section)
      
      tableView.deleteRows(at: [indexPath1], with: .fade)
      
    case .update:
      let indexPath1 = IndexPath(row:indexPath!.row+1,section:indexPath!.section)
      
      let cell = tableView.cellForRow(at: indexPath1)
      
      configureCell(cell!, withTresorDocumentItem: (anObject as? TresorDocumentItem)!)
    
    case .move:
      let indexPath1 = IndexPath(row:indexPath!.row+1,section:indexPath!.section)
      let newIndexPath1 = IndexPath(row:newIndexPath!.row+1,section:newIndexPath!.section)
      
      let cell = tableView.cellForRow(at: indexPath1)
       
     configureCell(cell!, withTresorDocumentItem: (anObject as? TresorDocumentItem)!)
      tableView.moveRow(at: indexPath1, to: newIndexPath1)
    }
  }
  
  func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
    tableView.endUpdates()
  }
  
}

