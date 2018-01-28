//
//  Copyright © 2018 prisnoc. All rights reserved.
//


public enum TresorLogMessageName: String {
  case createObject
  case modifyObject
  case encryptObject
  case deleteObject
}

public enum TresorLogObjectType: String {
  case Tresor
  case TresorDocument
  case TresorDocumentItem
}

public extension TresorLog {

  public convenience init(context: NSManagedObjectContext,
                          ckUserId: String?,
                          messageName:TresorLogMessageName,
                          objectType:TresorLogObjectType?,
                          objectId:String?
                          ) {
    
    self.init(context:context,
              ckUserId:ckUserId,
              messageName:messageName, messageParameter1: nil,messageParameter2: nil, messageParameter3: nil,
              objectType:objectType, objectId: objectId)
  }
  
  public convenience init(context: NSManagedObjectContext,
                          ckUserId: String?,
                          messageName:TresorLogMessageName, messageParameter1:String?, messageParameter2:String?, messageParameter3:String?,
                          objectType:TresorLogObjectType?, objectId:String?
    ) {
    self.init(context:context)
    
    self.createts = Date()
    self.ckuserid = ckUserId
    
    self.messageid = String.uuid()
    self.messagename = messageName.rawValue
    self.messageparameter1 = messageParameter1
    self.messageparameter2 = messageParameter2
    self.messageparameter3 = messageParameter3
    self.objecttype = objectType?.rawValue
    self.objectid = objectId
    
    self.devicevendorid = UIDevice.current.identifierForVendor?.uuidString
    self.devicename = UIDevice.current.name
    self.devicemodel = UIDevice.current.model
    self.devicesystemname = UIDevice.current.systemName
    self.devicesystemversion = UIDevice.current.systemVersion
    self.deviceuitype = Int16(UIDevice.current.userInterfaceIdiom.rawValue)
  }
}
