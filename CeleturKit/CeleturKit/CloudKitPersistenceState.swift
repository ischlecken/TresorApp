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
class CKAddedObjectInfo : NSObject, NSCoding, NSCopying {
  
  var entityType : String
  var entityId : String
  var objectUri : String
  var ckuserid: String
  
  func encode(with aCoder: NSCoder) {
    aCoder.encode(self.entityId, forKey: "entityid")
    aCoder.encode(self.entityType, forKey: "entitytype")
    aCoder.encode(self.objectUri, forKey: "objecturi")
    aCoder.encode(self.ckuserid, forKey: "ckuserid")
  }
  
  required convenience init?(coder aDecoder: NSCoder) {
    let id = aDecoder.decodeObject(forKey: "entityid") as? String
    let type = aDecoder.decodeObject(forKey: "entitytype") as? String
    let uri = aDecoder.decodeObject(forKey: "objecturi") as? String
    let ckuserid = aDecoder.decodeObject(forKey: "ckuserid") as? String
    
    self.init(type: type!, id: id!, uri: uri!, ckuserid:ckuserid!)
  }
  
  init(type:String,id:String,uri:String,ckuserid:String) {
    self.entityType = type
    self.entityId = id
    self.objectUri = uri
    self.ckuserid = ckuserid
  }
  
  static func == (lhs: CKAddedObjectInfo, rhs: CKAddedObjectInfo) -> Bool {
    return lhs.entityType == rhs.entityType && lhs.entityId == rhs.entityId
  }
  
  override var hashValue: Int {
    return self.entityId.hashValue
  }
  
  func copy(with zone: NSZone? = nil) -> Any {
    return CKAddedObjectInfo(type: self.entityType, id: self.entityId, uri: self.objectUri, ckuserid:self.ckuserid)
  }
}

@objc
class CKDeletedObjectInfo : NSObject, NSCoding {
  
  var entityType : String
  var entityId : String
  var ckuserid: String
  
  func encode(with aCoder: NSCoder) {
    aCoder.encode(self.entityId, forKey: "entityid")
    aCoder.encode(self.entityType, forKey: "entitytype")
    aCoder.encode(self.ckuserid, forKey: "ckuserid")
  }
  
  required convenience init?(coder aDecoder: NSCoder) {
    let id = aDecoder.decodeObject(forKey: "entityid") as? String
    let type = aDecoder.decodeObject(forKey: "entitytype") as? String
    let ckuserid = aDecoder.decodeObject(forKey: "ckuserid") as? String
    
    self.init(type: type!, id: id!, ckuserid: ckuserid!)
  }
  
  init(type:String,id:String,ckuserid:String) {
    self.entityType = type
    self.entityId = id
    self.ckuserid = ckuserid
  }
  
  static func == (lhs: CKDeletedObjectInfo, rhs: CKDeletedObjectInfo) -> Bool {
    return lhs.entityType == rhs.entityType && lhs.entityId == rhs.entityId
  }
  
  override var hashValue: Int {
    return self.entityId.hashValue
  }
}

class CloudKitPersistenceState {
  
  var serverChangeTokensFilePath : String
  var changedIdsFilePath : String
  var deletedIdsFilePath: String
  
  var changeTokens : [String:CKServerChangeTokenModel]?
  var changedObjectIds : Set<CKAddedObjectInfo>?
  var deletedObjectIds : Set<CKDeletedObjectInfo>?
  
  var saveLock = NSLock()
  
  init(appGroupContainerId:String) throws {
    let dirURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupContainerId)!
    
    self.serverChangeTokensFilePath = dirURL.appendingPathComponent("ckserverchangetokens.plist").path
    self.changedIdsFilePath = dirURL.appendingPathComponent("changedids.plist").path
    self.deletedIdsFilePath = dirURL.appendingPathComponent("deletedids.plist").path
    
    self.load()
  }
  
  func load() {
    celeturKitLogger.debug("CloudKitPersistenceState.load()")
    
    self.changedObjectIds = NSKeyedUnarchiver.unarchiveObject(withFile: self.changedIdsFilePath) as? Set<CKAddedObjectInfo>
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
    
    self.changedObjectIds = Set<CKAddedObjectInfo>()
    self.deletedObjectIds = Set<CKDeletedObjectInfo>()
 
    NSKeyedArchiver.archiveRootObject(self.changedObjectIds as Any, toFile: self.changedIdsFilePath)
    NSKeyedArchiver.archiveRootObject(self.deletedObjectIds as Any, toFile: self.deletedIdsFilePath)
  }
  
  func addChangedObject(o:NSManagedObject) {
    guard let entityId = o.value(forKey: "id") as? String,
      let entityType = o.entity.name,
      let ckUserId = o.value(forKey: "ckuserid") as? String
      else { return }
    
    self.saveLock.lock()
    defer {
      self.saveLock.unlock()
    }
    
    let uri = o.objectID.uriRepresentation().absoluteString
    
    var c : Set<CKAddedObjectInfo> = self.changedObjectIds ?? Set<CKAddedObjectInfo>()
    
    var found = false
    for aoi in c {
      if aoi.entityId == entityId && aoi.ckuserid == ckUserId {
        found = true
        break
      }
    }
    
    if !found {
      c.insert(CKAddedObjectInfo(type: entityType, id: entityId, uri: uri, ckuserid:ckUserId) )
    }
    
    self.changedObjectIds = c
  
    celeturKitLogger.debug("CloudKitPersistenceState.addChangedObject(\(entityType),\(entityId)): \(c.count)")
  }
  
  func findChangedObject(entityId:String) -> [CKAddedObjectInfo] {
    var result = [CKAddedObjectInfo]()
    
    if let c = self.changedObjectIds {
      for aoi in c {
        if aoi.entityId == entityId {
          result.append(aoi)
        }
      }
    }
    
    return result
  }
  
  func changedObjectHasBeenSaved(ckUserId: String, entityIds:[String]) {
    self.saveLock.lock()
    defer {
      self.saveLock.unlock()
    }
    
    let removed = self.removeEntityIdFromChangedObjects(ckUserId:ckUserId, entityIds: entityIds)
    if removed.count>0 {
      celeturKitLogger.debug("CloudKitPersistenceState.changedObjectHasBeenSaved(\(entityIds))")
    } else {
      celeturKitLogger.debug("CloudKitPersistenceState.changedObjectHasBeenSaved(\(entityIds)) not found")
    }
  }
  
  fileprivate func removeEntityIdFromChangedObjects(ckUserId: String, entityIds:[String]) -> [CKAddedObjectInfo] {
    var removed = [CKAddedObjectInfo]()
    
    if let c = self.changedObjectIds {
      var newC = Set<CKAddedObjectInfo>()
      
      for aoi in c {
        var found : CKAddedObjectInfo?
        
        for entityId in entityIds {
          if aoi.entityId == entityId && aoi.ckuserid == ckUserId {
            found = aoi
          }
        }
        
        if let f = found {
          removed.append(f)
        } else {
          newC.insert(aoi)
        }
      }
      
      self.changedObjectIds = newC
    }
    
    return removed
  }
  
  func isObjectChanged(o:NSManagedObject) -> Bool {
    guard let entityId = o.value(forKey: "id") as? String else { return false }
    
    self.saveLock.lock()
    defer {
      self.saveLock.unlock()
    }
    
    return self.findChangedObject(entityId: entityId).count>0
  }
  
  func addDeletedObject(o:NSManagedObject) {
    guard let entityId = o.value(forKey: "id") as? String,
      let entityType = o.entity.name,
      let ckUserId = o.value(forKey: "ckuserid") as? String
      else { return }
  
    self.saveLock.lock()
    defer {
      self.saveLock.unlock()
    }
    
    let _ = self.removeEntityIdFromChangedObjects(ckUserId:ckUserId, entityIds: [entityId])
    
    var d : Set<CKDeletedObjectInfo> = self.deletedObjectIds ?? Set<CKDeletedObjectInfo>()
    
    var found = false
    
    for doi in d {
      if doi.entityId == entityId {
        found = true
        break;
      }
    }
    
    if !found {
      d.insert(CKDeletedObjectInfo(type:entityType, id: entityId, ckuserid: ckUserId))
    }
    self.deletedObjectIds = d
    
    celeturKitLogger.debug("CloudKitPersistenceState.addDeletedObject(\(entityType),\(entityId)): \(d.count)")
  }
  
  
  func deletedObjectHasBeenDeleted(ckUserId: String, entityIds:[String]) {
    if let _ = self.deletedObjectIds {
      self.saveLock.lock()
      defer {
        self.saveLock.unlock()
      }
      
      if let d = self.deletedObjectIds {
        var newD = Set<CKDeletedObjectInfo>()
        
        for delinfo in d {
          var found : CKDeletedObjectInfo?
          
          for entityId in entityIds {
            if delinfo.entityId == entityId && delinfo.ckuserid==ckUserId {
              found = delinfo
              
              break
            }
          }
          
          if found == nil {
            newD.insert(delinfo)
          }
        }
        
        self.deletedObjectIds = newD
      }
    }
  }
  
  func isObjectDeleted(o:NSManagedObject) -> Bool {
    guard let entityId = o.value(forKey: "id") as? String, let _ = self.deletedObjectIds else { return false }
      
    var result = false
    
    self.saveLock.lock()
    defer {
      self.saveLock.unlock()
    }
    
    if let d = self.deletedObjectIds {
      for delinfo in d {
        if delinfo.entityId == entityId {
          result = true
          
          break
        }
      }
    }
  
    return result
  }
  
  
  func getServerChangeToken(forName name:String) -> CKServerChangeToken? {
    guard let ct = self.changeTokens, let ctName = ct[name] else { return nil }
    
    //celeturKitLogger.debug("getServerChangeToken(\(name)): \(ctName.serverChangeToken)")
      
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
    
    //celeturKitLogger.debug("setServerChangeToken(\(name)): \(token)")
    
    NSKeyedArchiver.archiveRootObject(self.changeTokens as Any, toFile: self.serverChangeTokensFilePath)
  }
  
  func flushServerChangeTokens() {
    self.changeTokens = [String:CKServerChangeTokenModel]()
    
    do {
      try FileManager.default.removeItem(atPath: self.serverChangeTokensFilePath)
    } catch {
      celeturKitLogger.error("Error deleted servertoken file", error: error)
    }
  }
  
  func changedRecords(moc:NSManagedObjectContext, ckUserId:String, zoneId:CKRecordZoneID? ) -> [CKRecord] {
    var records = [CKRecord]()
    
    if let coi = self.changedObjectIds {
      for aoi in coi {
        if aoi.ckuserid != ckUserId {
          continue
        }
        
        if let url = URL(string:aoi.objectUri),
          let oID = moc.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: url),
          let r = moc.object(with: oID).mapToRecord(zoneId: zoneId) {
            records.append(r)
        }
      }
    }
    
    return records
  }
  
  func deletedRecordIds(moc:NSManagedObjectContext, ckUserId:String, zoneId:CKRecordZoneID? ) -> [CKRecordID] {
    var result = [CKRecordID]()
    
    if let dOIds = self.deletedObjectIds {
      for doi in dOIds {
        if doi.ckuserid != ckUserId {
          continue
        }
        
        if let zId = zoneId {
          result.append(CKRecordID(recordName: doi.entityId, zoneID: zId))
        }
      }
    }
    
    return result
  }
}
