//
//  Created by Feldmaus on 09.07.17.
//  Copyright © 2017 ischlecken. All rights reserved.
//

import UIKit
import CoreData
import CeleturKit

class TresorViewController: UITableViewController, NSFetchedResultsControllerDelegate, UISplitViewControllerDelegate {
  
  var tresorAppModel : TresorAppModel?
  
  fileprivate let dateFormatter = DateFormatter()
  fileprivate var infoViewController : InfoViewController?
  fileprivate var fetchedResultsController : NSFetchedResultsController<Tresor>?
  fileprivate var lastTresorLog : TresorLog?
  
  fileprivate var discardDetailController = true
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    self.navigationItem.largeTitleDisplayMode = .always
    self.refreshControl = UIRefreshControl()
    self.refreshControl?.addTarget(self, action: #selector(refreshTable(_:)), for: .valueChanged)
    
    self.dateFormatter.dateStyle = DateFormatter.Style.short
    self.dateFormatter.timeStyle = DateFormatter.Style.short
    
    self.tableView.register(UINib(nibName:"TresorCell",bundle:nil),forCellReuseIdentifier:"tresorCell")
    
    NotificationCenter.default.addObserver(self,
                                           selector: #selector(onTresorModelReady(_:)),
                                           name: Notification.Name.onTresorModelReady,
                                           object:nil)

    NotificationCenter.default.addObserver(self,
                                           selector: #selector(onTresorCloudkitStatusChanged(_:)),
                                           name: Notification.Name.onTresorCloudkitStatusChanged,
                                           object:nil)
    
    NotificationCenter.default.addObserver(self,
                                           selector: #selector(onTresorCloudkitChangesFetched(_:)),
                                           name: Notification.Name.onTresorCloudkitChangesFetched,
                                           object:nil)
    
    

    self.becomeFirstResponder()
    
    celeturLogger.debug("TresorViewController.viewDidLoad()")
  }
  
  override func viewWillAppear(_ animated: Bool) {
    celeturLogger.debug("TresorViewController.viewWillAppear()")
    
    clearsSelectionOnViewWillAppear = splitViewController!.isCollapsed
    
    super.viewWillAppear(animated)
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    celeturLogger.debug("TresorViewController.viewWillDisappear()")
    
    super.viewWillDisappear(animated)
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
  
  @IBAction
  func onAddAction(_ sender: Any) {
    if self.tresorAppModel?.tresorModel.icloudAvailable() ?? false {
      let actionSheet = UIAlertController(title: "Add new tresor", message: "Select store where the new tresor should be added", preferredStyle: .actionSheet)
      
      actionSheet.popoverPresentationController?.barButtonItem = sender as? UIBarButtonItem 
      
      actionSheet.addAction(UIAlertAction(title: "iCloud", style: .default, handler: { alertAction in
        let tempTresor = self.tresorAppModel?.tresorModel.createScratchpadICloudTresorObject()
        
        self.performSegue(withIdentifier: "showEditTresor", sender: tempTresor)
      }))
      
      actionSheet.addAction(UIAlertAction(title: "Local Device", style: .default, handler: { alertAction in
        let tempTresor = self.tresorAppModel?.tresorModel.createScratchpadLocalDeviceTresorObject()
        
        self.performSegue(withIdentifier: "showEditTresor", sender: tempTresor)
      }))
      
      actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler:nil))
      
      self.present(actionSheet, animated: true, completion: nil)
    } else {
      let tempTresor = self.tresorAppModel?.tresorModel.createScratchpadLocalDeviceTresorObject()
      
      self.performSegue(withIdentifier: "showEditTresor", sender: tempTresor)
    }
  }
  
  @objc
  func onTresorModelReady(_ notification: Notification) {
    celeturLogger.debug("onTresorModelReady")
    
    NotificationCenter.default.addObserver(self, selector: #selector(managedObjectContextObjectsDidSave), name: NSNotification.Name.NSManagedObjectContextDidSave, object: self.tresorAppModel?.tresorModel.getCoreDataManager()?.mainManagedObjectContext)
    
    self.updateFetchedResultsController()
    //self.updateLastLogEvent()
    self.tableView.reloadData()
  }
  
  @objc
  func managedObjectContextObjectsDidSave(notification: NSNotification) {
    guard let userInfo = notification.userInfo else { return }
    
    if let inserts = userInfo[NSInsertedObjectsKey] as? Set<NSManagedObject>, inserts.count > 0 {
      celeturLogger.debug("TresorViewController.inserts:\(inserts.count)")
    }
    
    if let updates = userInfo[NSUpdatedObjectsKey] as? Set<NSManagedObject>, updates.count > 0 {
      celeturLogger.debug("TresorViewController.updates:\(updates.count)")
    }
    
    if let deletes = userInfo[NSDeletedObjectsKey] as? Set<NSManagedObject>, deletes.count > 0 {
      celeturLogger.debug("TresorViewController.deletes:\(deletes.count)")
    }
    
    self.updateLastLogEvent()
    self.tableView.reloadSections(IndexSet([0]), with: .fade)
  }
  
  @objc
  func onTresorCloudkitStatusChanged(_ notification: Notification) {
    celeturLogger.debug("TresorViewController.onTresorCloudkitStatusChanged")
  }
  
  @objc
  func onTresorCloudkitChangesFetched(_ notification: Notification) {
    celeturLogger.debug("TresorViewController.onTresorCloudkitChangesFetched")
  }
  
  @objc
  private func refreshTable(_ sender: Any) {
    self.tresorAppModel?.fetchCloudKitChanges(in: .private, completion: {
      DispatchQueue.main.async {
        self.refreshControl?.endRefreshing()
      }
    })
  }
  
  
  // MARK: - Navigation
  
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    if let ident = segue.identifier {
      switch ident {
      case "showTresorDocument":
        if let indexPath = tableView.indexPathForSelectedRow {
          let controller = (segue.destination as! UINavigationController).topViewController as! TresorDocumentViewController
          
          controller.tresorAppModel = self.tresorAppModel
          controller.tresor = self.getObject(indexPath: indexPath)
          controller.navigationItem.leftBarButtonItem = self.splitViewController?.displayModeButtonItem
          controller.navigationItem.leftItemsSupplementBackButton = true
          self.discardDetailController = false
        }
        
      case "showTresorLog":
        let controller = (segue.destination as! UINavigationController).topViewController as! TresorLogViewController
        
        controller.tresorAppModel = self.tresorAppModel
        controller.navigationItem.leftBarButtonItem = self.splitViewController?.displayModeButtonItem
        controller.navigationItem.leftItemsSupplementBackButton = true
        
        self.discardDetailController = false
        
      case "showEditTresor":
        let controller = (segue.destination as! UINavigationController).topViewController as! EditTresorViewController
        controller.tresorAppModel = self.tresorAppModel
        controller.tresor = sender as? TempTresorObject
        
      case "showSettings":
        let controller = (segue.destination as! UINavigationController).topViewController as! SettingsViewController
        controller.tresorAppModel = self.tresorAppModel
        
        
      default: break
      }
    }
  }
  
  @IBAction
  func onTestInfoController(_ sender: Any) {
    if let ivc = self.infoViewController {
      ivc.dismissInfo()
      self.infoViewController = nil
    } else {
      self.infoViewController = InfoViewController(info: "test info")
      
      self.infoViewController?.showInfo()
    }
  }
  
  @IBAction
  func unwindFromEditTresor(segue: UIStoryboardSegue) {
    if segue.identifier == "saveEditTresor" {
      if let controller = segue.source as? EditTresorViewController, let tt = controller.tresor, !tt.tempTresor.isreadonly {
        controller.updateTempTresor()
        
        tt.saveTresor()
      }
    }
  }
  
  @IBAction
  func unwindFromSettings(segue: UIStoryboardSegue) {
    
  }
  
  // MARK: - Table View
  
  override func numberOfSections(in tableView: UITableView) -> Int {
    let sections = self.fetchedResultsController?.sections
    
    return sections != nil ? sections!.count + 1 : 1
  }
  
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    let sections = self.fetchedResultsController?.sections
    
    return sections != nil && section>0 ? sections![section-1].numberOfObjects : 1
  }
  
  fileprivate func getObject(indexPath:IndexPath) -> Tresor? {
    return indexPath.section>0 ? self.fetchedResultsController!.object(at: IndexPath(row: indexPath.row, section: indexPath.section-1)) : nil
  }
  
  override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    if let t = self.getObject(indexPath: IndexPath(row:0,section:section)) {
      return self.tresorAppModel?.tresorModel.displayInfoForCkUserId(ckUserId: t.ckuserid)
    }
    
    return "Tresor Log"
  }
  
  
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    if indexPath.section>0 {
      let cell = tableView.dequeueReusableCell(withIdentifier: "tresorCell", for: indexPath) as? TresorCell
      let tresor = self.getObject(indexPath: indexPath)
      
      configureCell(cell!, withTresor: tresor!)
      
      return cell!
    }
    
    let cell = tableView.dequeueReusableCell(withIdentifier: "templateCell", for: indexPath)
    cell.textLabel?.text = "Log"
    cell.detailTextLabel?.text = nil
    
    if let lastLogEvent = self.lastTresorLog {
      cell.textLabel?.text = TresorLogDescriptor.localizededDescription(lastLogEvent)
      cell.detailTextLabel?.text = TresorLogDescriptor.subtitle(lastLogEvent)
    }
    
    return cell
  }
  
  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    if indexPath.section>0 {
      self.performSegue(withIdentifier: "showTresorDocument", sender: self)
    } else {
      self.tableView.deselectRow(at: indexPath, animated: true)
    }
  }
  
  override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
    return indexPath.section > 0
  }
  
  override func tableView(_ tableView: UITableView, editActionsForRowAt: IndexPath) -> [UITableViewRowAction]? {
    guard let tresor = self.getObject(indexPath: editActionsForRowAt) else { return nil }
    
    let editActionTitle = tresor.isreadonly ? "Show" : "Edit"
    
    let editAction = UITableViewRowAction(style: .normal, title: editActionTitle) { action, index in
      let tempTresor = self.tresorAppModel?.tresorModel.createScratchpadTresorObject(tresor: tresor)
      
      self.performSegue(withIdentifier: "showEditTresor", sender: tempTresor)
    }
    editAction.backgroundColor = .orange
    
    let deleteAction = UITableViewRowAction(style: .destructive, title: "Delete") { action, index in
      let message = tresor.ckuserid != nil ? "Delete tresor with all documents on all devices" : "Delete tresor with all documents on this device"
      let actionSheet = UIAlertController(title: "Delete tresor", message: message, preferredStyle: .actionSheet)
      
      actionSheet.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { alertAction in
        self.tresorAppModel?.tresorModel.deleteTresor(tresor: tresor) {
        }
      }))
      
      actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler:nil))
      
      self.present(actionSheet, animated: true, completion: nil)
    }
    
    let testAction = UITableViewRowAction(style: .normal, title: "Test") { action, index in
      self.onTestInfoController(self)
    }
    
    return [editAction, deleteAction, testAction]
  }
  
  override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
    if editingStyle == .delete {
      
    }
  }
  
  func configureCell(_ cell: TresorCell, withTresor tresor: Tresor) {
    cell.tresorImage.image = UIImage(named: tresor.iconname ?? "shield")
    
    switch tresor.cksyncstatus! {
    case CloudKitEntitySyncState.pending.rawValue:
      cell.cksyncstatusImage.image = UIImage(named: "ckpending")
    case CloudKitEntitySyncState.unknown.rawValue:
      cell.cksyncstatusImage.image = UIImage(named: "ckunknown")
    case CloudKitEntitySyncState.failed.rawValue:
      cell.cksyncstatusImage.image = UIImage(named: "ckfailed")
    default:
      cell.cksyncstatusImage.image = nil
    }
    
    if tresor.isreadonly {
      cell.createdLabel!.textColor = UIColor.lightGray
      cell.nameLabel!.textColor = UIColor.lightGray
      cell.descriptionLabel!.textColor = UIColor.lightGray
    } else {
      cell.createdLabel!.textColor = UIColor.darkText
      cell.nameLabel!.textColor = UIColor.celeturPrimary
      cell.descriptionLabel!.textColor = UIColor.darkText
    }
    
    cell.createdLabel!.text = self.dateFormatter.string(from: tresor.modifyts)
    cell.nameLabel!.text = tresor.name
    cell.descriptionLabel!.text = tresor.tresordescription
  }
  
  // MARK: - Fetched results controller
  
  fileprivate func updateLastLogEvent() {
    do {
      self.lastTresorLog = nil
      
      if let lastLogEvents = try self.tresorAppModel?.tresorModel.lastLogEvents(), lastLogEvents.count>0 {
        self.lastTresorLog = lastLogEvents[0]
      }
      
    } catch {
      celeturLogger.error("error while fetching last logevent",error:error)
    }
  }
  
  fileprivate func updateFetchedResultsController() {
    do {
      try self.fetchedResultsController = (self.tresorAppModel?.tresorModel.createAndFetchTresorFetchedResultsController(delegate: self))!
    } catch {
      celeturLogger.error("error while fetching tresor info",error:error)
    }
  }
  
  func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
    tableView.beginUpdates()
    
    celeturLogger.debug("TresorViewController.controllerWillChangeContent()")
  }
  
  func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
    
    celeturLogger.debug("TresorViewController.controller() sectionDidChange")
    
    switch type {
    case .insert:
      tableView.insertSections(IndexSet(integer: sectionIndex+1), with: .fade)
    case .delete:
      tableView.deleteSections(IndexSet(integer: sectionIndex+1), with: .fade)
    default:
      return
    }
  }
  
  func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
    
    celeturLogger.debug("TresorViewController.controller() ObjectDidChange")
    
    switch type {
    case .insert:
      tableView.insertRows(at: [IndexPath(row:newIndexPath!.row,section:newIndexPath!.section+1)], with: .fade)
    case .delete:
      tableView.deleteRows(at: [IndexPath(row:indexPath!.row,section:indexPath!.section+1)], with: .fade)
    case .update:
      let cell = tableView.cellForRow(at: IndexPath(row:indexPath!.row,section:indexPath!.section+1)) as? TresorCell
      
      if let c = cell {
        configureCell(c, withTresor: anObject as! Tresor)
      }
    case .move:
      let cell = tableView.cellForRow(at: IndexPath(row:indexPath!.row,section:indexPath!.section+1)) as? TresorCell
      
      if let c = cell {
        configureCell(c, withTresor: anObject as! Tresor)
        
        tableView.moveRow(at: IndexPath(row:indexPath!.row,section:indexPath!.section+1), to: IndexPath(row:newIndexPath!.row,section:newIndexPath!.section+1))
      }
    }
  }
  
  func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
    tableView.endUpdates()
    
    celeturLogger.debug("TresorViewController.controllerDidChangeContent()")
  }
  
  
  //
  // MARK: - UISplitViewControllerDelegate
  //
  
  func splitViewController(_ splitViewController: UISplitViewController, collapseSecondary secondaryViewController: UIViewController, onto primaryViewController: UIViewController) -> Bool {
    let result = self.discardDetailController
    
    celeturLogger.debug("TresorViewController.splitViewController onto primary:\(result)")
    
    return result
  }
}
