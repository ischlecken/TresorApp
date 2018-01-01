//
//  Created by Feldmaus on 06.08.17.
//  Copyright © 2017 prisnoc. All rights reserved.
//

import Foundation
import Contacts
import CloudKit


extension Notification.Name {
  public static let onTresorCloudkitChangesFetched = Notification.Name("onTresorCloudkitChangesFetched")
}
public class CloudKitManager {
  let privateDB : CKDatabase
  let sharedDB : CKDatabase
  let createZoneGroup : DispatchGroup
  
  let tresorZone = "tresor"
  var tresorZoneId : CKRecordZoneID?
  
  let privateSubscriptionId = "private-changes"
  let sharedSubscriptionId = "shared-changes"
  
  let ckPersistenceState : CloudKitPersistenceState
  
  let coreDataManager: CoreDataManager
  
  let cloudKitUserId: String
  
  
  
  // MARK: - Init
  
  init(cloudKitPersistenceState:CloudKitPersistenceState, coreDataManager: CoreDataManager, ckUserId:String) {
    self.ckPersistenceState = cloudKitPersistenceState
    self.coreDataManager = coreDataManager
    self.cloudKitUserId = ckUserId
    
    self.privateDB = CKContainer.default().privateCloudDatabase
    self.sharedDB = CKContainer.default().sharedCloudDatabase
    
    self.createZoneGroup = DispatchGroup()
    self.tresorZoneId = self.createZones(zoneName: tresorZone)
  }
  
  
  func getPrivateDB() -> CKDatabase {
    return self.privateDB
  }
  
  
  // MARK: - Save Changed from CoreData
  
  func saveChanges(context:NSManagedObjectContext) {
    let moc = context
    let records = self.ckPersistenceState.changedRecords(moc: moc, ckUserId: self.cloudKitUserId, zoneId: self.tresorZoneId)
    let deletedRecordIds = self.ckPersistenceState.deletedRecordIds(moc:moc, ckUserId: self.cloudKitUserId, zoneId: self.tresorZoneId)
    
    if records.count>0 || deletedRecordIds.count>0 {
      celeturKitLogger.debug("CloudKitManager.saveChanges() records:\(records.count) deletedRecordIds:\(deletedRecordIds.count)")
      
      let modifyOperation = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: deletedRecordIds)
      
      modifyOperation.completionBlock = {
        celeturKitLogger.debug("CloudKitManager.saveChanges() modify finished")
      }
      modifyOperation.modifyRecordsCompletionBlock = { savedRecords, deletedRecordIDs, error in
        if let e = error {
          let _ = self.handleError(context: "saveChanges", error: e)
          
          //
          // TODO: more sophisticated error handling
          //
          self.ckPersistenceState.flushChangedIds()
        } else {
          celeturKitLogger.debug("CloudKitManager.saveChanges() modify records complete")
          if let sr=savedRecords {
            for r in sr {
              r.dumpRecordInfo(prefix: "  ")
            }
            
            let entityIds = sr.map({ (r) -> String in
              return r.recordID.recordName
            })
            
            self.ckPersistenceState.changedObjectHasBeenSaved(ckUserId: self.cloudKitUserId, entityIds: entityIds)
          }
          
          if let dr=deletedRecordIDs {
            for dri in dr {
              celeturKitLogger.debug("CloudKitManager.saveChanges()  record \(dri.recordName) in \(dri.zoneID.zoneName) deleted")
            }
            
            let entityIds = dr.map({ (r) -> String in
              return r.recordName
            })
            
            self.ckPersistenceState.deletedObjectHasBeenDeleted(ckUserId: self.cloudKitUserId, entityIds: entityIds)
          }
          
          //self.ckPersistenceState.flushChangedIds()
          self.ckPersistenceState.saveChangedIds()
          
          if let savedRecords = savedRecords {
            if savedRecords.count>0 {
              for r in savedRecords {
                let obj = r.getManagedObject(usingContext:moc)
                
                if let o = obj {
                  o.setValue(r.cksystemdata(), forKey: "ckdata")
                }
              }
              
              moc.perform({
                do {
                  try moc.save()
                  
                  celeturKitLogger.debug("CloudKitManager.saveChanges() update from cloudkit saved in Private Managed Object Context.")
                } catch {
                  celeturKitLogger.error("Unable to Save Changes of Private Managed Object Context after update from cloudkit", error:error)
                }
              })
            }
          }
        }
      }
      
      self.privateDB.add(modifyOperation)
    }
  }
  
  func deleteAllRecordsForZone() {
    var recordIds = [CKRecordID]()
    
    let fetchOperation = CKFetchRecordZoneChangesOperation(recordZoneIDs: [self.tresorZoneId!], optionsByRecordZoneID: nil)
    
    fetchOperation.recordChangedBlock = { (record) in
      celeturKitLogger.debug("  delete candidate \(record.recordType): \(record.recordID.recordName)")
      recordIds.append(record.recordID)
    }
    
    fetchOperation.completionBlock = {
      let deleteOperation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: recordIds)
      
      deleteOperation.modifyRecordsCompletionBlock = { savedRecords, deletedRecordIDs, error in
        if let e = error {
          celeturKitLogger.error("Error deleted all records",error:e)
        }
        
        if let dri = deletedRecordIDs {
          for i in dri {
            celeturKitLogger.debug("    deleted record \(i.recordName)")
          }
        }
      }
      
      self.privateDB.add(deleteOperation)
    }
    
    self.privateDB.add(fetchOperation)
  }
  
  func updateInfoForChangedObjects(moc:NSManagedObjectContext) {
    if moc.hasChanges {
      for o in moc.insertedObjects {
        if o.isCKStoreableObject() {
          self.ckPersistenceState.addChangedObject(o: o)
        }
      }
      
      for o in moc.updatedObjects {
        if o.isCKStoreableObject() {
          self.ckPersistenceState.addChangedObject(o: o)
        }
      }
      
      for o in moc.deletedObjects {
        if o.isCKStoreableObject() {
          self.ckPersistenceState.addDeletedObject(o: o)
        }
      }
      
      self.ckPersistenceState.saveChangedIds()
    }
  }
  
  
  
  // MARK: - Error Handling
  
  fileprivate func handleError(context:String, error:Error) -> CeleturKitError? {
    CloudKitManager.dumpCloudKitError(context: context,error: error)
    
    return nil
  }
  
  
  class func dumpCloudKitError(context:String, error:Error) {
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
    
  }
  
  
  class func isCloudAvailable(completion: @escaping (Error?) -> Void) {
    
    CKContainer.default().accountStatus() { (accountStatus, error) in
      
      guard error == nil else {
        self.dumpCloudKitError(context: "isCloudAvailable", error: error!)
        return
      }
      
      switch accountStatus {
      case .available:
        if FileManager.default.ubiquityIdentityToken != nil {
          completion(nil)
        }
        else {
          completion(CeleturKitError.cloudkitNotSignedIn)
        }
      case .noAccount:
        celeturKitLogger.debug("isCloudAvailable() .noAccount")
        completion(CeleturKitError.cloudkitNotAvailable)
      case .restricted:
        celeturKitLogger.debug("isCloudAvailable() .restricted")
        completion(CeleturKitError.cloudkitNotAvailable)
      case .couldNotDetermine:
        celeturKitLogger.debug("isCloudAvailable() .couldNotDetermine")
        completion(CeleturKitError.cloudkitNotAvailable)
      }
    }
    
  }
  
  // MARK: - Init CloudKit Objects
  
  
  func createDatabaseSubscriptionOperation(subscriptionId: String) -> CKModifySubscriptionsOperation {
    let subscription = CKDatabaseSubscription(subscriptionID: subscriptionId)
    
    let notificationInfo = CKNotificationInfo()
    //notificationInfo.alertBody = "A new notification has been posted!"
    notificationInfo.shouldSendContentAvailable = true
    //notificationInfo.soundName = "default"
    
    subscription.notificationInfo = notificationInfo
    
    let operation = CKModifySubscriptionsOperation(subscriptionsToSave: [subscription], subscriptionIDsToDelete: [])
    operation.qualityOfService = .utility
    
    return operation
  }
  
  
  public func createCloudKitSubscription() {
    let createSubscriptionOperation = self.createDatabaseSubscriptionOperation(subscriptionId: privateSubscriptionId)
    createSubscriptionOperation.modifySubscriptionsCompletionBlock = { (subscriptions, deletedIds, error) in
      if error == nil {
        celeturKitLogger.debug("subscription modified")
      }
      
      if let e = error {
        let _ = self.handleError(context: "creating privateSubscriptionId subscription", error: e)
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
  
  
  
  // MARK: - Fetch Changes from CloudKit
  
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
  
  
  fileprivate func fetchDatabaseChanges(database: CKDatabase, databaseTokenKey: String, completion: @escaping () -> Void) {
    celeturKitLogger.debug("CloudKitManager.fetchDatabaseChanges() fetch for changes in database \(databaseTokenKey) started...")
    
    var changedZoneIDs: [CKRecordZoneID] = []
    
    let operation = CKFetchDatabaseChangesOperation(previousServerChangeToken: self.getChangeToken(tokenName: databaseTokenKey))
    
    operation.recordZoneWithIDChangedBlock = { (zoneID) in
      changedZoneIDs.append(zoneID)
      
      celeturKitLogger.debug("CloudKitManager.fetchDatabaseChanges()   zone \(zoneID.zoneName) changed")
    }
    
    operation.recordZoneWithIDWasDeletedBlock = { (zoneID) in
      // Write this zone deletion to memory
      
      celeturKitLogger.debug("CloudKitManager.fetchDatabaseChanges()   zone \(zoneID.zoneName) deleted")
    }
    
    operation.changeTokenUpdatedBlock = { (token) in
      // Flush zone deletions for this database to disk
      // Write this new database change token to memory
      
      self.setChangeToken(tokenName: databaseTokenKey, changeToken: token)
      celeturKitLogger.debug("CloudKitManager.fetchDatabaseChanges()   changeToken \(token.description) for \( databaseTokenKey) updated")
    }
    
    operation.fetchDatabaseChangesCompletionBlock = { (token, moreComing, error) in
      if let e = error {
        let _ = self.handleError(context: "fetch shared database changes", error: e)
        completion()
        return
      }
      
      // Flush zone deletions for this database to disk
      // Write this new database change token to memory
      
      if let c = token {
        self.setChangeToken(tokenName: databaseTokenKey, changeToken: c)
        
        celeturKitLogger.debug("CloudKitManager.fetchDatabaseChanges() fetch for changes in database \(databaseTokenKey) completed.")
      }
      
      if changedZoneIDs.count>0 {
        self.fetchZoneChanges(database: database, databaseTokenKey: databaseTokenKey, zoneIDs: changedZoneIDs) {
          DispatchQueue.main.async {
            NotificationCenter.default.post(name: .onTresorCloudkitChangesFetched, object: self.coreDataManager)
          }
          
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
  
  struct RecordObject {
    var object : NSManagedObject
    var record : CKRecord
    
    init(object : NSManagedObject,record : CKRecord) {
      self.object = object
      self.record = record
    }
  }
  
  fileprivate func fetchZoneChanges(database: CKDatabase, databaseTokenKey: String, zoneIDs: [CKRecordZoneID], completion: @escaping () -> Void) {
    let zoneNames = zoneIDs.map { (zoneId) -> String in
      return zoneId.zoneName
    }
    
    celeturKitLogger.debug("CloudKitManager.fetchZoneChanges() fetch for changes in zones \(zoneNames) started...")
    
    var updateObjects = [RecordObject]()
    
    // Look up the previous change token for each zone
    var optionsByRecordZoneID = [CKRecordZoneID: CKFetchRecordZoneChangesOptions]()
    for zoneID in zoneIDs {
      let options = CKFetchRecordZoneChangesOptions()
      
      options.previousServerChangeToken = self.getChangeToken(tokenName: zoneID.zoneName)
      optionsByRecordZoneID[zoneID] = options
    }
    let operation = CKFetchRecordZoneChangesOperation(recordZoneIDs: zoneIDs, optionsByRecordZoneID: optionsByRecordZoneID)
    
    let tempMOC = self.coreDataManager.privateChildManagedObjectContext()
      
    operation.recordChangedBlock = { (record) in
      let o = record.updateManagedObject(context: tempMOC)
      
      updateObjects.append( RecordObject(object:o, record: record) )
      
      record.dumpRecordInfo(prefix: "CloudKitManager.fetchZoneChanges()   changed:")
    }
    
    operation.recordWithIDWasDeletedBlock = { (recordId,recordType) in
      recordId.deleteManagedObject(context: tempMOC, usingEntityName: recordType)
      
      celeturKitLogger.debug("CloudKitManager.fetchZoneChanges()   deleted: \(recordId)")
    }
    
    operation.recordZoneChangeTokensUpdatedBlock = { (zoneId, token, data) in
      if let c = token {
        self.setChangeToken(tokenName: zoneId.zoneName, changeToken: c)
        
        celeturKitLogger.debug("CloudKitManager.fetchZoneChanges()   changeToken \(c.description) for \(zoneId.zoneName) updated")
      }
    }
    
    operation.recordZoneFetchCompletionBlock = { (zoneId, changeToken, _, _, error) in
      if let e = error {
        let _ = self.handleError(context: "fetching zone changes for \(databaseTokenKey) database", error: e)
      } else {
        
        if let c = changeToken {
          self.setChangeToken(tokenName: zoneId.zoneName, changeToken: c)
          
          celeturKitLogger.debug("CloudKitManager.fetchZoneChanges()  fetch for zone \(zoneId.zoneName) completed, changeToken is \(c.description)")
        }
      }
    }
    
    operation.fetchRecordZoneChangesCompletionBlock = { (error) in
      if let e = error {
        let _ = self.handleError(context: "fetching zone changes for \(databaseTokenKey) database", error: e)
      } else {
        
        tempMOC.perform {
          do {
            
            for or in updateObjects {
              or.object.updateRelationships(context: tempMOC, usingRecord: or.record)
            }
            
            try tempMOC.save()
            
            self.coreDataManager.saveChanges(notifyChangesToCloudKit: false)
          } catch {
            celeturKitLogger.error("error saving ck changes to core data",error:error)
          }
        }
        
        celeturKitLogger.debug("CloudKitManager.fetchZoneChanges() fetch for changes in zones \(zoneNames) completed...")
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
        let _ = self.handleError(context: "creating custom zone", error: e)
      }
      
      self.createZoneGroup.leave()
    }
    createZoneOperation.qualityOfService = .userInitiated
    
    self.privateDB.add(createZoneOperation)
    
    return zoneID
  }
  
  fileprivate func getChangeToken(tokenName:String) -> CKServerChangeToken? {
    return self.ckPersistenceState.getServerChangeToken(forName: tokenName)
  }
  
  fileprivate func setChangeToken(tokenName:String, changeToken: CKServerChangeToken) {
    self.ckPersistenceState.setServerChangeToken(token: changeToken, forName: tokenName)
  }
}
