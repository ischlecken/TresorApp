//
//  Created by Feldmaus on 06.08.17.
//  Copyright © 2017 prisnoc. All rights reserved.
//

import Foundation
import Contacts
import CloudKit

extension Notification.Name {
  public static let onTresorModelReady = Notification.Name("onTresorModelReady")
}


let appGroup = "group.net.prisnoc.Celetur"
let celeturKitIdentifier = "net.prisnoc.CeleturKit"

public class TresorModel {
  
  public var currentUserInfo : UserInfo?
  public var currentDeviceInfo : DeviceInfo?
  
  public var userDevices : [TresorUserDevice]?
  
  public var tresorCoreDataManager : CoreDataManager?
  
  var tresorMetaInfoCoreDataManager : CoreDataManager?
  
  let cipherQueue = OperationQueue()
  
  let initModelDispatchGroup : DispatchGroup
  
  public init() {
    self.initModelDispatchGroup = DispatchGroup()
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
        
        celeturKitLogger.debug("TresorModel.completeSetup() --leave--")
        self.initModelDispatchGroup.leave()
      }
    }
    
    self.initModelDispatchGroup.notify(queue: DispatchQueue.main) {
      celeturKitLogger.debug("TresorModel.initModelDispatchGroup.notify()")
      
      NotificationCenter.default.post(name: .onTresorModelReady, object: self)
    }
  }
  
  fileprivate func switchTresorCoreDataManager() {
    guard let u = self.currentUserInfo else { return }
    
    let cdm = CoreDataManager(modelName: "CeleturKit",
                              using:Bundle(identifier:celeturKitIdentifier)!,
                              inAppGroupContainer:appGroup,
                              forUserId: u.userRecordID)
    
    cdm.completeSetup { error in
      celeturKitLogger.debug("TresorModel.switchTresorCoreDataManager()")
      
      do {
        let ckps = try CloudKitPersistenceState(appGroupContainerId: appGroup, forUserId:u.userRecordID)
        
        let ckm = CloudKitManager(cloudKitPersistenceState: ckps, coreDataManager: cdm)
        ckm.createCloudKitSubscription()
        
        cdm.cloudKitManager = ckm
        
        DispatchQueue.main.async {
          self.userDevices = TresorUserDevice.loadUserDevices(context: cdm.mainManagedObjectContext)
          
          let di = DeviceInfo()
          if let userDevices = self.userDevices {
            let _ = di.selectUserDevice(userDevices: userDevices)
          }
          
          self.currentDeviceInfo = di
          self.tresorCoreDataManager = cdm
          
          self.saveUserInfo(userInfo:u)
          
          celeturKitLogger.debug("TresorModel.switchTresorCoreDataManager() --leave--")
          self.initModelDispatchGroup.leave()
        }
      } catch {
        celeturKitLogger.error("Error while setup core data manager ...",error:error)
      }
    }
  }
  
  fileprivate func saveUserInfo(userInfo u : UserInfo) {
    if let metacdm = self.tresorMetaInfoCoreDataManager {
      let moc = metacdm.mainManagedObjectContext
      
      let fetchRequest : NSFetchRequest<TresorUser> = TresorUser.fetchRequest()
      fetchRequest.predicate = NSPredicate(format: "id = %@", (u.userRecordID)!)
      fetchRequest.fetchBatchSize = 1
      
      do {
        var tresorUser : TresorUser?
        
        let records = try moc.fetch(fetchRequest)
        if records.count>0 {
          tresorUser = records[0]
        }
        
        if tresorUser == nil {
          tresorUser = TresorUser(context: moc)
          
          tresorUser?.id = u.userRecordID
          tresorUser?.createts = Date()
        }
        
        tresorUser?.username = u.userDisplayName
        
        metacdm.saveChanges(notifyChangesToCloudKit:false)
      } catch {
        celeturKitLogger.error("Error while saving tresoruser info...",error:error)
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
                let ui = UserInfo()
                
                ui.updateUserIdentityInfo(userIdentity: u)
                
                self.currentUserInfo = ui
                
                self.switchTresorCoreDataManager()
              }
            })
          }
        })
      }
    }
  }
  
  public func setCurrentDeviceAPNToken(deviceToken:Data) {
    celeturKitLogger.debug("setCurrentDeviceAPNToken(\(deviceToken.hexEncodedString()))")
    
    if let di = self.currentDeviceInfo {
      di.updateAPNToken(deviceToken: deviceToken)
    }
  }
  
  
  func isCurrentDeviceKnown() -> Bool {
    return self.currentDeviceInfo != nil
  }
  
  func createCurrentUserInfo() {
    guard let deviceInfo = self.currentDeviceInfo else { return }
    
    if let apntoken = deviceInfo.apnToken,
      let userName = self.currentUserInfo?.userFamilyName,
      let cdm = self.tresorCoreDataManager {
      
      let tempMOC = cdm.privateChildManagedObjectContext()
      let _ = TresorUserDevice.createCurrentUserDevice(context: tempMOC,userName:userName, apndeviceToken: apntoken)
      
      tempMOC.perform {
        do {
          try tempMOC.save()
          
          cdm.saveChanges(notifyChangesToCloudKit: true)
        } catch {
          celeturKitLogger.error("Error saving contacts",error:error)
        }
      }
    }
  }
  
  
  public func createDummyUserDevices() {
    if let moc = self.tresorCoreDataManager?.mainManagedObjectContext {
      TresorUserDevice.createCurrentUserDevice(context: moc, userName: "Hugo Müller", apndeviceToken: "0000-1111")
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
  
  
  public func createTresorDocument(tresor:Tresor, plainText: String, masterKey: TresorKey?) throws -> TresorDocument? {
    var result : TresorDocument?
    
    if let moc = self.tresorCoreDataManager?.mainManagedObjectContext {
      let newTresorDocument = try TresorDocument.createTresorDocument(context: moc, tresor: tresor)
      
      for ud in tresor.userdevices! {
        let userdevice = ud as! TresorUserDevice
        
        let item = try self.createTresorDocumentItem(tresorDocument: newTresorDocument,
                                                     plainText: plainText,
                                                     userDevice: userdevice,
                                                     masterKey: masterKey!)
        
        newTresorDocument.addToDocumentitems(item!)
        userdevice.addToDocumentitems(item!)
      }
      
      self.saveChanges()
      
      result = newTresorDocument
    }
    
    return result
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
                                       masterKey:TresorKey) throws -> TresorDocumentItem? {
    var result : TresorDocumentItem?
    
    if let moc = self.tresorCoreDataManager?.mainManagedObjectContext {
      let newTresorDocumentItem = TresorDocumentItem.createPendingTresorDocumentItem(context:moc,
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
        
        result = newTresorDocumentItem
      } catch {
        celeturKitLogger.error("Error while saving tresordocumentitem", error: error)
      }
    }
    
    return result
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
  
  public func saveDocumentItemModelData(tresorDocumentItem: TresorDocumentItem, model : [String:Any], masterKey: TresorKey) {
    if let moc = self.tresorCoreDataManager?.privateChildManagedObjectContext() {
      moc.perform {
        self.encryptAndSaveTresorDocumentItem(tempManagedContext: moc,
                                              masterKey: masterKey,
                                              tresorDocumentItem: tresorDocumentItem,
                                              payload: model)
        
        self.saveChanges()
      }
    }
  }
  
  public func deleteTresorUserDevice(userDevice:TresorUserDevice) {
    if let moc = self.tresorCoreDataManager?.mainManagedObjectContext {
      moc.delete(userDevice)
      
      do {
        try moc.save()
        
        self.saveChanges()
      } catch {
        celeturKitLogger.error("Error while deleting TresorUserDevice", error: error)
      }
    }
  }
}
