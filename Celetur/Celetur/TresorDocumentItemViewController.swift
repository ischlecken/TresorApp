//
//  DetailViewController.swift
//  Celetur
//
//  Created by Feldmaus on 09.07.17.
//  Copyright © 2017 ischlecken. All rights reserved.
//

import UIKit
import CeleturKit

class TresorDocumentItemViewController: UITableViewController {
  
  var tresorAppState: TresorAppState?
  
  var tresorDocumentItem: TresorDocumentItem? {
    didSet {
      // Update the view.
      configureView()
    }
  }
  
  @IBOutlet weak var activityView: UIActivityIndicatorView!
  @IBOutlet weak var dataLabel: UILabel!
  @IBOutlet weak var createtsLabel: UILabel!
  
  let dateFormatter = DateFormatter()
  var model = [String:Any]()
  var modelIndex = [String]()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    self.dateFormatter.dateStyle = DateFormatter.Style.short
    self.dateFormatter.timeStyle = DateFormatter.Style.short
    
    configureView()
  }
  
  func configureView() {
    
    if let item = tresorDocumentItem {
      if let label = createtsLabel {
        
        label.text = self.dateFormatter.string(from: item.createts!)
      }
      
      if let label = dataLabel {
        label.text = ""
        
        if let payload = item.payload {
          self.activityView.startAnimating()
          label.text = payload.hexEncodedString()
          
          if let key = self.tresorAppState?.masterKey {
            self.tresorAppState!.tresorDataModel.decryptTresorDocumentItemPayload(tresorDocumentItem: item, masterKey:key) { (operation) in
              if let d = operation.outputData {
                label.text = String(data: d, encoding: String.Encoding.utf8)
                
                do {
                  self.model = (try JSONSerialization.jsonObject(with: d, options: []) as? [String:Any])!
                  
                  self.modelIndex = Array(self.model.keys)
                  
                  self.tableView.reloadData()
                } catch {
                  celeturLogger.error("Error while parsing payload",error:error)
                }
                
              } else {
                label.text = "Failed to decrypt payload: \(String(describing: operation.error))"
              }
              
              self.activityView.stopAnimating()
            }
          } else {
            label.text = "Masterkey not set, could not decrypt payload..."
            self.activityView.stopAnimating()
          }
        }
      }
    }
  }
  
  // MARK: - Segue
  
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    if let ident = segue.identifier {
      switch ident {
      case "showEditTresorDocumentItem":
        let controller = (segue.destination as! UINavigationController).topViewController as! EditTresorDocumentItemViewController
        
        controller.tresorAppState = self.tresorAppState
        controller.tresorDocumentItem = try! self.tresorAppState?.tresorDataModel.copyTemporaryTresorDocumentItem(tresorDocumentItem: self.tresorDocumentItem!)
        
      default: break
      }
    }
  }
  
  @IBAction func unwindToTresorDocumentItem(segue: UIStoryboardSegue) {
    if "saveEditTresorDocumentItem" == segue.identifier {
      celeturLogger.debug("saveEditTresorDocumentItem")
      
      let tresorDocumentItem = (segue.source as? EditTresorDocumentItemViewController)?.tresorDocumentItem
      let payload = try! JSONSerialization.data( withJSONObject: (segue.source as? EditTresorDocumentItemViewController)?.model as Any, options: [])
      
      try! self.tresorAppState?.tresorDataModel.encryptAndSaveTemporaryTresorDocumentItem(masterKey: (self.tresorAppState?.masterKey)!, tresorDocumentItem: tresorDocumentItem!, payload: payload)
    }
  }
  
  // MARK: - Table View
  
  override func numberOfSections(in tableView: UITableView) -> Int {
    return 1
  }
  
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return self.modelIndex.count
  }
  
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "detailCell", for: indexPath)
    
    configureCell(cell, forKey: self.modelIndex[indexPath.row])
    
    return cell
  }
  
  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    
  }
  
  override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
    return true
  }
  
  override func tableView(_ tableView: UITableView, editActionsForRowAt: IndexPath) -> [UITableViewRowAction]? {
    
    let editAction = UITableViewRowAction(style: .normal, title: "Edit") { action, index in
      print("edit button tapped")
      
    }
    editAction.backgroundColor = .orange
    
    let deleteAction = UITableViewRowAction(style: .destructive, title: "Delete") { action, index in
      _ = self.tresorAppState?.persistentContainer.context
      
    }
    
    return [editAction, deleteAction]
  }
  
  override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
    if editingStyle == .delete {
      
    }
  }
  
  func configureCell(_ cell: UITableViewCell, forKey key: String) {
    cell.textLabel?.text = key
    cell.detailTextLabel?.text = self.model[key] as? String
  }
  
}

