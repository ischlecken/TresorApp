//
//  CKRecord+Extension.swift
//  CeleturKit
//
//  Created by Feldmaus on 23.09.17.
//  Copyright © 2017 prisnoc. All rights reserved.
//

import CloudKit

extension CKRecord {
  
  func data() -> Data {
    let result = NSMutableData()
    let archiver = NSKeyedArchiver(forWritingWith: result)
    
    archiver.requiresSecureCoding = true
    
    self.encodeSystemFields(with: archiver)
    
    archiver.finishEncoding()
    
    return result as Data
  }
  
  convenience init?(archivedData:Data) {
    let unarchiver = NSKeyedUnarchiver(forReadingWith: archivedData)
    unarchiver.requiresSecureCoding = true
    
    self.init(coder: unarchiver)
  }
}

