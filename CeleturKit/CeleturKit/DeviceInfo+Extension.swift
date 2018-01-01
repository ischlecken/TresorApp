//
//  DeviceInfo.swift
//  CeleturKit
//

public var currentDeviceInfo : DeviceInfo?

public extension DeviceInfo {
 
  class func createCurrentUserDevice(context:NSManagedObjectContext) -> DeviceInfo {
    let deviceInfo = DeviceInfo(context:context)
    
    deviceInfo.createts = Date()
    deviceInfo.id = UIDevice.current.identifierForVendor?.uuidString
    
    deviceInfo.devicename = UIDevice.current.name
    deviceInfo.devicemodel = UIDevice.current.model
    deviceInfo.devicesystemname = UIDevice.current.systemName
    deviceInfo.devicesystemversion = UIDevice.current.systemVersion
    deviceInfo.deviceuitype = Int16(UIDevice.current.userInterfaceIdiom.rawValue)
    
    return deviceInfo
  }
  
  
  func updateAPNToken(deviceToken: Data) {
    self.apndevicetoken = deviceToken.hexEncodedString()
  }
  
  
  public func isCurrentDevice(tresorUserDevice: TresorUserDevice?) -> Bool {
    guard let tud = tresorUserDevice else { return false }
    
    return tud.id == localUserDeviceId || self.id == tud.id
  }
  
  
  class func loadCurrentDeviceInfo(context: NSManagedObjectContext, apnDeviceToken: Data?) {
    let fetchRequest : NSFetchRequest<DeviceInfo> = DeviceInfo.fetchRequest()
    fetchRequest.fetchBatchSize = 1
    
    do {
      var deviceInfo : DeviceInfo?
      
      let records = try context.fetch(fetchRequest)
      if records.count>0 {
        deviceInfo = records[0]
      } else {
        deviceInfo = DeviceInfo.createCurrentUserDevice(context: context)
      }
      
      if let adt = apnDeviceToken {
        deviceInfo!.updateAPNToken(deviceToken: adt)
      }
      
      currentDeviceInfo = deviceInfo
    } catch {
      celeturKitLogger.error("Error while saving device info...",error:error)
    }
  }
  
  func currentCloudTresorUserDevice(cdm: CoreDataManager, cui:UserInfo) -> TresorUserDevice? {
    var result : TresorUserDevice?
    
    let moc = cdm.mainManagedObjectContext
    let fetchRequest : NSFetchRequest<TresorUserDevice> = TresorUserDevice.fetchRequest()
    fetchRequest.predicate = NSPredicate(format: "ckuserid = %@ and id = %@", cui.id!, self.id!)
    fetchRequest.fetchBatchSize = 1
    
    do {
      var tresorUserDevice : TresorUserDevice?
      
      let records = try moc.fetch(fetchRequest)
      if records.count>0 {
        tresorUserDevice = records[0]
      } else {
        tresorUserDevice = TresorUserDevice.createCurrentUserDevice(context: moc, deviceInfo: self)
      }
      
      tresorUserDevice!.updateCurrentUserInfo(currentUserInfo: cui)
      
      cdm.saveChanges(notifyChangesToCloudKit:true)
      
      result = tresorUserDevice
    } catch {
      celeturKitLogger.error("Error while saving tresor userdevice info...",error:error)
    }
    
    return result
  }
  
  func currentLocalTresorUserDevice(cdm: CoreDataManager) -> TresorUserDevice? {
    var result : TresorUserDevice?
    
    let moc = cdm.mainManagedObjectContext
    let fetchRequest : NSFetchRequest<TresorUserDevice> = TresorUserDevice.fetchRequest()
    fetchRequest.predicate = NSPredicate(format: "ckuserid = nil and id = %@", localUserDeviceId)
    fetchRequest.fetchBatchSize = 1
    
    do {
      var tresorUserDevice : TresorUserDevice?
      
      let records = try moc.fetch(fetchRequest)
      if records.count>0 {
        tresorUserDevice = records[0]
      } else {
        tresorUserDevice = TresorUserDevice.createLocalUserDevice(context: moc, deviceInfo: self)
      }
      
      result = tresorUserDevice
    } catch {
      celeturKitLogger.error("Error while saving tresor userdevice info...",error:error)
    }
    
    return result
  }
  
  public func displayInfoForCkUserId(ckUserId:String?, userInfo: UserInfo?) -> String {
    var result = "This Device"
    
    if let ui = UIUserInterfaceIdiom(rawValue: Int(self.deviceuitype)) {
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
    
    if let s = self.devicemodel {
      result += "\(s)"
    }
    
    if let s = self.devicename {
      result += " '\(s)'"
    }
    
    if let s0 = self.devicesystemname,let s1 = self.devicesystemversion {
      result += " with \(s0) \(s1)"
    }
    
    result += ")"
    
    
    if let userid = ckUserId {
      result = "icloud: \(userid)"
      
      if let cui = userInfo, let currentCkUserId = cui.id, currentCkUserId == userid, let userDisplayName = cui.userDisplayName {
        result = "icloud: \(userDisplayName)"
      }
    }
    
    return result
  }
}
