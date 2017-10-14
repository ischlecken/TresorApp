//
//  Created by Feldmaus on 15.08.17.
//  Copyright © 2017 ischlecken. All rights reserved.
//

import UIKit
import CeleturKit

class EditTresorViewController: UITableViewController {
  
  var tresorAppState: TresorAppModel?
  var tresor: Tresor!
  
  @IBOutlet weak var nameTextfield: UITextField!
  @IBOutlet weak var descriptionTextfield: UITextField!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    if let deviceId = self.tresorAppState?.tresorModel.currentDeviceInfo?.userDevice?.id, self.tresor.owneruserdeviceid == nil {
      self.tresor.owneruserdeviceid = deviceId
    }
    
    self.nameTextfield.becomeFirstResponder()
    if let t  = self.tresor {
      self.nameTextfield.text = t.name
      self.descriptionTextfield.text = t.tresordescription
    }
    
  }
  
  func getUpdatedModel() -> Tresor {
    self.tresor?.name = self.nameTextfield!.text
    self.tresor?.tresordescription = self.descriptionTextfield!.text
    self.tresor?.changets = Date()
    
    return self.tresor!
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
    
    let contains = self.tresor!.userdevices?.contains(userDevice)
    
    if contains ?? false {
      self.tresor.removeFromUserdevices(userDevice)
    } else {
      self.tresor.addToUserdevices(userDevice)
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
    
    let contains = self.tresor!.userdevices?.contains(userDevice)
    
    cell.accessoryType = contains != nil && contains! ? .checkmark : .none
    cell.indentationLevel = 0
  }
  
  
  func getUserDevice(forPath indexPath:IndexPath) -> TresorUserDevice? {
    return self.tresorAppState?.tresorModel.userDevices?[indexPath.row]
  }
  
}
