//
//  Created by Feldmaus on 20.08.17.
//  Copyright © 2017 ischlecken. All rights reserved.
//

import UIKit
import CeleturKit


class EditTresorDocumentItemViewController: UITableViewController, UITextFieldDelegate {
  
  @IBOutlet weak var iconView: UIImageView!
  
  @IBOutlet weak var titleTextField: UITextField!
  @IBOutlet weak var descriptionTextField: UITextField!
  
  var tresorAppModel: TresorAppModel?
  var tresorDocumentMetaInfo : TresorDocumentMetaInfo?
  
  fileprivate let dateFormatter = DateFormatter()
  fileprivate var model : Payload?
  
  fileprivate var actualEditingItemValueIndexPath : IndexPath?
  fileprivate var clickedItemNameIndexPath : IndexPath?
  
  func setModel(payload:Payload?, metaInfo: TresorDocumentMetaInfo?) {
    self.model = payload
    self.tresorDocumentMetaInfo = metaInfo
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
    
    if let m = self.tresorDocumentMetaInfo {
      if let t = m[TresorDocumentMetaInfoKey.title.rawValue] {
        self.titleTextField.text = t
      }
      
      if let d = m[TresorDocumentMetaInfoKey.description.rawValue] {
        self.descriptionTextField.text = d
      }
      
      if let i = m[TresorDocumentMetaInfoKey.iconname.rawValue] {
        self.iconView.image = UIImage(named: i)
      }
    }
    
    self.titleTextField.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
    self.descriptionTextField.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
  }
  
  
  // MARK: - Navigation
  
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    if "showItemNameSelection" == segue.identifier {
      if let s = (segue.destination as? UINavigationController)?.topViewController as? SelectItemNameTableViewController,
        let selectedItem = self.clickedItemNameIndexPath?.row {
        s.itemNames = (self.model?.getActualSectionItems(forSection: 0).map() { payloadItem in
          return payloadItem.name
          })!
        s.selectedItem = selectedItem
      }
    }
    else if segue.identifier == "showSelectIcon" {
      let controller = (segue.destination as! UINavigationController).topViewController as! SelectIconViewController
      
      controller.tresorAppModel = self.tresorAppModel
    }
  }
  
  @IBAction
  func unwindFromSelectItem(segue: UIStoryboardSegue) {
    if "saveItemName" == segue.identifier {
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
  
  @IBAction
  func unwindFromSelectIcon(segue: UIStoryboardSegue) {
    guard segue.identifier == "saveSelectIcon",
      let controller = segue.source as? SelectIconViewController,
      self.tresorDocumentMetaInfo != nil
    else { return }
    
    self.tresorDocumentMetaInfo![TresorDocumentMetaInfoKey.iconname.rawValue] = controller.selectedIcon?.name
    self.iconView.image = UIImage(named: controller.selectedIcon?.name ?? "shield")
  }
 
  // MARK: - Actions
  
  @objc func textFieldDidChange(_ textField: UITextField) {
    if self.tresorDocumentMetaInfo != nil {
      if textField == self.titleTextField {
        self.tresorDocumentMetaInfo![TresorDocumentMetaInfoKey.title.rawValue] = textField.text
      } else if textField == self.descriptionTextField {
        self.tresorDocumentMetaInfo![TresorDocumentMetaInfoKey.description.rawValue] = textField.text
      }
    }
  }
  
  @IBAction
  func itemNameAction(_ sender: Any) {
    if let b = sender as? UIButton, let c = b.superview?.superview as? UITableViewCell {
      self.clickedItemNameIndexPath = self.tableView.indexPath(for: c)
      
      celeturLogger.debug("item name clicked:\(String(describing: clickedItemNameIndexPath))")
      
      self.performSegue(withIdentifier: "showItemNameSelection", sender: self)
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
                                    value: .s(""))
      
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
      let _ = self.model?.removeItemFromActualSection(forPath: indexPath)
      
      tableView.deleteRows(at: [indexPath], with: .fade)
    } else if editingStyle == .insert {
      // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }
  }
  
  fileprivate func configureCell(_ cell: EditTresorDocumentItemCell, forPath indexPath: IndexPath) {
    if let payloadItem = self.model?.getActualItem(forPath: indexPath), let metainfoName = self.model?.metainfo {
      
      cell.itemNameButton?.setTitle(payloadItem.name, for: .normal)
      cell.itemValueTextfield?.text = payloadItem.value.toString()
      
      if let payloadMetainfoItem = self.tresorAppModel?.templates.payloadMetainfoItem(name: metainfoName, indexPath: indexPath) {
        cell.itemValueTextfield.placeholder = payloadMetainfoItem.placeholder
      }
      
    }
  }
}
