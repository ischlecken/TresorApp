//
//  Created by Feldmaus on 15.08.17.
//  Copyright © 2017 ischlecken. All rights reserved.
//

import UIKit
import CeleturKit

class EditTresorViewController: UITableViewController {
  
  var tresorAppState: TresorAppModel?
  var tresor: Tresor!
  var userList : [TresorUser]?
  
  @IBOutlet weak var nameTextfield: UITextField!
  @IBOutlet weak var descriptionTextfield: UITextField!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    do {
      self.userList = try self.tresor!.managedObjectContext?.fetch(TresorUser.fetchRequest())
      
      if self.tresor.owneduser == nil {
        self.tresor.owneduser = self.userList?[0]
      }
    } catch {
      celeturLogger.error("Error loading userlist",error:error)
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
    
    return self.tresor!
  }
  
  
  // MARK: - Table View
  
  override func numberOfSections(in tableView: UITableView) -> Int {
    return (self.userList?.count)!
  }
  
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return (self.userList?[section].userdevices!.count)! + 1
  }
  
  override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    let user = self.userList?[section]
    
    return user?.id
  }
  
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "editTresorCell", for: indexPath)
    
    if indexPath.row == 0 {
      let user = self.getUser(forPath: indexPath)
      
      configureCell(cell, withUser: user)
      
    } else {
      let userDevice = self.getUserDevice(forPath: indexPath)
      
      configureCell(cell, withUserDevice: userDevice)
    }
    
    return cell
  }
  
  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    if indexPath.row == 0 {
      let user = self.getUser(forPath: indexPath)
      
      self.tresor!.owneduser = user
      self.tableView.reloadData()
    } else {
      let userDevice = self.getUserDevice(forPath: indexPath)
      let contains = self.tresor!.userdevices?.contains(userDevice)
      
      if contains != nil && contains! {
        self.tresor.removeFromUserdevices(userDevice)
      } else {
        self.tresor.addToUserdevices(userDevice)
      }
    
      self.tableView.reloadRows(at:[indexPath] , with: UITableViewRowAnimation.fade)
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
    
    let contains = self.tresor!.userdevices?.contains(userDevice)
    
    cell.accessoryType = contains != nil && contains! ? .checkmark : .none
    cell.indentationLevel = 1
  }
  
  func configureCell(_ cell: UITableViewCell, withUser user: TresorUser) {
    cell.textLabel?.text = user.firstname! + " " + user.lastname!
    cell.detailTextLabel?.text = user.email
    
    cell.accessoryType = self.tresor!.owneduser == user ? .checkmark : .none
    cell.indentationLevel = 0
  }
  
  func getUserDevice(forPath indexPath:IndexPath) -> TresorUserDevice {
    return self.userList?[indexPath.section].userdevices?.allObjects[indexPath.row-1] as! TresorUserDevice
  }
  
  func getUser(forPath indexPath:IndexPath) -> TresorUser {
    return (self.userList?[indexPath.section])!
  }
  
}
