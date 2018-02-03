//
//  TempTresorObject.swift
//  CeleturKit
//
//  Created by Feldmaus on 01.11.17.
//  Copyright © 2017 prisnoc. All rights reserved.
//


public class TempTresorObject {
  public var tresorModel: TresorModel
  public var tempManagedObjectContext: NSManagedObjectContext
  public var tempTresor: Tresor
  public var userDevices: [TresorUserDevice]?
  public var isNewTresor: Bool
  
  init(tresorModel: TresorModel, context:NSManagedObjectContext, tresor:Tresor, userDevices: [TresorUserDevice]?, isNewTresor:Bool) {
    self.tresorModel = tresorModel
    self.tempManagedObjectContext = context
    self.tempTresor = tresor
    self.userDevices = userDevices
    self.isNewTresor = isNewTresor
  }
  
  convenience init?(tresorModel: TresorModel, tresorCoreDataManager:CoreDataManager?, tresor:Tresor) {
    guard let cdm = tresorCoreDataManager else { return nil }
    
    let scratchpadContext = cdm.privateChildManagedObjectContext()
    let tempTresor = scratchpadContext.object(with: tresor.objectID) as? Tresor
    
    tempTresor?.isreadonly = tresor.isreadonly
    
    if let t = tempTresor {
      self.init(tresorModel: tresorModel,
                context:scratchpadContext,
                tresor:t,
                userDevices:TresorUserDevice.loadUserDevices(context: cdm.mainManagedObjectContext, ckUserId: tresor.ckuserid),
                isNewTresor:false)
    } else {
      return nil
    }
  }
  
  convenience init?(tresorModel: TresorModel, tresorCoreDataManager:CoreDataManager?, ckUserId: String?, isReadOnly: Bool) {
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
      self.init(tresorModel: tresorModel,
                context:scratchpadContext,
                tresor:t,
                userDevices:TresorUserDevice.loadUserDevices(context: cdm.mainManagedObjectContext, ckUserId: ckUserId),
                isNewTresor:true)
    } else {
      return nil
    }
  }
  
  fileprivate func logTresorChange(messageName:TresorLogMessageName) {
    var logEntries = [TresorLogInfo]()
    logEntries.append(TresorLogInfo(messageIndentLevel: 0, messageName: messageName, messageParameter1:self.tempTresor.name,
                                    objectType: .Tresor, objectId: self.tempTresor.id!))
    
    TresorLog.createLogEntries(context: self.tempManagedObjectContext, ckUserId: self.tempTresor.ckuserid, entries: logEntries)
  }
  
  public func saveTresor() {
    self.logTresorChange(messageName: self.isNewTresor ? .createObject: .modifyObject)
    
    self.tempManagedObjectContext.performSave(contextInfo: "tresor object", completion: {
      self.tresorModel.saveChanges()
    })
  }
}
