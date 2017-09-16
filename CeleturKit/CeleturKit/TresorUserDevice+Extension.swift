//
//  TresorUserDevice+Extension.swift
//  CeleturKit
//

extension TresorUserDevice {
  
  class func createUserDevice(context:NSManagedObjectContext,user:TresorUser, deviceName:String) {
    let newUserDevice = TresorUserDevice(context:context)
    
    newUserDevice.createts = Date()
    newUserDevice.devicename = deviceName
    newUserDevice.id = String.uuid()
    newUserDevice.apndevicetoken = String.uuid()
    newUserDevice.user = user
    
    user.addToUserdevices(newUserDevice)
  }
  
  class func createCurrentUserDevice(context:NSManagedObjectContext,user:TresorUser) {
    let newUserDevice = TresorUserDevice(context:context)
    
    newUserDevice.createts = Date()
    newUserDevice.devicename = UIDevice.current.name
    newUserDevice.id = UIDevice.current.identifierForVendor?.uuidString
    newUserDevice.apndevicetoken = String.uuid()
    newUserDevice.user = user
    
    user.addToUserdevices(newUserDevice)
  }
}
