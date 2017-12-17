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

public enum TresorModelStoreType {
  case local
  case icloud
}

public struct TresorFetchedResultsControllerType {
  public var storeType : TresorModelStoreType
  public var fetchResultsController : NSFetchedResultsController<Tresor>
}

public class TresorModel {
  
  public var currentUserInfo : UserInfo?
  
  fileprivate var icloudCoreDataManager : CoreDataManager?
  fileprivate var localCoreDataManager : CoreDataManager?
  
  var tresorMetaInfoCoreDataManager : CoreDataManager?
  var apnDeviceToken : Data?
  
  let initModelDispatchGroup  = DispatchGroup()
  
  public init() {
    NotificationCenter.default.addObserver(self,
                                           selector: #selector(checkICloudAvailability),
                                           name: .CKAccountChanged,
                                           object: nil)
    
  }
  
  public func getCoreDataManager(storeType:TresorModelStoreType) -> CoreDataManager? {
    switch(storeType) {
    case .local: return self.localCoreDataManager
    case .icloud: return self.icloudCoreDataManager
    }
  }
  
  @objc
  func checkICloudAvailability(_ notification: Notification? = nil) {
    celeturKitLogger.debug("checkICloudAvailability()")
    
    self.requestUserDiscoverabilityPermission()
  }
  
  public func completeSetup() {
    celeturKitLogger.debug("TresorModel.completeSetup() --enter--")
    
    self.requestUserDiscoverabilityPermission()
    self.createMetainfoCoreDataManager()
    self.createLocalCoreDataManager()
    
    self.initModelDispatchGroup.notify(queue: DispatchQueue.main) {
      celeturKitLogger.debug("TresorModel.initModelDispatchGroup.notify()")
      
      NotificationCenter.default.post(name: .onTresorModelReady, object: self)
    }
  }
  
  fileprivate func createMetainfoCoreDataManager() {
    self.initModelDispatchGroup.enter()
    let cdm = CoreDataManager(modelName: celetorKitMetaModelName,
                              using:Bundle(identifier:celeturKitIdentifier)!,
                              inAppGroupContainer:appGroup,
                              forUserId: nil)
    
    cdm.completeSetup { error in
      if error == nil {
        self.tresorMetaInfoCoreDataManager = cdm
        
        self.loadCurrentDeviceInfo()
        
        celeturKitLogger.debug("TresorModel.createMetainfoCoreDataManager --leave--")
        self.initModelDispatchGroup.leave()
      }
    }
  }
  
  fileprivate func createIcloudCoreDataManager(userIdentity:CKUserIdentity) {
    guard let userId = userIdentity.userRecordID?.recordName else { return }
    
    let cdm = CoreDataManager(modelName: celetorKitModelName,
                              using:Bundle(identifier:celeturKitIdentifier)!,
                              inAppGroupContainer:appGroup,
                              forUserId: userId)
    
    cdm.completeSetup { error in
      celeturKitLogger.debug("TresorModel.createIcloudCoreDataManager()")
      
      do {
        let ckps = try CloudKitPersistenceState(appGroupContainerId: appGroup, forUserId:userId)
        
        let ckm = CloudKitManager(cloudKitPersistenceState: ckps, coreDataManager: cdm)
        ckm.createCloudKitSubscription()
        
        cdm.cloudKitManager = ckm
        
        DispatchQueue.main.async {
          self.icloudCoreDataManager = cdm
          
          self.currentUserInfo = UserInfo.loadUserInfo(self.tresorMetaInfoCoreDataManager!,userIdentity:userIdentity)
          
          self.findAndUpdateCurrentTresorUserDevice(cdm: cdm)
          
          celeturKitLogger.debug("TresorModel.createIcloudCoreDataManager() --leave--")
          self.initModelDispatchGroup.leave()
          
          NotificationCenter.default.post(name: .onTresorUserInfoChanged, object: self)
        }
      } catch {
        celeturKitLogger.error("Error while setup core data manager ...",error:error)
      }
    }
  }
  
  
  fileprivate func createLocalCoreDataManager() {
    self.initModelDispatchGroup.enter()
    
    let cdm = CoreDataManager(modelName: celetorKitModelName,
                              using:Bundle(identifier:celeturKitIdentifier)!,
                              inAppGroupContainer:appGroup,
                              forUserId: nil)
    
    cdm.completeSetup { error in
      celeturKitLogger.debug("createLocalCoreDataManager()")
      
      if error == nil {
        DispatchQueue.main.async {
          self.localCoreDataManager = cdm
          
          self.findAndUpdateCurrentTresorUserDevice(cdm: cdm)
          
          celeturKitLogger.debug("TresorModel.createLocalCoreDataManager() --leave--")
          self.initModelDispatchGroup.leave()
        }
      }
    }
  }
  
  
  fileprivate func loadCurrentDeviceInfo() {
    if let metacdm = self.tresorMetaInfoCoreDataManager {
      let moc = metacdm.mainManagedObjectContext
      
      DeviceInfo.loadCurrentDeviceInfo(context: moc, apnDeviceToken: self.apnDeviceToken)
      metacdm.saveChanges(notifyChangesToCloudKit:false)
    }
  }
  
  fileprivate func findAndUpdateCurrentTresorUserDevice(cdm: CoreDataManager) {
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
        
        tresorUserDevice!.updateCurrentUserDevice(deviceInfo: cdi, userName: self.currentUserInfo?.userDisplayName)
        
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
   
    if let cdm = self.localCoreDataManager {
      cdm.saveChanges(notifyChangesToCloudKit:false)
    }
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
                self.createIcloudCoreDataManager(userIdentity:u)
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
  
  
  public func createScratchpadTresorObject(tresor: Tresor?, storeType:TresorModelStoreType) -> TempTresorObject? {
    return TempTresorObject(tresorCoreDataManager: self.getCoreDataManager(storeType: storeType), tresor: tresor)
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
  
  public func createAndFetchTresorFetchedResultsControllers(delegate: NSFetchedResultsControllerDelegate?) throws -> [TresorFetchedResultsControllerType]? {
    var result : [TresorFetchedResultsControllerType] = []
    
    if let moc = self.icloudCoreDataManager?.mainManagedObjectContext {
      let fetchedResultsController = TresorFetchedResultsControllerType(storeType: .icloud,
                                                                      fetchResultsController: try Tresor.createAndFetchTresorFetchedResultsController(context: moc))
      
      fetchedResultsController.fetchResultsController.delegate = delegate
      
      result.append(fetchedResultsController)
    }
    
    if let moc = self.localCoreDataManager?.mainManagedObjectContext {
      let fetchedResultsController = TresorFetchedResultsControllerType(storeType: .local,
                                                                      fetchResultsController: try Tresor.createAndFetchTresorFetchedResultsController(context: moc))
      
      fetchedResultsController.fetchResultsController.delegate = delegate
      
      result.append(fetchedResultsController)
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
  
  
  public func createAndFetchTresorDocumentItemFetchedResultsController(tresor:Tresor?,storeType: TresorModelStoreType) throws -> NSFetchedResultsController<TresorDocumentItem>? {
    var result : NSFetchedResultsController<TresorDocumentItem>?
    
    if let moc = self.getCoreDataManager(storeType: storeType)?.mainManagedObjectContext {
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
    self.removeCoreData(for: self.localCoreDataManager)
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
