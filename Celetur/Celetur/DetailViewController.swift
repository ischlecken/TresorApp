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
          do {
            let data = try self.tresorAppState!.tresorDataModel.decryptTresorDocumentItemPayload(tresorDocumentItem: item, masterKey:key)
            
            label.text = String(data: data, encoding: String.Encoding.utf8)
          } catch {
            celeturLogger.error("Error while decrypting payload", error: error)
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

