//
//  TresorUserDevice+Extension.swift
//  CeleturKit
//

let localUserDeviceId = "00000000-0000-0000-0000-000000000000"

public var localTresorUserDevice : TresorUserDevice?


extension TresorUserDevice {
  
  class func createCurrentUserDevice(context:NSManagedObjectContext, deviceInfo:DeviceInfo) -> TresorUserDevice {
    let newUserDevice = TresorUserDevice(context:context)
    
    newUserDevice.createts = Date()
    newUserDevice.id = deviceInfo.id
    newUserDevice.cksyncstatus = CloudKitEntitySyncState.pending.rawValue
    newUserDevice.updateCurrentUserDevice(deviceInfo:deviceInfo)
    
    do {
      newUserDevice.messagekey = try Data(withRandomData:SymmetricCipherAlgorithm.aes_256.requiredKeySize())
      newUserDevice.messageencryption = "aes256"
    } catch {
      celeturKitLogger.error("error create messagekey", error: error)
    }
    
    return newUserDevice
  }
  
  class func createLocalUserDevice(context:NSManagedObjectContext, deviceInfo:DeviceInfo) -> TresorUserDevice {
    let newUserDevice = TresorUserDevice(context:context)
    
    newUserDevice.createts = Date()
    newUserDevice.id = localUserDeviceId
    newUserDevice.cksyncstatus = CloudKitEntitySyncState.pending.rawValue
    newUserDevice.updateCurrentUserDevice(deviceInfo:deviceInfo)
    
    return newUserDevice
  }
  
  
  fileprivate func updateCurrentUserDevice(deviceInfo:DeviceInfo) {
    self.devicename = deviceInfo.devicename
    self.devicemodel = deviceInfo.devicemodel
    self.devicesystemname = deviceInfo.devicesystemname
    self.devicesystemversion = deviceInfo.devicesystemversion
    self.deviceuitype = deviceInfo.deviceuitype
    self.apndevicetoken = deviceInfo.apndevicetoken
  }
  
  
  func updateCurrentUserInfo(currentUserInfo:UserInfo) {
    guard self.id != localUserDeviceId else { return }
    
    self.username = currentUserInfo.userDisplayName
    self.ckuserid = currentUserInfo.id
  }
  
  
  class public func loadUserDevices(context:NSManagedObjectContext, ckUserId: String?) -> [TresorUserDevice]? {
    var result : [TresorUserDevice]?
    
    do {
      let fetchRequest : NSFetchRequest<TresorUserDevice> = TresorUserDevice.fetchRequest()
      
      fetchRequest.fetchBatchSize = 20
      fetchRequest.sortDescriptors = [NSSortDescriptor(key: "id", ascending: true)]
      
      if let userid = ckUserId {
        fetchRequest.predicate = NSPredicate(format: "ckuserid = %@", userid)
      } else {
        fetchRequest.predicate = NSPredicate(format: "ckuserid = nil ")
      }
      
      result = try context.fetch(fetchRequest)
      
    } catch {
      celeturKitLogger.error("Error while loading user devices...",error:error)
    }
    
    return result
  }
  
  
  class func createAndFetchUserdeviceFetchedResultsController(context:NSManagedObjectContext) throws -> NSFetchedResultsController<TresorUserDevice> {
    let fetchRequest: NSFetchRequest<TresorUserDevice> = TresorUserDevice.fetchRequest()
    
    fetchRequest.fetchBatchSize = 20
    fetchRequest.sortDescriptors = [NSSortDescriptor(key: "username", ascending: true),NSSortDescriptor(key: "createts", ascending: false)]
    
    let aFetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: context, sectionNameKeyPath: "username", cacheName: nil)
    
    do {
      try aFetchedResultsController.performFetch()
    } catch {
      throw CeleturKitError.creationOfFetchResultsControllerFailed(coreDataError: error as NSError)
    }
    
    return aFetchedResultsController
  }
  
  class func loadCurrentCloudTresorUserDevice(cdm: CoreDataManager,cui:UserInfo) {
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
}
