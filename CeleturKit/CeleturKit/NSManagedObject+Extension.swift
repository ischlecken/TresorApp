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
  
  func update(context:NSManagedObjectContext, usingRecord record:CKRecord) {
    let attributes = self.entity.attributesByName
    
    for k in record.allKeys() {
      if let v = record.value(forKey: k), attributes[k] != nil {
        self.setValue(v, forKey: k)
      }
    }
    
    if attributes["ckdata"] != nil {
      self.setValue(record.cksystemdata(), forKey: "ckdata")
    }
  }
  
  func updateRelationships(context:NSManagedObjectContext, usingRecord record:CKRecord) {
    for (n,p) in self.entity.relationshipsByName {
      if !p.isToMany, let ref = record.value(forKey: n) as? CKReference, let refEntityName = p.destinationEntity?.name {
        let refObj = CKRecord.getManagedObject(usingContext: context, withEntityName: refEntityName, andId: ref.recordID.recordName)
        
        self.setValue(refObj, forKey: n)
      } else if p.isToMany,
        p.inverseRelationship?.isToMany ?? false,
        let refEntityName = p.destinationEntity?.name {
        
        if let l = record.value(forKey: n) as? [CKReference] {
          let refObjSet = self.mutableSetValue(forKey: n)
          refObjSet.removeAllObjects()
          for r in l {
            if let refObj = CKRecord.getManagedObject(usingContext: context, withEntityName: refEntityName, andId: r.recordID.recordName) {
              refObjSet.add( refObj as Any )
            }
          }
        } else {
          self.setValue(nil, forKey: n)
        }
      }
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
  
  
  func mapToRecord(zoneId:CKRecordZoneID? ) -> CKRecord? {
    var result : CKRecord?
    
    if self.isCKStoreableObject() {
      //self.dumpMetaInfo()
      
      if let zId = zoneId {
        let record = self.createCKRecord(zoneId: zId)
        if let r = record {
          self.mapObjectAttributes(zId: zId, r: r)
          self.mapObjectRelationship(zId: zId, r: r)
          
          result = r
        }
      }
    }
    
    return result
  }
  
  fileprivate func mapObjectAttributes(zId:CKRecordZoneID, r:CKRecord) {
    let ed = self.entity
    let attributesByName = ed.attributesByName
    
    for (n,_) in attributesByName {
      let v = self.value(forKey: n) as? CKRecordValue
      if n == "ckdata" {
        continue
      }
      
      r.setObject(v, forKey: n)
    }
  }
  
  fileprivate func mapObjectRelationship(zId:CKRecordZoneID, r:CKRecord) {
    let ed = self.entity
    let id = self.value(forKey: "id") as? String
    
    celeturKitLogger.debug("set references for \(ed.name ?? "-" ): \(id ?? "-")")
    
    for (n,p) in ed.relationshipsByName {
      if !p.isToMany,
        let destValue = self.value(forKey:n) as? NSManagedObject,
        let destId = destValue.value(forKey: "id") as? String {
        
        let ref = CKReference(recordID: CKRecordID(recordName: destId, zoneID: zId), action: .none)
        
        celeturKitLogger.debug("  reference to \(p.destinationEntity?.name ?? "-"): \(destId)")
        
        r.setObject(ref, forKey:n)
      } else if p.isToMany,
        let relationObjects = self.value(forKey:n) as? NSSet,
        p.inverseRelationship?.isToMany ?? false {
        
        celeturKitLogger.debug("  \(n) is many-to-many relation...")
        
        var rList = [CKReference]()
        for ro in relationObjects {
          if let o = ro as? NSManagedObject, let destId = o.value(forKey: "id") as? String {
            celeturKitLogger.debug("    reference to \(p.destinationEntity?.name ?? "-"): \(destId)")
            
            rList.append(CKReference(recordID: CKRecordID(recordName: destId, zoneID: zId), action: .none))
          }
        }
        
        if rList.count>0 {
          r.setObject(rList as CKRecordValue, forKey: n)
        } else {
          r.setObject(nil, forKey: n)
        }
      }
    }
  }
  
}
