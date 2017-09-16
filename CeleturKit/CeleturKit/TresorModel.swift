//
//  Created by Feldmaus on 06.08.17.
//  Copyright © 2017 prisnoc. All rights reserved.
//

import Foundation
import Contacts
import CloudKit

public class TresorModel {
  
  let cdm : CoreDataManager
  let cipherQueue = OperationQueue()
  
  fileprivate var userList : [TresorUser]?
  fileprivate var userListInited = false
  
  public func getUserList() -> [TresorUser]? {
    guard !self.userListInited else { return self.userList }
    
    self.userListInited = true
    
    do {
      self.userList = try self.cdm.mainManagedObjectContext.fetch(TresorUser.fetchRequest())
      
      if userList == nil || userList!.count == 0 {
        var newUser = TresorUser.createUser(context: self.cdm.mainManagedObjectContext, firstName: "Hugo",lastName: "Müller",appleid: "bla@fasel.de")
        
        TresorUserDevice.createCurrentUserDevice(context: self.cdm.mainManagedObjectContext, user: newUser)
        TresorUserDevice.createUserDevice(context: self.cdm.mainManagedObjectContext, user: newUser, deviceName: "Hugos iPhone")
        TresorUserDevice.createUserDevice(context: self.cdm.mainManagedObjectContext, user: newUser, deviceName: "Hugos iPad")
        TresorUserDevice.createUserDevice(context: self.cdm.mainManagedObjectContext, user: newUser, deviceName: "Hugos iWatch")
        
        self.userList?.append(newUser)
        
        newUser = TresorUser.createUser(context: self.cdm.mainManagedObjectContext, firstName: "Manfred",lastName: "Schmid",appleid: "mane@gmx.de")
        
        TresorUserDevice.createUserDevice(context: self.cdm.mainManagedObjectContext, user: newUser, deviceName: "Manfreds iPhone")
        TresorUserDevice.createUserDevice(context: self.cdm.mainManagedObjectContext, user: newUser, deviceName: "Manfreds iPad")
        TresorUserDevice.createUserDevice(context: self.cdm.mainManagedObjectContext, user: newUser, deviceName: "Manfreds iWatch")
        TresorUserDevice.createUserDevice(context: self.cdm.mainManagedObjectContext, user: newUser, deviceName: "Manfreds iTV")
        
        self.userList?.append(newUser)
      }
    } catch {
      celeturKitLogger.error("Error while create objects...",error:error)
    }
  
    return self.userList
  }
  
  public init(_ coreDataManager:CoreDataManager) {
    self.cdm = coreDataManager
  }
  
  public var managedContext : NSManagedObjectContext {
    return self.cdm.mainManagedObjectContext
  }
  
  public func getCurrentUserDevice() -> TresorUserDevice? {
    var result:TresorUserDevice? = nil
    
    let vendorDeviceId = UIDevice.current.identifierForVendor?.uuidString
    let _ = self.getUserList()
    
    for u in self.userList! {
      for ud in u.userdevices! {
        let userDevice = ud as! TresorUserDevice
        
        if let udi = userDevice.id, let vdi = vendorDeviceId, udi == vdi {
          result = userDevice
          break;
        }
      }
      
      if result != nil {
        break
      }
    }
    
    return result
  }
  
  
  func getTresorUser(withId id:String, tempMOC:NSManagedObjectContext) -> TresorUser? {
    var result : TresorUser?
    
    let fetchRequest: NSFetchRequest<TresorUser> = TresorUser.fetchRequest()
    
    // Set the batch size to a suitable number.
    fetchRequest.fetchBatchSize = 1
    fetchRequest.predicate = NSPredicate(format: "id = %@", id)
    
    do {
      let records = try tempMOC.fetch(fetchRequest)
      
      if records.count>0 {
        result = records[0]
      }
    } catch {
      celeturKitLogger.error("Error while fetching tresoruser",error:error)
    }
    
    return result
  }
  
  public func createTempTresor(tempManagedContext: NSManagedObjectContext) throws -> Tresor {
    let newTresor = Tresor(context: tempManagedContext)
    newTresor.createts = Date()
    newTresor.id = String.uuid()
    newTresor.nonce = try Data(withRandomData: SymmetricCipherAlgorithm.aes_256.requiredBlockSize())
    
    return newTresor
  }
  
  public func createTempUser(tempManagedContext: NSManagedObjectContext, contact: CNContact) -> TresorUser {
    let result = TresorUser(context:tempManagedContext)
    
    result.createts = Date()
    result.id = String.uuid()
    
    result.firstname = contact.givenName
    result.lastname = contact.familyName
    result.email = contact.emailAddresses.first?.value as String?
    result.profilepicture = contact.imageData
    
    return result
  }
  
  public func saveTresorUsersUsingContacts(contacts:[CNContact], completion: @escaping (_ inner:() throws -> [TresorUser]) -> Void) {
    let tempMOC = self.createScratchPadContext()
    let users = contacts.map { self.createTempUser(tempManagedContext: tempMOC,contact: $0) }
    
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
    
    self.cdm.mainManagedObjectContext.delete(user)
    
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
  
  public func createTresorDocument(tresor:Tresor,masterKey: TresorKey?) throws -> TresorDocument {
    let newTresorDocument = TresorDocument(context: self.cdm.mainManagedObjectContext)
    newTresorDocument.createts = Date()
    newTresorDocument.id = String.uuid()
    newTresorDocument.tresor = tresor
    newTresorDocument.nonce = try Data(withRandomData:SymmetricCipherAlgorithm.aes_256.requiredBlockSize())
    
    for ud in tresor.userdevices! {
      let userdevice = ud as! TresorUserDevice
      
      let item = try self.createTresorDocumentItem(tresorDocument: newTresorDocument,userDevice: userdevice,masterKey: masterKey!)
      
      newTresorDocument.addToDocumentitems(item)
      userdevice.addToDocumentitems(item)
    }
    
    return newTresorDocument
  }
  
  public func createScratchPadContext() -> NSManagedObjectContext {
    return self.cdm.privateChildManagedObjectContext()
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
      tdi.createts = Date()
      
      try tempManagedContext.save()
    } catch {
      celeturKitLogger.error("Error while encryption payload from edit dialogue",error:error)
    }
  }
  
  public func createTresorDocumentItem(tresorDocument:TresorDocument, userDevice:TresorUserDevice, masterKey:TresorKey) throws -> TresorDocumentItem {
    let newTresorDocumentItem = TresorDocumentItem.createPendingTresorDocumentItem(context:self.cdm.mainManagedObjectContext,
                                                                                   tresorDocument: tresorDocument,
                                                                                   userDevice:userDevice)
    
    tresorDocument.addToDocumentitems(newTresorDocumentItem)
    userDevice.addToDocumentitems(newTresorDocumentItem)
    
    do {
      let key = masterKey.accessToken!
      let plainText = "{ \"title\": \"gmx.de\",\"user\":\"bla@fasel.de\",\"password\":\"hugo\"}"
      
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
  
  public func decryptTresorDocumentItemPayload(tresorDocumentItem:TresorDocumentItem,masterKey:TresorKey) -> SymmetricCipherOperation? {
    var result : SymmetricCipherOperation?
    
    if let payload = tresorDocumentItem.payload, let nonce = tresorDocumentItem.nonce {
      let operation = AES256DecryptionOperation(key:masterKey.accessToken!,inputData: payload, iv:nonce)
      
      result = operation
    }
    
    return result
  }
  
  public func addToCipherQueue(_ op:Operation) {
    self.cipherQueue.addOperation(op)
  }
  
  
  public func createAndFetchTresorFetchedResultsController() throws -> NSFetchedResultsController<Tresor> {
    let fetchRequest: NSFetchRequest<Tresor> = Tresor.fetchRequest()
    
    // Set the batch size to a suitable number.
    fetchRequest.fetchBatchSize = 20
    
    // Edit the sort key as appropriate.
    let sortDescriptor = NSSortDescriptor(key: "createts", ascending: false)
    
    fetchRequest.sortDescriptors = [sortDescriptor]
    
    let aFetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: self.cdm.mainManagedObjectContext, sectionNameKeyPath: nil, cacheName: nil)
    
    do {
      try aFetchedResultsController.performFetch()
    } catch {
      throw CeleturKitError.creationOfFetchResultsControllerFailed(coreDataError: error as NSError)
    }
    
    return aFetchedResultsController
  }
  
  
  public func createAndFetchUserFetchedResultsController() throws -> NSFetchedResultsController<TresorUser> {
    let fetchRequest: NSFetchRequest<TresorUser> = TresorUser.fetchRequest()
    
    // Set the batch size to a suitable number.
    fetchRequest.fetchBatchSize = 20
    
    // Edit the sort key as appropriate.
    let sortDescriptor = NSSortDescriptor(key: "createts", ascending: false)
    
    fetchRequest.sortDescriptors = [sortDescriptor]
    
    let aFetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: self.cdm.mainManagedObjectContext, sectionNameKeyPath: nil, cacheName: nil)
    
    do {
      try aFetchedResultsController.performFetch()
    } catch {
      throw CeleturKitError.creationOfFetchResultsControllerFailed(coreDataError: error as NSError)
    }
    
    return aFetchedResultsController
  }
  
  public func createAndFetchUserdeviceFetchedResultsController() throws -> NSFetchedResultsController<TresorUserDevice> {
    let fetchRequest: NSFetchRequest<TresorUserDevice> = TresorUserDevice.fetchRequest()
    
    // Set the batch size to a suitable number.
    fetchRequest.fetchBatchSize = 20
    
    // Edit the sort key as appropriate.
    let sortDescriptor = NSSortDescriptor(key: "createts", ascending: false)
    
    fetchRequest.sortDescriptors = [sortDescriptor]
    
    let aFetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: self.cdm.mainManagedObjectContext, sectionNameKeyPath: "user.email", cacheName: nil)
    
    do {
      try aFetchedResultsController.performFetch()
    } catch {
      throw CeleturKitError.creationOfFetchResultsControllerFailed(coreDataError: error as NSError)
    }
    
    return aFetchedResultsController
  }
  
  
  public func createAndFetchTresorDocumentItemFetchedResultsController(tresor:Tresor?) throws -> NSFetchedResultsController<TresorDocumentItem> {
    let fetchRequest: NSFetchRequest<TresorDocumentItem> = TresorDocumentItem.fetchRequest()
    
    // Set the batch size to a suitable number.
    fetchRequest.fetchBatchSize = 20
    fetchRequest.predicate = NSPredicate(format: "document.tresor.id = %@", (tresor?.id)!)
    
    
    // Edit the sort key as appropriate.
    let sortDescriptor = NSSortDescriptor(key: "createts", ascending: false)
    
    fetchRequest.sortDescriptors = [sortDescriptor]
    
    let aFetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: self.cdm.mainManagedObjectContext, sectionNameKeyPath: "document.id", cacheName: nil)
    
    do {
      try aFetchedResultsController.performFetch()
    } catch {
      throw CeleturKitError.creationOfFetchResultsControllerFailed(coreDataError: error as NSError)
    }
    
    return aFetchedResultsController
  }
}
