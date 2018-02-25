//
//  Created by Feldmaus on 06.08.17.
//  Copyright © 2017 prisnoc. All rights reserved.
//

import Foundation
import CloudKit

extension Notification.Name {
  public static let onTresorCloudkitStatusChanged = Notification.Name("onTresorCloudkitStatusChanged")
}

public class CloudKitModel {
  
  public var currentUserInfo : UserInfo?
  public var currentCloudTresorUserDevice : TresorUserDevice?
  
  fileprivate var coreDataManager : CoreDataManager
  fileprivate var tresorMetaInfoCoreDataManager : CoreDataManager
  
  // used to get the .ckaccountchanged notification
  fileprivate let ckDefaultContainer : CKContainer

  fileprivate var cloudkitPersistenceState : CloudKitPersistenceState
  fileprivate var ckAccountStatus: CKAccountStatus = .couldNotDetermine
  
  public var ckUserId : String? {
    get {
      return self.currentUserInfo?.id
    }
  }
  
  init(coreDataManager : CoreDataManager,
       tresorMetaInfoCoreDataManager : CoreDataManager,
       cloudkitPersistenceState: CloudKitPersistenceState) {
    self.coreDataManager = coreDataManager
    self.tresorMetaInfoCoreDataManager = tresorMetaInfoCoreDataManager
    self.cloudkitPersistenceState = cloudkitPersistenceState
    
    self.ckDefaultContainer = CKContainer.default()
    
    NotificationCenter.default.addObserver(self,
                                           selector: #selector(checkICloudAvailability),
                                           name: .CKAccountChanged,
                                           object: nil)
  }
  
  @objc
  func checkICloudAvailability(_ notification: Notification? = nil) {
    celeturKitLogger.debug("checkICloudAvailability()")
    
    self.requestCKAccountStatus()
  }
  
  func requestCKAccountStatus() {
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
  
  fileprivate func createCloudKitManager(userIdentity:CKUserIdentity) {
    guard let userId = userIdentity.userRecordID?.recordName, let cdi = currentDeviceInfo
      else { return }
    
    let cdm = self.coreDataManager
    let ckps = self.cloudkitPersistenceState
    let ckm = CloudKitManager(cloudKitPersistenceState: ckps, coreDataManager: cdm, ckUserId:userId)
    ckm.createCloudKitSubscription()
    
    cdm.connectToCloudKitManager(ckm: ckm)
    
    DispatchQueue.main.async {
      let cui = UserInfo.loadUserInfo(self.tresorMetaInfoCoreDataManager,userIdentity:userIdentity)
      
      self.currentUserInfo = cui
      
      self.currentCloudTresorUserDevice = cdi.currentCloudTresorUserDevice(cdm: cdm, cui: cui)
      
      NotificationCenter.default.post(name: .onTresorCloudkitStatusChanged, object: self)
      
      celeturKitLogger.debug("CloudKitModel.createCloudKitManager() --success--")
    }
  }
  
  fileprivate func resetCloudKitManager() {
    self.coreDataManager.disconnectFromCloudKitManager()
    
    self.currentUserInfo = nil
    self.currentCloudTresorUserDevice = nil
    
    DispatchQueue.main.async {
      NotificationCenter.default.post(name: .onTresorCloudkitStatusChanged, object: self)
    }
    
    celeturKitLogger.debug("CloudKitModel.resetCloudKitManager()")
  }
  
  public func icloudAvailable() -> Bool {
    return self.currentUserInfo != nil
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
  
}
