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
    
    if let t = tempTresor {
      self.init(context:scratchpadContext, tresor:t, userDevices:TresorUserDevice.loadUserDevices(context: cdm.mainManagedObjectContext))
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
    } catch {
      celeturKitLogger.error("Error creating temp tresor object",error:error)
    }
    
    if let t = tempTresor {
      self.init(context:scratchpadContext, tresor:t, userDevices:TresorUserDevice.loadUserDevices(context: cdm.mainManagedObjectContext))
    } else {
      return nil
    }
    
  }
}
