//
//  Created by Feldmaus on 20.08.17.
//  Copyright © 2017 ischlecken. All rights reserved.
//

import UIKit
import CeleturKit


class EditTresorDocumentItemViewController: UITableViewController {
  
  var tresorAppState: TresorAppState?
  var tresorDocumentItem: TresorDocumentItem?
  
  @IBOutlet weak var activityView: UIActivityIndicatorView!
  
  
  let dateFormatter = DateFormatter()
  var model = [String:Any]()
  var modelIndex = [String]()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    self.decryptPayload()
    
    // Uncomment the following line to preserve selection between presentations
    // self.clearsSelectionOnViewWillAppear = false
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem
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
      result = 1
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
    case 1:
      cell = tableView.dequeueReusableCell(withIdentifier: "addFieldCell", for: indexPath)
    default:
      break
    }
    
    return cell
  }
  
  override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
    return true
  }
  
  override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
    if editingStyle == .delete {
      // Delete the row from the data source
      tableView.deleteRows(at: [indexPath], with: .fade)
    } else if editingStyle == .insert {
      // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }
  }
  
  
  /*
   override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {
   }
   
   override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
   return true
   }
   */
  
  func configureCell(_ cell: UITableViewCell, forKey key: String) {
    cell.textLabel?.text = key
    cell.detailTextLabel?.text = self.model[key] as? String
  }
  
  func decryptPayload() {
    if let _ = tresorDocumentItem?.payload {
      self.activityView.startAnimating()
      
      if let key = self.tresorAppState?.masterKey {
        self.tresorAppState!.tresorDataModel.decryptTresorDocumentItemPayload(tresorDocumentItem: tresorDocumentItem!, masterKey:key) { (operation) in
          if let d = operation.outputData {
            
            do {
              self.model = (try JSONSerialization.jsonObject(with: d, options: []) as? [String:Any])!
              
              self.modelIndex = Array(self.model.keys)
              
              self.tableView.reloadData()
            } catch {
              celeturLogger.error("Error while parsing payload",error:error)
            }
            
          }
          
          self.activityView.stopAnimating()
        }
      }
    }
  }
}
