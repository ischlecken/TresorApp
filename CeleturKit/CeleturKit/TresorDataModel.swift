//
//  Created by Feldmaus on 06.08.17.
//  Copyright © 2017 prisnoc. All rights reserved.
//

import Foundation
import Contacts
import CloudKit

public class TresorDataModel {
  
  let managedContext : NSManagedObjectContext
  let cipherQueue = OperationQueue()
  let privateDB : CKDatabase
  let sharedDB : CKDatabase
  let createZoneGroup : DispatchGroup
  
  let tresorusersGroup = "Tresorusers"
  let tresoruserType = "Tresoruser"
  let privateSubscriptionId = "private-changes"
  let sharedSubscriptionId = "shared-changes"
  
  var privateDBChangeToken : CKServerChangeToken?
  var sharedDBChangeToken : CKServerChangeToken?
  var tresorusersChangeToken : CKServerChangeToken?
  
  public var userList : [TresorUser]?
  
  public init(_ coreDataStack:CoreDataStack) {
    self.managedContext = coreDataStack.context
    
    self.privateDB = CKContainer.default().privateCloudDatabase
    self.sharedDB = CKContainer.default().sharedCloudDatabase
    self.createZoneGroup = DispatchGroup()
    
    self.createZones(zoneName: tresorusersGroup)
    
    self.privateDBChangeToken = self.getCloudKitCKServerChangeToken(name: "private")
    self.sharedDBChangeToken = self.getCloudKitCKServerChangeToken(name: "shared")
    self.tresorusersChangeToken = self.getCloudKitCKServerChangeToken(name: tresorusersGroup)
    
    self.initObjects()
  }
  
  public func getMOC() -> NSManagedObjectContext {
    return self.managedContext
  }
  
  public func getCurrentUserDevice() -> TresorUserDevice? {
    var result:TresorUserDevice? = nil
    
    let vendorDeviceId = UIDevice.current.identifierForVendor?.uuidString
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
  
  fileprivate func createUserDevice(user:TresorUser, deviceName:String) {
    let newUserDevice = TresorUserDevice(context:self.managedContext)
    newUserDevice.createts = Date()
    newUserDevice.devicename = deviceName
    newUserDevice.id = String.uuid()
    newUserDevice.apndevicetoken = String.uuid()
    newUserDevice.user = user
    user.addToUserdevices(newUserDevice)
  }
  
  fileprivate func createCurrentUserDevice(user:TresorUser) {
    let newUserDevice = TresorUserDevice(context:self.managedContext)
    newUserDevice.createts = Date()
    newUserDevice.devicename = UIDevice.current.name
    newUserDevice.id = UIDevice.current.identifierForVendor?.uuidString
    newUserDevice.apndevicetoken = String.uuid()
    newUserDevice.user = user
    user.addToUserdevices(newUserDevice)
  }
  
  fileprivate func createUser(firstName:String, lastName: String, appleid: String) -> TresorUser {
    let newUser = TresorUser(context: self.managedContext)
    newUser.firstname = firstName
    newUser.lastname = lastName
    newUser.email = appleid
    newUser.createts = Date()
    newUser.id = String.uuid()
    
    return newUser
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
  
  func initObjects() {
    do {
      self.userList = try self.managedContext.fetch(TresorUser.fetchRequest())
      
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
        
        self.saveContextInMainThread()
        
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
      } catch {
        celeturKitLogger.error("Error saving contacts",error:error)
        
        completion( {throw error} )
      }
    }
  }
  
  public func deleteTresorUser(user:TresorUser, completion: @escaping (_ inner:() throws -> Void) -> Void) {
    let userId = user.id!
    
    self.managedContext.delete(user)
    
    do {
      try self.managedContext.save()
      
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
  }
  
  public func createTresorDocument(tresor:Tresor,masterKey: TresorKey?) throws -> TresorDocument {
    let newTresorDocument = TresorDocument(context: self.managedContext)
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
  
  fileprivate func createPendingTresorDocumentItem(tresorDocument:TresorDocument,userDevice:TresorUserDevice) -> TresorDocumentItem {
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
  
  public func createTresorDocumentItem(tresorDocument:TresorDocument, userDevice:TresorUserDevice, masterKey:TresorKey) throws -> TresorDocumentItem {
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
  
  
  public func createAndFetchUserFetchedResultsController() throws -> NSFetchedResultsController<TresorUser> {
    let fetchRequest: NSFetchRequest<TresorUser> = TresorUser.fetchRequest()
    
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
  
  public func createAndFetchUserdeviceFetchedResultsController() throws -> NSFetchedResultsController<TresorUserDevice> {
    let fetchRequest: NSFetchRequest<TresorUserDevice> = TresorUserDevice.fetchRequest()
    
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
  
  
  // MARK: - CloudKit
  
  
  
  public func getPrivateDB() -> CKDatabase {
    return self.privateDB
  }
  
  func saveTresorUsersToCloudKit(tresorUsers:[TresorUser]) -> CKModifyRecordsOperation {
    let zoneId = CKRecordZoneID(zoneName: tresorusersGroup, ownerName: CKCurrentUserDefaultName)
    
    var records = [CKRecord]()
    for tresorUser in tresorUsers {
      let recordId = CKRecordID(recordName: tresorUser.id!, zoneID: zoneId)
      
      let record = CKRecord(recordType: "Tresoruser", recordID: recordId)
      
      record["id"] = tresorUser.id as CKRecordValue?
      record["firstname"] = tresorUser.firstname as CKRecordValue?
      record["lastname"] = tresorUser.lastname as CKRecordValue?
      record["email"] = tresorUser.email as CKRecordValue?
      
      records.append(record)
    }
    
    return CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
  }
  
  func deleteTresorUserFromCloudKit(tresorUserId:String) -> CKModifyRecordsOperation {
    let zoneId = CKRecordZoneID(zoneName: tresorusersGroup, ownerName: CKCurrentUserDefaultName)
    let recordId = CKRecordID(recordName: tresorUserId, zoneID: zoneId)
      
    return CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: [recordId])
  }
  
  
  
  func createDatabaseSubscriptionOperation(subscriptionId: String) -> CKModifySubscriptionsOperation {
    let subscription = CKDatabaseSubscription(subscriptionID: subscriptionId)
    
    let notificationInfo = CKNotificationInfo()
    // send a silent notification
    notificationInfo.shouldSendContentAvailable = true
    subscription.notificationInfo = notificationInfo
    
    let operation = CKModifySubscriptionsOperation(subscriptionsToSave: [subscription], subscriptionIDsToDelete: [])
    operation.qualityOfService = .utility
    
    return operation
  }
  
  
  public func createCloudKitSubscription() {
    let createSubscriptionOperation = self.createDatabaseSubscriptionOperation(subscriptionId: privateSubscriptionId)
    createSubscriptionOperation.modifySubscriptionsCompletionBlock = { (subscriptions, deletedIds, error) in
      if let e = error {
        celeturKitLogger.error("Error creating privateSubscriptionId subscription",error:e)
      }
    }
    self.privateDB.add(createSubscriptionOperation)
    
    /*
      let createSubscriptionOperation = self.createDatabaseSubscriptionOperation(subscriptionId: sharedSubscriptionId)
      createSubscriptionOperation.modifySubscriptionsCompletionBlock = { (subscriptions, deletedIds, error) in
        if let e = error {
          celeturKitLogger.error("Error creating sharedSubscriptionId subscription",error:e)
        }
      }
      self.sharedDB.add(createSubscriptionOperation)
 */
    
    self.createZoneGroup.notify(queue: DispatchQueue.global()) {
      self.fetchChanges(in: .private) {}
     // self.fetchChanges(in: .shared) {}
    }
  }
  
  public func fetchChanges(in databaseScope: CKDatabaseScope, completion: @escaping () -> Void) {
    switch databaseScope {
    case .private:
      fetchDatabaseChanges(database: self.privateDB, databaseTokenKey: "private", completion: completion)
    case .shared:
      fetchDatabaseChanges(database: self.sharedDB, databaseTokenKey: "shared", completion: completion)
    case .public:
      break
    }
  }
  
  func getChangeToken(tokenName:String) -> CKServerChangeToken? {
    if tokenName == "private" {
      return self.privateDBChangeToken
    } else if tokenName == "shared" {
      return self.sharedDBChangeToken
    } else if tokenName == tresorusersGroup {
      return self.sharedDBChangeToken
    }
    
    return nil
  }
  
  func setChangeToken(tokenName:String, changeToken: CKServerChangeToken) {
    if tokenName == "private" {
      self.privateDBChangeToken = changeToken
      self.saveCloudKitServerChangeToken(name: tokenName, changeToken: changeToken)
    } else if tokenName == "shared" {
      self.sharedDBChangeToken = changeToken
      self.saveCloudKitServerChangeToken(name: tokenName, changeToken: changeToken)
    } else if tokenName == tresorusersGroup {
      self.sharedDBChangeToken = changeToken
      self.saveCloudKitServerChangeToken(name: tokenName, changeToken: changeToken)
    }
  }
  
  func fetchDatabaseChanges(database: CKDatabase, databaseTokenKey: String, completion: @escaping () -> Void) {
    var changedZoneIDs: [CKRecordZoneID] = []
    
    let operation = CKFetchDatabaseChangesOperation(previousServerChangeToken: self.getChangeToken(tokenName: databaseTokenKey))
    
    operation.recordZoneWithIDChangedBlock = { (zoneID) in
      changedZoneIDs.append(zoneID)
    }
    
    operation.recordZoneWithIDWasDeletedBlock = { (zoneID) in
      // Write this zone deletion to memory
    }
    
    operation.changeTokenUpdatedBlock = { (token) in
      // Flush zone deletions for this database to disk
      // Write this new database change token to memory
      
      celeturKitLogger.debug("changeTokenUpdatedBlock:\(token)")
      self.setChangeToken(tokenName: databaseTokenKey, changeToken: token)
    }
    
    operation.fetchDatabaseChangesCompletionBlock = { (token, moreComing, error) in
      if let e = error {
        celeturKitLogger.error("Error during fetch shared database changes operation", error:e)
        completion()
        return
      }
      
      // Flush zone deletions for this database to disk
      // Write this new database change token to memory
      
      if let c = token {
        celeturKitLogger.debug("fetchDatabaseChangesCompletionBlock:\(c)")
        self.setChangeToken(tokenName: databaseTokenKey, changeToken: c)
      }
      
      if changedZoneIDs.count>0 {
        self.fetchZoneChanges(database: database, databaseTokenKey: databaseTokenKey, zoneIDs: changedZoneIDs) {
          // Flush in-memory database change token to disk
          completion()
        }
      } else {
        completion()
      }
    }
    operation.qualityOfService = .userInitiated
    
    database.add(operation)
  }
  
  func fetchZoneChanges(database: CKDatabase, databaseTokenKey: String, zoneIDs: [CKRecordZoneID], completion: @escaping () -> Void) {
    
    // Look up the previous change token for each zone
    var optionsByRecordZoneID = [CKRecordZoneID: CKFetchRecordZoneChangesOptions]()
    for zoneID in zoneIDs {
      let options = CKFetchRecordZoneChangesOptions()
      
      options.previousServerChangeToken = self.getChangeToken(tokenName: zoneID.zoneName)
      optionsByRecordZoneID[zoneID] = options
    }
    let operation = CKFetchRecordZoneChangesOperation(recordZoneIDs: zoneIDs, optionsByRecordZoneID: optionsByRecordZoneID)
    
    
    let tempMOC = self.createScratchPadContext()
    
    operation.recordChangedBlock = { (record) in
      celeturKitLogger.debug("Record changed:\(record)")
      
      if record.recordType == self.tresoruserType {
        var user = self.getTresorUser(withId: record["id"] as! String,tempMOC: tempMOC)
        
        if user == nil {
          user = TresorUser(context:tempMOC)
          user?.createts = Date()
          user?.id = String.uuid()
        }
        
        user?.firstname = record["firstname"] as? String
        user?.lastname = record["lastname"] as? String
        user?.email = record["email"] as? String
      }
    }
    
    operation.recordWithIDWasDeletedBlock = { (recordId,recordType) in
      celeturKitLogger.debug("Record deleted:\(recordId)")
      
      let user = self.getTresorUser(withId: recordId.recordName ,tempMOC: tempMOC)
      
      if let u = user {
        tempMOC.delete(u)
      }
    }
    
    operation.recordZoneChangeTokensUpdatedBlock = { (zoneId, token, data) in
      if let c = token {
        celeturKitLogger.debug("recordZone:\(zoneId) changeToken:\(c)")
        
        self.setChangeToken(tokenName: zoneId.zoneName, changeToken: c)
      }
    }
    
    operation.recordZoneFetchCompletionBlock = { (zoneId, changeToken, _, _, error) in
      if let e = error {
        celeturKitLogger.error("Error fetching zone changes for \(databaseTokenKey) database:", error: e)
        return
      }
    }
    
    operation.fetchRecordZoneChangesCompletionBlock = { (error) in
      if let e = error {
        celeturKitLogger.error("Error fetching zone changes for \(databaseTokenKey) database:", error: e)
      } else {
        tempMOC.perform {
          do {
            try tempMOC.save()
            
            self.saveContextInMainThread()
          } catch {
            celeturKitLogger.error("error saving ck changes to core data",error:error)
          }
        }
      }
      completion()
    }
    
    database.add(operation)
  }
  
  public func createZones(zoneName:String) {
    self.createZoneGroup.enter()
    
    let zoneID = CKRecordZoneID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
    let customZone = CKRecordZone(zoneID: zoneID)
    
    let createZoneOperation = CKModifyRecordZonesOperation(recordZonesToSave: [customZone], recordZoneIDsToDelete: [] )
    
    createZoneOperation.modifyRecordZonesCompletionBlock = { (saved, deleted, error) in
      if let e = error {
        celeturKitLogger.error("Error creating custom zone \(zoneID)", error: e)
        return
      }
      
      self.createZoneGroup.leave()
    }
    createZoneOperation.qualityOfService = .userInitiated
    
    self.privateDB.add(createZoneOperation)
    
  }
  
  func createCloudKitServerChangeToken(name:String, changeToken:CKServerChangeToken) -> CloudKitServerChangeToken {
    let result = CloudKitServerChangeToken(context: self.managedContext)
    
    result.name = name
    result.createts = Date()
    result.data = NSKeyedArchiver.archivedData(withRootObject: changeToken)
    
    return result
  }
  
  func saveCloudKitServerChangeToken(name:String, changeToken:CKServerChangeToken) {
    let record = self.getCloudKitServerChangeToken(name: name)
    
    if let r = record {
      r.data = NSKeyedArchiver.archivedData(withRootObject: changeToken)
      r.createts = Date()
    } else {
      let _ = self.createCloudKitServerChangeToken(name:name,changeToken: changeToken)
    }
    
    do {
      try self.saveContext()
    } catch {
      celeturKitLogger.error("Error saving serverchangetoken",error:error)
    }
  }
  
  func getCloudKitServerChangeToken(name:String) -> CloudKitServerChangeToken? {
    var result : CloudKitServerChangeToken?
    
    let fetchRequest: NSFetchRequest<CloudKitServerChangeToken> = CloudKitServerChangeToken.fetchRequest()
    
    // Set the batch size to a suitable number.
    fetchRequest.fetchBatchSize = 1
    fetchRequest.predicate = NSPredicate(format: "name = %@", name)
    
    do {
      let records = try self.managedContext.fetch(fetchRequest)
      
      if records.count>0 {
        result = records[0]
      }
    } catch {
      celeturKitLogger.error("Error while fetching serverchangetoken",error:error)
    }
    
    return result
  }
  
  func getCloudKitCKServerChangeToken(name:String) -> CKServerChangeToken? {
    let result = self.getCloudKitServerChangeToken(name: name)
    
    if let r = result {
      return NSKeyedUnarchiver.unarchiveObject(with: r.data!) as? CKServerChangeToken
    }
    
    return nil
  }
}
