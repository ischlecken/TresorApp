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
  
  var tresorAppState: TresorAppModel?
  
  var tresorDocumentItem: TresorDocumentItem? {
    didSet {
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
    
    NotificationCenter.default.addObserver(self, selector: #selector(contextDidSave(_:)),
                                           name: Notification.Name.NSManagedObjectContextObjectsDidChange,
                                           object:self.tresorAppState?.mainManagedObjectContext())
  }
  
  deinit {
    NotificationCenter.default.removeObserver(self)
  }
  
  @objc func contextDidSave(_ notification: Notification) {
    /*
    celeturLogger.debug("MOCObjectsDidChange")
    
    guard let userInfo = notification.userInfo else { return }
    
    if let inserts = userInfo[NSInsertedObjectsKey] as? Set<NSManagedObject>, inserts.count > 0 {
      for insert in inserts {
        celeturLogger.debug("inserts:"+String(describing:insert))
      }
    }
    
    if let updates = userInfo[NSUpdatedObjectsKey] as? Set<NSManagedObject>, updates.count > 0 {
      for update in updates {
        celeturLogger.debug("updates:"+String(describing:update))
      }
     
    }
    
    if let deletes = userInfo[NSDeletedObjectsKey] as? Set<NSManagedObject>, deletes.count > 0 {
      for delete in deletes {
        celeturLogger.debug("delete:"+String(describing:delete))
      }
    }
 */
    
    self.configureView()
  }
  
  func configureView() {
    
    if let item = tresorDocumentItem {
      if let label = createtsLabel {
        
        label.text = self.dateFormatter.string(from: item.createts!)
      }
      
      if let label = dataLabel {
        label.text = ""
        
        if let payload = item.payload {
          label.text = payload.hexEncodedString()
          
          let key = self.tresorAppState?.masterKey
          if key == nil {
            label.text = "Masterkey not set, could not decrypt payload..."
            
            return
          }
          
          self.activityView.startAnimating()
        
          self.tresorAppState!.tresorModel.decryptTresorDocumentItemPayload(tresorDocumentItem: item, masterKey:key!) {
            (decryptOperation:SymmetricCipherOperation?) in
            
            guard let deop=decryptOperation else {
              self.setDataLabel(data: nil)
              return
            }
            
            if let d = deop.outputData {
              do {
                self.model = (try JSONSerialization.jsonObject(with: d, options: []) as? [String:Any])!
                self.modelIndex = Array(self.model.keys)
                
                self.setDataLabel(data: d)
              } catch {
                celeturLogger.error("Error while decoding json",error:error)
              }
            }
          }
        }
      }
    }
  }
  
  func setDataLabel(data:Data?) {
    DispatchQueue.main.async {
      if let d=data {
        self.dataLabel!.text = String(data: d, encoding: String.Encoding.utf8)
      }
      
      self.tableView.reloadData()
      self.activityView.stopAnimating()
    }
  }
  
  // MARK: - Segue
  
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    if let ident = segue.identifier {
      switch ident {
      case "showEditTresorDocumentItem":
        let controller = (segue.destination as! UINavigationController).topViewController as! EditTresorDocumentItemViewController
        
        controller.tresorAppState = self.tresorAppState
        controller.model = self.model
        controller.modelIndex = self.modelIndex
        
      default:
        break
      }
    }
  }
  
  @IBAction func unwindToTresorDocumentItem(segue: UIStoryboardSegue) {
    if "saveEditTresorDocumentItem" == segue.identifier {
      celeturLogger.debug("saveEditTresorDocumentItem")
      
      let model = (segue.source as? EditTresorDocumentItemViewController)?.model
      let scratchpadContext = self.tresorAppState?.tresorModel.privateChildManagedContext
      
      scratchpadContext?.perform {
        
        self.tresorAppState?.tresorModel.encryptAndSaveTresorDocumentItem(tempManagedContext: scratchpadContext!,
                                                                              masterKey: (self.tresorAppState?.masterKey)!,
                                                                              tresorDocumentItem: self.tresorDocumentItem!,
                                                                              payload: model!)
      }
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
  
  func configureCell(_ cell: UITableViewCell, forKey key: String) {
    cell.textLabel?.text = key
    cell.detailTextLabel?.text = self.model[key] as? String
  }
  
}

