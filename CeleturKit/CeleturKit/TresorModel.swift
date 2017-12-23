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
let celetorKitModelName = "CeleturKit"
let celetorKitMetaModelName = "CeleturKitMetaInfo"

public class TresorModel {
  
  public var currentUserInfo : UserInfo?
  
  fileprivate var icloudCoreDataManager : CoreDataManager?
  fileprivate var tresorMetaInfoCoreDataManager : CoreDataManager?
  fileprivate var apnDeviceToken : Data?
  fileprivate let initModelDispatchGroup  = DispatchGroup()
  
  public init() {
    NotificationCenter.default.addObserver(self,
                                           selector: #selector(checkICloudAvailability),
                                           name: .CKAccountChanged,
                                           object: nil)
    
  }
  
  public func getCoreDataManager() -> CoreDataManager? {
    return self.icloudCoreDataManager
  }
  
  @objc
  func checkICloudAvailability(_ notification: Notification? = nil) {
    celeturKitLogger.debug("checkICloudAvailability()")
    
    self.requestUserDiscoverabilityPermission()
  }
  
  public func completeSetup() {
    celeturKitLogger.debug("TresorModel.completeSetup() --enter--")
    
    self.createICloudCoreDataManager()
    self.createMetainfoCoreDataManager()
    self.requestUserDiscoverabilityPermission()
    
    self.initModelDispatchGroup.notify(queue: DispatchQueue.main) {
      celeturKitLogger.debug("TresorModel.initModelDispatchGroup.notify()")
      
      NotificationCenter.default.post(name: .onTresorModelReady, object: self)
    }
  }
  
  fileprivate func createMetainfoCoreDataManager() {
    self.initModelDispatchGroup.enter()
    let cdm = CoreDataManager(modelName: celetorKitMetaModelName,
                              using:Bundle(identifier:celeturKitIdentifier)!,
                              inAppGroupContainer:appGroup)
    
    cdm.completeSetup { error in
      if error == nil {
        self.tresorMetaInfoCoreDataManager = cdm
        
        self.loadCurrentDeviceInfo()
        
        celeturKitLogger.debug("TresorModel.createMetainfoCoreDataManager --leave--")
        self.initModelDispatchGroup.leave()
      }
    }
  }
  
  fileprivate func createICloudCoreDataManager() {
    self.initModelDispatchGroup.enter()
    
    let cdm = CoreDataManager(modelName: celetorKitModelName,
                              using:Bundle(identifier:celeturKitIdentifier)!,
                              inAppGroupContainer:appGroup)
    
    cdm.completeSetup { error in
      celeturKitLogger.debug("createICloudCoreDataManager()")
      
      self.icloudCoreDataManager = cdm
      
      DispatchQueue.main.async {
        celeturKitLogger.debug("createICloudCoreDataManager() --leave--")
        self.initModelDispatchGroup.leave()
      }
    }
  }
  
  
  fileprivate func createCloudKitManager(userIdentity:CKUserIdentity) {
    guard let userId = userIdentity.userRecordID?.recordName, let cdm = self.icloudCoreDataManager else { return }
    
    do {
      let ckps = try CloudKitPersistenceState(appGroupContainerId: appGroup, ckUserId: userId)
      let ckm = CloudKitManager(cloudKitPersistenceState: ckps, coreDataManager: cdm, ckUserId:userId)
      ckm.createCloudKitSubscription()
      
      cdm.cloudKitManager = ckm
      
      DispatchQueue.main.async {
        let cui = UserInfo.loadUserInfo(self.tresorMetaInfoCoreDataManager!,userIdentity:userIdentity)
        
        self.currentUserInfo = cui
        
        self.findAndUpdateCurrentTresorUserDevice(cdm: cdm, cui: cui)
        
        celeturKitLogger.debug("createCloudKitManager() --leave--")
      }
    } catch {
      celeturKitLogger.error("Error while setup core data manager ...",error:error)
    }
  }
  
  fileprivate func loadCurrentDeviceInfo() {
    if let metacdm = self.tresorMetaInfoCoreDataManager {
      let moc = metacdm.mainManagedObjectContext
      
      DeviceInfo.loadCurrentDeviceInfo(context: moc, apnDeviceToken: self.apnDeviceToken)
      metacdm.saveChanges(notifyChangesToCloudKit:false)
    }
  }
  
  fileprivate func findAndUpdateCurrentTresorUserDevice(cdm: CoreDataManager,cui:UserInfo) {
    if let cdi = currentDeviceInfo {
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
        
        tresorUserDevice!.updateCurrentUserDevice(deviceInfo: cdi)
        tresorUserDevice!.updateCurrentUserInfo(currentUserInfo: cui)
        
        cdm.saveChanges(notifyChangesToCloudKit:true)
      } catch {
        celeturKitLogger.error("Error while saving tresor userdevice info...",error:error)
      }
    }
  }
  
  public func saveChanges(notifyCloudKit:Bool=true) {
    if let cdm = self.icloudCoreDataManager {
      cdm.saveChanges(notifyChangesToCloudKit:notifyCloudKit)
    }
  }
  
  
  func requestUserDiscoverabilityPermission() {
    celeturKitLogger.debug("TresorModel.requestUserDiscoverabilityPermission() --enter--")
    
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
                self.createCloudKitManager(userIdentity:u)
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
    
    if let cdi = currentDeviceInfo {
      cdi.updateAPNToken(deviceToken: deviceToken)
    }
  }
  
  
  public func saveDocumentItemModelData(context:NSManagedObjectContext,
                                        tresorDocumentItem: TresorDocumentItem,
                                        model : Payload,
                                        masterKey: TresorKey) {
    
    if let payload = PayloadSerializer.jsonData(model: model),
      let tresorDocument = tresorDocumentItem.document,
      let tempTresorDocument = context.object(with: tresorDocument.objectID) as? TresorDocument {
      
      tempTresorDocument.setMetaInfo(model:model)
      
      for case let it as TresorDocumentItem in (tempTresorDocument.documentitems)! {
        if let ud = it.userdevice {
          let isUserDeviceCurrentDevice = currentDeviceInfo?.isCurrentDevice(tresorUserDevice: ud) ?? false
          
          celeturKitLogger.debug("  docItem:\(it.id ?? "-") userdevice:\(ud.id ?? "-") isUserDeviceCurrentDevice:\(isUserDeviceCurrentDevice)")
          
          if let key = isUserDeviceCurrentDevice ? masterKey.accessToken : ud.messagekey {
            let status : TresorDocumentItemStatus = isUserDeviceCurrentDevice ? .encrypted : .shouldBeEncryptedByDevice
            
            let _ = it.encryptPayload(key: key, payload: payload, status: status)
            
            celeturKitLogger.debug("item after encryption:\(it)")
          }
        }
      }
      
      tempTresorDocument.changets = Date()
      
      celeturKitLogger.debug("saveDocumentItemModelData(): encryption completed")
    }
  }
  
  
  public func fetchChanges(in databaseScope: CKDatabaseScope, completion: @escaping () -> Void) {
    self.icloudCoreDataManager?.cloudKitManager?.fetchChanges(in: databaseScope, completion: completion)
  }
  
  public func createScratchpadTresorObject(tresor: Tresor?) -> TempTresorObject? {
    return TempTresorObject(tresorCoreDataManager: self.getCoreDataManager(), tresor: tresor)
  }
  
  
  public func createScratchpadLocalDeviceTresorObject() -> TempTresorObject? {
    return TempTresorObject(tresorCoreDataManager: self.getCoreDataManager(), tresor: nil)
  }
  
  public func createScratchpadICloudTresorObject() -> TempTresorObject? {
    let result = TempTresorObject(tresorCoreDataManager: self.getCoreDataManager(), tresor: nil)
    
    if let ckuserid = self.currentUserInfo?.id {
      result?.tempTresor.ckuserid = ckuserid
    }
    
    return result
  }
  
  
  public func shouldEncryptAllDocumentItemsThatShouldBeEncryptedByDevice(tresor:Tresor) -> Bool {
    guard let documents = tresor.documents else { return false }
    
    var result = false
    
    for case let tresorDocument as TresorDocument in documents {
      if let items = tresorDocument.documentitems {
        for case let item as TresorDocumentItem in items where item.itemStatus == .shouldBeEncryptedByDevice {
          result = true
          break
        }
      }
    }
    
    return result
  }
  
  public func encryptAllDocumentItemsThatShouldBeEncryptedByDevice(tresor: Tresor, masterKey: TresorKey) {
    guard let context = self.icloudCoreDataManager?.privateChildManagedObjectContext(),
      let tempTresor = context.object(with: tresor.objectID) as? Tresor,
      let documents = tempTresor.documents
      else { return }
    
    celeturKitLogger.debug("encryptAllDocumentItemsThatShouldBeEncryptedByDevice()")
    
    context.perform {
      do {
        for case let tresorDocument as TresorDocument in documents {
          if let items = tresorDocument.documentitems {
            for case let item as TresorDocumentItem in items where item.itemStatus == .shouldBeEncryptedByDevice {
              let _ = item.encryptMessagePayload(masterKey: masterKey)
            }
          }
        }
      
        celeturKitLogger.debug("save for encryptAllDocumentItemsThatShouldBeEncryptedByDevice...")
        try context.save()
        
        self.saveChanges()
      } catch {
        celeturKitLogger.error("Error while saving encryptAllDocumentItemsThatShouldBeEncryptedByDevice...",error:error)
      }
    }
  }
  
  // MARK: - Delete Entities
  
  public func deleteTresor(tresor: Tresor, completionAfterDelete: (()->Void)? = nil) {
    if let context = tresor.managedObjectContext {
      tresor.deleteTresor()
      
      context.performSave(contextInfo: "deleting tresor object", completion: {
        self.saveChanges()
        
        DispatchQueue.main.async {
          if let cad = completionAfterDelete {
            cad()
          }
        }
      })
    }
  }
  
  public func deleteTresorUserDevice(userDevice:TresorUserDevice) {
    if let moc = userDevice.managedObjectContext {
      moc.delete(userDevice)
      
      moc.performSave(contextInfo: "deleting tresorUserDevice object", completion: {
        self.saveChanges()
      })
    }
  }
  
  // MARK: - create FetchedResultsController
  
  public func createAndFetchTresorFetchedResultsController(delegate: NSFetchedResultsControllerDelegate?) throws -> NSFetchedResultsController<Tresor>? {
    var result : NSFetchedResultsController<Tresor>?
    
    if let moc = self.icloudCoreDataManager?.mainManagedObjectContext {
      result = try Tresor.createAndFetchTresorFetchedResultsController(context: moc)
      
      result?.delegate = delegate
    }
    
    return result
  }
  
  public func createAndFetchUserdeviceFetchedResultsController() throws -> NSFetchedResultsController<TresorUserDevice>? {
    var result : NSFetchedResultsController<TresorUserDevice>?
    
    if let moc = self.icloudCoreDataManager?.mainManagedObjectContext {
      result = try TresorUserDevice.createAndFetchUserdeviceFetchedResultsController(context: moc)
    }
    
    return result
  }
  
  
  public func createAndFetchTresorDocumentItemFetchedResultsController(tresor:Tresor?) throws -> NSFetchedResultsController<TresorDocumentItem>? {
    var result : NSFetchedResultsController<TresorDocumentItem>?
    
    if let moc = self.getCoreDataManager()?.mainManagedObjectContext {
      result = try TresorDocumentItem.createAndFetchTresorDocumentItemFetchedResultsController(context: moc, tresor: tresor)
    }
    
    return result
  }
  
  // MARK: - Reset Data
  
  public func resetChangeTokens() {
    self.icloudCoreDataManager?.cloudKitManager?.ckPersistenceState.flushChangedIds()
    self.icloudCoreDataManager?.cloudKitManager?.ckPersistenceState.flushServerChangeTokens()
  }
  
  public func removeAllCloudKitData() {
    self.icloudCoreDataManager?.cloudKitManager?.deleteAllRecordsForZone()
  }
  
  public func removeAllCoreData() {
    self.removeCoreData(for: self.icloudCoreDataManager)
  }
  
  public func removeCoreData(for coreDataManager:CoreDataManager?) {
    guard let cdm = coreDataManager else { return }
    
    let tempMoc = cdm.privateChildManagedObjectContext()
    
    do {
      cdm.removeAllEntities(context: tempMoc, entityName: "TresorDocumentItem")
      cdm.removeAllEntities(context: tempMoc, entityName: "TresorDocument")
      cdm.removeAllEntities(context: tempMoc, entityName: "Tresor")
      cdm.removeAllEntities(context: tempMoc, entityName: "TresorUserDevice")
      cdm.removeAllEntities(context: tempMoc, entityName: "TresorAudit")
      
      try tempMoc.save()
      
      cdm.saveChanges(notifyChangesToCloudKit:false)
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
