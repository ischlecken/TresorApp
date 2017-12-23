//
//  Created by Feldmaus on 09.07.17.
//  Copyright © 2017 ischlecken. All rights reserved.
//

import UIKit
import CoreData
import CeleturKit

class TresorViewController: UITableViewController, NSFetchedResultsControllerDelegate {
  
  var tresorAppState : TresorAppModel?
  
  fileprivate let dateFormatter = DateFormatter()
  fileprivate var infoViewController : InfoViewController?
  fileprivate var fetchedResultsController : NSFetchedResultsController<Tresor>?
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    self.refreshControl = UIRefreshControl()
    self.refreshControl?.addTarget(self, action: #selector(refreshTable(_:)), for: .valueChanged)
    
    self.dateFormatter.dateStyle = DateFormatter.Style.short
    self.dateFormatter.timeStyle = DateFormatter.Style.short
    
    self.tableView.register(UINib(nibName:"TresorCell",bundle:nil),forCellReuseIdentifier:"tresorCell")
    
    NotificationCenter.default.addObserver(self,
                                           selector: #selector(onTresorModelReady(_:)),
                                           name: Notification.Name.onTresorModelReady,
                                           object:self.tresorAppState?.tresorModel)
    
    self.becomeFirstResponder()
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
      self.tresorAppState?.makeMasterKeyUnavailable()
    }
  }
  
  @IBAction
  func onAddAction(_ sender: Any) {
    let actionSheet = UIAlertController(title: "Add new tresor", message: "Select store where the new tresor should be added", preferredStyle: .actionSheet)
    
    actionSheet.addAction(UIAlertAction(title: "iCloud", style: .default, handler: { alertAction in
      let tempTresor = self.tresorAppState?.tresorModel.createScratchpadICloudTresorObject()
      
      self.performSegue(withIdentifier: "showEditTresor", sender: tempTresor)
    }))
    
    actionSheet.addAction(UIAlertAction(title: "Local Device", style: .default, handler: { alertAction in
      let tempTresor = self.tresorAppState?.tresorModel.createScratchpadLocalDeviceTresorObject()
      
      self.performSegue(withIdentifier: "showEditTresor", sender: tempTresor)
    }))
    
    actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler:nil))
    
    self.present(actionSheet, animated: true, completion: nil)
  }
  
  @objc
  func onTresorModelReady(_ notification: Notification) {
    celeturLogger.debug("onTresorModelReady")
    
    self.updateFetchedResultsController()
    self.tableView.reloadData()
  }
  
  
  @objc
  private func refreshTable(_ sender: Any) {
    self.tresorAppState?.fetchChanges(in: .private, completion: {
      DispatchQueue.main.async {
        self.refreshControl?.endRefreshing()
      }
    })
  }
  
  
  // MARK: - Segues
  
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    if let ident = segue.identifier {
      switch ident {
      case "showTresorDocument":
        if let indexPath = tableView.indexPathForSelectedRow {
          let object = self.getObject(indexPath: indexPath)
          let controller = segue.destination as! TresorDocumentViewController
          
          controller.tresorAppState = self.tresorAppState
          controller.tresor = object
          controller.navigationItem.leftBarButtonItem = splitViewController?.displayModeButtonItem
          controller.navigationItem.leftItemsSupplementBackButton = true
        }
        
      case "showEditTresor":
        let controller = (segue.destination as! UINavigationController).topViewController as! EditTresorViewController
        controller.tresorAppState = self.tresorAppState
        controller.tresor = sender as? TempTresorObject
        
      case "showSettings":
        let controller = (segue.destination as! UINavigationController).topViewController as! SettingsViewController
        controller.tresorAppState = self.tresorAppState
        
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
  func unwindToTresor(segue: UIStoryboardSegue) {
    if segue.identifier == "saveUnwindToTresor" {
      if let controller = segue.source as? EditTresorViewController, let tt = controller.tresor {
        controller.updateTempTresor()
        
        self.saveTempTresor(tempTresor: tt)
      }
    } else if segue.identifier == "settingsUnwindToTresor" {
    }
  }
  
  fileprivate func saveTempTresor(tempTresor:TempTresorObject) {
    let moc = tempTresor.tempManagedObjectContext
    
    moc.performSave(contextInfo: "tresor object", completion: {
      self.tresorAppState?.tresorModel.saveChanges()
    })
  }
  
  // MARK: - Table View
  
  override func numberOfSections(in tableView: UITableView) -> Int {
    return self.fetchedResultsController?.sections?.count ?? 0
  }
  
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return self.fetchedResultsController?.sections![section].numberOfObjects ?? 0
  }
  
  fileprivate func getObject(indexPath:IndexPath) -> Tresor {
    return self.fetchedResultsController!.object(at: indexPath)
  }
  
  override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    let t = self.getObject(indexPath: IndexPath(row:0,section:section))
    
    return t.ckuserid ?? "This Device"
  }
  
  
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "tresorCell", for: indexPath) as? TresorCell
    let tresor = self.getObject(indexPath: indexPath)
    
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
      let tempTresor = self.tresorAppState?.tresorModel.createScratchpadTresorObject(tresor:self.getObject(indexPath: index))
      
      self.performSegue(withIdentifier: "showEditTresor", sender: tempTresor)
    }
    editAction.backgroundColor = .orange
    
    let deleteAction = UITableViewRowAction(style: .destructive, title: "Delete") { action, index in
      let tresor = self.getObject(indexPath: index)
      
      self.tresorAppState?.tresorModel.deleteTresor(tresor: tresor) {
      }
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
    cell.createdLabel!.text = self.dateFormatter.string(from: tresor.modifyts)
    cell.nameLabel!.text = tresor.name
    cell.descriptionLabel!.text = tresor.tresordescription
  }
  
  // MARK: - Fetched results controller
  
  func updateFetchedResultsController() {
    do {
      try self.fetchedResultsController = (self.tresorAppState?.tresorModel.createAndFetchTresorFetchedResultsController(delegate: self))!
    } catch {
      celeturLogger.error("error while fetching",error:error)
    }
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
      let cell = tableView.cellForRow(at: indexPath!) as? TresorCell
      
      configureCell(cell!, withTresor: anObject as! Tresor)
    case .move:
      let cell = tableView.cellForRow(at: indexPath!) as? TresorCell
      
      configureCell(cell!, withTresor: anObject as! Tresor)
      tableView.moveRow(at: indexPath!, to: newIndexPath!)
    }
  }
  
  func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
    tableView.endUpdates()
  }
}

