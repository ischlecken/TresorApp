//
//  SelectItemNameTableViewController.swift
//  Celetur
//
//  Created by Feldmaus on 05.11.17.
//  Copyright © 2017 ischlecken. All rights reserved.
//

import UIKit

class SelectItemNameTableViewController: UITableViewController,UITextFieldDelegate {
  
  var itemNames = ["user","password","email","title","description"]
  var selectedItem = 0
  
  var showCustomItemEditField = false
  var customItemName : String?
  
  override func viewDidLoad() {
    super.viewDidLoad()
  }
  
  // MARK: - Table view data source
  
  override func numberOfSections(in tableView: UITableView) -> Int {
    return 2
  }
  
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    switch section {
    case 0:
      return self.itemNames.count
    default:
      return 1
    }
  }
  
  
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    switch indexPath.section {
    case 0:
      let cell = tableView.dequeueReusableCell(withIdentifier: "basicCell", for: indexPath)
      
      cell.textLabel?.text = self.itemNames[indexPath.row]
      cell.accessoryType = self.selectedItem == indexPath.row ? .checkmark : .none
      return cell
      
    default:
      let cell = tableView.dequeueReusableCell(withIdentifier: self.showCustomItemEditField ? "editCustomItemNameCell": "addCustomItemNameCell", for: indexPath)
      
      if self.showCustomItemEditField, let textField = cell.viewWithTag(42) as? UITextField {
        textField.becomeFirstResponder()
        textField.delegate = self
      }
      
      return cell
    }
  }
  
  
  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    if indexPath.section == 0 {
      let oldSelectedItem = self.selectedItem
      self.selectedItem = indexPath.row
      
      self.tableView.reloadRows(at: [IndexPath(row: oldSelectedItem, section: 0), indexPath], with: .none)
    }
  }
  
  
  // Override to support conditional editing of the table view.
  override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
    return false
  }
  
  
  
  // Override to support editing the table view.
  override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
    if editingStyle == .delete {
      // Delete the row from the data source
      tableView.deleteRows(at: [indexPath], with: .fade)
    } else if editingStyle == .insert {
      // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }
  }
  
  // MARK: - Actions
  
  @IBAction
  func addCustomItemNameAction(_ sender: Any) {
    self.showCustomItemEditField = true
    
    self.tableView.reloadRows(at: [IndexPath(row:0,section:1)], with: .none)
  }
  
  @IBAction
  func editCustomItemNameAction(_ sender: Any) {
    if let t = sender as? UITextField {
      self.customItemName = t.text
    }
  }
  
  
  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    textField.resignFirstResponder()
    self.performSegue(withIdentifier: "saveItemNameSegue", sender: self)
    
    return true
  }
}
