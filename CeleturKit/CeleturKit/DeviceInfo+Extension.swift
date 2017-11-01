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
    
    return self.id == tud.id
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
}
