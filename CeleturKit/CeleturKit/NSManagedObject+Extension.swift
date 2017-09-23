//
//  NSManagedObject+Extension.swift
//  CeleturKit
//
//  Created by Feldmaus on 23.09.17.
//  Copyright © 2017 prisnoc. All rights reserved.
//

import CloudKit

extension NSManagedObject {
  
  func storedCKRecord() -> CKRecord? {
    let ckdata = self.value(forKey: "ckdata") as? Data
    
    guard let d = ckdata else { return nil }
    
    let unarchiver = NSKeyedUnarchiver(forReadingWith: d)
    unarchiver.requiresSecureCoding = true
    
    return CKRecord(coder: unarchiver)
  }
  
  func isCKStoreableObject() -> Bool {
    let ed = self.entity
    let entityName = ed.name
    let attributesByName = ed.attributesByName
    
    return entityName!.starts(with: "Tresor") && attributesByName.keys.contains("ckdata") && attributesByName.keys.contains("id")
  }
}
