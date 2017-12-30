//
//  Created by Feldmaus on 15.08.17.
//  Copyright © 2017 ischlecken. All rights reserved.
//

import UIKit
import CeleturKit

class EditTresorViewController: UITableViewController, UITextFieldDelegate {
  
  var tresorAppState: TresorAppModel?
  var tresor: TempTresorObject?
  
  @IBOutlet weak var nameTextfield: UITextField!
  @IBOutlet weak var descriptionTextfield: UITextField!
  
  override func viewDidLoad() {
    super.viewDidLoad()

/*
    if let userDevice = self.tresorAppState?.tresorModel.currentTresorUserDevice,
      self.tresor?.tempTresor.userdevices?.count==0,
      let udnew = self.tresor?.tempManagedObjectContext.object(with: userDevice.objectID) as? TresorUserDevice {
      
      self.tresor?.tempTresor.addToUserdevices(udnew)
    }
*/
    
    self.nameTextfield.becomeFirstResponder()
    
    if let t  = self.tresor?.tempTresor {
      self.nameTextfield.text = t.name
      self.descriptionTextfield.text = t.tresordescription
    }
  
    self.navigationItem.rightBarButtonItem?.title = (self.tresor?.tempTresor.isreadonly ?? false) ? "Done" : "Save"
  }
  
  func updateTempTresor() {
    if let t = self.tresor?.tempTresor {
      t.name = self.nameTextfield!.text
      t.tresordescription = self.descriptionTextfield!.text
      t.changets = Date()
    }
  }
  
  // MARK: - Table View
  
  override func numberOfSections(in tableView: UITableView) -> Int {
    return 1
  }
  
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return self.tresor?.userDevices?.count ?? 0
  }
  
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "editTresorCell", for: indexPath)
    
    if let userDevice = self.getUserDevice(forPath: indexPath) {
      configureCell(cell, withUserDevice: userDevice)
    } 
    
    return cell
  }
  
  override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    return "User Devices"
  }
  
  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    guard let userDevice = self.getUserDevice(forPath: indexPath) else { return }
    
    if let t = self.tresor?.tempTresor {
      
      let foundUserDevice = t.findUserDevice(userDevice: userDevice)
      if let ud = foundUserDevice {
        if let tc = t.userdevices?.count, tc>1 {
          t.removeFromUserdevices(ud)
        }
      } else {
        if let udnew = self.tresor?.tempManagedObjectContext.object(with: userDevice.objectID) as? TresorUserDevice {
          t.addToUserdevices(udnew)
        }
      }
    
      self.tableView.reloadRows(at:[indexPath] , with: .fade)
    } else {
      self.tableView.reloadRows(at:[indexPath] , with: .none)
    }
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
    
    if currentDeviceInfo?.isCurrentDevice(tresorUserDevice: userDevice) ?? false {
      cell.textLabel?.textColor = UIColor.blue
      cell.textLabel?.font = UIFont.boldSystemFont(ofSize: UIFont.systemFontSize)
      cell.detailTextLabel?.font = UIFont.boldSystemFont(ofSize: UIFont.systemFontSize)
    } else {
      cell.textLabel?.textColor = UIColor.darkText
      cell.textLabel?.font = UIFont.systemFont(ofSize: UIFont.systemFontSize)
      cell.detailTextLabel?.font = UIFont.systemFont(ofSize: UIFont.systemFontSize)
    }
    
    if let t = self.tresor?.tempTresor, t.findUserDevice(userDevice:userDevice) != nil {
      cell.accessoryType = .checkmark
    }
  }
  
  
  func getUserDevice(forPath indexPath:IndexPath) -> TresorUserDevice? {
    return self.tresor?.userDevices?[indexPath.row]
  }
  
  //
  // MARK: - UITextFieldDelegate
  //
  
  public func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
    let readonly = self.tresor?.tempTresor.isreadonly ?? false
    
    return !readonly
  }
  
}
