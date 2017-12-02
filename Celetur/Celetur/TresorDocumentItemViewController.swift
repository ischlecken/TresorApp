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
  var model : Payload?
  
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
    
    self.becomeFirstResponder()
  }
  
  override var canBecomeFirstResponder: Bool {
    get {
      return true
    }
  }
  
  override func motionEnded(_ motion: UIEventSubtype, with event: UIEvent?) {
    if(event?.subtype == UIEventSubtype.motionShake) {
      self.tresorAppState?.makeMasterKeyUnavailable()
    }
  }
  
  @objc
  func contextDidSave(_ notification: Notification) {
  }
  
  fileprivate func setModel(payload:Payload?) {
    self.model = payload
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
          
          self.tresorAppState?.getMasterKey(){ (tresorKey, error) in
            if let key = tresorKey {
              self.activityView.startAnimating()
              DispatchQueue.global().async {
                if let decryptedPayload = item.decryptPayload(masterKey:key), let d = PayloadSerializer.payload(jsonData: decryptedPayload) {
                  self.setModel(payload: d)
                  
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
            } else {
              label.text = "Masterkey not set, could not decrypt payload..."
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
        controller.setModel(payload: self.model)
        
        controller.navigationItem.title = self.model?.title
        
      default:
        break
      }
    }
  }
  
  @IBAction
  func unwindToTresorDocumentItem(segue: UIStoryboardSegue) {
    if "saveEditTresorDocumentItem" == segue.identifier,
      let m = (segue.source as? EditTresorDocumentItemViewController)?.getModel(),
      let tdi = self.tresorDocumentItem {
      
      self.tresorAppState?.getMasterKey() { (tresorKey, error) in
        if let key = tresorKey {
          self.saveChangedItem(tdi: tdi, k: key, m: m)
        }
      }
    }
  }
  
  fileprivate func saveChangedItem(tdi: TresorDocumentItem,k: TresorKey, m:Payload) {
    if let context = self.tresorAppState?.tresorModel.tresorCoreDataManager?.privateChildManagedObjectContext() {
      self.activityView.startAnimating()
      self.navigationItem.rightBarButtonItem?.isEnabled = false
      self.setModel(payload: nil)
      self.tableView.reloadData()
      
      context.perform {
        self.tresorAppState?.tresorModel.saveDocumentItemModelData(context: context, tresorDocumentItem: tdi, model : m, masterKey: k)
        
        do {
          let _ = try context.save()
          
          DispatchQueue.main.async {
            self.tresorAppState?.tresorModel.saveChanges()
            self.setModel(payload: m)
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
  
  // MARK: - Table View
  
  override func numberOfSections(in tableView: UITableView) -> Int {
    return self.model?.getActualSectionCount() ?? 0
  }
  
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return self.model?.getActualRowCount(forSection: section) ?? 0
  }
  
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "tresorDocumentItemCell", for: indexPath) as! TresorDocumentItemCell
    
    configureCell(cell, forPath: indexPath)
    
    return cell
  }
  
  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    
  }
  
  override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
    return true
  }
  
  override func tableView(_ tableView: UITableView, editActionsForRowAt: IndexPath) -> [UITableViewRowAction]? {
    var result = [UITableViewRowAction]()
    
    if let payloadItem = self.model?.getActualItem(forPath: editActionsForRowAt) {
      let editAction = UITableViewRowAction(style: .normal, title: "Copy") { action, index in
        UIPasteboard.general.string = self.model?.getActualItem(forPath: editActionsForRowAt).value.toString()
      }
      editAction.backgroundColor = .orange
      result.append(editAction)
      
      if payloadItem.isRevealable() && !payloadItem.isRevealed() {
        let revealAction = UITableViewRowAction(style: .normal, title: "Reveal") { action, index in
          if var item = self.model?.getActualItem(forPath: editActionsForRowAt) {
            item.reveal()
            
            self.model?.setActualItem(forPath: editActionsForRowAt,payloadItem:item)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
              self.tableView.reloadRows(at: [editActionsForRowAt], with: .fade)
            }
          }
        }
        revealAction.backgroundColor = .blue
        
        result.append(revealAction)
      }
    }
    
    return result
  }
  
  override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
    if editingStyle == .delete {
      
    }
  }
  
  func configureCell(_ cell: TresorDocumentItemCell, forPath indexPath:IndexPath) {
    guard let payloadItem = self.model?.getActualItem(forPath: indexPath) else {
      return
    }
    
    cell.itemKeyLabel?.text = payloadItem.name
    
    let value = payloadItem.value.toString()
    
    if payloadItem.isRevealable() && !payloadItem.isRevealed() {
      cell.itemValueLabel?.text = String(repeating:"*", count:value.count)
    } else {
      cell.itemValueLabel?.text = value
    }
  
  }
  
}

