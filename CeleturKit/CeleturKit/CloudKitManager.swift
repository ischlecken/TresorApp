//
//  Created by Feldmaus on 06.08.17.
//  Copyright © 2017 prisnoc. All rights reserved.
//

import Foundation
import Contacts
import CloudKit

public class CloudKitManager {
  
  let tresorModel:TresorModel
  let privateDB : CKDatabase
  let sharedDB : CKDatabase
  let createZoneGroup : DispatchGroup
  
  let tresoruserZone = "tresoruser"
  let tresorZone = "tresor"
  
  var tresoruserZoneId : CKRecordZoneID?
  var tresorZoneId : CKRecordZoneID?
  
  let privateSubscriptionId = "private-changes"
  let sharedSubscriptionId = "shared-changes"
  
  let ckPersistenceState : CloudKitPersistenceState
  
  public init(tresorModel:TresorModel,appGroupContainer appGroupContainerId:String) {
    self.tresorModel = tresorModel
    self.ckPersistenceState = CloudKitPersistenceState(appGroupContainerId: appGroupContainerId)
    
    self.privateDB = CKContainer.default().privateCloudDatabase
    self.sharedDB = CKContainer.default().sharedCloudDatabase
    
    self.createZoneGroup = DispatchGroup()
    
    self.tresoruserZoneId = self.createZones(zoneName: tresoruserZone)
    self.tresorZoneId = self.createZones(zoneName: tresorZone)
  }
  
  
  func getPrivateDB() -> CKDatabase {
    return self.privateDB
  }
  
  fileprivate func createNewCKRecord(_ o:NSManagedObject) -> CKRecord? {
    let ed = o.entity
    let entityName = ed.name
    let zoneId = entityName!.starts(with: "TresorUser") ? self.tresoruserZoneId : self.tresorZoneId
    let id = o.value(forKey: "id") as? String
    
    guard let zId = zoneId, let rId = id, let eName = entityName else { return nil }
    
    return CKRecord(recordType: eName, recordID:  CKRecordID(recordName: rId, zoneID: zId))
  }
  
  fileprivate func createCKRecord(_ o:NSManagedObject) -> CKRecord? {
    let result = o.storedCKRecord()
    
    return result != nil ? result : self.createNewCKRecord(o)
  }
  
  func saveChanges(moc:NSManagedObjectContext) {
    var records = [CKRecord]()
    var deletedRecordIds = [CKRecordID]()
    
    for o in moc.updatedObjects {
      celeturKitLogger.debug("updated:\(o)")
      
      if o.isCKStoreableObject() {
        let record = self.createCKRecord(o)
        if let r = record {
          let ed = o.entity
          let attributesByName = ed.attributesByName
          
          for (n,_) in attributesByName {
            let v = o.value(forKey: n) as? CKRecordValue
            if n == "ckdata" {
              continue
            }
            
            r.setObject(v, forKey: n)
          }
          
          records.append(r)
          
          self.ckPersistenceState.addChangedObject(o: o)
        }
      }
    }
    
    for o in moc.deletedObjects {
      celeturKitLogger.debug("deleted:\(o)")
      
      if o.isCKStoreableObject() {
        let record = o.storedCKRecord()
        if let r = record {
          deletedRecordIds.append(r.recordID)
          self.ckPersistenceState.addDeletedObject(o: o)
        }
      }
    }
    
    if records.count>0 || deletedRecordIds.count>0 {
      self.ckPersistenceState.saveChangedIds()
      
      let modifyOperation = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: deletedRecordIds)
      
      modifyOperation.completionBlock = {
        celeturKitLogger.debug("modify finished")
      }
      modifyOperation.modifyRecordsCompletionBlock = { savedRecords, deletedRecordIDs, error in
        if let e = error {
          let _ = self.handleError(context: "saveChanges", error: e)
        } else {
          celeturKitLogger.debug("savedRecords:\(String(describing: savedRecords))")
          self.ckPersistenceState.flushChangedIds()
        }
      }
      
      self.privateDB.add(modifyOperation)
    }
  }
  
  
  
  fileprivate func handleError(context:String, error:Error) -> CeleturKitError? {
    celeturKitLogger.error("CloudKit error in context \(context)", error: error)
    
    let ckerror = error as? CKError
    
    if let ckerror = ckerror {
      switch ckerror.code {
      case .alreadyShared:
        celeturKitLogger.debug("An error indicating that a record or share cannot be saved because doing so would cause the same hierarchy of records to exist in multiple shares.")
      case .assetFileModified:
        celeturKitLogger.debug("An error indicating that the content of the specified asset file was modified while being saved.")
      case .assetFileNotFound:
        celeturKitLogger.debug("An error that is returned when the specified asset file is not found.")
      case .badContainer:
        celeturKitLogger.debug("An error that is returned when the specified container is unknown or unauthorized.")
      case .badDatabase:
        celeturKitLogger.debug("An error indicating that the operation could not be completed on the given database.")
      case .batchRequestFailed:
        celeturKitLogger.debug("An error indicating that the entire batch was rejected.")
      case .changeTokenExpired:
        celeturKitLogger.debug("An error indicating that the previous server change token is too old.")
      case .constraintViolation:
        celeturKitLogger.debug("An error indicating that the server rejected the request because of a conflict with a unique field.")
      case .incompatibleVersion:
        celeturKitLogger.debug("An error indicating that your app version is older than the oldest version allowed.")
      case .internalError:
        celeturKitLogger.debug("A nonrecoverable error encountered by CloudKit.")
      case .invalidArguments:
        celeturKitLogger.debug("An error that is returned when the specified request contains bad information.")
      case .limitExceeded:
        celeturKitLogger.debug("An error that is returned when a request to the server is too large.")
      case .managedAccountRestricted:
        celeturKitLogger.debug("An error that is returned when a request is rejected due to a managed-account restriction.")
      case .missingEntitlement:
        celeturKitLogger.debug("An error that is returned when the app is missing a required entitlement.")
      case .networkFailure:
        celeturKitLogger.debug("An error that is returned when the network is available but cannot be accessed.")
      case .networkUnavailable:
        celeturKitLogger.debug("An error that is returned when the network is not available.")
      case .notAuthenticated:
        celeturKitLogger.debug("An error indicating that the current user is not authenticated, and no user record was available.")
      case .operationCancelled:
        celeturKitLogger.debug("An error indicating that an operation was explicitly canceled.")
      case .partialFailure:
        celeturKitLogger.debug("An error indicating that some items failed, but the operation succeeded overall.")
      case .participantMayNeedVerification:
        celeturKitLogger.debug("An error that is returned when the user is not a member of the share.")
      case .permissionFailure:
        celeturKitLogger.debug("An error indicating that the user did not have permission to perform the specified save or fetch operation.")
      case .quotaExceeded:
        celeturKitLogger.debug("An error that is returned when saving the record would exceed the user’s current storage quota.")
      case .referenceViolation:
        celeturKitLogger.debug("An error that is returned when the target of a record's parent or share reference is not found.")
      case .requestRateLimited:
        celeturKitLogger.debug("Transfers to and from the server are being rate limited for the client at this time.")
      case .resultsTruncated:
        celeturKitLogger.debug("Deprecated: An error indicating that the query results were truncated by the server.")
      case .serverRecordChanged:
        celeturKitLogger.debug("An error indicating that the record was rejected because the version on the server is different.")
      case .serverRejectedRequest:
        celeturKitLogger.debug("An error indicating that the server rejected the request.")
      case .serverResponseLost:
        celeturKitLogger.debug("An error that is returned when the CloudKit service is unavailable.")
      case .serviceUnavailable:
        celeturKitLogger.debug("An error that is returned when the CloudKit service is unavailable.")
      case .tooManyParticipants:
        celeturKitLogger.debug("An error indicating that a share cannot be saved because too many participants are attached to the share.")
      case .unknownItem:
        celeturKitLogger.debug("An error that is returned when the specified record does not exist.")
      case .userDeletedZone:
        celeturKitLogger.debug("An error indicating that the user has deleted this zone from the settings UI.")
      case .zoneBusy:
        celeturKitLogger.debug("An error indicating that the server is too busy to handle the zone operation.")
      case .zoneNotFound:
        celeturKitLogger.debug("An error indicating that the specified record zone does not exist on the server.")
      }
    }
    
    return nil
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
      //self.fetchChanges(in: .shared) {}
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
  
  fileprivate func getChangeToken(tokenName:String) -> CKServerChangeToken? {
    return self.ckPersistenceState.getServerChangeToken(forName: tokenName)
  }
  
  fileprivate func setChangeToken(tokenName:String, changeToken: CKServerChangeToken) {
    self.ckPersistenceState.setServerChangeToken(token: changeToken, forName: tokenName)
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
    
    
    let tempMOC = self.tresorModel.createTempPrivateManagedObjectContext()
    
    operation.recordChangedBlock = { (record) in
      celeturKitLogger.debug("Record changed:\(record)")
      
      self.tresorModel.coreDataManager.updateManagedObject(context: tempMOC, usingRecord:record)
    }
    
    operation.recordWithIDWasDeletedBlock = { (recordId,recordType) in
      celeturKitLogger.debug("Record deleted:\(recordId)")
      
      self.tresorModel.coreDataManager.deleteManagedObject(context: tempMOC, usingEntityName: recordType, andId: recordId.recordName)
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
          } catch {
            celeturKitLogger.error("error saving ck changes to core data",error:error)
          }
        }
      }
      
      completion()
    }
    
    database.add(operation)
  }
  
  public func createZones(zoneName:String) -> CKRecordZoneID {
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
    
    return zoneID
  }
  
  
  public func requestUserDiscoverabilityPermission() {
    CKContainer.default().requestApplicationPermission(CKApplicationPermissions.userDiscoverability) { (status, error) in
      if let error=error {
        celeturKitLogger.error("Error requesting UserDiscoverabilityPermission", error: error)
      }
      
      celeturKitLogger.debug("status:\(status.rawValue)")
      
      if status == CKApplicationPermissionStatus.granted {
        CKContainer.default().fetchUserRecordID(completionHandler: { (recordID, error) in
          if let r = recordID {
            celeturKitLogger.debug("recordID:\(r)")
            
            CKContainer.default().discoverUserIdentity(withUserRecordID: r, completionHandler: { (userIdentity, error) in
              if let u = userIdentity?.nameComponents {
                celeturKitLogger.debug("nameComponents:\(u)")
                
                let formatter = PersonNameComponentsFormatter()
                
                formatter.style = PersonNameComponentsFormatter.Style.long
                
                let displayName = formatter.string(from: u)
                
                celeturKitLogger.debug("user:\(displayName)")
              }
            })
          }
        })
      }
    }
  }
}
