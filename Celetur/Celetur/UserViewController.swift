//
//  Created by Feldmaus on 27.08.17.
//  Copyright © 2017 ischlecken. All rights reserved.
//

import UIKit
import CoreData
import CeleturKit
import Contacts
import ContactsUI

class UserViewController: UITableViewController, NSFetchedResultsControllerDelegate, CNContactPickerDelegate {
  
  var tresorAppState: TresorAppState?
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
  }

  
  @IBAction func addUsers(_ sender: Any) {
    let contactPicker = CNContactPickerViewController()
    
   contactPicker.predicateForEnablingContact = NSPredicate(format: "emailAddresses.@count > 0")
    contactPicker.delegate = self
    
    self.present(contactPicker, animated: true)
  }
  
  func contactPicker(_ picker: CNContactPickerViewController, didSelect contacts: [CNContact]) {
    self.tresorAppState?.tresorDataModel.saveContacts(contacts: contacts)
  }
  
  func presentPermissionErrorAlert() {
    DispatchQueue.main.async {
      let alert =
        UIAlertController(title: "Could Not Save Contact",
                          message: "How am I supposed to add the contact if you didn't give me permission?",
                          preferredStyle: .alert)
      
      let openSettingsAction = UIAlertAction(title: "Settings",
                                             style: .default,
                                             handler: { alert in
                                              UIApplication.shared.open(URL(string: UIApplicationOpenSettingsURLString)!)
                                              
      })
      let dismissAction = UIAlertAction(title: "OK",style: .cancel, handler: nil)
      alert.addAction(openSettingsAction)
      alert.addAction(dismissAction)
      
      self.present(alert, animated: true,completion: nil)
    }
  }
  
  // MARK: - Table view data source
  
  override func numberOfSections(in tableView: UITableView) -> Int {
    return fetchedResultsController.sections?.count ?? 0
  }
  
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    let sectionInfo = fetchedResultsController.sections![section]
    
    return sectionInfo.numberOfObjects
  }
  
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "userCell", for: indexPath)
    let user = fetchedResultsController.object(at: indexPath)
    
    configureCell(cell, withUser: user)
    
    return cell
  }
  
  override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
    return true
  }
  
  // Override to support editing the table view.
  override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
    if editingStyle == .delete {
      let user = fetchedResultsController.object(at: indexPath)
      let context = self.tresorAppState?.persistentContainer.context
      
      context?.delete(user)
      
      do {
        try context?.save()
      } catch {
        celeturLogger.error("Error while deleting User", error: error)
      }
    }
  }
  
  
  func configureCell(_ cell: UITableViewCell, withUser user: User) {
    cell.textLabel!.text = "\(user.firstname ?? "") \(user.lastname ?? "")"
    cell.detailTextLabel!.text = user.email
  }
  
  /*
   // Override to support rearranging the table view.
   override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {
   
   }
   */
  
  /*
   // Override to support conditional rearranging of the table view.
   override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
   // Return false if you do not want the item to be re-orderable.
   return true
   }
   */
  
  
  // MARK: - Navigation
  
  // In a storyboard-based application, you will often want to do a little preparation before navigation
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    // Get the new view controller using segue.destinationViewController.
    // Pass the selected object to the new view controller.
  }
  
  
  // MARK: - Fetched results controller
  
  var fetchedResultsController: NSFetchedResultsController<User> {
    if _fetchedResultsController != nil {
      return _fetchedResultsController!
    }
    
    do {
      try _fetchedResultsController = self.tresorAppState?.tresorDataModel.createAndFetchUserFetchedResultsController()
      
      _fetchedResultsController?.delegate = self
    } catch {
      celeturLogger.error("CeleturKitError while creating FetchedResultsController",error:error)
    }
    
    return _fetchedResultsController!
  }
  var _fetchedResultsController: NSFetchedResultsController<User>? = nil
  
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
      configureCell(cell!, withUser: (anObject as? User)!)
    case .move:
      let cell = tableView.cellForRow(at: indexPath!)
      
      configureCell(cell!, withUser: (anObject as? User)!)
      tableView.moveRow(at: indexPath!, to: newIndexPath!)
    }
  }
  
  func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
    tableView.endUpdates()
  }
  
  
}
