//
//  UserInfo.swift
//  CeleturKit
//

import CloudKit

extension UserInfo {
  
  func updateUserIdentityInfo(userIdentity:CKUserIdentity) {
    if let u = userIdentity.nameComponents,let li = userIdentity.lookupInfo {
      let formatter = PersonNameComponentsFormatter()
      
      formatter.style = PersonNameComponentsFormatter.Style.long
      
      self.userDisplayName = formatter.string(from: u)
      self.userGivenName = u.givenName
      self.userFamilyName = u.familyName
      self.userEMailAddress = li.emailAddress
      
      if self.id == nil {
        self.id = li.userRecordID?.recordName
      }
      
      celeturKitLogger.debug("  LoggedIn Cloud User DisplayName:\(self.userDisplayName ?? "-")")
      celeturKitLogger.debug("                     userRecordID:\(self.id ?? "-" )")
    }
  }
  
  
  class func loadUserInfo(_ cdm:CoreDataManager, userIdentity:CKUserIdentity) -> UserInfo {
    let moc = cdm.mainManagedObjectContext
    var result : UserInfo?
    
    if let userId = userIdentity.userRecordID?.recordName {
      let fetchRequest : NSFetchRequest<UserInfo> = UserInfo.fetchRequest()
      fetchRequest.predicate = NSPredicate(format: "id = %@", userId)
      fetchRequest.fetchBatchSize = 1
      
      do {
        var userInfo : UserInfo?
        
        let records = try moc.fetch(fetchRequest)
        if records.count>0 {
          userInfo = records[0]
        } else {
          userInfo = UserInfo(context: moc)
          
          userInfo?.createts = Date()
        }
        
        userInfo?.updateUserIdentityInfo(userIdentity:userIdentity)
        
        cdm.saveChanges(notifyChangesToCloudKit:false)
        
        result = userInfo
      } catch {
        celeturKitLogger.error("Error while saving tresoruser info...",error:error)
      }
    }
    
    return result!
  }
}
