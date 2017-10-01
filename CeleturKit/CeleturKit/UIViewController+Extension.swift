//
//  UIViewController+Extension.swift
//  CeleturKit
//
//  Created by Feldmaus on 01.10.17.
//  Copyright © 2017 prisnoc. All rights reserved.
//

import Foundation


public extension UIViewController {
  
  
  public func presentAlertController(title:String, message:String, alertAction:UIAlertAction? = nil) {
    DispatchQueue.main.async {
      let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
      
      if let aa = alertAction {
        alert.addAction(aa)
      }
      alert.addAction(UIAlertAction(title: "OK",style: .cancel, handler: nil))
      
      self.present(alert, animated: true, completion: nil)
    }
  }
}
