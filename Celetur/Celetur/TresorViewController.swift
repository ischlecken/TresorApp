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
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    self.refreshControl = UIRefreshControl()
    self.refreshControl?.addTarget(self, action: #selector(refreshTable(_:)), for: .valueChanged)
    
    self.dateFormatter.dateStyle = DateFormatter.Style.short
    self.dateFormatter.timeStyle = DateFormatter.Style.short
    
    self.tableView.register(UINib(nibName:"TresorCell",bundle:nil),forCellReuseIdentifier:"tresorCell")
    
    self.tableView.backgroundView = GradientView()
    
    NotificationCenter.default.addObserver(self,
                                           selector: #selector(onTresorModelReady(_:)),
                                           name: Notification.Name.onTresorModelReady,
                                           object:self.tresorAppState?.tresorModel)
    
    let titleView = UILabel()
    
    titleView.text = "Celetur\nsecond line"
    titleView.textColor = .celeturTintColor
    titleView.textAlignment = .center
    titleView.numberOfLines = 0
    titleView.adjustsFontSizeToFitWidth = true
    
    self.navigationItem.titleView = titleView
  }
  
  override func viewWillAppear(_ animated: Bool) {
    clearsSelectionOnViewWillAppear = splitViewController!.isCollapsed
    
    super.viewWillAppear(animated)
    
  }

  func setTitleInfo(titleinfo:String) {
    let titleLabel = self.navigationItem.titleView as? UILabel
    
    titleLabel?.text = titleinfo
  }
  
  
  deinit {
    NotificationCenter.default.removeObserver(self)
  }
  
  @objc
  func onTresorModelReady(_ notification: Notification) {
    celeturLogger.debug("onTresorModelReady")
    
    self._fetchedResultsController = nil
    let _ = self.fetchedResultsController
    
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
        if let indexPath = tableView.indexPathForSelectedRow, let object = fetchedResultsController?.object(at: indexPath) {
          let controller = segue.destination as! TresorDocumentViewController
          
          controller.tresorAppState = self.tresorAppState
          controller.tresor = object
          controller.navigationItem.leftBarButtonItem = splitViewController?.displayModeButtonItem
          controller.navigationItem.leftItemsSupplementBackButton = true
        }
        
      case "showEditTresor":
        let controller = (segue.destination as! UINavigationController).topViewController as! EditTresorViewController
        controller.tresorAppState = self.tresorAppState
        controller.tresor = self.tresorAppState?.tresorModel.createScratchpadTresorObject(tresor:sender as? Tresor)
        
      case "showSettings":
        let controller = (segue.destination as! UINavigationController).topViewController as! SettingsViewController
        controller.tresorAppState = self.tresorAppState
        
        
      default: break
      }
    }
  }
  
  @IBAction func unwindToTresor(segue: UIStoryboardSegue) {
    if segue.identifier == "saveUnwindToTresor" {
      if let controller = segue.source as? EditTresorViewController {
        controller.saveTempTresor()
      }
    } else if segue.identifier == "settingsUnwindToTresor" {
    }
  }
  
  // MARK: - Table View
  
  override func numberOfSections(in tableView: UITableView) -> Int {
    return fetchedResultsController?.sections?.count ?? 0
  }
  
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    let sectionInfo = fetchedResultsController?.sections![section]
    
    return sectionInfo?.numberOfObjects ?? 0
  }
  
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "tresorCell", for: indexPath) as? TresorCell
    
    if let tresor = fetchedResultsController?.object(at: indexPath) {
      configureCell(cell!, withTresor: tresor)
    }
    
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
      if let object = self.fetchedResultsController?.object(at: editActionsForRowAt) {
        self.performSegue(withIdentifier: "showEditTresor", sender: object)
      }
    }
    editAction.backgroundColor = .orange
    
    let deleteAction = UITableViewRowAction(style: .destructive, title: "Delete") { action, index in
      if let tresor = self.fetchedResultsController?.object(at: index) {
        self.tresorAppState?.tresorModel.deleteTresor(tresor: tresor)
      }
    }
    
    return [editAction, deleteAction]
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
  
  var fetchedResultsController: NSFetchedResultsController<Tresor>? {
    if _fetchedResultsController != nil {
      return _fetchedResultsController
    }
    
    do {
      try _fetchedResultsController = self.tresorAppState?.tresorModel.createAndFetchTresorFetchedResultsController()
      
      _fetchedResultsController?.delegate = self
    } catch {
      celeturLogger.error("CeleturKitError while creating FetchedResultsController",error:error)
    }
    
    return _fetchedResultsController
  }
  var _fetchedResultsController: NSFetchedResultsController<Tresor>?
  
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
  
  /*
   // Implementing the above methods to update the table view in response to individual changes may have performance implications if a large number of changes are made simultaneously. If this proves to be an issue, you can instead just implement controllerDidChangeContent: which notifies the delegate that all section and object changes have been processed.
   
   func controllerDidChangeContent(controller: NSFetchedResultsController) {
   // In the simplest, most efficient, case, reload the table view.
   tableView.reloadData()
   }
   */
  
}

