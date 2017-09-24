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
    
    celeturKitLogger.debug("getManagedObject(entityName:\(entityName),id:\(id)):\(String(describing: result))")
    
    return result
  }
}

