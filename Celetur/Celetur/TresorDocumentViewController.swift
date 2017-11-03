//
//  Created by Feldmaus on 09.07.17.
//  Copyright © 2017 ischlecken. All rights reserved.
//

import UIKit
import CoreData
import CeleturKit

class TresorDocumentViewController: UITableViewController, NSFetchedResultsControllerDelegate {
  
  var tresor: Tresor? {
    didSet {
      if let t = tresor {
        self.tresorAppState?.encryptAllDocumentItemsThatShouldBeEncryptedByDevice(tresor: t)
      }
    }
  }
  var tresorAppState: TresorAppModel?
  
  let dateFormatter = DateFormatter()
  
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
    if let t = self.tresor,
      let masterKey = self.tresorAppState?.masterKey,
      let context = self.tresorAppState?.tresorModel.tresorCoreDataManager?.privateChildManagedObjectContext() {
      
      self.beginInsertNewObject()
      context.perform {
        do {
          let model = [ "title": "gmx.de", "description": "Mail Konto", "user": "bla@fasel.de", "password":"hugo"]
          
          let _ = try TresorDocument(context: context, masterKey: masterKey, tresor: t, model: model)
          
          let _ = try context.save()
          
          DispatchQueue.main.async {
            self.tresorAppState?.tresorModel.saveChanges()
            self.endInsertNewObject()
          }
          
        } catch {
          celeturLogger.error("Error while creating new tresor document...",error:error)
        
          DispatchQueue.main.async {
            self.endInsertNewObject()
          }
        }
      }
    }
  }
  
  fileprivate func beginInsertNewObject() {
    self.navigationItem.rightBarButtonItem?.isEnabled = false
    self.refreshControl?.beginRefreshingManually()
  }
  
  fileprivate func endInsertNewObject() {
    self.refreshControl?.endRefreshing()
    self.navigationItem.rightBarButtonItem?.isEnabled = true
  }
  
  // MARK: - Segues
  
  override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
    var result = true
    
    if identifier == "showTresorDocumentItemDetail", let indexPath = tableView.indexPathForSelectedRow {
      result = indexPath.row-1>=0
    }
    
    return result
  }
  
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    if segue.identifier == "showTresorDocumentItemDetail" {
      if let indexPath = tableView.indexPathForSelectedRow {
        let newIndexPath = IndexPath(row: indexPath.row-1, section: indexPath.section)
        
        if newIndexPath.row<0 {
          return
        }
        
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
      return "DocId:\(currentSection.name)"
    }
    
    return nil
  }
  
  override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
    let tresorDocumentItem = fetchedResultsController.object(at: IndexPath(row: 0, section: section) )
    
    if let tresorDocument = tresorDocumentItem.document {
      return "changed at \(self.dateFormatter.string(from: tresorDocument.modifyts))"
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
      var context : NSManagedObjectContext?
      
      if indexPath.row == 0 {
        if let tresorDocument = fetchedResultsController.object(at: indexPath).document {
          context = tresorDocument.managedObjectContext
          
          tresorDocument.deleteTresorDocument()
        }
      } else {
        let newIndexPath = IndexPath(row: indexPath.row-1, section: indexPath.section)
        let tresorDocumentItem = fetchedResultsController.object(at: newIndexPath)
        
        if let tresorDoc = tresorDocumentItem.document {
          context = tresorDoc.managedObjectContext
          
          if tresorDoc.documentitems?.count == 1 {
            tresorDoc.deleteTresorDocument()
          } else {
            context?.delete(tresorDocumentItem)
          }
        }
      }
      
      if let context = context {
        context.performSave(contextInfo: "deleting tresor object", completion: {
          self.tresorAppState?.tresorModel.saveChanges()
        })
      }
      
    }
  }
  
  func configureCellForTresorDocument(_ cell: UITableViewCell, withTresorDocument tresorDocument: TresorDocument?) {
    cell.textLabel!.text = "Document"
    cell.detailTextLabel!.text = "-"
    cell.indentationLevel = 0
    cell.textLabel?.textColor = UIColor.black
    cell.detailTextLabel?.textColor = UIColor.black
    
    if let doc = tresorDocument {
      if let docMetaInfo = doc.getMetaInfo(), let title = docMetaInfo["title"] {
        cell.textLabel?.text = title
        
        if let description = docMetaInfo["description"] {
          cell.detailTextLabel?.text = description
        }
      }
    }
  }
  
  func configureCell(_ cell: UITableViewCell, withTresorDocumentItem tresorDocumentItem: TresorDocumentItem) {
    cell.textLabel!.text = "Id:\(tresorDocumentItem.id!)"
    cell.textLabel?.font = UIFont.systemFont(ofSize: UIFont.systemFontSize)
    cell.textLabel?.textColor = tresorDocumentItem.itemStatusColor
    cell.indentationLevel = 1
    
    if let tdiUserDevice = tresorDocumentItem.userdevice {
      cell.detailTextLabel!.text = "Device:"+(tdiUserDevice.devicename ?? "-") + " " + (tdiUserDevice.id ?? "-")
      cell.detailTextLabel!.textColor = tresorDocumentItem.itemStatusColor
      
      if currentDeviceInfo?.isCurrentDevice(tresorUserDevice: tdiUserDevice) ?? false {
        cell.textLabel?.font = UIFont.boldSystemFont(ofSize: UIFont.systemFontSize)
      }
    }
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

