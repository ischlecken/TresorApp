//
//  Copyright © 2018 prisnoc. All rights reserved.
//

import UIKit
import CoreData
import CeleturKit

class TresorLogViewController: UITableViewController, NSFetchedResultsControllerDelegate {
  var tresorAppModel : TresorAppModel?
  
  fileprivate var fetchedResultsController : NSFetchedResultsController<TresorLog>?
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    self.title = "Tresor Log"
    self.updateFetchedResultsController()
  }
  
  
  // MARK: - Table view data source
  
  override func numberOfSections(in tableView: UITableView) -> Int {
    return self.fetchedResultsController?.sections?.count ?? 0
  }
  
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return self.fetchedResultsController?.sections![section].numberOfObjects ?? 0
  }
  
  
  override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    let tresorLog = self.getObject(indexPath: IndexPath(row:0,section:section))
    
    return self.tresorAppModel?.tresorModel.displayInfoForCkUserId(ckUserId: tresorLog.ckuserid)
  }
  
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "logCell", for: indexPath)
    let tresorLog = self.getObject(indexPath: indexPath)
    
    self.configureCell(cell, with: tresorLog)
    
    return cell
  }
  
  fileprivate func getObject(indexPath:IndexPath) -> TresorLog {
    return self.fetchedResultsController!.object(at: indexPath)
  }
  
  fileprivate func configureCell(_ cell: UITableViewCell, with tresorLog:TresorLog) {
    cell.indentationLevel = Int(tresorLog.messageindentlevel)
    cell.textLabel!.text = TresorLogDescriptor.localizededDescription(tresorLog)
    cell.detailTextLabel!.text = TresorLogDescriptor.subtitle(tresorLog)
  }
  
  override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
    return false
  }
  
  
  // MARK: - Navigation
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
  }
  
  // MARK: - Fetched results controller
  fileprivate func updateFetchedResultsController() {
    do {
      try self.fetchedResultsController = (self.tresorAppModel?.tresorModel.createAndFetchTresorLogFetchedResultsController(delegate: self))!
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
      if let cell = tableView.cellForRow(at: indexPath!) {
        self.configureCell(cell, with: self.getObject(indexPath:indexPath!))
      }
    case .move:
      if let cell = tableView.cellForRow(at: indexPath!) {
        self.configureCell(cell, with: self.getObject(indexPath:indexPath!))
        
        tableView.moveRow(at: indexPath!, to: newIndexPath!)
      }
    }
  }
  
  func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
    tableView.endUpdates()
  }
}
