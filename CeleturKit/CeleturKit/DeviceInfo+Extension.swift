//
//  DeviceInfo.swift
//  CeleturKit
//

extension DeviceInfo {
 
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
  
}
