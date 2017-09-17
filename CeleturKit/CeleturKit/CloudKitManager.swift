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
  
  let tresorusersGroup = "Tresorusers"
  let tresoruserType = "Tresoruser"
  let privateSubscriptionId = "private-changes"
  let sharedSubscriptionId = "shared-changes"
  
  lazy var privateDBChangeToken : CKServerChangeToken? = {
    return CloudKitServerChangeToken.getCloudKitCKServerChangeToken(context: self.tresorModel.mainManagedContext, name: "private")
  }()
  lazy var sharedDBChangeToken : CKServerChangeToken? = {
    return CloudKitServerChangeToken.getCloudKitCKServerChangeToken(context: self.tresorModel.mainManagedContext, name: "shared")
  }()
  lazy var tresorusersChangeToken : CKServerChangeToken? = {
    return CloudKitServerChangeToken.getCloudKitCKServerChangeToken(context: self.tresorModel.mainManagedContext, name: tresorusersGroup)
  }()
  
  
  public init(tresorModel:TresorModel) {
    self.tresorModel = tresorModel
    
    self.privateDB = CKContainer.default().privateCloudDatabase
    self.sharedDB = CKContainer.default().sharedCloudDatabase
    self.createZoneGroup = DispatchGroup()
    
    self.createZones(zoneName: tresorusersGroup)
  }
  
  
  public func getPrivateDB() -> CKDatabase {
    return self.privateDB
  }
  
  func saveTresorUsersToCloudKit(tresorUsers:[TresorUser]) -> CKModifyRecordsOperation {
    let zoneId = CKRecordZoneID(zoneName: tresorusersGroup, ownerName: CKCurrentUserDefaultName)
    
    var records = [CKRecord]()
    for tresorUser in tresorUsers {
      let recordId = CKRecordID(recordName: tresorUser.id!, zoneID: zoneId)
      
      let record = CKRecord(recordType: "Tresoruser", recordID: recordId)
      
      record["id"] = tresorUser.id as CKRecordValue?
      record["firstname"] = tresorUser.firstname as CKRecordValue?
      record["lastname"] = tresorUser.lastname as CKRecordValue?
      record["email"] = tresorUser.email as CKRecordValue?
      
      records.append(record)
    }
    
    return CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
  }
  
  func deleteTresorUserFromCloudKit(tresorUserId:String) -> CKModifyRecordsOperation {
    let zoneId = CKRecordZoneID(zoneName: tresorusersGroup, ownerName: CKCurrentUserDefaultName)
    let recordId = CKRecordID(recordName: tresorUserId, zoneID: zoneId)
      
    return CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: [recordId])
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
     // self.fetchChanges(in: .shared) {}
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
  
  func getChangeToken(tokenName:String) -> CKServerChangeToken? {
    if tokenName == "private" {
      return self.privateDBChangeToken
    } else if tokenName == "shared" {
      return self.sharedDBChangeToken
    } else if tokenName == tresorusersGroup {
      return self.sharedDBChangeToken
    }
    
    return nil
  }
  
  func setChangeToken(tokenName:String, changeToken: CKServerChangeToken) {
    if tokenName == "private" {
      self.privateDBChangeToken = changeToken
      CloudKitServerChangeToken.saveCloudKitServerChangeToken(context: self.tresorModel.mainManagedContext, name: tokenName, changeToken: changeToken)
    } else if tokenName == "shared" {
      self.sharedDBChangeToken = changeToken
      CloudKitServerChangeToken.saveCloudKitServerChangeToken(context: self.tresorModel.mainManagedContext,name: tokenName, changeToken: changeToken)
    } else if tokenName == tresorusersGroup {
      self.sharedDBChangeToken = changeToken
      CloudKitServerChangeToken.saveCloudKitServerChangeToken(context: self.tresorModel.mainManagedContext,name: tokenName, changeToken: changeToken)
    }
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
    
    
    let tempMOC = self.tresorModel.privateChildManagedContext
    
    operation.recordChangedBlock = { (record) in
      celeturKitLogger.debug("Record changed:\(record)")
      
      if record.recordType == self.tresoruserType {
        var user = TresorUser.findTresorUser(context: tempMOC, withId: record["id"] as! String)
        
        if user == nil {
          user = TresorUser(context:tempMOC)
          user?.createts = Date()
          user?.id = String.uuid()
        }
        
        user?.firstname = record["firstname"] as? String
        user?.lastname = record["lastname"] as? String
        user?.email = record["email"] as? String
      }
    }
    
    operation.recordWithIDWasDeletedBlock = { (recordId,recordType) in
      celeturKitLogger.debug("Record deleted:\(recordId)")
      
      let user = TresorUser.findTresorUser(context: tempMOC, withId: recordId.recordName)
      
      if let u = user {
        tempMOC.delete(u)
      }
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
  
  public func createZones(zoneName:String) {
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
