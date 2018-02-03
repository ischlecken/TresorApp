//
//  Created by Feldmaus on 06.08.17.
//  Copyright © 2017 prisnoc. All rights reserved.
//

import Foundation
import CloudKit

extension Notification.Name {
  public static let onTresorModelReady = Notification.Name("onTresorModelReady")
}

let appGroup = "group.net.prisnoc.Celetur"
let celeturKitIdentifier = "net.prisnoc.CeleturKit"
let celetorKitModelName = "CeleturKit"
let celetorKitMetaModelName = "CeleturKitMetaInfo"

public class TresorModel {
  
  fileprivate var currentLocalTresorUserDevice : TresorUserDevice?
  
  fileprivate var coreDataManager : CoreDataManager?
  fileprivate var tresorMetaInfoCoreDataManager : CoreDataManager?
  fileprivate var apnDeviceToken : Data?
  fileprivate let initModelDispatchGroup  = DispatchGroup()
  
  fileprivate var cloudKitModel : CloudKitModel?
  
  public var ckUserId : String? {
    get {
      return self.cloudKitModel?.currentUserInfo?.id
    }
  }
  
  public init() {
    
  }
  
  public func getCoreDataManager() -> CoreDataManager? {
    return self.coreDataManager
  }
  
  public func completeSetup() {
    celeturKitLogger.debug("TresorModel.completeSetup() --enter--")
    
    self.createCoreDataManager()
    self.createMetainfoCoreDataManager()
    
    self.initModelDispatchGroup.notify(queue: DispatchQueue.main) {
      celeturKitLogger.debug("TresorModel.initModelDispatchGroup.notify()")
      
      if let cdm = self.coreDataManager,
        let tmicdm = self.tresorMetaInfoCoreDataManager,
        let cdi = currentDeviceInfo {
        self.currentLocalTresorUserDevice = cdi.currentLocalTresorUserDevice(cdm: cdm)
        
        cdm.saveChanges(notifyChangesToCloudKit: false)
        
        do {
          let cloudkitPersistenceState = try CloudKitPersistenceState(appGroupContainerId: appGroup)
          
          self.cloudKitModel = CloudKitModel(coreDataManager: cdm,
                                             tresorMetaInfoCoreDataManager: tmicdm,
                                             cloudkitPersistenceState: cloudkitPersistenceState)
          
          self.cloudKitModel!.requestCKAccountStatus()
        
          NotificationCenter.default.post(name: .onTresorModelReady, object: self)
        } catch {
          celeturKitLogger.error("Error while init cloudkitPersistenceState...",error:error)
        }
      }
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
        
        cdm.loadCurrentDeviceInfo(apnDeviceToken: self.apnDeviceToken)
        
        celeturKitLogger.debug("TresorModel.createMetainfoCoreDataManager --leave--")
        self.initModelDispatchGroup.leave()
      }
    }
  }
  
  fileprivate func createCoreDataManager() {
    self.initModelDispatchGroup.enter()
    
    let cdm = CoreDataManager(modelName: celetorKitModelName,
                              using:Bundle(identifier:celeturKitIdentifier)!,
                              inAppGroupContainer:appGroup)
    
    cdm.completeSetup { error in
      celeturKitLogger.debug("createCoreDataManager()")
      
      self.coreDataManager = cdm
      
      DispatchQueue.main.async {
        celeturKitLogger.debug("createCoreDataManager() --leave--")
        self.initModelDispatchGroup.leave()
      }
    }
  }
  
  
  
  public func saveChanges(notifyCloudKit:Bool=true) {
    if let cdm = self.coreDataManager {
      cdm.saveChanges(notifyChangesToCloudKit:notifyCloudKit)
    }
  }
  
  
  public func setCurrentDeviceAPNToken(deviceToken:Data) {
    celeturKitLogger.debug("setCurrentDeviceAPNToken(\(deviceToken.hexEncodedString()))")
    
    self.apnDeviceToken = deviceToken
    
    if let cdi = currentDeviceInfo {
      cdi.updateAPNToken(deviceToken: deviceToken)
    }
  }
  
  
  
  public func fetchCloudKitChanges(in databaseScope: CKDatabaseScope, completion: @escaping () -> Void) {
    self.coreDataManager?.fetchCloudKitChanges(in: databaseScope, completion: completion)
  }
  
  public func createScratchpadTresorObject(tresor: Tresor) -> TempTresorObject? {
    return TempTresorObject(tresorModel:self, tresorCoreDataManager: self.getCoreDataManager(), tresor: tresor)
  }
  
  
  public func createScratchpadLocalDeviceTresorObject() -> TempTresorObject? {
    return TempTresorObject(tresorModel:self, tresorCoreDataManager: self.getCoreDataManager(), ckUserId: nil, isReadOnly: false)
  }
  
  public func createScratchpadICloudTresorObject() -> TempTresorObject? {
    guard let ckuserid = self.ckUserId  else { return nil }
    
    return TempTresorObject(tresorModel:self, tresorCoreDataManager: self.getCoreDataManager(), ckUserId: ckuserid, isReadOnly: false)
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
    
    if let moc = self.coreDataManager?.mainManagedObjectContext {
      result = try Tresor.createAndFetchTresorFetchedResultsController(context: moc)
      
      if let r = result {
        r.updateReadonlyInfo(ckUserId: self.ckUserId)
      }
      
      result?.delegate = delegate
    }
    
    return result
  }
  
  public func createAndFetchTresorLogFetchedResultsController(delegate: NSFetchedResultsControllerDelegate?) throws -> NSFetchedResultsController<TresorLog>? {
    var result : NSFetchedResultsController<TresorLog>?
    
    if let moc = self.coreDataManager?.mainManagedObjectContext {
      result = try TresorLog.createAndFetchTresorLogFetchedResultsController(context: moc)
      
      result?.delegate = delegate
    }
    
    return result
  }
  
  public func createAndFetchUserdeviceFetchedResultsController() throws -> NSFetchedResultsController<TresorUserDevice>? {
    var result : NSFetchedResultsController<TresorUserDevice>?
    
    if let moc = self.coreDataManager?.mainManagedObjectContext {
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
    self.coreDataManager?.resetChangeTokens()
  }
  
  public func removeAllCloudKitData() {
    self.coreDataManager?.resetChangeTokens()
  }
  
  public func removeAllCoreData() {
    self.removeCoreData(for: self.coreDataManager)
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
  
  public func icloudAvailable() -> Bool {
    return self.cloudKitModel?.icloudAvailable() ?? false
  }
  
  public func currentTresorUserDevice(ckUserId: String?) -> TresorUserDevice? {
    if ckUserId == nil {
      return self.currentLocalTresorUserDevice
    }
    
    return self.cloudKitModel?.currentCloudTresorUserDevice
  }
  
  public func displayInfoForCkUserId(ckUserId:String?) -> String? {
    return currentDeviceInfo?.displayInfoForCkUserId(ckUserId: ckUserId, userInfo: self.cloudKitModel?.currentUserInfo)
  }
}
