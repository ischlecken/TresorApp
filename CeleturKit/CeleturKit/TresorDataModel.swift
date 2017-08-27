//
//  Created by Feldmaus on 06.08.17.
//  Copyright © 2017 prisnoc. All rights reserved.
//

import Foundation
import Contacts

public class TresorDataModel {
  
  let managedContext : NSManagedObjectContext
  let cipherQueue = OperationQueue()
  
  public var userList : [User]?
  
  public init(_ coreDataStack:CoreDataStack) {
    self.managedContext = coreDataStack.context
    
    self.initObjects()
  }
  
  public func getMOC() -> NSManagedObjectContext {
    return self.managedContext
  }
  
  public func getCurrentUserDevice() -> UserDevice? {
    var result:UserDevice? = nil
    
    let vendorDeviceId = UIDevice.current.identifierForVendor?.uuidString
    for u in self.userList! {
      for ud in u.userdevices! {
        let userDevice = ud as! UserDevice
        
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
  
  fileprivate func createUserDevice(user:User, deviceName:String) {
    let newUserDevice = UserDevice(context:self.managedContext)
    newUserDevice.createts = Date()
    newUserDevice.devicename = deviceName
    newUserDevice.id = String.uuid()
    newUserDevice.apndevicetoken = String.uuid()
    newUserDevice.user = user
    user.addToUserdevices(newUserDevice)
  }
  
  fileprivate func createCurrentUserDevice(user:User) {
    let newUserDevice = UserDevice(context:self.managedContext)
    newUserDevice.createts = Date()
    newUserDevice.devicename = UIDevice.current.name
    newUserDevice.id = UIDevice.current.identifierForVendor?.uuidString
    newUserDevice.apndevicetoken = String.uuid()
    newUserDevice.user = user
    user.addToUserdevices(newUserDevice)
  }
  
  fileprivate func createUser(firstName:String, lastName: String, appleid: String) -> User {
    let newUser = User(context: self.managedContext)
    newUser.firstname = firstName
    newUser.lastname = lastName
    newUser.email = appleid
    newUser.createts = Date()
    newUser.id = String.uuid()
    
    return newUser
  }
  
  func initObjects() {
    do {
      self.userList = try self.managedContext.fetch(User.fetchRequest())
      
      if self.userList == nil || self.userList!.count == 0 {
        var newUser = createUser(firstName: "Hugo",lastName: "Müller",appleid: "bla@fasel.de")
        
        self.createCurrentUserDevice(user: newUser)
        self.createUserDevice(user: newUser, deviceName: "Hugos iPhone")
        self.createUserDevice(user: newUser, deviceName: "Hugos iPad")
        self.createUserDevice(user: newUser, deviceName: "Hugos iWatch")
        
        self.userList?.append(newUser)
        
        newUser = createUser(firstName: "Manfred",lastName: "Schmid",appleid: "mane@gmx.de")
        
        self.createUserDevice(user: newUser, deviceName: "Manfreds iPhone")
        self.createUserDevice(user: newUser, deviceName: "Manfreds iPad")
        self.createUserDevice(user: newUser, deviceName: "Manfreds iWatch")
        self.createUserDevice(user: newUser, deviceName: "Manfreds iTV")
        
        self.userList?.append(newUser)
        
        try self.saveContext()
      }
    } catch {
      celeturKitLogger.error("Error while create objects...",error:error)
    }
  }
  
  public func createTempTresor(tempManagedContext: NSManagedObjectContext) throws -> Tresor {
    let newTresor = Tresor(context: tempManagedContext)
    newTresor.createts = Date()
    newTresor.id = String.uuid()
    newTresor.nonce = try Data(withRandomData: SymmetricCipherAlgorithm.aes_256.requiredBlockSize())
    
    return newTresor
  }
  
  public func createTempUser(tempManagedContext: NSManagedObjectContext, contact: CNContact) -> User {
    let result = User(context:tempManagedContext)
    
    result.createts = Date()
    result.id = String.uuid()
    
    result.firstname = contact.givenName
    result.lastname = contact.familyName
    result.email = contact.emailAddresses.first!.value as String
    result.profilepicture = contact.imageData
    
    return result
  }
  
  public func saveContacts(contacts:[CNContact]) {
    let tempMOC = self.createScratchPadContext()
    let _ = contacts.map { self.createTempUser(tempManagedContext: tempMOC,contact: $0) }
    
    tempMOC.perform {
      do {
        try tempMOC.save()
        
        self.saveContextInMainThread()
        
      } catch {
        celeturKitLogger.error("Error saving contacts",error:error)
      }
    }
  }
  
  public func createTresorDocument(tresor:Tresor,masterKey: TresorKey?) throws -> TresorDocument {
    let newTresorDocument = TresorDocument(context: self.managedContext)
    newTresorDocument.createts = Date()
    newTresorDocument.id = String.uuid()
    newTresorDocument.tresor = tresor
    newTresorDocument.nonce = try Data(withRandomData:SymmetricCipherAlgorithm.aes_256.requiredBlockSize())
    
    for ud in tresor.userdevices! {
      let userdevice = ud as! UserDevice
      
      let item = try self.createTresorDocumentItem(tresorDocument: newTresorDocument,userDevice: userdevice,masterKey: masterKey!)
      
      newTresorDocument.addToDocumentitems(item)
      userdevice.addToDocumentitems(item)
    }
    
    return newTresorDocument
  }
  
  fileprivate func createPendingTresorDocumentItem(tresorDocument:TresorDocument,userDevice:UserDevice) -> TresorDocumentItem {
    let result = TresorDocumentItem(context: self.managedContext)
    
    result.createts = Date()
    result.id = String.uuid()
    result.status = "pending"
    result.document = tresorDocument
    result.userdevice = userDevice
    
    return result
  }
  
  public func createScratchPadContext() -> NSManagedObjectContext {
    let tempManagedContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
    tempManagedContext.parent = self.managedContext
    
    return tempManagedContext
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
      
      DispatchQueue.main.async {
        if self.managedContext.hasChanges {
          do {
            try self.managedContext.save()
          } catch {
            celeturKitLogger.error("Error saving in main context",error:error)
          }
        }
      }
    } catch {
      celeturKitLogger.error("Error while encryption payload from edit dialogue",error:error)
    }
  }
  
  public func createTresorDocumentItem(tresorDocument:TresorDocument, userDevice:UserDevice, masterKey:TresorKey) throws -> TresorDocumentItem {
    let newTresorDocumentItem = self.createPendingTresorDocumentItem(tresorDocument: tresorDocument,userDevice:userDevice)
    
    tresorDocument.addToDocumentitems(newTresorDocumentItem)
    userDevice.addToDocumentitems(newTresorDocumentItem)
    
    do {
      try self.saveContext()
      
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
          
          do {
            try self.saveContext()
          } catch {
            celeturKitLogger.error("Error while saving tresordocumentitem", error: error)
          }
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
  
  public func saveContext() throws {
    do {
      if self.managedContext.hasChanges {
        try self.managedContext.save()
      }
    } catch {
      throw CeleturKitError.dataSaveFailed(coreDataError: error as NSError)
    }
  }
  
  
  public func saveContextInMainThread() {
    DispatchQueue.main.async {
      do {
        if self.managedContext.hasChanges {
          try self.managedContext.save()
        }
      } catch {
        celeturKitLogger.error("Error while saving tresor object",error:error)
      }
    }
    
  }
  
  public func createAndFetchTresorFetchedResultsController() throws -> NSFetchedResultsController<Tresor> {
    let fetchRequest: NSFetchRequest<Tresor> = Tresor.fetchRequest()
    
    // Set the batch size to a suitable number.
    fetchRequest.fetchBatchSize = 20
    
    // Edit the sort key as appropriate.
    let sortDescriptor = NSSortDescriptor(key: "createts", ascending: false)
    
    fetchRequest.sortDescriptors = [sortDescriptor]
    
    let aFetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: self.managedContext, sectionNameKeyPath: nil, cacheName: nil)
    
    do {
      try aFetchedResultsController.performFetch()
    } catch {
      throw CeleturKitError.creationOfFetchResultsControllerFailed(coreDataError: error as NSError)
    }
    
    return aFetchedResultsController
  }
  
  
  public func createAndFetchUserFetchedResultsController() throws -> NSFetchedResultsController<User> {
    let fetchRequest: NSFetchRequest<User> = User.fetchRequest()
    
    // Set the batch size to a suitable number.
    fetchRequest.fetchBatchSize = 20
    
    // Edit the sort key as appropriate.
    let sortDescriptor = NSSortDescriptor(key: "createts", ascending: false)
    
    fetchRequest.sortDescriptors = [sortDescriptor]
    
    let aFetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: self.managedContext, sectionNameKeyPath: nil, cacheName: nil)
    
    do {
      try aFetchedResultsController.performFetch()
    } catch {
      throw CeleturKitError.creationOfFetchResultsControllerFailed(coreDataError: error as NSError)
    }
    
    return aFetchedResultsController
  }
  
  public func createAndFetchUserdeviceFetchedResultsController() throws -> NSFetchedResultsController<UserDevice> {
    let fetchRequest: NSFetchRequest<UserDevice> = UserDevice.fetchRequest()
    
    // Set the batch size to a suitable number.
    fetchRequest.fetchBatchSize = 20
    
    // Edit the sort key as appropriate.
    let sortDescriptor = NSSortDescriptor(key: "createts", ascending: false)
    
    fetchRequest.sortDescriptors = [sortDescriptor]
    
    let aFetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: self.managedContext, sectionNameKeyPath: "user.email", cacheName: nil)
    
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
    
    let aFetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: self.managedContext, sectionNameKeyPath: "document.id", cacheName: nil)
    
    do {
      try aFetchedResultsController.performFetch()
    } catch {
      throw CeleturKitError.creationOfFetchResultsControllerFailed(coreDataError: error as NSError)
    }
    
    return aFetchedResultsController
  }
}
