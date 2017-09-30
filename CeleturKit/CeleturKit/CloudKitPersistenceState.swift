//
//  CloudKitPersistenceState.swift
//  CeleturKit
//
//  Created by Feldmaus on 23.09.17.
//  Copyright © 2017 prisnoc. All rights reserved.
//

import CloudKit

@objc
class CKServerChangeTokenModel : NSObject, NSCoding {

  func encode(with aCoder: NSCoder) {
    aCoder.encode(self.type, forKey: "type")
    
    self.serverChangeToken.encode(with: aCoder)
  }
  
  required convenience init?(coder aDecoder: NSCoder) {
    let type = aDecoder.decodeObject(forKey: "type") as? String
    let sct = CKServerChangeToken.init(coder: aDecoder)
    
    self.init(type: type!, serverChangeToken: sct!)
  }
  
  var serverChangeToken:CKServerChangeToken
  var type:String
  
  init(type:String,serverChangeToken:CKServerChangeToken) {
    self.type = type
    self.serverChangeToken = serverChangeToken
  }
}

@objc
class CKDeletedObjectInfo : NSObject, NSCoding {
  
  var entityType : String
  var entityId : String
  
  func encode(with aCoder: NSCoder) {
    aCoder.encode(self.entityId, forKey: "entityid")
    aCoder.encode(self.entityType, forKey: "entitytype")
  }
  
  required convenience init?(coder aDecoder: NSCoder) {
    let id = aDecoder.decodeObject(forKey: "entityid") as? String
    let type = aDecoder.decodeObject(forKey: "entitytype") as? String
    
    self.init(type: type!, id: id!)
  }
  
  init(type:String,id:String) {
    self.entityType = type
    self.entityId = id
  }
  
  static func == (lhs: CKDeletedObjectInfo, rhs: CKDeletedObjectInfo) -> Bool {
    return lhs.entityType == rhs.entityType && lhs.entityId == rhs.entityId
  }
  
  override var hashValue: Int {
    return self.entityId.hashValue + self.entityType.hashValue
  }
}

class CloudKitPersistenceState {
  
  var serverChangeTokensFilePath : String
  var changedIdsFilePath : String
  var deletedIdsFilePath: String
  
  var changeTokens : [String:CKServerChangeTokenModel]?
  var changedObjectIds : Set<String>?
  var deletedObjectIds : Set<CKDeletedObjectInfo>?

  var saveLock = NSLock()
  
  init(appGroupContainerId:String) {
    self.serverChangeTokensFilePath = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupContainerId)!.appendingPathComponent("ckserverchangetokens.plist").path
    self.changedIdsFilePath = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupContainerId)!.appendingPathComponent("changedids.plist").path
    self.deletedIdsFilePath = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupContainerId)!.appendingPathComponent("deletedids.plist").path
  }
  
  func load() {
    celeturKitLogger.debug("CloudKitPersistenceState.load()")
    
    self.changedObjectIds = NSKeyedUnarchiver.unarchiveObject(withFile: self.changedIdsFilePath) as? Set<String>
    self.deletedObjectIds = NSKeyedUnarchiver.unarchiveObject(withFile: self.deletedIdsFilePath) as? Set<CKDeletedObjectInfo>
    self.changeTokens = NSKeyedUnarchiver.unarchiveObject(withFile: self.serverChangeTokensFilePath) as? [String:CKServerChangeTokenModel]
  }
  
  func saveChangedIds() {
    celeturKitLogger.debug("CloudKitPersistenceState.saveChangedIds()")
    
    self.saveLock.lock()
    
    defer {
     self.saveLock.unlock()
    }
    
    NSKeyedArchiver.archiveRootObject(self.changedObjectIds as Any, toFile: self.changedIdsFilePath)
    NSKeyedArchiver.archiveRootObject(self.deletedObjectIds as Any, toFile: self.deletedIdsFilePath)
  }
  
  func flushChangedIds() {
    celeturKitLogger.debug("CloudKitPersistenceState.flushChangedIds()")
    
    self.saveLock.lock()
    
    defer {
      self.saveLock.unlock()
    }
    
    self.changedObjectIds = Set<String>()
    self.deletedObjectIds = Set<CKDeletedObjectInfo>()
 
    NSKeyedArchiver.archiveRootObject(self.changedObjectIds as Any, toFile: self.changedIdsFilePath)
    NSKeyedArchiver.archiveRootObject(self.deletedObjectIds as Any, toFile: self.deletedIdsFilePath)
  }
  
  func addChangedObject(o:NSManagedObject) {
    let uri = o.objectID.uriRepresentation().absoluteString
    
    self.saveLock.lock()
    defer {
      self.saveLock.unlock()
    }
    
    celeturKitLogger.debug("CloudKitPersistenceState.addChangedObject(\(uri))")
    if self.changedObjectIds == nil {
      self.changedObjectIds = Set<String>()
    }
    
    self.changedObjectIds?.insert(uri)
  }
  
  func addDeletedObject(o:NSManagedObject) {
    let uri = o.objectID.uriRepresentation().absoluteString
    let entityType = o.entity.name
    let entityId = o.value(forKey: "id") as? String
    
    self.saveLock.lock()
    defer {
      self.saveLock.unlock()
    }
    
    celeturKitLogger.debug("CloudKitPersistenceState.addDeletedObject(\(uri))")
    if self.deletedObjectIds == nil {
      self.deletedObjectIds = Set<CKDeletedObjectInfo>()
    }
    
    if let et = entityType, let ei = entityId {
      self.deletedObjectIds?.insert(CKDeletedObjectInfo(type:et, id: ei))
    }
  }
  
  
  func getServerChangeToken(forName name:String) -> CKServerChangeToken? {
    guard let ct = self.changeTokens, let ctName = ct[name] else { return nil }
      
    return ctName.serverChangeToken
  }
  
  func setServerChangeToken(token:CKServerChangeToken, forName name:String) {
    if self.changeTokens == nil {
      self.changeTokens = [String:CKServerChangeTokenModel]()
    }
    
    if self.changeTokens![name] == nil {
      self.changeTokens![name] = CKServerChangeTokenModel(type: name, serverChangeToken: token)
    } else {
      self.changeTokens![name]?.serverChangeToken = token
    }
    
    NSKeyedArchiver.archiveRootObject(self.changeTokens as Any, toFile: self.serverChangeTokensFilePath)
  }
  
  func changedRecords(moc:NSManagedObjectContext,zoneId:( (NSManagedObject) -> CKRecordZoneID?) ) -> [CKRecord] {
    var records = [CKRecord]()
    
    if let coi = self.changedObjectIds {
      for urlString in coi {
        if let url = URL(string:urlString) {
          if let oID = moc.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: url) {
            let o = moc.object(with: oID)
            
            o.dumpMetaInfo()
            
            if o.isCKStoreableObject() {
              if let zId = zoneId(o) {
                let record = o.createCKRecord(zoneId: zId)
                if let r = record {
                  let ed = o.entity
                  let attributesByName = ed.attributesByName
                  
                  for (n,_) in attributesByName {
                    let v = o.value(forKey: n) as? CKRecordValue
                    if n == "ckdata" {
                      continue
                    }
                    
                    r.setObject(v, forKey: n)
                  }
                  
                  records.append(r)
                }
              }
            }
          }
        }
      }
    }
    
    return records
  }
  
  func deletedRecordIds(moc:NSManagedObjectContext,zoneId:( (String) -> CKRecordZoneID?) ) -> [CKRecordID] {
    var result = [CKRecordID]()
    
    if let dOIds = self.deletedObjectIds {
      for doi in dOIds {
        if let zId = zoneId(doi.entityType) {
          let rId = CKRecordID(recordName: doi.entityId, zoneID: zId)
          
          result.append(rId)
        }
      }
    }
    
    return result
  }
}
