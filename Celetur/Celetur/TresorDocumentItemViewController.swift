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
  var revealable = [Bool]()
  var revealed = [Bool]()
  
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
  
  fileprivate func setModel(payloadModel:PayloadModelType?) {
    if let p = payloadModel {
      self.model = p
      self.modelIndex = Array(self.model.keys)
      
      self.revealable = Array(repeating:false, count: self.modelIndex.count)
      self.revealed = Array(repeating:false, count: self.modelIndex.count)
      for (i,v) in self.modelIndex.enumerated() {
        self.revealable[i] = v == "password"
      }
    } else {
      self.model = PayloadModelType()
      self.modelIndex = [String]()
      self.revealable = [Bool]()
      self.revealed = [Bool]()
    }
    
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
              self.setModel(payloadModel: d)
              
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
        controller.setModel(payloadModel: self.model)
        
        controller.navigationItem.title = self.model["title"] as? String
        
      default:
        break
      }
    }
  }
  
  @IBAction
  func unwindToTresorDocumentItem(segue: UIStoryboardSegue) {
    if "saveEditTresorDocumentItem" == segue.identifier {
      if let m = (segue.source as? EditTresorDocumentItemViewController)?.getModel(),
        let tdi = self.tresorDocumentItem,
        let k = self.tresorAppState?.masterKey,
        let context = self.tresorAppState?.tresorModel.tresorCoreDataManager?.privateChildManagedObjectContext() {
      
        self.activityView.startAnimating()
        self.navigationItem.rightBarButtonItem?.isEnabled = false
        self.setModel(payloadModel: nil)
        self.tableView.reloadData()
        
        context.perform {
          self.tresorAppState?.tresorModel.saveDocumentItemModelData(context: context, tresorDocumentItem: tdi, model : m, masterKey: k)
          
          do {
            let _ = try context.save()
            
            DispatchQueue.main.async {
              self.tresorAppState?.tresorModel.saveChanges()
              self.setModel(payloadModel: m)
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
    
    configureCell(cell, forKey: self.modelIndex[indexPath.row],andIndex: indexPath.row)
    
    return cell
  }
  
  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    
  }
  
  override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
    return true
  }
  
  override func tableView(_ tableView: UITableView, editActionsForRowAt: IndexPath) -> [UITableViewRowAction]? {
    var result = [UITableViewRowAction]()
    
    let editAction = UITableViewRowAction(style: .normal, title: "Copy") { action, index in
      UIPasteboard.general.string = self.model[self.modelIndex[editActionsForRowAt.row]] as? String
    }
    editAction.backgroundColor = .orange
    
    result.append(editAction)
    
    if self.revealable[editActionsForRowAt.row] && !self.revealed[editActionsForRowAt.row] {
      let revealAction = UITableViewRowAction(style: .normal, title: "Reveal") { action, index in
        self.revealed[editActionsForRowAt.row] = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
          self.tableView.reloadRows(at: [editActionsForRowAt], with: .fade)
        }
      }
      revealAction.backgroundColor = .blue
      
      result.append(revealAction)
    }
    
    return result
  }
  
  override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
    if editingStyle == .delete {
      
    }
  }
  
  func configureCell(_ cell: TresorDocumentItemCell, forKey key: String, andIndex index: Int) {
    cell.itemKeyLabel?.text = key
    
    
    if let value = self.model[key] as? String {
      if self.revealable[index] && !self.revealed[index] {
        cell.itemValueLabel?.text =  String(repeating:"*", count:value.count)
      } else {
        cell.itemValueLabel?.text = value
      }
    } else {
      cell.itemValueLabel?.text = "-"
    }
  }
  
}

