//
//  TresorDataModel.swift
//  CeleturKit
//
//  Created by Feldmaus on 06.08.17.
//  Copyright © 2017 prisnoc. All rights reserved.
//

import Foundation

public class TresorDataModel {
  
  var managedContext : NSManagedObjectContext? = nil
  let cipherQueue = OperationQueue()
  var userList : [User]?
  
  public init(_ coreDataStack:CoreDataStack) {
    self.managedContext = coreDataStack.context
    
    self.initObjects()
  }
  
  func initObjects() {
    do {
      let userFetchRequest: NSFetchRequest<User> = User.fetchRequest()
      
      self.userList = try self.managedContext?.fetch(userFetchRequest)
      
      if self.userList == nil || self.userList!.count == 0 {
        var newUser = User(context: self.managedContext!)
        newUser.abfirstname = "Hugo"
        newUser.ablastname = "Müller"
        newUser.appleid = "bla@fasel.de"
        newUser.abrecordid = 0
        newUser.createts = Date()
        newUser.id = String.uuid()
        
        var newUserDevice = UserDevice(context:self.managedContext!)
        newUserDevice.createts = Date()
        newUserDevice.devicename = "Hugos iPhone"
        newUserDevice.id = String.uuid()
        newUserDevice.apndevicetoken = String.uuid()
        newUserDevice.userid = newUser
        newUser.addToUserdevices(newUserDevice)
        
        newUserDevice = UserDevice(context:self.managedContext!)
        newUserDevice.createts = Date()
        newUserDevice.devicename = "Hugos iPad"
        newUserDevice.id = String.uuid()
        newUserDevice.apndevicetoken = String.uuid()
        newUserDevice.userid = newUser
        newUser.addToUserdevices(newUserDevice)
        
        newUserDevice = UserDevice(context:self.managedContext!)
        newUserDevice.createts = Date()
        newUserDevice.devicename = "Hugos iWatch"
        newUserDevice.id = String.uuid()
        newUserDevice.apndevicetoken = String.uuid()
        newUserDevice.userid = newUser
        newUser.addToUserdevices(newUserDevice)
        
        self.userList?.append(newUser)
        
        newUser = User(context: self.managedContext!)
        newUser.abfirstname = "Manfred"
        newUser.ablastname = "Schmidt"
        newUser.appleid = "manne@gmx.de"
        newUser.abrecordid = 1
        newUser.createts = Date()
        newUser.id = String.uuid()
        
        newUserDevice = UserDevice(context:self.managedContext!)
        newUserDevice.createts = Date()
        newUserDevice.devicename = "Manfreds iPhone"
        newUserDevice.id = String.uuid()
        newUserDevice.apndevicetoken = String.uuid()
        newUserDevice.userid = newUser
        newUser.addToUserdevices(newUserDevice)
        
        newUserDevice = UserDevice(context:self.managedContext!)
        newUserDevice.createts = Date()
        newUserDevice.devicename = "Manfreds iPad"
        newUserDevice.id = String.uuid()
        newUserDevice.apndevicetoken = String.uuid()
        newUserDevice.userid = newUser
        newUser.addToUserdevices(newUserDevice)
        
        newUserDevice = UserDevice(context:self.managedContext!)
        newUserDevice.createts = Date()
        newUserDevice.devicename = "Manfreds iWatch"
        newUserDevice.id = String.uuid()
        newUserDevice.apndevicetoken = String.uuid()
        newUserDevice.userid = newUser
        newUser.addToUserdevices(newUserDevice)
        
        newUserDevice = UserDevice(context:self.managedContext!)
        newUserDevice.createts = Date()
        newUserDevice.devicename = "Manfreds iTV"
        newUserDevice.id = String.uuid()
        newUserDevice.apndevicetoken = String.uuid()
        newUserDevice.userid = newUser
        newUser.addToUserdevices(newUserDevice)
        
        self.userList?.append(newUser)
        
        try self.saveContext()
      }
    } catch {
      celeturKitLogger.error("Error while create objects...",error:error)
    }
  }
  
  public func createTresor(name:String, description:String?) throws -> Tresor {
    let newTresor = Tresor(context: self.managedContext!)
    newTresor.createts = Date()
    newTresor.id = String.uuid()
    newTresor.name = name
    newTresor.tresordescription = description
    newTresor.nonce = try Data(withRandomData: SymmetricCipherAlgorithm.aes_256.requiredBlockSize())
    
    try self.saveContext()
    
    return newTresor
  }
  
  public func createTresorDocument(tresor:Tresor) throws -> TresorDocument {
    let newTresorDocument = TresorDocument(context: self.managedContext!)
    newTresorDocument.createts = Date()
    newTresorDocument.id = String.uuid()
    newTresorDocument.tresorid = tresor
    newTresorDocument.nonce = try Data(withRandomData:SymmetricCipherAlgorithm.aes_256.requiredBlockSize())
    
    try self.saveContext()
    
    return newTresorDocument
  }
  
  public func createTresorDocumentItem(tresorDocument:TresorDocument,masterKey:TresorKey, onCompleted:(()->Void)? = nil) throws {
    let key = masterKey.accessToken
    let plainText = "{ 'title': 'gmx.de','user':'bla@fasel.de','password':'hugo'}"
    
    let operation = AES256EncryptionOperation(key:masterKey.accessToken!,inputString: plainText, iv:nil)
    try operation.createRandomIV()
    
    operation.mainQueueCompletionBlock = { (cipherOperation) in
      let newTresorDocumentItem = TresorDocumentItem(context: self.managedContext!)
      
      newTresorDocumentItem.createts = Date()
      newTresorDocumentItem.id = String.uuid()
      newTresorDocumentItem.type = "main"
      newTresorDocumentItem.mimetype = "application/json"
      newTresorDocumentItem.payload = cipherOperation.outputData
      newTresorDocumentItem.nonce = cipherOperation.iv
      
      if self.userList != nil && self.userList!.count > 0 {
        let userDeviceList = self.userList![Int(arc4random()) % self.userList!.count].userdevices!.allObjects as! [UserDevice]
        let index = Int(arc4random()) % userDeviceList.count
        print("userDeviceList.count:\(userDeviceList.count) index:\(index)")
        userDeviceList[index].addToDocumentitems(newTresorDocumentItem)
      }
      
      tresorDocument.addToItems(newTresorDocumentItem)
      
      celeturKitLogger.debug("plain:\(plainText) key:\(key!) encryptedText:\(String(describing: cipherOperation.outputData?.hexEncodedString()))")
      
      do {
        try self.saveContext()
        
        onCompleted?()
      } catch {
        celeturKitLogger.error("Error while saving tresordocumentitem", error: error)
      }
    }
    
    self.cipherQueue.addOperation(operation)
  }
  
  public func decryptTresorDocumentItemPayload(tresorDocumentItem:TresorDocumentItem,masterKey:TresorKey, completionBlock: SymmetricCipherCompletionType?) {
    let operation = AES256DecryptionOperation(key:masterKey.accessToken!,inputData: tresorDocumentItem.payload!, iv:tresorDocumentItem.nonce)
    
    if let c = completionBlock {
      operation.mainQueueCompletionBlock = c
    }
    
    self.cipherQueue.addOperation(operation)
  }
  
  public func saveContext() throws {
    do {
      try self.managedContext!.save()
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
    
    let aFetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: self.managedContext!, sectionNameKeyPath: nil, cacheName: "Tresor")
    
    do {
      try aFetchedResultsController.performFetch()
    } catch {
      throw CeleturKitError.creationOfFetchResultsControllerFailed(coreDataError: error as NSError)
    }
    
    return aFetchedResultsController
  }
  
  public func flushFetchedResultsControllerCache() {
    let cacheName = "Tresor"
    
    NSFetchedResultsController<NSFetchRequestResult>.deleteCache(withName: cacheName)
  }
  
}
