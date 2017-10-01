//
//  CKRecord+Extension.swift
//  CeleturKit
//
//  Created by Feldmaus on 23.09.17.
//  Copyright © 2017 prisnoc. All rights reserved.
//

import CloudKit

extension CKRecordID {
  
  func deleteManagedObject(context:NSManagedObjectContext, usingEntityName entityName:String) {
    let obj = CKRecord.getManagedObject(usingContext: context, withEntityName: entityName, andId: self.recordName)
    
    if let o = obj {
      context.delete(o)
    }
  }
}

extension CKRecord {
  
  func cksystemdata() -> Data {
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
  
  func updateManagedObject(context:NSManagedObjectContext) {
    var o = self.getManagedObject(usingContext: context)
    if o == nil {
      o = NSEntityDescription.insertNewObject(forEntityName: self.recordType, into: context)
    }
    
    if let o = o {
      o.update(usingRecord: self)
    }
  }
  
  func getManagedObject(usingContext context:NSManagedObjectContext) -> NSManagedObject? {
    return CKRecord.getManagedObject(usingContext: context, withEntityName: self.recordType, andId: self.recordID.recordName)
  }
  
  class func getManagedObject(usingContext context:NSManagedObjectContext,withEntityName entityName:String,andId id:String) -> NSManagedObject? {
    let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
    fetchRequest.predicate = NSPredicate(format: "id = %@", id)
    fetchRequest.fetchBatchSize = 1
    
    var result : NSManagedObject?
    
    do {
      let records = try context.fetch(fetchRequest)
      if records.count>0 {
        result = records[0] as? NSManagedObject
      }
    } catch {
      celeturKitLogger.error("Error while find corresponding managed object",error:error)
    }
    
    //celeturKitLogger.debug("CKRecord.getManagedObject(entityName:\(entityName),id:\(id)):\(String(describing: result))")
    
    return result
  }
  
  func dumpRecordInfo(prefix:String) {
    celeturKitLogger.debug(prefix+"\(self.recordType): \(self.recordID.recordName) in \(self.recordID.zoneID.zoneName)")
  }
}

