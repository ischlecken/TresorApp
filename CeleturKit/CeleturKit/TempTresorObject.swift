//
//  TempTresorObject.swift
//  CeleturKit
//
//  Created by Feldmaus on 01.11.17.
//  Copyright © 2017 prisnoc. All rights reserved.
//


public class TempTresorObject {
  public var tempManagedObjectContext : NSManagedObjectContext
  public var tempTresor : Tresor
  public var userDevices : [TresorUserDevice]?
  
  init(context:NSManagedObjectContext, tresor:Tresor, userDevices: [TresorUserDevice]?) {
    self.tempManagedObjectContext = context
    self.tempTresor = tresor
    self.userDevices = userDevices
  }
  
  convenience init?(tresorCoreDataManager:CoreDataManager?, tresor:Tresor) {
    guard let cdm = tresorCoreDataManager else { return nil }
    
    let scratchpadContext = cdm.privateChildManagedObjectContext()
    let tempTresor = scratchpadContext.object(with: tresor.objectID) as? Tresor
    
    tempTresor?.isreadonly = tresor.isreadonly
    
    var logEntries = [TresorLogInfo]()
    logEntries.append(TresorLogInfo(messageIndentLevel: 0, messageName: .modifyObject, objectType: .Tresor, objectId: (tempTresor?.id!)!))
    TresorLog.createLogEntries(context: scratchpadContext, ckUserId: tempTresor?.ckuserid, entries: logEntries)
    
    if let t = tempTresor {
      self.init(context:scratchpadContext, tresor:t, userDevices:TresorUserDevice.loadUserDevices(context: cdm.mainManagedObjectContext, ckUserId: tresor.ckuserid))
    } else {
      return nil
    }
  }
  
  convenience init?(tresorCoreDataManager:CoreDataManager?, ckUserId: String?, isReadOnly: Bool) {
    guard let cdm = tresorCoreDataManager else { return nil }
    
    let scratchpadContext = cdm.privateChildManagedObjectContext()
    var tempTresor : Tresor?
    
    do {
      tempTresor = try Tresor.createTempTresor(context: scratchpadContext, ckUserId: ckUserId)
      tempTresor?.ckuserid = ckUserId
      tempTresor?.isreadonly = isReadOnly
      
      var logEntries = [TresorLogInfo]()
      logEntries.append(TresorLogInfo(messageIndentLevel: 0, messageName: .createObject, objectType: .Tresor, objectId: (tempTresor?.id!)!))
      
      TresorLog.createLogEntries(context: scratchpadContext, ckUserId: ckUserId, entries: logEntries)
    } catch {
      celeturKitLogger.error("Error creating temp tresor object",error:error)
    }
    
    if let t = tempTresor {
      self.init(context:scratchpadContext, tresor:t, userDevices:TresorUserDevice.loadUserDevices(context: cdm.mainManagedObjectContext, ckUserId: ckUserId))
    } else {
      return nil
    }
    
  }
}
