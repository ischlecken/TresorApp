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
    let uri = o.objectID.uriRepresentation().absoluteString
    
    self.saveLock.lock()
    defer {
      self.saveLock.unlock()
    }
    
    let entityId = o.value(forKey: "id") as? String
    let entityType = o.entity.name
    
    celeturKitLogger.debug("CloudKitPersistenceState.addChangedObject(\(entityType ?? "nil"): \(entityId ?? "nil"))")
    if self.changedObjectIds == nil {
      self.changedObjectIds = Set<String>()
    }
    
    self.changedObjectIds?.insert(uri)
  }
  
  func isObjectChanged(o:NSManagedObject) -> Bool {
    return self.changedObjectIds != nil && self.changedObjectIds?.contains(o.objectID.uriRepresentation().absoluteString) ?? false
  }
  
  func addDeletedObject(o:NSManagedObject) {
    let uri = o.objectID.uriRepresentation().absoluteString
    let entityType = o.entity.name
    let entityId = o.value(forKey: "id") as? String
    
    self.saveLock.lock()
    defer {
      self.saveLock.unlock()
    }
    
    celeturKitLogger.debug("CloudKitPersistenceState.addDeletedObject(\(entityType ?? "nil"): \(entityId ?? "nil"))")
    if self.deletedObjectIds == nil {
      self.deletedObjectIds = Set<CKDeletedObjectInfo>()
    }
    
    if var c = self.changedObjectIds {
      c.remove(uri)
    }
    
    if let et = entityType, let ei = entityId {
      self.deletedObjectIds?.insert(CKDeletedObjectInfo(type:et, id: ei))
    }
  }
  
  func isObjectDeleted(o:NSManagedObject) -> Bool {
    let delInfo = CKDeletedObjectInfo(type:o.entity.name!, id: o.value(forKey: "id") as! String)
    
    return self.deletedObjectIds != nil && self.deletedObjectIds?.contains(delInfo) ?? false
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
