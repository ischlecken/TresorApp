//
//  Created by Feldmaus on 06.08.17.
//  Copyright © 2017 prisnoc. All rights reserved.
//

import Foundation
import Contacts
import CloudKit

let appGroup = "group.net.prisnoc.Celetur"
let celeturKitIdentifier = "net.prisnoc.CeleturKit"

public class TresorModel {
  
  let coreDataManager: CoreDataManager
  lazy var cloudKitManager = {
    return CloudKitManager(tresorModel: self)
  }()
  
  lazy var cloudKitPersistenceState : CloudKitPersistenceState = {
    let ckps = CloudKitPersistenceState(appGroupContainerId: appGroup)
    
    ckps.load()
    
    return ckps
  }()
  
  let cipherQueue = OperationQueue()
  
  fileprivate var userList : [TresorUser]?
  fileprivate var userListInited = false
  
  public init() {
    self.coreDataManager = CoreDataManager(modelName: "CeleturKit", using:Bundle(identifier:celeturKitIdentifier)!, inAppGroupContainer:appGroup)
  }
  
  
  public func completeSetup() {
    self.coreDataManager.completeSetup {
      celeturKitLogger.debug("TresorModel.completeSetup()")
      
      self.cloudKitManager.createCloudKitSubscription()
      self.cloudKitManager.requestUserDiscoverabilityPermission()
      self.coreDataManager.cloudKitManager = self.cloudKitManager
      
      DispatchQueue.main.async {
        let _ = self.getUserList()
      }
    }
  }
  
  
  public var privateManagedContext : NSManagedObjectContext {
    return self.coreDataManager.privateManagedObjectContext
  }
  
  
  public var mainManagedContext : NSManagedObjectContext {
    return self.coreDataManager.mainManagedObjectContext
  }
  
  
  public var privateChildManagedContext : NSManagedObjectContext {
    return self.coreDataManager.privateChildManagedObjectContext()
  }
  
  public func saveChanges(notifyCloudKit:Bool=true) {
    self.coreDataManager.saveChanges(notifyChangesToCloudKit:notifyCloudKit)
  }
  
  public func getUserList() -> [TresorUser]? {
    guard !self.userListInited else { return self.userList }
    
    do {
      self.userList = try self.mainManagedContext.fetch(TresorUser.fetchRequest())
    
      self.userListInited = true
    } catch {
      celeturKitLogger.error("Error while create objects...",error:error)
    }
  
    return self.userList
  }
  
  
  public func createDummyUsers() {
    do {
      var newUser = TresorUser.createUser(context: self.mainManagedContext, firstName: "Hugo",lastName: "Müller",appleid: "bla@fasel.de")
      
      TresorUserDevice.createUserDevice(context: self.mainManagedContext, user: newUser, deviceName: "Hugos iPhone")
      TresorUserDevice.createUserDevice(context: self.mainManagedContext, user: newUser, deviceName: "Hugos iPad")
      TresorUserDevice.createUserDevice(context: self.mainManagedContext, user: newUser, deviceName: "Hugos iWatch")
      
      newUser = TresorUser.createUser(context: self.mainManagedContext, firstName: "Manfred",lastName: "Schmid",appleid: "mane@gmx.de")
      
      TresorUserDevice.createUserDevice(context: self.mainManagedContext, user: newUser, deviceName: "Manfreds iPhone")
      TresorUserDevice.createUserDevice(context: self.mainManagedContext, user: newUser, deviceName: "Manfreds iPad")
      TresorUserDevice.createUserDevice(context: self.mainManagedContext, user: newUser, deviceName: "Manfreds iWatch")
      TresorUserDevice.createUserDevice(context: self.mainManagedContext, user: newUser, deviceName: "Manfreds iTV")
      
      self.saveChanges()
      
      self.userList = try self.mainManagedContext.fetch(TresorUser.fetchRequest())
    } catch {
      celeturKitLogger.error("Error while create objects...",error:error)
    }
  }
  
  public func getCurrentUserDevice() -> TresorUserDevice? {
    var result:TresorUserDevice? = nil
    
    if let userList = self.getUserList() {
      result = TresorUserDevice.getCurrentUserDevice(userList: userList)
    }
    
    return result
  }
  
  var currentUserGivenName:String?
  var currentUserFamilyName:String?
  var currentUserEMailAddress:String?
  var currentUserDisplayName:String?
  var currentUserRecordID:String?
  var currentAPNToken:String?
  
  public func updateAPNToken(deviceToken: Data) {
    self.currentAPNToken = deviceToken.hexEncodedString()
    
    self.createCurrentUserInfo()
  }
  
  public func updateUserIdentityInfo(userIdentity:CKUserIdentity) {
    if let u = userIdentity.nameComponents,let li = userIdentity.lookupInfo {
      let formatter = PersonNameComponentsFormatter()
      
      formatter.style = PersonNameComponentsFormatter.Style.long
      
      self.currentUserDisplayName = formatter.string(from: u)
      self.currentUserGivenName = u.givenName
      self.currentUserFamilyName = u.familyName
      self.currentUserEMailAddress = li.emailAddress
      self.currentUserRecordID = li.userRecordID?.recordName
      
      if self.currentUserEMailAddress == nil {
        self.currentUserEMailAddress = "bla@me.com"
      }
      
      celeturKitLogger.debug("  LoggedIn Cloud User DisplayName:\(self.currentUserDisplayName ?? "-")")
      celeturKitLogger.debug("                     userRecordID:\(self.currentUserRecordID ?? "-" )")
      
      self.createCurrentUserInfo()
    }
  }
  
  func isCurrentDeviceKnown() -> Bool {
    if let ul = self.userList {
      for u in ul {
        if let udlist = u.userdevices {
          for ud in udlist {
            if let ud0 = ud as? TresorUserDevice {
              if let apndt = ud0.apndevicetoken {
                if apndt == self.currentAPNToken {
                  return true
                }
              }
            }
          }
        }
      }
    }
    
    return false
  }
  
  func createCurrentUserInfo() {
    if self.isCurrentDeviceKnown() {
      return
    }
    
    if let apntoken = self.currentAPNToken,
      let fn = self.currentUserGivenName,
      let ln = self.currentUserFamilyName,
      let aid = self.currentUserEMailAddress {
      let tempMOC = self.privateChildManagedContext
      
      let u = TresorUser.createUser(context: tempMOC, firstName: fn, lastName: ln, appleid: aid)
      let _ = TresorUserDevice.createCurrentUserDevice(context: tempMOC,user: u, apndeviceToken: apntoken)
      
      tempMOC.perform {
        do {
          try tempMOC.save()
          
          self.coreDataManager.saveChanges(notifyChangesToCloudKit: true)
        } catch {
          celeturKitLogger.error("Error saving contacts",error:error)
        }
      }
    }
  }
  
  public func saveTresorUsersUsingContacts(contacts:[CNContact], completion: @escaping (_ inner:() throws -> [TresorUser]) -> Void) {
    let tempMOC = self.privateChildManagedContext
    let users = contacts.map { TresorUser.createTempUser(context: tempMOC,contact: $0) }
    
    tempMOC.perform {
      do {
        try tempMOC.save()
        
        self.coreDataManager.saveChanges(notifyChangesToCloudKit: true)
        
        completion( {return users} )
      } catch {
        celeturKitLogger.error("Error saving contacts",error:error)
        
        completion( {throw error} )
      }
    }
  }
  
  public func deleteTresorUser(user:TresorUser, completion: @escaping (_ inner:() throws -> Void) -> Void) {
    let _ = user.id!
    
    self.mainManagedContext.delete(user)
    
    self.coreDataManager.saveChanges(notifyChangesToCloudKit: true)
  }
  
  public func createTresorDocument(tresor:Tresor, plainText: String, masterKey: TresorKey?) throws -> TresorDocument {
    let newTresorDocument = try TresorDocument.createTresorDocument(context: self.mainManagedContext, tresor: tresor)
    
    for ud in tresor.userdevices! {
      let userdevice = ud as! TresorUserDevice
      
      let item = try self.createTresorDocumentItem(tresorDocument: newTresorDocument,
                                                   plainText: plainText,
                                                   userDevice: userdevice,
                                                   masterKey: masterKey!)
      
      newTresorDocument.addToDocumentitems(item)
      userdevice.addToDocumentitems(item)
    }
    
    self.saveChanges()
    
    return newTresorDocument
  }
  
  public func deleteTresor(context:NSManagedObjectContext, tresor:Tresor) {
    if let docs = tresor.documents {
      for doc in docs {
        if let o = doc as? TresorDocument {
          self.deleteTresorDocument(context: context, tresorDocument: o)
        }
      }
    }
    
    context.delete(tresor)
  }
  
  public func deleteTresorDocument(context:NSManagedObjectContext, tresorDocument:TresorDocument) {
    if let docItems = tresorDocument.documentitems {
      for item in docItems {
        if let o = item as? NSManagedObject {
          context.delete(o)
        }
      }
    }
    
    context.delete(tresorDocument)
  }
  
 
  
  public func encryptAndSaveTresorDocumentItem(tempManagedContext: NSManagedObjectContext,
                                               masterKey:TresorKey,
                                               tresorDocumentItem:TresorDocumentItem,
                                               payload: Any) {
    
    do {
      let tdi = tempManagedContext.object(with: tresorDocumentItem.objectID) as! TresorDocumentItem
      
      tdi.status = "pending"
      try tempManagedContext.save()
      
      let payload = try JSONSerialization.data( withJSONObject: payload, options: [])
      let key = masterKey.accessToken
      let operation = AES256EncryptionOperation(key:key!, inputData: payload, iv:nil)
      try operation.createRandomIV()
      
      operation.start()
      
      if operation.isFinished {
        tdi.status = "encrypted"
        tdi.type = "main"
        tdi.mimetype = "application/json"
        tdi.payload = operation.outputData
        tdi.nonce = operation.iv
      } else {
        tdi.status = "failed"
      }
      tdi.changets = Date()
      
      try tempManagedContext.save()
    } catch {
      celeturKitLogger.error("Error while encryption payload from edit dialogue",error:error)
    }
  }
  
  // "{ \"title\": \"gmx.de\",\"user\":\"bla@fasel.de\",\"password\":\"hugo\"}"
  
  public func createTresorDocumentItem(tresorDocument:TresorDocument,
                                       plainText: String,
                                       userDevice:TresorUserDevice,
                                       masterKey:TresorKey) throws -> TresorDocumentItem {
    let newTresorDocumentItem = TresorDocumentItem.createPendingTresorDocumentItem(context:self.mainManagedContext,
                                                                                   tresorDocument: tresorDocument,
                                                                                   userDevice:userDevice)
    
    tresorDocument.addToDocumentitems(newTresorDocumentItem)
    userDevice.addToDocumentitems(newTresorDocumentItem)
    
    do {
      let key = masterKey.accessToken!
      let operation = AES256EncryptionOperation(key:key,inputString: plainText, iv:nil)
      try operation.createRandomIV()
      
      operation.completionBlock = {
        DispatchQueue.main.async {
          newTresorDocumentItem.type = "main"
          newTresorDocumentItem.mimetype = "application/json"
          newTresorDocumentItem.status = "encrypted"
          newTresorDocumentItem.payload = operation.outputData
          newTresorDocumentItem.nonce = operation.iv
          
          self.saveChanges()
          
          celeturKitLogger.debug("plain:\(plainText) key:\(key) encryptedText:\(String(describing: operation.outputData?.hexEncodedString()))")
        }
      }
      
      self.cipherQueue.addOperation(operation)
    } catch {
      celeturKitLogger.error("Error while saving tresordocumentitem", error: error)
    }
    
    return newTresorDocumentItem
  }
  
  public func decryptTresorDocumentItemPayload(tresorDocumentItem:TresorDocumentItem,
                                               masterKey:TresorKey,
                                               completion: ((SymmetricCipherOperation?)->Void)?) {
    var result : SymmetricCipherOperation?
    
    if let payload = tresorDocumentItem.payload, let nonce = tresorDocumentItem.nonce {
      let operation = AES256DecryptionOperation(key:masterKey.accessToken!,inputData: payload, iv:nonce)
      
      result = operation
      
      if let c = completion {
        result!.completionBlock = {
          c(result)
        }
      }
      
      self.cipherQueue.addOperation(result!)
    } else {
      if let c = completion {
        c(nil)
      }
    }
  }
  
  public func createAndFetchTresorFetchedResultsController() throws -> NSFetchedResultsController<Tresor> {
    return try Tresor.createAndFetchTresorFetchedResultsController(context: self.mainManagedContext)
  }
  
  
  public func createAndFetchUserFetchedResultsController() throws -> NSFetchedResultsController<TresorUser> {
    return try TresorUser.createAndFetchUserFetchedResultsController(context: self.mainManagedContext)
  }
  
  public func createAndFetchUserdeviceFetchedResultsController() throws -> NSFetchedResultsController<TresorUserDevice> {
    return try TresorUserDevice.createAndFetchUserdeviceFetchedResultsController(context: self.mainManagedContext)
  }
  
  
  public func createAndFetchTresorDocumentItemFetchedResultsController(tresor:Tresor?) throws -> NSFetchedResultsController<TresorDocumentItem> {
    return try TresorDocumentItem.createAndFetchTresorDocumentItemFetchedResultsController(context: self.mainManagedContext, tresor: tresor)
  }
  
  public func fetchChanges(in databaseScope: CKDatabaseScope, completion: @escaping () -> Void) {
    self.cloudKitManager.fetchChanges(in: databaseScope, completion: completion)
  }
  
  public func isObjectChanged(o:NSManagedObject) -> Bool {
    return self.cloudKitPersistenceState.isObjectChanged(o:o)
  }
  
  public func isObjectDeleted(o:NSManagedObject) -> Bool {
    return self.cloudKitPersistenceState.isObjectDeleted(o:o)
  }
  
  public func deleteObject(o:NSManagedObject) {
    self.cloudKitPersistenceState.addDeletedObject(o: o)
  }
  
  public func resetChangeTokens() {
    self.cloudKitPersistenceState.flushChangedIds()
    self.cloudKitPersistenceState.flushServerChangeTokens()
  }
  
  public func removeAllCloudKitData() {
    self.cloudKitManager.deleteAllRecordsForZone()
  }
  
  public func removeAllCoreData() {
    let tempMoc = self.coreDataManager.privateChildManagedObjectContext()
    
    do {
      self.coreDataManager.removeAllEntities(context: tempMoc, entityName: "TresorDocumentItem")
      self.coreDataManager.removeAllEntities(context: tempMoc, entityName: "TresorDocument")
      self.coreDataManager.removeAllEntities(context: tempMoc, entityName: "Tresor")
      self.coreDataManager.removeAllEntities(context: tempMoc, entityName: "TresorUserDevice")
      self.coreDataManager.removeAllEntities(context: tempMoc, entityName: "TresorUser")
      
      try tempMoc.save()
      
      self.saveChanges(notifyCloudKit: false)
    } catch {
      celeturKitLogger.error("Error delete all entities",error:error)
    }
  }
  
  public func resetAll() {
    self.resetChangeTokens()
    self.removeAllCloudKitData()
    self.removeAllCoreData()
  }
  
}
