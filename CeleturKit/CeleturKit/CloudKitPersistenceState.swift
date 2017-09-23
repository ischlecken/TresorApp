//
//  CloudKitPersistenceState.swift
//  CeleturKit
//
//  Created by Feldmaus on 23.09.17.
//  Copyright © 2017 prisnoc. All rights reserved.
//

import CloudKit

@objc
class CKServerChangeTokenModel : NSObject,NSCoding {

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

class CloudKitPersistenceState {
  
  var serverChangeTokensFilePath : String
  var changedIdsFilePath : String
  var deletedIdsFilePath: String
  
  var changeTokens : [String:CKServerChangeTokenModel]?
  var changedObjectIds : Set<String>?
  var deletedObjectIds : Set<String>?
  var saveLock = NSLock()
  
  init(appGroupContainerId:String) {
    self.serverChangeTokensFilePath = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupContainerId)!.appendingPathComponent("ckserverchangetokens.plist").path
    self.changedIdsFilePath = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupContainerId)!.appendingPathComponent("changedids.plist").path
    self.deletedIdsFilePath = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupContainerId)!.appendingPathComponent("deletedids.plist").path
  }
  
  func load() {
    celeturKitLogger.debug("CloudKitPersistenceState.load()")
    
    self.changedObjectIds = NSKeyedUnarchiver.unarchiveObject(withFile: self.changedIdsFilePath) as? Set<String>
    self.deletedObjectIds = NSKeyedUnarchiver.unarchiveObject(withFile: self.deletedIdsFilePath) as? Set<String>
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
    self.deletedObjectIds = Set<String>()
    
    NSKeyedArchiver.archiveRootObject(self.changedObjectIds as Any, toFile: self.changedIdsFilePath)
    NSKeyedArchiver.archiveRootObject(self.deletedObjectIds as Any, toFile: self.deletedIdsFilePath)
  }
  
  func addChangedObject(o:NSManagedObject) {
    let uri = o.objectID.uriRepresentation().path
    celeturKitLogger.debug("CloudKitPersistenceState.addChangedObject(\(uri))")
    
    self.saveLock.lock()
    
    defer {
      self.saveLock.unlock()
    }
    
    if self.changedObjectIds == nil {
      self.changedObjectIds = Set<String>()
    }
    
    self.changedObjectIds?.insert(uri)
  }
  
  func addDeletedObject(o:NSManagedObject) {
    let uri = o.objectID.uriRepresentation().path
    celeturKitLogger.debug("CloudKitPersistenceState.addDeletedObject(\(uri))")
    
    self.saveLock.lock()
    
    defer {
      self.saveLock.unlock()
    }
    
    if self.deletedObjectIds == nil {
      self.deletedObjectIds = Set<String>()
    }
    
    self.deletedObjectIds?.insert(uri)
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
}
