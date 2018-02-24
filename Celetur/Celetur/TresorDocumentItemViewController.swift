//
//  DetailViewController.swift
//  Celetur
//
//  Created by Feldmaus on 09.07.17.
//  Copyright © 2017 ischlecken. All rights reserved.
//

import UIKit
import CeleturKit

class TresorDocumentItemViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
  
  var tresorAppModel: TresorAppModel?
  var tresorDocumentItem: TresorDocumentItem? {
    didSet {
      configureView()
    }
  }
  
  @IBOutlet weak var headerView: UIView!
  @IBOutlet weak var tableView: UITableView!
  @IBOutlet weak var headerViewHeightConstraint: NSLayoutConstraint!
  
  @IBOutlet weak var iconView: UIImageView!
  @IBOutlet weak var titleView: UILabel!
  @IBOutlet weak var descriptionView: UILabel!
  
  @IBOutlet weak var activityView: UIActivityIndicatorView!
  @IBOutlet weak var dataLabel: UILabel!
  @IBOutlet weak var createtsLabel: UILabel!
  
  fileprivate let maxHeaderHeight: CGFloat = 160;
  fileprivate let minHeaderHeight: CGFloat = 40;
  fileprivate let iconMinHeight: CGFloat = 0.5;
  fileprivate var previousScrollOffset : CGFloat = 0.0
  
  let dateFormatter = DateFormatter()
  var model : Payload?
  var revealInfo : [String:Bool] = [:]
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    self.navigationItem.largeTitleDisplayMode = .automatic
    self.navigationItem.rightBarButtonItem?.isEnabled = false
    
    self.dateFormatter.dateStyle = DateFormatter.Style.short
    self.dateFormatter.timeStyle = DateFormatter.Style.short
   
    self.tableView.register(UINib(nibName:"TresorDocumentItemCell",bundle:nil),forCellReuseIdentifier:"tresorDocumentItemCell")
    
    self.headerViewHeightConstraint.constant = self.maxHeaderHeight
    
    configureView()
    
    NotificationCenter.default.addObserver(self, selector: #selector(contextDidSave(_:)),
                                           name: Notification.Name.NSManagedObjectContextObjectsDidChange,
                                           object:self.tresorDocumentItem?.managedObjectContext)
    
    
    self.becomeFirstResponder()
  }
  
  override var canBecomeFirstResponder: Bool {
    get {
      return true
    }
  }
  
  override func motionEnded(_ motion: UIEventSubtype, with event: UIEvent?) {
    if(event?.subtype == UIEventSubtype.motionShake) {
      self.tresorAppModel?.makeMasterKeyUnavailable()
    }
  }
  
  @objc
  func contextDidSave(_ notification: Notification) {
    celeturLogger.debug("contextDidSave")
    
    self.configureView()
  }
  
  
  fileprivate func configureView() {
    if let item = tresorDocumentItem {
      
      if let metaInfo = item.document?.getMetaInfo() {
        self.navigationItem.title = metaInfo[TresorDocumentMetaInfoKey.title.rawValue]
      }
      
      if let label = createtsLabel {
        label.text = self.dateFormatter.string(from: item.modifyts)
      }
      
      if let tdi = self.tresorDocumentItem,
        let m = tdi.document?.getMetaInfo(),
        let tv = self.titleView,
        let dv = self.descriptionView,
        let iv = self.iconView {
        
        tv.text = m[TresorDocumentMetaInfoKey.title.rawValue]
        dv.text = m[TresorDocumentMetaInfoKey.description.rawValue]
        
        if let i = m[TresorDocumentMetaInfoKey.iconname.rawValue] {
          iv.image = UIImage(named: i)
        }
      }
      
      if let label = dataLabel {
        label.text = ""
        
        if let payload = item.payload {
          label.text = payload.hexEncodedString()
          
          self.tresorAppModel?.getMasterKey(){ (tresorKey, error) in
            if let key = tresorKey {
              self.startAnimation()
              DispatchQueue.global().async {
                if let decryptedPayload = item.decryptPayload(masterKey:key), let d = PayloadSerializer.payload(jsonData: decryptedPayload) {
                  DispatchQueue.main.async {
                    self.setModel(payload: d)
                  }
                }
                
                DispatchQueue.main.async {
                  self.stopAnimation()
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
  
  fileprivate func setModel(payload:Payload?) {
    self.model = payload
    
    self.navigationItem.rightBarButtonItem?.isEnabled = self.model != nil
    self.tableView.reloadData()
  }
  
  fileprivate func setDataLabel(data:Data?, error:Error?) {
    if let e=error {
      self.dataLabel!.text = e.localizedDescription
    } else if let d=data {
      self.dataLabel!.text = String(data: d, encoding: String.Encoding.utf8)
    } else {
      self.dataLabel!.text = ""
    }
  }
  
  fileprivate func startAnimation() {
    celeturLogger.debug("startAnimation")
    
    self.activityView.startAnimating()
    
    UIView.animate(withDuration: 1.0) {
      self.activityView.superview?.layoutIfNeeded()
    }
  }
  
  fileprivate func stopAnimation() {
    celeturLogger.debug("stopAnimation")
    
    UIView.animate(withDuration: 2, animations: {
      self.activityView.superview?.layoutIfNeeded()
    }) { complete in
      self.activityView.stopAnimating()
    }
  }
  
  // MARK: - Segue
  
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    if let ident = segue.identifier {
      switch ident {
      case "showEditTresorDocumentItem":
        let controller = (segue.destination as! UINavigationController).topViewController as! EditTresorDocumentItemViewController
        
        controller.tresorAppModel = self.tresorAppModel
        
        let tresorDocumentMetaInfo = self.tresorDocumentItem?.document?.getMetaInfo()
        
        controller.setModel(payload: self.model, metaInfo: tresorDocumentMetaInfo)
        
        controller.navigationItem.title = tresorDocumentMetaInfo?[TresorDocumentMetaInfoKey.title.rawValue]
        
      default:
        break
      }
    }
  }
  
  
  
  @IBAction
  func unwindFromEditTresorDocumentItem(segue: UIStoryboardSegue) {
    if "saveEditTresorDocumentItem" == segue.identifier,
      let m = (segue.source as? EditTresorDocumentItemViewController)?.getModel(),
      let mi = (segue.source as? EditTresorDocumentItemViewController)?.tresorDocumentMetaInfo,
      let tdi = self.tresorDocumentItem {
      
      self.expandHeader()
      
      self.tresorAppModel?.getMasterKey() { (tresorKey, error) in
        if let key = tresorKey {
          self.saveChangedItem(tdi: tdi, k: key, metaInfo: mi, m: m)
        }
      }
    }
  }
  
  fileprivate func saveChangedItem(tdi: TresorDocumentItem,k: TresorKey, metaInfo: TresorDocumentMetaInfo, m:Payload) {
    if let context = self.tresorAppModel?.tresorModel.getCoreDataManager()?.privateChildManagedObjectContext() {
      self.setModel(payload: nil)
      self.startAnimation()
      
      context.perform {
        tdi.saveDocumentItemModelData(context: context, model : m, metaInfo: metaInfo, masterKey: k)
        
        do {
          let _ = try context.save()
          
          DispatchQueue.main.async {
            self.tresorAppModel?.tresorModel.saveChanges()
          }
        } catch {
          celeturLogger.error("Error while saving changed tresor document items...",error:error)
        }
      }
    }
  }
  
  // MARK: - Table View
  
  func numberOfSections(in tableView: UITableView) -> Int {
    return self.model?.getActualSectionCount() ?? 0
  }
  
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return self.model?.getActualRowCount(forSection: section) ?? 0
  }
  
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "tresorDocumentItemCell", for: indexPath) as! TresorDocumentItemCell
    
    configureCell(cell, forPath: indexPath)
    
    return cell
  }
  
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    
  }
  
  func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
    return true
  }
  
  func tableView(_ tableView: UITableView, editActionsForRowAt: IndexPath) -> [UITableViewRowAction]? {
    var result = [UITableViewRowAction]()
    
    if let payloadItem = self.model?.getActualItem(forPath: editActionsForRowAt),
      let metainfoName = self.model?.metainfo,
      let payloadMetainfoItem = self.tresorAppModel?.templates.payloadMetainfoItem(name: metainfoName, indexPath: editActionsForRowAt) {
      
      let editAction = UITableViewRowAction(style: .normal, title: "Copy") { action, index in
        UIPasteboard.general.string = self.model?.getActualItem(forPath: editActionsForRowAt).value.toString()
      }
      editAction.backgroundColor = .orange
      result.append(editAction)
      
      if payloadMetainfoItem.isRevealable() && !(self.payloadItemIsRevealed(indexPath: editActionsForRowAt,payloadItem: payloadItem) ?? false) {
        let revealAction = UITableViewRowAction(style: .normal, title: "Reveal") { action, index in
          self.revealPayloadItem(indexPath: editActionsForRowAt, payloadItem: payloadItem)
            
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            self.tableView.reloadRows(at: [editActionsForRowAt], with: .fade)
          }
        }
        revealAction.backgroundColor = .blue
        
        result.append(revealAction)
      }
    }
    
    return result
  }
  
  func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
    if editingStyle == .delete {
      
    }
  }
  
  func configureCell(_ cell: TresorDocumentItemCell, forPath indexPath:IndexPath) {
    guard let payloadItem = self.model?.getActualItem(forPath: indexPath), let metainfoName = self.model?.metainfo else { return }
    
    let payloadMetainfoItem = self.tresorAppModel?.templates.payloadMetainfoItem(name: metainfoName, indexPath: indexPath)
    
    cell.itemKeyLabel?.text = payloadItem.name
    cell.itemValueLabel?.text = nil
    cell.itemValueLabel?.textColor = UIColor.darkText
    
    let value = payloadItem.value.toString()
    if payloadMetainfoItem != nil &&
      (payloadMetainfoItem?.isRevealable() ?? false) &&
      !(self.payloadItemIsRevealed(indexPath: indexPath, payloadItem: payloadItem) ?? false) {
      cell.itemValueLabel?.text = String(repeating:"*", count:value.count)
    } else {
      cell.itemValueLabel?.text = value
    }
    
    if let pmii = payloadMetainfoItem, let c = cell.itemValueLabel?.text?.count, c == 0, let p = pmii.placeholder {
      cell.itemValueLabel?.text = p
      cell.itemValueLabel?.textColor = UIColor.lightGray
    }
  }
  
  fileprivate func payloadItemIsRevealed(indexPath:IndexPath, payloadItem: PayloadItem) -> Bool? {
    guard let metainfoName = self.model?.metainfo else { return false }
    
    return self.revealInfo["\(metainfoName).\(indexPath.section).\(payloadItem.name)"]
  }
  
  fileprivate func revealPayloadItem(indexPath:IndexPath, payloadItem: PayloadItem) {
    if let metainfoName = self.model?.metainfo {
      self.revealInfo["\(metainfoName).\(indexPath.section).\(payloadItem.name)"] = true
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
    UIView.animate(withDuration: 1.2, animations: {
      self.headerViewHeightConstraint.constant = self.minHeaderHeight
      self.view.layoutIfNeeded()
    })
  }
  
  func expandHeader() {
    self.view.layoutIfNeeded()
    UIView.animate(withDuration: 1.2, animations: {
      self.headerViewHeightConstraint.constant = self.maxHeaderHeight
      self.view.layoutIfNeeded()
    })
  }
  
  func setScrollPosition(position: CGFloat) {
    self.tableView.contentOffset = CGPoint(x: self.tableView.contentOffset.x, y: position)
  }
}

