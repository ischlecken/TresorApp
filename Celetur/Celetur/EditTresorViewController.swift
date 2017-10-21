//
//  Created by Feldmaus on 15.08.17.
//  Copyright © 2017 ischlecken. All rights reserved.
//

import UIKit
import CeleturKit

class EditTresorViewController: UITableViewController {
  
  var tresorAppState: TresorAppModel?
  var tresor: TresorModel.TempTresorObject?
  
  @IBOutlet weak var nameTextfield: UITextField!
  @IBOutlet weak var descriptionTextfield: UITextField!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    if let deviceId = self.tresorAppState?.tresorModel.currentDeviceInfo?.userDevice?.id, self.tresor?.tempTresor.owneruserdeviceid == nil {
      self.tresor?.tempTresor.owneruserdeviceid = deviceId
    }
    
    self.nameTextfield.becomeFirstResponder()
    if let t  = self.tresor?.tempTresor {
      self.nameTextfield.text = t.name
      self.descriptionTextfield.text = t.tresordescription
    }
    
  }
  
  func saveTempTresor() {
    if let t = self.tresor?.tempTresor {
      t.name = self.nameTextfield!.text
      t.tresordescription = self.descriptionTextfield!.text
      t.changets = Date()
    }
    
    if let moc = self.tresor?.tempManagedObjectContext {
      moc.perform {
        do {
          try moc.save()
          
          self.tresorAppState?.tresorModel.saveChanges()
        } catch {
          celeturLogger.error("Error while saving tresor object",error:error)
        }
      }
    }
    
  }
  
  // MARK: - Table View
  
  override func numberOfSections(in tableView: UITableView) -> Int {
    return 1
  }
  
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return self.tresorAppState?.tresorModel.userDevices?.count ?? 0
  }
  
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "editTresorCell", for: indexPath)
    
    if let userDevice = self.getUserDevice(forPath: indexPath) {
      configureCell(cell, withUserDevice: userDevice)
    } 
    
    return cell
  }
  
  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    guard let userDevice = self.getUserDevice(forPath: indexPath) else { return }
    
    if let t = self.tresor?.tempTresor {
      if t.userdevices?.contains(userDevice) ?? false {
        t.removeFromUserdevices(userDevice)
      } else {
        t.addToUserdevices(userDevice)
      }
    }
    
    self.tableView.reloadRows(at:[indexPath] , with: UITableViewRowAnimation.fade)
  }
  
  override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
    return true
  }
  
  override func tableView(_ tableView: UITableView, editActionsForRowAt: IndexPath) -> [UITableViewRowAction]? {
    let editAction = UITableViewRowAction(style: .normal, title: "Edit") { action, index in
      
    }
    editAction.backgroundColor = .orange
    
    let deleteAction = UITableViewRowAction(style: .destructive, title: "Delete") { action, index in
      
    }
    
    return [editAction, deleteAction]
  }
  
  override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
    if editingStyle == .delete {
      
    }
  }
  
  func configureCell(_ cell: UITableViewCell, withUserDevice userDevice: TresorUserDevice) {
    cell.textLabel?.text = userDevice.devicename
    cell.detailTextLabel?.text = userDevice.id
    cell.accessoryType = .none
    cell.indentationLevel = 0
    
    if let t = self.tresor?.tempTresor {
      if t.userdevices?.contains(userDevice) ?? false {
        cell.accessoryType = .checkmark
      }
    }
  }
  
  
  func getUserDevice(forPath indexPath:IndexPath) -> TresorUserDevice? {
    return self.tresorAppState?.tresorModel.userDevices?[indexPath.row]
  }
  
}
