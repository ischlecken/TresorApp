//
//  Created by Feldmaus on 20.08.17.
//  Copyright © 2017 ischlecken. All rights reserved.
//

import UIKit
import CeleturKit


class EditTresorDocumentItemViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
  
  @IBOutlet weak var headerView: UIView!
  @IBOutlet weak var tableView: UITableView!
  @IBOutlet weak var headerViewHeightConstraint: NSLayoutConstraint!
  
  @IBOutlet weak var iconView: UIImageView!
  @IBOutlet weak var titleView: UILabel!
  @IBOutlet weak var descriptionView: UILabel!
  
  fileprivate let maxHeaderHeight: CGFloat = 160;
  fileprivate let minHeaderHeight: CGFloat = 40;
  fileprivate let iconMinHeight: CGFloat = 0.5;
  fileprivate var previousScrollOffset : CGFloat = 0.0
  
  var tresorAppState: TresorAppModel?
  
  fileprivate let dateFormatter = DateFormatter()
  fileprivate var tresorDocumentMetaInfo : TresorDocumentMetaInfo?
  fileprivate var model : Payload?
  fileprivate var tresorDocumentItem : TresorDocumentItem?
  
  fileprivate var actualEditingItemValueIndexPath : IndexPath?
  fileprivate var clickedItemNameIndexPath : IndexPath?
  
  func setModel(tresorDocumentItem:TresorDocumentItem, payload:Payload?, metaInfo: TresorDocumentMetaInfo?) {
    self.tresorDocumentItem = tresorDocumentItem
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
    
    self.headerViewHeightConstraint.constant = self.maxHeaderHeight
    if let tdi = self.tresorDocumentItem, let m = tdi.document?.getMetaInfo() {
      if let t = m["title"] {
        self.titleView.text = t
      }
      
      if let d = m["description"] {
        self.descriptionView.text = d
      }
      
      if let i = m["iconname"] {
        self.iconView.image = UIImage(named: i)
      }
    }
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
  
  func numberOfSections(in tableView: UITableView) -> Int {
    return 2
  }
  
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
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
  
  
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
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
  
  func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
    return true
  }
  
  func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
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
    if let payloadItem = self.model?.getActualItem(forPath: indexPath), let metainfoName = self.model?.metainfo {
      
      cell.itemNameButton?.setTitle(payloadItem.name, for: .normal)
      cell.itemValueTextfield?.text = payloadItem.value.toString()
      
      if let payloadMetainfoItem = self.tresorAppState?.templates.payloadMetainfoItem(name: metainfoName, indexPath: indexPath) {
        cell.itemValueTextfield.placeholder = payloadMetainfoItem.placeholder
      }
      
    }
  }
  
  
  func scrollViewDidScroll(_ scrollView: UIScrollView) {
    let scrollDiff = scrollView.contentOffset.y - self.previousScrollOffset
    
    //celeturLogger.debug("scrollViewDidScroll(): scrollDiff=\(scrollDiff)")
    
    let absoluteTop: CGFloat = 0;
    let absoluteBottom: CGFloat = scrollView.contentSize.height - scrollView.frame.size.height;
    
    let isScrollingDown = scrollDiff > 0 && scrollView.contentOffset.y > absoluteTop
    let isScrollingUp = scrollDiff < 0 && scrollView.contentOffset.y < absoluteBottom
    
    if canAnimateHeader(scrollView) {
      var newHeight = self.headerViewHeightConstraint.constant
      if isScrollingDown {
        newHeight = max(self.minHeaderHeight, self.headerViewHeightConstraint.constant - abs(scrollDiff))
      } else if isScrollingUp {
        newHeight = min(self.maxHeaderHeight, self.headerViewHeightConstraint.constant + abs(scrollDiff))
      }
      
      if newHeight != self.headerViewHeightConstraint.constant {
        //celeturLogger.debug("scrollViewDidScroll(): newHeight=\(newHeight)")
        self.headerViewHeightConstraint.constant = newHeight
        self.setScrollPosition(position: self.previousScrollOffset)
      }
    }
    
    self.previousScrollOffset = scrollView.contentOffset.y
  }
  
  func canAnimateHeader(_ scrollView: UIScrollView) -> Bool {
    // Calculate the size of the scrollView when header is collapsed
    let scrollViewMaxHeight = scrollView.frame.height + self.headerViewHeightConstraint.constant - minHeaderHeight
    
    // Make sure that when header is collapsed, there is still room to scroll
    let result = scrollView.contentSize.height > scrollViewMaxHeight
    
    //celeturLogger.debug("canAnimateHeader(): scrollViewMaxHeight=\(scrollViewMaxHeight) --> \(result)")
    
    return result
  }
  
  func collapseHeader() {
    self.view.layoutIfNeeded()
    UIView.animate(withDuration: 0.2, animations: {
      self.headerViewHeightConstraint.constant = self.minHeaderHeight
      self.view.layoutIfNeeded()
    })
  }
  
  func expandHeader() {
    self.view.layoutIfNeeded()
    UIView.animate(withDuration: 0.2, animations: {
      self.headerViewHeightConstraint.constant = self.maxHeaderHeight
      self.view.layoutIfNeeded()
    })
  }
  
  func setScrollPosition(position: CGFloat) {
    self.tableView.contentOffset = CGPoint(x: self.tableView.contentOffset.x, y: position)
  }
}
