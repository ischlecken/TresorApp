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
    return CloudKitManager(tresorModel: self, appGroupContainer: appGroup)
  } ()
  
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
    }
  }
  
  
  public var mainManagedContext : NSManagedObjectContext {
    return self.coreDataManager.mainManagedObjectContext
  }
  
  
  public var privateChildManagedContext : NSManagedObjectContext {
    return self.coreDataManager.privateChildManagedObjectContext()
  }
  
  public func getUserList() -> [TresorUser]? {
    guard !self.userListInited else { return self.userList }
    
    self.userListInited = true
    
    do {
      self.userList = try self.mainManagedContext.fetch(TresorUser.fetchRequest())
      
      if userList == nil || userList!.count == 0 {
        var newUser = TresorUser.createUser(context: self.mainManagedContext, firstName: "Hugo",lastName: "Müller",appleid: "bla@fasel.de")
        
        TresorUserDevice.createCurrentUserDevice(context: self.mainManagedContext, user: newUser)
        TresorUserDevice.createUserDevice(context: self.mainManagedContext, user: newUser, deviceName: "Hugos iPhone")
        TresorUserDevice.createUserDevice(context: self.mainManagedContext, user: newUser, deviceName: "Hugos iPad")
        TresorUserDevice.createUserDevice(context: self.mainManagedContext, user: newUser, deviceName: "Hugos iWatch")
        
        self.userList?.append(newUser)
        
        newUser = TresorUser.createUser(context: self.mainManagedContext, firstName: "Manfred",lastName: "Schmid",appleid: "mane@gmx.de")
        
        TresorUserDevice.createUserDevice(context: self.mainManagedContext, user: newUser, deviceName: "Manfreds iPhone")
        TresorUserDevice.createUserDevice(context: self.mainManagedContext, user: newUser, deviceName: "Manfreds iPad")
        TresorUserDevice.createUserDevice(context: self.mainManagedContext, user: newUser, deviceName: "Manfreds iWatch")
        TresorUserDevice.createUserDevice(context: self.mainManagedContext, user: newUser, deviceName: "Manfreds iTV")
        
        self.userList?.append(newUser)
      }
    } catch {
      celeturKitLogger.error("Error while create objects...",error:error)
    }
  
    return self.userList
  }
  
  
  
  public func getCurrentUserDevice() -> TresorUserDevice? {
    var result:TresorUserDevice? = nil
    
    if let userList = self.getUserList() {
      result = TresorUserDevice.getCurrentUserDevice(userList: userList)
    }
    
    return result
  }
  
  public func saveTresorUsersUsingContacts(contacts:[CNContact], completion: @escaping (_ inner:() throws -> [TresorUser]) -> Void) {
    let tempMOC = self.privateChildManagedContext
    let users = contacts.map { TresorUser.createTempUser(context: tempMOC,contact: $0) }
    
    tempMOC.perform {
      do {
        try tempMOC.save()
        
        completion( {return users} )
        
        /*
        let modifyOperation = self.saveTresorUsersToCloudKit(tresorUsers: users)
        modifyOperation.completionBlock = {
          celeturKitLogger.debug("modify finished")
        }
        modifyOperation.modifyRecordsCompletionBlock = { savedRecords, deletedRecordIDs, error in
          if let e = error {
            celeturKitLogger.error("Error while saving users in cloudkit", error: e)
            completion( {throw e} )
          } else {
            completion( {return users} )
          }
        }
        
        self.privateDB.add(modifyOperation)
 */
      } catch {
        celeturKitLogger.error("Error saving contacts",error:error)
        
        completion( {throw error} )
      }
    }
  }
  
  public func deleteTresorUser(user:TresorUser, completion: @escaping (_ inner:() throws -> Void) -> Void) {
    let _ = user.id!
    
    self.mainManagedContext.delete(user)
    
    /*
     do {
      try self.managedContext.save()
      
      completion( {} )
      
      let modifyOperation = self.deleteTresorUserFromCloudKit(tresorUserId: userId)
      
      modifyOperation.modifyRecordsCompletionBlock = {savedRecords, deletedRecordIDs, error in
        if let e = error {
          celeturKitLogger.error("Error while deleting tresor user from cloudkit", error: e)
          completion( {throw e} )
        } else {
          completion( {} )
        }
      }
      
      self.privateDB.add(modifyOperation)
 
    } catch {
      celeturKitLogger.error("Error while deleting TresorUser", error: error)
      
      completion( {throw error} )
    }
 */
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
    
    return newTresorDocument
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
}
