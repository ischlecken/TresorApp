//
//  Created by Feldmaus on 20.08.17.
//  Copyright © 2017 ischlecken. All rights reserved.
//

import UIKit
import CeleturKit


class EditTresorDocumentItemViewController: UITableViewController {
  
  var tresorAppState: TresorAppState?
  
  let dateFormatter = DateFormatter()
  var model = [String:Any]()
  var modelIndex = [String]()
  
  override func viewDidLoad() {
    super.viewDidLoad()
  
  }
  
  
  // MARK: - Actions
  
  
  @IBAction func addFieldAction(_ sender: Any) {
    let key = "key"+String(Int(arc4random())%100)
    
    self.model[key] = "value"+String(Int(arc4random())%1000)
    
    self.modelIndex = Array(self.model.keys)
    
    self.tableView.reloadData()
  }
  
  @IBAction func deleteFieldsAction(_ sender: Any) {
    self.model = [String:Any]()
    
    self.modelIndex = Array(self.model.keys)
    
    self.tableView.reloadData()
  }
  
  // MARK: - Segue
  
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
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
      cell = tableView.dequeueReusableCell(withIdentifier: "editCell", for: indexPath)
      
      configureCell(cell, forKey: self.modelIndex[indexPath.row])
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
  
  fileprivate func configureCell(_ cell: UITableViewCell, forKey key: String) {
    cell.textLabel?.text = key
    cell.detailTextLabel?.text = self.model[key] as? String
  }
  
}
