//
//  Created by Feldmaus on 20.08.17.
//  Copyright © 2017 ischlecken. All rights reserved.
//

import UIKit
import CeleturKit


class EditTresorDocumentItemViewController: UITableViewController {
  
  var tresorAppState: TresorAppModel?
  
  let dateFormatter = DateFormatter()
  var model = PayloadModelType()
  var modelIndex = [String]()
  
  var actualEditingItemValueIndexPath : IndexPath?
  var clickedItemNameIndexPath : IndexPath?
  
  func setModel(payloadModel:PayloadModelType?) {
    if let p = payloadModel {
      self.model = p
      self.modelIndex = Array(self.model.keys)
    } else {
      self.model = PayloadModelType()
      self.modelIndex = [String]()
    }
  }
  
  func getModel() -> PayloadModelType {
    if let indexPath = self.actualEditingItemValueIndexPath,let c = self.tableView.cellForRow(at: indexPath) as? EditTresorDocumentItemCell {
      celeturLogger.debug("getModel():\(c.itemValueTextfield?.text ?? "-")")
      
      self.model[self.modelIndex[indexPath.row]] = c.itemValueTextfield?.text
    }
  
    return self.model
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
  
    self.tableView.register(UINib(nibName:"EditTresorDocumentItemCell",bundle:nil),forCellReuseIdentifier:"editTresorDocumentItemCell")
    
  }
  
  // MARK: - Actions
  
  
  
  @IBAction
  func itemNameAction(_ sender: Any) {
    if let b = sender as? UIButton, let c = b.superview?.superview as? UITableViewCell {
      self.clickedItemNameIndexPath = self.tableView.indexPath(for: c)
      
      celeturLogger.debug("item name clicked:\(String(describing: clickedItemNameIndexPath))")
      
      self.performSegue(withIdentifier: "showItemNameSelectionSegue", sender: self)
    }
    
  }
  
  @IBAction
  func itemValueBeginEditingAction(_ sender: Any) {
    if let t = sender as? UITextField, let c = t.superview?.superview as? UITableViewCell {
      self.actualEditingItemValueIndexPath = self.tableView.indexPath(for: c)
    }
  }
  
  @IBAction
  func itemValueEndEditingAction(_ sender: Any) {
    if let t = sender as? UITextField, let indexPath = self.actualEditingItemValueIndexPath {
      self.model[self.modelIndex[indexPath.row]] = t.text
    }
  }
  
  
  @IBAction
  func addFieldAction(_ sender: Any) {
    let key = "New Item "+String(Int(arc4random())%100)
    
    self.model[key] = "---"
    
    self.modelIndex = Array(self.model.keys)
    
    self.tableView.reloadData()
  }
  
  @IBAction func deleteFieldsAction(_ sender: Any) {
    self.model = PayloadModelType()
    
    self.modelIndex = Array(self.model.keys)
    
    self.tableView.reloadData()
  }
  
  // MARK: - Segue
  
  override
  func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    if "showItemNameSelectionSegue" == segue.identifier {
      if let s = (segue.destination as? UINavigationController)?.topViewController as? SelectItemNameTableViewController,
        let selectedItem = self.clickedItemNameIndexPath?.row {
        s.itemNames = self.modelIndex
        s.selectedItem = selectedItem
      }
    }
  }
  
  @IBAction
  func unwindToEditTresorDocumentItemView(segue: UIStoryboardSegue) {
    if "saveItemNameSegue" == segue.identifier {
      if let s = segue.source as? SelectItemNameTableViewController,
        let selectedItem = self.clickedItemNameIndexPath?.row {
        
        var newItemName = s.customItemName
        
        if newItemName == nil {
          newItemName = s.itemNames[s.selectedItem]
        }
        
        celeturLogger.debug("selected new itemname:\(newItemName ?? "-")")
        
        if let newValue = newItemName,
          self.modelIndex[selectedItem] != newValue,
          let oldValue = self.model.removeValue(forKey: self.modelIndex[selectedItem]) {
        
          self.model[newValue] = oldValue
          self.modelIndex[selectedItem] = newValue
          
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.tableView.reloadRows(at: [IndexPath(row:selectedItem,section:0)], with: .fade)
          }
        }
        
        self.clickedItemNameIndexPath = nil
      }
    }
  }
  
  // MARK: - Table view data source
  
  override func numberOfSections(in tableView: UITableView) -> Int {
    return 2
  }
  
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    var result = 0
    
    switch section {
    case 0:
      result = self.modelIndex.count
    case 1:
      result = 2
    default: break
    }
    
    return result
  }
  
  
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    var cell : UITableViewCell
    
    switch indexPath.section {
    case 0:
      let editCell = tableView.dequeueReusableCell(withIdentifier: "editTresorDocumentItemCell", for: indexPath) as! EditTresorDocumentItemCell
      
      configureCell(editCell, forKey: self.modelIndex[indexPath.row])
      cell = editCell
      
    default:
      let cellIdentifier = indexPath.row == 0 ? "addFieldCell" : "deleteFieldsCell"
      
      cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath)
    }
    
    return cell
  }
  
  override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
    return true
  }
  
  override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
    if editingStyle == .delete {
      self.model.removeValue(forKey: self.modelIndex[indexPath.row])
      self.modelIndex = Array(self.model.keys)
      
      tableView.deleteRows(at: [indexPath], with: .fade)
    } else if editingStyle == .insert {
      // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }
  }
  
  fileprivate func configureCell(_ cell: EditTresorDocumentItemCell, forKey key: String) {
    cell.itemNameButton?.setTitle(key, for: .normal)
    cell.itemValueTextfield?.text = self.model[key] as? String
  }
  
}
