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
  public var currentTresorUserDevice : TresorUserDevice?
  public var tresorCoreDataManager : CoreDataManager?
  public var userDevices: [TresorUserDevice]? {
    guard let moc = self.tresorCoreDataManager?.mainManagedObjectContext else { return nil }
    
    return TresorUserDevice.loadUserDevices(context: moc)
  }
  
  var tresorMetaInfoCoreDataManager : CoreDataManager?
  var apnDeviceToken : Data?
  
  let initModelDispatchGroup  = DispatchGroup()
  
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
        
        self.loadCurrentDeviceInfo()
        
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
          
          self.loadCurrentTresorUserDevice()
          
          celeturKitLogger.debug("TresorModel.switchTresorCoreDataManager() --leave--")
          self.initModelDispatchGroup.leave()
          
          NotificationCenter.default.post(name: .onTresorUserInfoChanged, object: self)
        }
      } catch {
        celeturKitLogger.error("Error while setup core data manager ...",error:error)
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
  
  fileprivate func loadCurrentTresorUserDevice() {
    if let cdm = self.tresorCoreDataManager, let cdi = currentDeviceInfo, let userName = self.currentUserInfo?.userDisplayName {
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
  
  public func   setCurrentDeviceAPNToken(deviceToken:Data) {
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
    self.tresorCoreDataManager?.cloudKitManager?.fetchChanges(in: databaseScope, completion: completion)
  }
  
  
  public func createScratchpadTresorObject(tresor: Tresor?) -> TempTresorObject? {
    return TempTresorObject(tresorModel: self, tresor: tresor)
  }
  
  
  public func encryptAllDocumentItemsThatShouldBeEncryptedByDevice(tresor: Tresor, masterKey: TresorKey) {
    guard let documents = tresor.documents,
      let context = self.tresorCoreDataManager?.privateChildManagedObjectContext()
      else { return }
    
    celeturKitLogger.debug("encryptAllDocumentItemsThatShouldBeEncryptedByDevice()")
    
    for case let tresorDocument as TresorDocument in documents {
      if let items = tresorDocument.documentitems {
        for case let item as TresorDocumentItem in items where item.itemStatus == .shouldBeEncryptedByDevice {
          
          if let tempItem = context.object(with: item.objectID) as? TresorDocumentItem {
            let _ = tempItem.encryptMessagePayload(masterKey: masterKey)
          }
        }
      }
    }
    
    context.performSave(contextInfo: "save encryptAllDocumentItemsThatShouldBeEncryptedByDevice") {
      celeturKitLogger.debug("encryptAllDocumentItemsThatShouldBeEncryptedByDevice() finished.")
      self.saveChanges()
    }
  }
  
  // MARK: - Delete Entities
  
  public func deleteTresor(tresor: Tresor) {
    if let context = tresor.managedObjectContext {
      tresor.deleteTresor()
      
      context.performSave(contextInfo: "deleting tresor object", completion: {
        self.saveChanges()
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
  
  // MARK: - Reset Data
  
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
  
}
