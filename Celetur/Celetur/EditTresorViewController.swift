//
//  Created by Feldmaus on 15.08.17.
//  Copyright © 2017 ischlecken. All rights reserved.
//

import UIKit
import CeleturKit

class EditTresorViewController: UITableViewController {
  
  var tresorAppState: TresorAppState?
  var tresor: Tresor?
  
  @IBOutlet weak var nameTextfield: UITextField!
  @IBOutlet weak var descriptionTextfield: UITextField!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    self.nameTextfield.becomeFirstResponder()
    
    if let t  = self.tresor {
      self.nameTextfield.text = t.name
      self.descriptionTextfield.text = t.tresordescription
    }
    
  }
  
  
  // MARK: - Table View
  
  override func numberOfSections(in tableView: UITableView) -> Int {
    return (self.tresorAppState?.tresorDataModel.userList?.count)!
  }
  
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return (self.tresorAppState?.tresorDataModel.userList?[section].userdevices!.count)!
  }
  
  override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    let user = self.tresorAppState?.tresorDataModel.userList?[section]
    
    return user?.appleid
  }
  
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "editTresorCell", for: indexPath)
    
    let userDevice = self.tresorAppState?.tresorDataModel.userList?[indexPath.section].userdevices?.allObjects[indexPath.row] as! UserDevice
    
    configureCell(cell, withUserDevice: userDevice)
    
    return cell
  }
  
  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    
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
  
  func configureCell(_ cell: UITableViewCell, withUserDevice userDevice: UserDevice) {
    cell.textLabel?.text = userDevice.devicename
    cell.detailTextLabel?.text = userDevice.id
  }
  
}
