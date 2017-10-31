//
//  Created by Feldmaus on 06.08.17.
//  Copyright © 2017 prisnoc. All rights reserved.
//

import Foundation
import Contacts
import CloudKit

extension Notification.Name {
  public static let onTresorModelReady = Notification.Name("onTresorModelReady")
  public static let onTresorUserInfoChanged = Notification.Name("onTresorUserInfoChanged")
}

let appGroup = "group.net.prisnoc.Celetur"
let celeturKitIdentifier = "net.prisnoc.CeleturKit"

public class TresorModel {
  
  public var currentUserInfo : UserInfo?
  public var currentDeviceInfo : DeviceInfo?
  public var currentTresorUserDevice : TresorUserDevice?
  public var tresorCoreDataManager : CoreDataManager?
  public var userDevices: [TresorUserDevice]? {
    guard let moc = self.tresorCoreDataManager?.mainManagedObjectContext else { return nil }
    
    return TresorUserDevice.loadUserDevices(context: moc)
  }
  
  var tresorMetaInfoCoreDataManager : CoreDataManager?
  var apnDeviceToken : Data?
  
  let initModelDispatchGroup  = DispatchGroup()
  let cipherQueue = OperationQueue()
  
  public init() {
    NotificationCenter.default.addObserver(self,
                                           selector: #selector(checkICloudAvailability),
                                           name: .CKAccountChanged,
                                           object: nil)
    
  }
  
  deinit {
    NotificationCenter.default.removeObserver(self)
  }
  
  @objc
  func checkICloudAvailability(_ notification: Notification? = nil) {
    celeturKitLogger.debug("checkICloudAvailability()")
    
    if let _ = self.tresorCoreDataManager {
      self.requestUserDiscoverabilityPermission()
    }
  }
  
  public func completeSetup() {
    celeturKitLogger.debug("TresorModel.completeSetup() --enter--")
    self.initModelDispatchGroup.enter()

    self.requestUserDiscoverabilityPermission()
    
    let cdm = CoreDataManager(modelName: "CeleturKitMetaInfo",
                              using:Bundle(identifier:celeturKitIdentifier)!,
                              inAppGroupContainer:appGroup,
                              forUserId: nil)
    
    cdm.completeSetup { error in
      if error == nil {
        celeturKitLogger.debug("TresorMetaInfo ready")
        
        self.tresorMetaInfoCoreDataManager = cdm
        
        self.loadDeviceInfo()
        
        celeturKitLogger.debug("TresorModel.completeSetup() --leave--")
        self.initModelDispatchGroup.leave()
      }
    }
    
    self.initModelDispatchGroup.notify(queue: DispatchQueue.main) {
      celeturKitLogger.debug("TresorModel.initModelDispatchGroup.notify()")
      
      NotificationCenter.default.post(name: .onTresorModelReady, object: self)
    }
  }
  
  fileprivate func switchTresorCoreDataManager(userIdentity:CKUserIdentity) {
    guard let userId = userIdentity.userRecordID?.recordName else { return }
    
    let cdm = CoreDataManager(modelName: "CeleturKit",
                              using:Bundle(identifier:celeturKitIdentifier)!,
                              inAppGroupContainer:appGroup,
                              forUserId: userId)
    
    cdm.completeSetup { error in
      celeturKitLogger.debug("TresorModel.switchTresorCoreDataManager()")
      
      do {
        let ckps = try CloudKitPersistenceState(appGroupContainerId: appGroup, forUserId:userId)
        
        let ckm = CloudKitManager(cloudKitPersistenceState: ckps, coreDataManager: cdm)
        ckm.createCloudKitSubscription()
        
        cdm.cloudKitManager = ckm
        
        DispatchQueue.main.async {
          self.tresorCoreDataManager = cdm
          
          self.currentUserInfo = UserInfo.loadUserInfo(self.tresorMetaInfoCoreDataManager!,userIdentity:userIdentity)
          
          self.loadTresorUserDevice()
          
          celeturKitLogger.debug("TresorModel.switchTresorCoreDataManager() --leave--")
          self.initModelDispatchGroup.leave()
          
          NotificationCenter.default.post(name: .onTresorUserInfoChanged, object: self)
        }
      } catch {
        celeturKitLogger.error("Error while setup core data manager ...",error:error)
      }
    }
  }
  
  
  fileprivate func loadDeviceInfo() {
    if let metacdm = self.tresorMetaInfoCoreDataManager {
      let moc = metacdm.mainManagedObjectContext
      
      let fetchRequest : NSFetchRequest<DeviceInfo> = DeviceInfo.fetchRequest()
      fetchRequest.fetchBatchSize = 1
      
      do {
        var deviceInfo : DeviceInfo?
        
        let records = try moc.fetch(fetchRequest)
        if records.count>0 {
          deviceInfo = records[0]
        } else {
          deviceInfo = DeviceInfo.createCurrentUserDevice(context: moc)
        }
        
        if let adt = self.apnDeviceToken {
          deviceInfo!.updateAPNToken(deviceToken: adt)
        }
        
        self.currentDeviceInfo = deviceInfo
        
        metacdm.saveChanges(notifyChangesToCloudKit:false)
      } catch {
        celeturKitLogger.error("Error while saving device info...",error:error)
      }
    }
  }
  
  fileprivate func loadTresorUserDevice() {
    if let cdm = self.tresorCoreDataManager, let cdi = self.currentDeviceInfo, let userName = self.currentUserInfo?.userDisplayName {
      let moc = cdm.mainManagedObjectContext
      
      let fetchRequest : NSFetchRequest<TresorUserDevice> = TresorUserDevice.fetchRequest()
      fetchRequest.fetchBatchSize = 1
      
      do {
        var tresorUserDevice : TresorUserDevice?
        
        let records = try moc.fetch(fetchRequest)
        if records.count>0 {
          tresorUserDevice = records[0]
        } else {
          tresorUserDevice = TresorUserDevice.createCurrentUserDevice(context: moc, deviceInfo: cdi)
        }
        
        tresorUserDevice!.updateCurrentUserDevice(deviceInfo: cdi, userName: userName)
        
        cdm.saveChanges(notifyChangesToCloudKit:true)
        
        self.currentTresorUserDevice = tresorUserDevice
      } catch {
        celeturKitLogger.error("Error while saving tresor userdevice info...",error:error)
      }
    }
  }
  
  public func saveChanges(notifyCloudKit:Bool=true) {
    guard let cdm = self.tresorCoreDataManager else { return }
    
    cdm.saveChanges(notifyChangesToCloudKit:notifyCloudKit)
  }
  
  
  func requestUserDiscoverabilityPermission() {
    celeturKitLogger.debug("TresorModel.requestUserDiscoverabilityPermission() --enter--")
    self.initModelDispatchGroup.enter()
    
    CKContainer.default().requestApplicationPermission(CKApplicationPermissions.userDiscoverability) { (status, error) in
      if let error=error {
        let _ = CloudKitManager.dumpCloudKitError(context: "UserDiscoverabilityPermission", error: error)
      }
      
      //celeturKitLogger.debug("status:\(status.rawValue)")
      
      if status == CKApplicationPermissionStatus.granted {
        CKContainer.default().fetchUserRecordID(completionHandler: { (recordID, error) in
          if let r = recordID {
            //celeturKitLogger.debug("recordID:\(r)")
            
            CKContainer.default().discoverUserIdentity(withUserRecordID: r, completionHandler: { (userIdentity, error) in
              if let u = userIdentity {
                self.switchTresorCoreDataManager(userIdentity:u)
              }
            })
          }
        })
      }
    }
  }
  
  public func setCurrentDeviceAPNToken(deviceToken:Data) {
    celeturKitLogger.debug("setCurrentDeviceAPNToken(\(deviceToken.hexEncodedString()))")
    
    self.apnDeviceToken = deviceToken
    
    if let cdi = self.currentDeviceInfo {
      cdi.updateAPNToken(deviceToken: deviceToken)
    }
  }
  
  
  public func isCurrentDevice(tresorUserDevice: TresorUserDevice?) -> Bool {
    guard let cdi = self.currentDeviceInfo,let tud = tresorUserDevice else { return false }
    
    return cdi.id == tud.id
  }
  
  
  public func createDummyUserDevices() {
    if let moc = self.tresorCoreDataManager?.mainManagedObjectContext {
      TresorUserDevice.createUserDevice(context: moc, userName: "Hugo Müller", deviceName: "Hugos iPhone")
      TresorUserDevice.createUserDevice(context: moc, userName: "Hugo Müller", deviceName: "Hugos iPad")
      TresorUserDevice.createUserDevice(context: moc, userName: "Hugo Müller", deviceName: "Hugos iWatch")
      
      TresorUserDevice.createUserDevice(context: moc, userName: "Manfred Schmidt", deviceName: "Manfreds iPhone")
      TresorUserDevice.createUserDevice(context: moc, userName: "Manfred Schmidt", deviceName: "Manfreds iPad")
      TresorUserDevice.createUserDevice(context: moc, userName: "Manfred Schmidt", deviceName: "Manfreds iWatch")
      TresorUserDevice.createUserDevice(context: moc, userName: "Manfred Schmidt", deviceName: "Manfreds iTV")
      
      self.saveChanges()
    }
  }
  
  
  
  
  public func deleteTresorAndSave(tresor: Tresor) {
    if let moc = self.tresorCoreDataManager?.mainManagedObjectContext {
      self.deleteTresor(context: moc, tresor: tresor)
      
      do {
        try moc.save()
        
        self.saveChanges()
      } catch {
        celeturKitLogger.error("Error while deleting tresor object",error:error)
      }
    }
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
  
  
  public func createTresorDocument(tresor:Tresor, model: [String:Any], masterKey: TresorKey?) throws -> TresorDocument? {
    var result : TresorDocument?
    var payload : Data?
    
    do {
      payload = try JSONSerialization.data(withJSONObject: model, options: [])
    } catch {
      celeturKitLogger.error("Error while serializing json object", error: error)
    }
    
    if let payload = payload, let moc = self.tresorCoreDataManager?.mainManagedObjectContext,let currentDeviceKey = masterKey?.accessToken {
      let newTresorDocument = try TresorDocument.createTresorDocument(context: moc, tresor: tresor)
      
      if let title = model["title"] as? String {
        newTresorDocument.setMetaInfo(title: title, description: model["description"] as? String)
      }
      
      for ud in tresor.userdevices! {
        let userDevice = ud as! TresorUserDevice
        let isUserDeviceCurrentDevice = self.isCurrentDevice(tresorUserDevice: userDevice)
        
        if let key = isUserDeviceCurrentDevice ? currentDeviceKey : userDevice.messagekey {
          let status : TresorDocumentItemStatus = isUserDeviceCurrentDevice ? .encrypted : .shouldBeEncryptedByDevice
          
          if let item = try self.createTresorDocumentItem(tresorDocument: newTresorDocument,
                                                          payload: payload,
                                                          userDevice: userDevice,
                                                          key: key,
                                                          status: status) {
            newTresorDocument.addToDocumentitems(item)
            userDevice.addToDocumentitems(item)
          }
        }
      }
      
      self.saveChanges()
      
      result = newTresorDocument
    }
    
    return result
  }
  
  fileprivate func createTresorDocumentItem(tresorDocument:TresorDocument,
                                       payload: Data,
                                       userDevice: TresorUserDevice,
                                       key: Data,
                                       status: TresorDocumentItemStatus) throws -> TresorDocumentItem? {
    var result : TresorDocumentItem?
    
    if let moc = self.tresorCoreDataManager?.mainManagedObjectContext {
      let newTresorDocumentItem = TresorDocumentItem.createPendingTresorDocumentItem(context:moc,
                                                                                     tresorDocument: tresorDocument,
                                                                                     userDevice:userDevice)
      
      tresorDocument.addToDocumentitems(newTresorDocumentItem)
      userDevice.addToDocumentitems(newTresorDocumentItem)
      
      do {
        let operation = AES256EncryptionOperation(key:key, inputData: payload, iv:nil)
        try operation.createRandomIV()
        
        operation.completionBlock = {
          DispatchQueue.main.async {
            newTresorDocumentItem.type = "main"
            newTresorDocumentItem.mimetype = "application/json"
            newTresorDocumentItem.status = status.rawValue
            newTresorDocumentItem.payload = operation.outputData
            newTresorDocumentItem.nonce = operation.iv
            
            self.saveChanges()
            
            celeturKitLogger.debug("key:\(key) encryptedText:\(String(describing: operation.outputData?.hexEncodedString()))")
          }
        }
        
        self.cipherQueue.addOperation(operation)
        
        result = newTresorDocumentItem
      } catch {
        celeturKitLogger.error("Error while saving tresordocumentitem", error: error)
      }
    }
    
    return result
  }
  
  public func saveDocumentItemModelData(tresorDocumentItem: TresorDocumentItem, model : [String:Any], masterKey: TresorKey) {
    var payload : Data?
    
    do {
      payload = try JSONSerialization.data(withJSONObject: model, options: [])
    } catch {
      celeturKitLogger.error("Error while serializing json object", error: error)
    }
    
    if let payload = payload, let tresorDocument = tresorDocumentItem.document, let moc = self.tresorCoreDataManager?.privateChildManagedObjectContext() {
      moc.perform {
        if let title = model["title"] as? String {
          tresorDocument.setMetaInfo(title: title, description: model["description"] as? String)
        }
      
        for case let it as TresorDocumentItem in (tresorDocumentItem.document?.documentitems)! {
          celeturKitLogger.debug("saveDocumentItemModelData(): docItem:\(it.id ?? "-")")
          if let ud = it.userdevice {
            let isUserDeviceCurrentDevice = self.isCurrentDevice(tresorUserDevice: ud)
            
            celeturKitLogger.debug("  saveDocumentItemModelData(): userdevice:\(ud.id ?? "-") isUserDeviceCurrentDevice:\(isUserDeviceCurrentDevice)")
            
            if let key = isUserDeviceCurrentDevice ? masterKey.accessToken : ud.messagekey {
              let status : TresorDocumentItemStatus = isUserDeviceCurrentDevice ? .encrypted : .shouldBeEncryptedByDevice
              
              self.encryptAndSaveTresorDocumentItem(tempManagedContext: moc,
                                                    key: key,
                                                    tresorDocumentItem: it,
                                                    payload: payload,
                                                    status: status)
            }
          }
        }
        
        self.saveChanges()
      }
    }
  }
  
  fileprivate func encryptAndSaveTresorDocumentItem(tempManagedContext: NSManagedObjectContext,
                                                    key:Data,
                                                    tresorDocumentItem:TresorDocumentItem,
                                                    payload: Data,
                                                    status: TresorDocumentItemStatus) {
    
    do {
      let tdi = tempManagedContext.object(with: tresorDocumentItem.objectID) as! TresorDocumentItem
      
      tdi.status = TresorDocumentItemStatus.pending.rawValue
      try tempManagedContext.save()
      
      let operation = AES256EncryptionOperation(key:key, inputData: payload, iv:nil)
      try operation.createRandomIV()
      
      operation.start()
      
      if operation.isFinished {
        celeturKitLogger.debug("encryptAndSaveTresorDocumentItem() item:\(tresorDocumentItem.id ?? "-") status:\(status)")
        
        tdi.status = status.rawValue
        tdi.type = "main"
        tdi.mimetype = "application/json"
        tdi.payload = operation.outputData
        tdi.nonce = operation.iv
      } else {
        tdi.status = TresorDocumentItemStatus.failed.rawValue
      }
      tdi.changets = Date()
      
      try tempManagedContext.save()
    } catch {
      celeturKitLogger.error("Error while encryption payload from edit dialogue",error:error)
    }
  }
  
  public func decryptTresorDocumentItemPayload(tresorDocumentItem:TresorDocumentItem,
                                               masterKey:TresorKey,
                                               completion: ((SymmetricCipherOperation?)->Void)?) {
    if let payload = tresorDocumentItem.payload, let nonce = tresorDocumentItem.nonce {
      let operation = AES256DecryptionOperation(key:masterKey.accessToken!,inputData: payload, iv:nonce)
      
      if let c = completion {
        operation.completionBlock = {
          c(operation)
        }
      }
      
      self.cipherQueue.addOperation(operation)
    } else {
      if let c = completion {
        c(nil)
      }
    }
  }
  
  public func createAndFetchTresorFetchedResultsController() throws -> NSFetchedResultsController<Tresor>? {
    var result : NSFetchedResultsController<Tresor>?
    
    if let moc = self.tresorCoreDataManager?.mainManagedObjectContext {
      result = try Tresor.createAndFetchTresorFetchedResultsController(context: moc)
    }
    
    return result
  }
  
  public func createAndFetchUserdeviceFetchedResultsController() throws -> NSFetchedResultsController<TresorUserDevice>? {
    var result : NSFetchedResultsController<TresorUserDevice>?
    
    if let moc = self.tresorCoreDataManager?.mainManagedObjectContext {
      result = try TresorUserDevice.createAndFetchUserdeviceFetchedResultsController(context: moc)
    }
    
    return result
  }
  
  
  public func createAndFetchTresorDocumentItemFetchedResultsController(tresor:Tresor?) throws -> NSFetchedResultsController<TresorDocumentItem>? {
    var result : NSFetchedResultsController<TresorDocumentItem>?
    
    if let moc = self.tresorCoreDataManager?.mainManagedObjectContext {
      result = try TresorDocumentItem.createAndFetchTresorDocumentItemFetchedResultsController(context: moc, tresor: tresor)
    }
    
    return result
  }
  
  public func fetchChanges(in databaseScope: CKDatabaseScope, completion: @escaping () -> Void) {
    self.tresorCoreDataManager?.cloudKitManager?.fetchChanges(in: databaseScope, completion: completion)
  }
  
  public func resetChangeTokens() {
    self.tresorCoreDataManager?.cloudKitManager?.ckPersistenceState.flushChangedIds()
    self.tresorCoreDataManager?.cloudKitManager?.ckPersistenceState.flushServerChangeTokens()
  }
  
  public func removeAllCloudKitData() {
    self.tresorCoreDataManager?.cloudKitManager?.deleteAllRecordsForZone()
  }
  
  public func removeAllCoreData() {
    guard let cdm = self.tresorCoreDataManager else { return }
    
    let tempMoc = cdm.privateChildManagedObjectContext()
    
    do {
      cdm.removeAllEntities(context: tempMoc, entityName: "TresorDocumentItem")
      cdm.removeAllEntities(context: tempMoc, entityName: "TresorDocument")
      cdm.removeAllEntities(context: tempMoc, entityName: "Tresor")
      cdm.removeAllEntities(context: tempMoc, entityName: "TresorUserDevice")
      
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
  
  
  public struct TempTresorObject {
    public var tempManagedObjectContext : NSManagedObjectContext
    public var tempTresor : Tresor
    
    init(context:NSManagedObjectContext, tresor:Tresor) {
      self.tempManagedObjectContext = context
      self.tempTresor = tresor
    }
  }
  
  public func createScratchpadTresorObject(tresor: Tresor?) -> TempTresorObject? {
    var result : TempTresorObject?
    
    if let cdm = self.tresorCoreDataManager {
      do {
        let scratchpadContext = cdm.privateChildManagedObjectContext()
        var tempTresor : Tresor?
        
        if let t = tresor {
          tempTresor = scratchpadContext.object(with: t.objectID) as? Tresor
        } else {
          tempTresor = try Tresor.createTempTresor(context: scratchpadContext)
        }
        
        result = TempTresorObject(context:scratchpadContext, tresor:tempTresor!)
      } catch {
        celeturKitLogger.error("Error creating temp tresor object",error:error)
      }
    }
    
    return result
  }
  
  
  
  public func deleteTresorUserDevice(userDevice:TresorUserDevice) {
    if let moc = userDevice.managedObjectContext {
      moc.delete(userDevice)
      
      do {
        try moc.save()
        
        self.saveChanges()
      } catch {
        celeturKitLogger.error("Error while deleting TresorUserDevice", error: error)
      }
    }
  }
  
  public func encryptAllDocumentItemsThatShouldBeEncryptedByDevice(tresor: Tresor, masterKey: TresorKey) {
    guard let documents = tresor.documents else { return }
    
    celeturKitLogger.debug("encryptAllDocumentItemsThatShouldBeEncryptedByDevice()")
    
    for case let tresorDocument as TresorDocument in documents {
      if let items = tresorDocument.documentitems {
        for case let item as TresorDocumentItem in items {
          if item.itemStatus == .shouldBeEncryptedByDevice,
            let ud = item.userdevice,
            let payload = item.payload,
            let nonce = item.nonce,
            let messageKey = ud.messagekey {
            if self.isCurrentDevice(tresorUserDevice: ud) {
              celeturKitLogger.debug("item \(item.id ?? "-") should be encrypted by device...")
              
              let operation = AES256DecryptionOperation(key: messageKey,inputData: payload, iv:nonce)
              
              operation.completionBlock = {
                do {
                  if let d = try operation.jsonOutputObject() {
                    celeturKitLogger.debug("payload:\(d)")
                    
                    let encryptOperation = AES256EncryptionOperation(key:masterKey.accessToken! ,inputData: operation.outputData!, iv:nil)
                    try encryptOperation.createRandomIV()
                    
                    encryptOperation.completionBlock = {
                      item.managedObjectContext?.perform {
                        item.type = "main"
                        item.mimetype = "application/json"
                        item.status = TresorDocumentItemStatus.encrypted.rawValue
                        item.payload = encryptOperation.outputData
                        item.nonce = encryptOperation.iv
                        
                        self.saveChanges()
                      }
                    }
                    
                    self.cipherQueue.addOperation(encryptOperation)
                  }
                } catch {
                  celeturKitLogger.error("error decoding payload", error: error)
                }
              }
              
              self.cipherQueue.addOperation(operation)
            }
          }
        }
      }
    }
  }
}
