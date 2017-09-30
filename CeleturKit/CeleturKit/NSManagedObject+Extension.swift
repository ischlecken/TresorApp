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
  
  func update(usingRecord record:CKRecord) {
    let attributes = self.entity.attributesByName
    
    for k in record.allKeys() {
      let v = record.value(forKey: k)
      
      if attributes[k] != nil {
        self.setValue(v, forKey: k)
      }
    }
    
    if attributes["ckdata"] != nil {
      self.setValue(record.cksystemdata(), forKey: "ckdata")
    }
  }
  
  func createNewCKRecord(zoneId:CKRecordZoneID) -> CKRecord? {
    let ed = self.entity
    let entityName = ed.name
    let id = self.value(forKey: "id") as? String
    
    guard let rId = id, let eName = entityName else { return nil }
    
    return CKRecord(recordType: eName, recordID:  CKRecordID(recordName: rId, zoneID: zoneId))
  }
  
  func createCKRecord(zoneId:CKRecordZoneID) -> CKRecord? {
    let result = self.storedCKRecord()
    
    return result != nil ? result : self.createNewCKRecord(zoneId:zoneId)
  }
  
  func dumpMetaInfo() {
    let ed = self.entity
    
    celeturKitLogger.debug("entityname:\(ed.name ?? "nil")")
    
    for (n,p) in ed.attributesByName {
      celeturKitLogger.debug("  \(n):\(p.attributeValueClassName ?? "nil" )")
    }
    
    for (n,p) in ed.relationshipsByName {
      celeturKitLogger.debug("  \(n): ")
      celeturKitLogger.debug("        type=\(p.destinationEntity?.name ?? "nil" )")
      celeturKitLogger.debug("        toMany=\(p.isToMany)")
      celeturKitLogger.debug("        inverseType=\(p.inverseRelationship?.name ?? "nil" )")
    }
  }
  
}
