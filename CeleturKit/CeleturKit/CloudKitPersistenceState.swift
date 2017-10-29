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
    return self.entityId.hashValue
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
  
  init(appGroupContainerId:String, forUserId userId:String? = nil) throws {
    let dirURL : URL
    
    if let userId = userId {
      dirURL = try URL.appGroupSubdirectoryURL(appGroupId: appGroupContainerId, dirName: userId)
    } else {
      dirURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupContainerId)!
    }
    
    self.serverChangeTokensFilePath = dirURL.appendingPathComponent("ckserverchangetokens.plist").path
    self.changedIdsFilePath = dirURL.appendingPathComponent("changedids.plist").path
    self.deletedIdsFilePath = dirURL.appendingPathComponent("deletedids.plist").path
    
    self.load()
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
    guard let entityId = o.value(forKey: "id") as? String, let entityType = o.entity.name else { return }
    
    self.saveLock.lock()
    defer {
      self.saveLock.unlock()
    }
    
    celeturKitLogger.debug("CloudKitPersistenceState.addChangedObject(\(entityType): \(entityId))")
    
    var c : Set<String> = self.changedObjectIds ?? Set<String>()
    c.insert(entityId)
  
  }
  
  func changedObjectHasBeenSaved(entityId:String) {
    celeturKitLogger.debug("CloudKitPersistenceState.changedObjectHasBeenSaved(\(entityId))")
    
    self.saveLock.lock()
    defer {
      self.saveLock.unlock()
    }
    
    if var c = self.changedObjectIds {
      let removed = c.remove(entityId)
      
      celeturKitLogger.debug("CloudKitPersistenceState.changedObjectHasBeenSaved(\(entityId)) removed:\(removed ?? "-")")
    }
  }
  
  func isObjectChanged(o:NSManagedObject) -> Bool {
    guard let entityId = o.value(forKey: "id") as? String, let _ = self.changedObjectIds else { return false }
    
    self.saveLock.lock()
    defer {
      self.saveLock.unlock()
    }
    
    var result = false
    if let c = self.changedObjectIds {
      result = c.contains(entityId)
    }
    
    return result
  }
  
  func addDeletedObject(o:NSManagedObject) {
    guard let entityId = o.value(forKey: "id") as? String, let entityType = o.entity.name else { return }
  
    self.saveLock.lock()
    defer {
      self.saveLock.unlock()
    }
    
    celeturKitLogger.debug("CloudKitPersistenceState.addDeletedObject(\(entityType): \(entityId))")
    if self.deletedObjectIds == nil {
      self.deletedObjectIds = Set<CKDeletedObjectInfo>()
    }
    
    if var c = self.changedObjectIds {
      c.remove(entityId)
    }
    
    self.deletedObjectIds?.insert(CKDeletedObjectInfo(type:entityType, id: entityId))
  }
  
  
  func deletedObjectHasBeenDeleted(entityId:String) {
    if let _ = self.deletedObjectIds {
      self.saveLock.lock()
      defer {
        self.saveLock.unlock()
      }
      
      if var d = self.deletedObjectIds {
        for delinfo in d {
          if delinfo.entityId == entityId {
            let removed = d.remove(delinfo)
            
            celeturKitLogger.debug("CloudKitPersistenceState.deletedObjectHasBeenDeleted(\(entityId)): removed:\(removed ?? nil)")
            
            break
          }
        }
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
  
  func changedRecords(moc:NSManagedObjectContext,zoneId:CKRecordZoneID? ) -> [CKRecord] {
    var records = [CKRecord]()
    
    if let coi = self.changedObjectIds {
      for urlString in coi {
        if let url = URL(string:urlString),
          let oID = moc.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: url),
          let r = moc.object(with: oID).mapToRecord(zoneId: zoneId) {
            records.append(r)
        }
      }
    }
    
    return records
  }
  
  func deletedRecordIds(moc:NSManagedObjectContext,zoneId:CKRecordZoneID? ) -> [CKRecordID] {
    var result = [CKRecordID]()
    
    if let dOIds = self.deletedObjectIds {
      for doi in dOIds {
        if let zId = zoneId {
          result.append(CKRecordID(recordName: doi.entityId, zoneID: zId))
        }
      }
    }
    
    return result
  }
}
