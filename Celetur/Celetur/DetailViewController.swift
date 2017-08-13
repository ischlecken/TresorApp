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
  
  @IBOutlet weak var titleLabel: UILabel!
  @IBOutlet weak var userLabel: UILabel!
  @IBOutlet weak var passwordLabel: UILabel!
  
  func configureView() {
    
    if let item = tresorDocumentItem {
      if let label = titleLabel {
        label.text = item.createts!.description
      }
      
      if let label = userLabel {
        label.text = item.type
      }
      
      
      if let label = passwordLabel {
        
        if let key = self.tresorAppState?.masterKey {
          self.tresorAppState!.tresorDataModel.decryptTresorDocumentItemPayload(tresorDocumentItem: item, masterKey:key) { (operation) in
            if let d = operation.outputData {
              label.text = String(data: d, encoding: String.Encoding.utf8)
            } else {
              label.text = "Failed to decrypt payload: \(String(describing: operation.error))"
            }
          }
        } else {
          label.text = "Masterkey not set, could not decrypt payload..."
        }
      }
    }
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    // Do any additional setup after loading the view, typically from a nib.
    configureView()
    
    celeturLogger.debug("DetailViewController.viewDidLoad")
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

