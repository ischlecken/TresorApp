//
//  Created by Feldmaus on 06.08.17.
//  Copyright © 2017 prisnoc. All rights reserved.
//

import Foundation
import Contacts
import CloudKit

extension Notification.Name {
  public static let onTresorModelReady = Notification.Name("onTresorModelReady")
  public static let onTresorCloudkitStatusChanged = Notification.Name("onTresorCloudkitStatusChanged")
}

let appGroup = "group.net.prisnoc.Celetur"
let celeturKitIdentifier = "net.prisnoc.CeleturKit"
let celetorKitModelName = "CeleturKit"
let celetorKitMetaModelName = "CeleturKitMetaInfo"

public class TresorModel {
  
  public var currentUserInfo : UserInfo?
  
  fileprivate var coreDataManager : CoreDataManager?
  fileprivate var cloudkitPersistenceState : CloudKitPersistenceState?
  fileprivate var tresorMetaInfoCoreDataManager : CoreDataManager?
  fileprivate var apnDeviceToken : Data?
  fileprivate let initModelDispatchGroup  = DispatchGroup()
  
  // used to get the .ckaccountchanged notification
  fileprivate let ckDefaultContainer : CKContainer
  fileprivate var ckAccountStatus: CKAccountStatus = .couldNotDetermine
  
  public var ckUserId : String? {
    get {
      return self.currentUserInfo?.id
    }
  }
  
  public init() {
    self.ckDefaultContainer = CKContainer.default()
    
    NotificationCenter.default.addObserver(self,
                                           selector: #selector(checkICloudAvailability),
                                           name: .CKAccountChanged,
                                           object: nil)
    
    
  }
  
  public func getCoreDataManager() -> CoreDataManager? {
    return self.coreDataManager
  }
  
  @objc
  func checkICloudAvailability(_ notification: Notification? = nil) {
    celeturKitLogger.debug("checkICloudAvailability()")
    
    self.requestCKAccountStatus()
  }
  
  fileprivate func requestCKAccountStatus() {
    self.ckDefaultContainer.accountStatus { [unowned self] (accountStatus, error) in
      if let error = error {
        celeturKitLogger.error("Error while request CloudKit account status", error: error)
      }
      
      self.ckAccountStatus = accountStatus
      
      celeturKitLogger.debug("ckAccountStatus="+String(self.ckAccountStatus.rawValue))
      
      switch self.ckAccountStatus {
      case .available:
        self.requestUserDiscoverabilityPermission()
      case .noAccount:
        self.resetCloudKitManager()
      case .restricted:
        break
      case .couldNotDetermine:
        self.resetCloudKitManager()
      }
    }
  }
  
  public func completeSetup() {
    celeturKitLogger.debug("TresorModel.completeSetup() --enter--")
    
    self.createCoreDataManager()
    self.createMetainfoCoreDataManager()
    self.requestCKAccountStatus()
    
    self.initModelDispatchGroup.notify(queue: DispatchQueue.main) {
      celeturKitLogger.debug("TresorModel.initModelDispatchGroup.notify()")
      
      if let cdm = self.coreDataManager, let cdi = currentDeviceInfo {
        TresorUserDevice.loadLocalUserDevice(context: cdm.mainManagedObjectContext, deviceInfo: cdi)
        
        cdm.saveChanges(notifyChangesToCloudKit: false)
      }
      
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
  
  fileprivate func createCoreDataManager() {
    self.initModelDispatchGroup.enter()
    
    let cdm = CoreDataManager(modelName: celetorKitModelName,
                              using:Bundle(identifier:celeturKitIdentifier)!,
                              inAppGroupContainer:appGroup)
    
    cdm.completeSetup { error in
      celeturKitLogger.debug("createCoreDataManager()")
      
      do {
        self.cloudkitPersistenceState = try CloudKitPersistenceState(appGroupContainerId: appGroup)
        
      } catch {
        celeturKitLogger.error("Error while init cloudkitPersistenceState...",error:error)
      }
      
      self.coreDataManager = cdm
      
      DispatchQueue.main.async {
        celeturKitLogger.debug("createCoreDataManager() --leave--")
        self.initModelDispatchGroup.leave()
      }
    }
  }
  
  
  fileprivate func createCloudKitManager(userIdentity:CKUserIdentity) {
    guard let userId = userIdentity.userRecordID?.recordName,
      let cdm = self.coreDataManager,
      let ckps = self.cloudkitPersistenceState
      else { return }
    
    
    let ckm = CloudKitManager(cloudKitPersistenceState: ckps, coreDataManager: cdm, ckUserId:userId)
    ckm.createCloudKitSubscription()
    
    cdm.connectToCloudKitManager(ckm: ckm)
    
    DispatchQueue.main.async {
      let cui = UserInfo.loadUserInfo(self.tresorMetaInfoCoreDataManager!,userIdentity:userIdentity)
      
      self.currentUserInfo = cui
      
      self.findAndUpdateCurrentTresorUserDevice(cdm: cdm, cui: cui)
      
      NotificationCenter.default.post(name: .onTresorCloudkitStatusChanged, object: self)
      
      celeturKitLogger.debug("createCloudKitManager() --success--")
    }
  }
  
  fileprivate func resetCloudKitManager() {
    guard let cdm = self.coreDataManager else { return }
    
    cdm.disconnectFromCloudKitManager()
    
    self.currentUserInfo = nil
    
    DispatchQueue.main.async {
      NotificationCenter.default.post(name: .onTresorCloudkitStatusChanged, object: self)
    }
    
    celeturKitLogger.debug("resetCloudKitManager()")
  }
  
  public func icloudAvailable() -> Bool {
    return self.currentUserInfo != nil
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
      fetchRequest.predicate = NSPredicate(format: "ckuserid = %@", cui.id!)
      fetchRequest.fetchBatchSize = 1
      
      do {
        var tresorUserDevice : TresorUserDevice?
        
        let records = try moc.fetch(fetchRequest)
        if records.count>0 {
          tresorUserDevice = records[0]
        } else {
          tresorUserDevice = TresorUserDevice.createCurrentUserDevice(context: moc, deviceInfo: cdi)
        }
        
        tresorUserDevice!.updateCurrentUserInfo(currentUserInfo: cui)
        
        cdm.saveChanges(notifyChangesToCloudKit:true)
      } catch {
        celeturKitLogger.error("Error while saving tresor userdevice info...",error:error)
      }
    }
  }
  
  public func saveChanges(notifyCloudKit:Bool=true) {
    if let cdm = self.coreDataManager {
      cdm.saveChanges(notifyChangesToCloudKit:notifyCloudKit)
    }
  }
  
  
  fileprivate func requestUserDiscoverabilityPermission() {
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
  
  
  public func fetchCloudKitChanges(in databaseScope: CKDatabaseScope, completion: @escaping () -> Void) {
    self.coreDataManager?.fetchCloudKitChanges(in: databaseScope, completion: completion)
  }
  
  public func createScratchpadTresorObject(tresor: Tresor) -> TempTresorObject? {
    return TempTresorObject(tresorCoreDataManager: self.getCoreDataManager(), tresor: tresor)
  }
  
  
  public func createScratchpadLocalDeviceTresorObject() -> TempTresorObject? {
    return TempTresorObject(tresorCoreDataManager: self.getCoreDataManager(), ckUserId: nil, isReadOnly: false)
  }
  
  public func createScratchpadICloudTresorObject() -> TempTresorObject? {
    guard let ckuserid = self.currentUserInfo?.id  else { return nil }
    
    return TempTresorObject(tresorCoreDataManager: self.getCoreDataManager(), ckUserId: ckuserid, isReadOnly: false)
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
    guard let context = self.coreDataManager?.privateChildManagedObjectContext(),
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
    
    if let moc = self.coreDataManager?.mainManagedObjectContext {
      result = try Tresor.createAndFetchTresorFetchedResultsController(context: moc)
      
      if let r = result {
        r.updateReadonlyInfo(ckUserId: self.ckUserId)
      }
      
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
  
  
  public func displayInfoForCkUserId(ckUserId:String?) -> String {
    var result = "This Device"
    
    if let cdi = currentDeviceInfo {
      if let ui = UIUserInterfaceIdiom(rawValue: Int(cdi.deviceuitype)) {
        switch ui {
        case .phone:
          result = "This iPhone"
        case .pad:
          result = "This iPad"
        default:
          break
        }
      }
      
      result += " ("
      
      if let s = cdi.devicemodel {
        result += "\(s)"
      }
      
      if let s = cdi.devicename {
        result += " '\(s)'"
      }
      
      if let s0 = cdi.devicesystemname,let s1 = cdi.devicesystemversion {
        result += " with \(s0) \(s1)"
      }
      
      result += ")"
    }
    
    if let userid = ckUserId {
      result = "icloud: \(userid)"
      
      if let cui = self.currentUserInfo, let currentCkUserId = cui.id, currentCkUserId == userid, let userDisplayName = cui.userDisplayName {
        result = "icloud: \(userDisplayName)"
      }
    }
    
    return result
  }
  
}
