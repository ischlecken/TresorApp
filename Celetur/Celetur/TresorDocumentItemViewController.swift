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
  var model = PayloadModelType()
  var modelIndex = [String]()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    self.dateFormatter.dateStyle = DateFormatter.Style.short
    self.dateFormatter.timeStyle = DateFormatter.Style.short
    
    self.navigationItem.rightBarButtonItem?.isEnabled = false
    
    self.tableView.register(UINib(nibName:"TresorDocumentItemCell",bundle:nil),forCellReuseIdentifier:"tresorDocumentItemCell")
    
    configureView()
    
    /*
    NotificationCenter.default.addObserver(self, selector: #selector(contextDidSave(_:)),
                                           name: Notification.Name.NSManagedObjectContextObjectsDidChange,
                                           object:self.tresorDocumentItem?.managedObjectContext)
   */
  }
  
  deinit {
  //  NotificationCenter.default.removeObserver(self)
  }
  
  @objc
  func contextDidSave(_ notification: Notification) {
  }
  
  func configureView() {
    if let item = tresorDocumentItem {
      
      if let metaInfo = item.document?.getMetaInfo() {
        self.navigationItem.title = metaInfo["title"]
      }
      
      if let label = createtsLabel {
        label.text = self.dateFormatter.string(from: item.modifyts)
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
          DispatchQueue.global().async {
            if let decryptedPayload = item.decryptPayload(masterKey:key!), let d = PayloadModel.model(jsonData: decryptedPayload) {
              self.model = d
              self.modelIndex = Array(self.model.keys)
              
              DispatchQueue.main.async {
                self.setDataLabel(data: nil, error: nil)
                self.navigationItem.rightBarButtonItem?.isEnabled = true
              }
            } else {
              DispatchQueue.main.async {
                self.setDataLabel(data: nil, error: nil)
              }
            }
          }
        }
      }
    }
  }
  
  func setDataLabel(data:Data?, error:Error?) {
    if let e=error {
      self.dataLabel!.text = e.localizedDescription
    } else if let d=data {
      self.dataLabel!.text = String(data: d, encoding: String.Encoding.utf8)
    } else {
      self.dataLabel!.text = ""
    }
    
    self.tableView.reloadData()
    self.activityView.stopAnimating()
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
        
        controller.navigationItem.title = self.model["title"] as? String
        
      default:
        break
      }
    }
  }
  
  @IBAction
  func unwindToTresorDocumentItem(segue: UIStoryboardSegue) {
    if "saveEditTresorDocumentItem" == segue.identifier {
      if let m = (segue.source as? EditTresorDocumentItemViewController)?.model,
        let tdi = self.tresorDocumentItem,
        let k = self.tresorAppState?.masterKey,
        let context = self.tresorAppState?.tresorModel.tresorCoreDataManager?.privateChildManagedObjectContext() {
      
        self.activityView.startAnimating()
        self.navigationItem.rightBarButtonItem?.isEnabled = false
        self.model = PayloadModelType()
        self.modelIndex = [String]()
        self.tableView.reloadData()
        
        context.perform {
          self.tresorAppState?.tresorModel.saveDocumentItemModelData(context: context, tresorDocumentItem: tdi, model : m, masterKey: k)
          
          do {
            let _ = try context.save()
            
            DispatchQueue.main.async {
              self.tresorAppState?.tresorModel.saveChanges()
              
              self.model = m
              self.modelIndex = Array(self.model.keys)
              self.tableView.reloadData()
            }
          } catch {
            celeturLogger.error("Error while saving changed tresor document items...",error:error)
          }
          
          DispatchQueue.main.async {
            self.activityView.stopAnimating()
            self.navigationItem.rightBarButtonItem?.isEnabled = true
            
          }
        }
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
    let cell = tableView.dequeueReusableCell(withIdentifier: "tresorDocumentItemCell", for: indexPath) as! TresorDocumentItemCell
    
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
  
  func configureCell(_ cell: TresorDocumentItemCell, forKey key: String) {
    cell.itemKeyLabel?.text = key
    cell.itemValueLabel?.text = self.model[key] as? String
  }
  
}

