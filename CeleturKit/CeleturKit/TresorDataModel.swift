//
//  TresorDataModel.swift
//  CeleturKit
//
//  Created by Feldmaus on 06.08.17.
//  Copyright © 2017 prisnoc. All rights reserved.
//

import Foundation

public class TresorDataModel {
  
  let managedContext : NSManagedObjectContext
  let cipherQueue = OperationQueue()
  var userList : [User]?
  
  public init(_ coreDataStack:CoreDataStack) {
    self.managedContext = coreDataStack.context
    
    self.initObjects()
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
  
  func initObjects() {
    do {
      let userFetchRequest: NSFetchRequest<User> = User.fetchRequest()
      
      self.userList = try self.managedContext.fetch(userFetchRequest)
      
      if self.userList == nil || self.userList!.count == 0 {
        var newUser = User(context: self.managedContext)
        newUser.abfirstname = "Hugo"
        newUser.ablastname = "Müller"
        newUser.appleid = "bla@fasel.de"
        newUser.abrecordid = 0
        newUser.createts = Date()
        newUser.id = String.uuid()
        
        self.createUserDevice(user: newUser, deviceName: "Hugos iPhone")
        self.createUserDevice(user: newUser, deviceName: "Hugos iPad")
        self.createUserDevice(user: newUser, deviceName: "Hugos iWatch")
        
        self.userList?.append(newUser)
        
        newUser = User(context: self.managedContext)
        newUser.abfirstname = "Manfred"
        newUser.ablastname = "Schmidt"
        newUser.appleid = "manne@gmx.de"
        newUser.abrecordid = 1
        newUser.createts = Date()
        newUser.id = String.uuid()
        
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
  
  public func createTresor(name:String, description:String?) throws -> Tresor {
    let newTresor = Tresor(context: self.managedContext)
    newTresor.createts = Date()
    newTresor.id = String.uuid()
    newTresor.name = name
    newTresor.tresordescription = description
    newTresor.nonce = try Data(withRandomData: SymmetricCipherAlgorithm.aes_256.requiredBlockSize())
    
    try self.saveContext()
    
    return newTresor
  }
  
  public func createTresorDocument(tresor:Tresor) throws -> TresorDocument {
    let newTresorDocument = TresorDocument(context: self.managedContext)
    newTresorDocument.createts = Date()
    newTresorDocument.id = String.uuid()
    newTresorDocument.tresor = tresor
    newTresorDocument.nonce = try Data(withRandomData:SymmetricCipherAlgorithm.aes_256.requiredBlockSize())
    
    try self.saveContext()
    
    return newTresorDocument
  }
  
  fileprivate func createPendingTresorDocumentItem(tresorDocument:TresorDocument) -> TresorDocumentItem {
    let result = TresorDocumentItem(context: self.managedContext)
    
    result.createts = Date()
    result.id = String.uuid()
    result.status = "pending"
    result.tresor = tresorDocument.tresor
    result.document = tresorDocument
    
    if self.userList != nil && self.userList!.count > 0 {
      let userDeviceList = self.userList![Int(arc4random()) % self.userList!.count].userdevices!.allObjects as! [UserDevice]
      let index = Int(arc4random()) % userDeviceList.count
      userDeviceList[index].addToDocumentitems(result)
    }
    
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
  
  public func createTresorDocumentItem(tresorDocument:TresorDocument, masterKey:TresorKey) throws {
    let newTresorDocumentItem = self.createPendingTresorDocumentItem(tresorDocument: tresorDocument)
    
    tresorDocument.tresor?.addToDocumentitems(newTresorDocumentItem)
    tresorDocument.addToDocumentitems(newTresorDocumentItem)
    
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
  
  public func flushFetchedResultsControllerCache() {
    
  }
  
  
  public func createAndFetchTresorDocumentItemFetchedResultsController(tresor:Tresor?) throws -> NSFetchedResultsController<TresorDocumentItem> {
    let fetchRequest: NSFetchRequest<TresorDocumentItem> = TresorDocumentItem.fetchRequest()
    
    // Set the batch size to a suitable number.
    fetchRequest.fetchBatchSize = 20
    fetchRequest.predicate = NSPredicate(format: "tresor.id = %@", (tresor?.id)!)
    
    
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
