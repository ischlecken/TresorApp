//
//  DetailViewController.swift
//  Celetur
//
//  Created by Feldmaus on 09.07.17.
//  Copyright © 2017 ischlecken. All rights reserved.
//

import UIKit
import CeleturKit

class DetailViewController: UIViewController {
  
  var tresorAppState: TresorAppState?
  
  @IBOutlet weak var activityView: UIActivityIndicatorView!
  @IBOutlet weak var dataLabel: UILabel!
  @IBOutlet weak var createtsLabel: UILabel!
  
  let dateFormatter = DateFormatter()
  
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
  
  
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
  
  var tresorDocumentItem: TresorDocumentItem? {
    didSet {
      // Update the view.
      configureView()
    }
  }
  
  
}

