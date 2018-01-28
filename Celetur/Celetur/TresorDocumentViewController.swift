//
//  Created by Feldmaus on 09.07.17.
//  Copyright © 2017 ischlecken. All rights reserved.
//

import UIKit
import CoreData
import CeleturKit

protocol TresorDocumentViewControllerDelegate: class {
  func documentItemSelected(documentItem:TresorDocumentItem)
}


class TresorDocumentViewController: UITableViewController, NSFetchedResultsControllerDelegate {
  
  weak var delegate : TresorDocumentViewControllerDelegate?
  
  var tresor: Tresor? {
    didSet {
      if let t = tresor {
        self.tresorAppModel?.encryptAllDocumentItemsThatShouldBeEncryptedByDevice(tresor: t)
      }
    }
  }
  var tresorAppModel: TresorAppModel?
  let dateFormatter = DateFormatter()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    // Do any additional setup after loading the view, typically from a nib.
    //navigationItem.leftBarButtonItem = editButtonItem
    
    let addButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(insertNewObject(_:)))
    navigationItem.rightBarButtonItem = addButton
    
    self.refreshControl = UIRefreshControl()
    self.refreshControl?.addTarget(self, action: #selector(refreshTable(_:)), for: .valueChanged)
    
    self.title = tresor?.name
    self.dateFormatter.dateStyle = DateFormatter.Style.short
    self.dateFormatter.timeStyle = DateFormatter.Style.short
    
    self.tableView.register(UINib(nibName:"TresorDocumentCell",bundle:nil),forCellReuseIdentifier:"tresorDocumentCell")
    self.tableView.register(UINib(nibName:"TresorDocumentItemCell0",bundle:nil),forCellReuseIdentifier:"tresorDocumentItemCell")
    
    self.becomeFirstResponder()
  }
  
  @objc
  private func refreshTable(_ sender: Any) {
    self.tresorAppModel?.fetchCloudKitChanges(in: .private, completion: {
      DispatchQueue.main.async {
        self.refreshControl?.endRefreshing()
      }
    })
  }
  
  
  override func viewWillAppear(_ animated: Bool) {
    clearsSelectionOnViewWillAppear = splitViewController!.isCollapsed
    super.viewWillAppear(animated)
  }
  
  override var canBecomeFirstResponder: Bool {
    get {
      return true
    }
  }
  
  override func motionEnded(_ motion: UIEventSubtype, with event: UIEvent?) {
    if(event?.subtype == UIEventSubtype.motionShake) {
      self.tresorAppModel?.makeMasterKeyUnavailable()
    }
  }
  
  
  // MARK: - Navigation
  
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    if segue.identifier == "editNewTresorDocument" {
      let payloadMetaInfo = sender as! PayloadMetainfo
      
      let controller = (segue.destination as! UINavigationController).topViewController as! EditTresorDocumentItemViewController
      controller.tresorAppModel = self.tresorAppModel
      
      controller.setModel(payload: payloadMetaInfo.toModel(), metaInfo: payloadMetaInfo.toTresorDocumentMetaInfo())
      
      controller.navigationItem.title = "New Tresor Document"
    }
  }
  
  @IBAction
  func unwindFromEditTresorDocumentItem(segue: UIStoryboardSegue) {
    if "saveEditTresorDocumentItem" == segue.identifier,
      let m = (segue.source as? EditTresorDocumentItemViewController)?.getModel(),
      let mi = (segue.source as? EditTresorDocumentItemViewController)?.tresorDocumentMetaInfo {
      
      self.createNewTresorDocument(tresorDocumentMetaInfo: mi, model: m)
    }
  }
  
  
  
  @IBAction
  func insertNewObject(_ sender: Any) {
    if let templates = self.tresorAppModel?.templates.templatenames, templates.count > 0 {
      let actionSheet = UIAlertController(title: "Add new Document", message: "Select template for new document", preferredStyle: .actionSheet)
      
      actionSheet.popoverPresentationController?.barButtonItem = sender as? UIBarButtonItem
      
      for t in templates {
        actionSheet.addAction(UIAlertAction(title: t, style: .default, handler: { [weak self] alertAction in
          let payloadMetainfo = self!.tresorAppModel?.templates.payloadMetainfo(name: t)
          
          self!.performSegue(withIdentifier: "editNewTresorDocument", sender: payloadMetainfo)
        }))
      }
      
      actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler:nil))
    
      self.present(actionSheet, animated: true, completion: nil)
    }
  }
  
  // MARK: - Data handling
  
  fileprivate func createNewTresorDocument(tresorDocumentMetaInfo : TresorDocumentMetaInfo, model:Payload) {
    self.tresorAppModel?.getMasterKey() { (tresorKey, error) in
      if let key = tresorKey,
        let t = self.tresor,
        let context = self.tresorAppModel?.tresorModel.getCoreDataManager()?.privateChildManagedObjectContext() {
        
        self.beginInsertNewObject()
        context.perform {
          do {
            let _ = try TresorDocument(context: context, masterKey: key, tresor: t, metaInfo: tresorDocumentMetaInfo, model: model)
            
            let _ = try context.save()
            
            DispatchQueue.main.async {
              self.tresorAppModel?.tresorModel.saveChanges()
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
  }
  
  fileprivate func beginInsertNewObject() {
    self.navigationItem.rightBarButtonItem?.isEnabled = false
    self.refreshControl?.beginRefreshingManually()
  }
  
  fileprivate func endInsertNewObject() {
    self.refreshControl?.endRefreshing()
    self.navigationItem.rightBarButtonItem?.isEnabled = true
  }
  
  
  
  // MARK: - Table View
  
  override func numberOfSections(in tableView: UITableView) -> Int {
    return  fetchedResultsController.sections?.count ?? 0
  }
  
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    let sectionInfo = fetchedResultsController.sections![section]
    
    return sectionInfo.numberOfObjects + 1
  }
  
  
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    var cell : UITableViewCell
    
    if indexPath.row == 0 {
      let documentCell = tableView.dequeueReusableCell(withIdentifier: "tresorDocumentCell", for: indexPath) as! TresorDocumentCell
      
      let tresorDocumentItem = fetchedResultsController.object(at: indexPath)
      let tresorDocument = tresorDocumentItem.document
      
      configureCellForTresorDocument(documentCell,withTresorDocument: tresorDocument)
      
      cell = documentCell
    } else {
      let itemCell = tableView.dequeueReusableCell(withIdentifier: "tresorDocumentItemCell", for: indexPath) as! TresorDocumentItemCell0
      
      let newIndexPath = IndexPath(row: indexPath.row-1, section: indexPath.section)
      let tresorDocumentItem = fetchedResultsController.object(at: newIndexPath)
      
      configureCell(itemCell, withTresorDocumentItem: tresorDocumentItem)
      
      cell = itemCell
    }
    
    return cell
  }
  
  override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
    return true
  }
  
  override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
    if editingStyle == .delete {
      var ctx : NSManagedObjectContext?
      
      if indexPath.row == 0 {
        if let tresorDocument = fetchedResultsController.object(at: indexPath).document,
          let context = tresorDocument.managedObjectContext {
          
          tresorDocument.deleteTresorDocument()
          ctx = context
        }
      } else {
        let newIndexPath = IndexPath(row: indexPath.row-1, section: indexPath.section)
        let tresorDocumentItem = fetchedResultsController.object(at: newIndexPath)
        
        if let tresorDoc = tresorDocumentItem.document,
          let context = tresorDoc.managedObjectContext {
          
          if tresorDoc.documentitems?.count == 1 {
            tresorDoc.deleteTresorDocument()
          } else {
            var logEntries = [TresorLogInfo]()
            logEntries.append(TresorLogInfo(messageIndentLevel: 0, messageName: .deleteObject, objectType: .TresorDocumentItem, objectId: tresorDocumentItem.id!))
            TresorLog.createLogEntries(context: context, ckUserId: tresorDocumentItem.ckuserid, entries: logEntries)
            
            context.delete(tresorDocumentItem)
            
            ctx = context
          }
        }
      }
      
      if let context = ctx {
        context.performSave(contextInfo: "deleting tresor object", completion: {
          self.tresorAppModel?.tresorModel.saveChanges()
        })
      }
    }
  }
  
  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    if indexPath.row-1>=0 {
      let newIndexPath = IndexPath(row: indexPath.row-1, section: indexPath.section)
      let selectedTresorDocumentItem = self.fetchedResultsController.object(at: newIndexPath)
      
      self.delegate?.documentItemSelected(documentItem: selectedTresorDocumentItem)
    }
    
    self.tableView.deselectRow(at: indexPath, animated: true)
  }
  
  override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
    return indexPath.row-1>=0 ? indexPath : nil
  }
  
  func configureCellForTresorDocument(_ cell: TresorDocumentCell, withTresorDocument tresorDocument: TresorDocument?) {
    cell.nameLabel!.text = "Document"
    cell.descriptionLabel!.text = "-"
    cell.documentIdLabel!.text = "-"
    cell.createdLabel!.text = "-"
    cell.indentationLevel = 0
    
    if let doc = tresorDocument {
      if let docMetaInfo = doc.getMetaInfo(), let title = docMetaInfo["title"] {
        cell.nameLabel?.text = title
        
        if let description = docMetaInfo["description"] {
          cell.descriptionLabel?.text = description
        }
        
        if let iconname = docMetaInfo["iconname"] {
          cell.documentImage.image = UIImage(named: iconname)
        }
        
        cell.documentIdLabel!.text = doc.id
        cell.createdLabel!.text = self.dateFormatter.string(from: doc.modifyts)
      }
    }
  }
  
  func configureCell(_ cell: TresorDocumentItemCell0, withTresorDocumentItem tresorDocumentItem: TresorDocumentItem) {
    cell.itemIdLabel!.text = tresorDocumentItem.id
    cell.itemIdLabel!.textColor = UIColor.black
    cell.indentationLevel = 1
    cell.deviceIdLabel?.font = UIFont.systemFont(ofSize: UIFont.systemFontSize)
    cell.itemIdLabel?.font = UIFont.systemFont(ofSize: UIFont.systemFontSize)
    
    if let tdiUserDevice = tresorDocumentItem.userdevice {
      cell.deviceIdLabel!.text = (tdiUserDevice.devicename ?? "-") + " " + (tdiUserDevice.id ?? "-")
      cell.deviceIdLabel!.textColor = tresorDocumentItem.itemStatusColor
      cell.itemIdLabel!.textColor = tresorDocumentItem.itemStatusColor
      
      if currentDeviceInfo?.isCurrentDevice(tresorUserDevice:tdiUserDevice) ?? false {
        cell.deviceIdLabel?.font = UIFont.boldSystemFont(ofSize: UIFont.systemFontSize)
        cell.itemIdLabel?.font = UIFont.boldSystemFont(ofSize: UIFont.systemFontSize)
      }
    }
  }
  
  
  // MARK: - Fetched results controller
  
  var fetchedResultsController: NSFetchedResultsController<TresorDocumentItem> {
    if _fetchedResultsController != nil {
      return _fetchedResultsController!
    }
    
    do {
      try _fetchedResultsController = self.tresorAppModel?.tresorModel.createAndFetchTresorDocumentItemFetchedResultsController(tresor: tresor)
      
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
      
      let cell = tableView.cellForRow(at: indexPath1) as! TresorDocumentItemCell0
      
      configureCell(cell, withTresorDocumentItem: (anObject as? TresorDocumentItem)!)
      
    case .move:
      let indexPath1 = IndexPath(row:indexPath!.row+1,section:indexPath!.section)
      let newIndexPath1 = IndexPath(row:newIndexPath!.row+1,section:newIndexPath!.section)
      
      let cell = tableView.cellForRow(at: indexPath1) as! TresorDocumentItemCell0
      
      configureCell(cell, withTresorDocumentItem: (anObject as? TresorDocumentItem)!)
      tableView.moveRow(at: indexPath1, to: newIndexPath1)
    }
  }
  
  func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
    tableView.endUpdates()
  }
  
}

