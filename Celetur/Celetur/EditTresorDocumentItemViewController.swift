//
//  Created by Feldmaus on 20.08.17.
//  Copyright © 2017 ischlecken. All rights reserved.
//

import UIKit
import CeleturKit


class EditTresorDocumentItemViewController: UITableViewController {
  
  var tresorAppState: TresorAppModel?
  
  let dateFormatter = DateFormatter()
  var model : Payload?
  
  var actualEditingItemValueIndexPath : IndexPath?
  var clickedItemNameIndexPath : IndexPath?
  
  func setModel(payload:Payload?) {
    self.model = payload
  }
  
  func getModel() -> Payload? {
    if let indexPath = self.actualEditingItemValueIndexPath,let c = self.tableView.cellForRow(at: indexPath) as? EditTresorDocumentItemCell {
      celeturLogger.debug("getModel():\(c.itemValueTextfield?.text ?? "-")")
      
      if var item = self.model?.getActualItem(forPath: indexPath) {
        item.value = .s(c.itemValueTextfield!.text!)
        
        self.model?.setActualItem(forPath: indexPath, payloadItem:item)
      }
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
    if let t = (sender as? UITextField)?.text,
      let indexPath = self.actualEditingItemValueIndexPath,
      var item = self.model?.getActualItem(forPath: indexPath) {
      
      item.value = .s(t)
      
      self.model?.setActualItem(forPath: indexPath, payloadItem:item)
    }
  }
  
  
  @IBAction
  func addFieldAction(_ sender: Any) {
    if let maxSection = self.model?.getActualSectionCount() {
      let payloadItem = PayloadItem(name: "New Item "+String(Int(arc4random())%100),
                                    value: .s(""),
                                    attributes: [:])
      
      self.model?.appendToActualSection(forSection: maxSection - 1, payloadItem: payloadItem)
      self.tableView.reloadData()
    }
  }
  
  @IBAction func deleteFieldsAction(_ sender: Any) {
    if let maxSection = self.model?.getActualSectionCount() {
      self.model?.removeAllItemsFromActualSection(forSection: maxSection - 1)
    
      self.tableView.reloadData()
    }
  }
  
  // MARK: - Segue
  
  override
  func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    if "showItemNameSelectionSegue" == segue.identifier {
      if let s = (segue.destination as? UINavigationController)?.topViewController as? SelectItemNameTableViewController,
        let selectedItem = self.clickedItemNameIndexPath?.row {
        s.itemNames = (self.model?.getActualSectionItems(forSection: 0).map() { payloadItem in
          return payloadItem.name
          })!
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
        
        if let newItemName = newItemName, var item = self.model?.getActualItem(forPath: self.clickedItemNameIndexPath!) {
          item.name = newItemName
          
          self.model?.setActualItem(forPath: self.clickedItemNameIndexPath!, payloadItem: item)
        
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
      result = self.model?.getActualRowCount(forSection: 0) ?? 0
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
      
      configureCell(editCell, forPath: indexPath)
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
      if var items = self.model?.getActualSectionItems(forSection: indexPath.section) {
        items.remove(at: indexPath.row)
        
        tableView.deleteRows(at: [indexPath], with: .fade)
      }
      
    } else if editingStyle == .insert {
      // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }
  }
  
  fileprivate func configureCell(_ cell: EditTresorDocumentItemCell, forPath indexPath: IndexPath) {
    if let payloadItem = self.model?.getActualItem(forPath: indexPath) {
      cell.itemNameButton?.setTitle(payloadItem.name, for: .normal)
      cell.itemValueTextfield?.text = payloadItem.value.toString()
    }
  }
  
}
