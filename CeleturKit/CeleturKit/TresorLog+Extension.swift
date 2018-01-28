//
//  Copyright © 2018 prisnoc. All rights reserved.
//


public enum TresorLogMessageName: String {
  case createObject
  case modifyObject
  case deleteObject
  case encryptPayload
  case decryptPayload
}

public enum TresorLogObjectType: String {
  case Tresor
  case TresorDocument
  case TresorDocumentItem
}

public struct TresorLogInfo {
  public let messageIndentLevel: Int8
  public let messageName:TresorLogMessageName
  public let objectType:TresorLogObjectType
  public let objectId:String
  
  public init(messageIndentLevel: Int8,messageName:TresorLogMessageName,objectType:TresorLogObjectType,objectId:String) {
    self.messageIndentLevel = messageIndentLevel
    self.messageName = messageName
    self.objectType = objectType
    self.objectId = objectId
  }
}

public extension TresorLog {
  
  public class func createLogEntries(context: NSManagedObjectContext,
                                     ckUserId: String?,
                                     entries:[TresorLogInfo]) {
    var messageGroupOrder: Int16 = 0
    let messageGroupId = String.uuid()
    for e in entries {
      let _ = TresorLog(context:context,
                        ckUserId: ckUserId,
                        messageGroupId:messageGroupId,
                        messageGroupOrder: messageGroupOrder,
                        messageIndentLevel: e.messageIndentLevel,
                        messageName: e.messageName,
                        messageParameter1: nil, messageParameter2: nil, messageParameter3: nil,
                        objectType: e.objectType,objectId: e.objectId)
      
      messageGroupOrder += 1
    }
  }

  public convenience init(context: NSManagedObjectContext,
                          ckUserId: String?,
                          messageName:TresorLogMessageName,
                          objectType:TresorLogObjectType?,
                          objectId:String?
                          ) {
    
    self.init(context:context,
              ckUserId:ckUserId,
              messageGroupId: String.uuid(), messageGroupOrder: 0, messageIndentLevel: 0,
              messageName:messageName, messageParameter1: nil,messageParameter2: nil, messageParameter3: nil,
              objectType:objectType, objectId: objectId)
  }
  
  public convenience init(context: NSManagedObjectContext,
                          ckUserId: String?,
                          messageGroupId: String,
                          messageGroupOrder: Int16,
                          messageIndentLevel: Int8,
                          messageName:TresorLogMessageName,
                          messageParameter1:String?, messageParameter2:String?, messageParameter3:String?,
                          objectType:TresorLogObjectType?, objectId:String?
    ) {
    self.init(context:context)
    
    self.createts = Date()
    self.ckuserid = ckUserId
    
    self.messageid = String.uuid()
    self.messagegroupid = messageGroupId
    self.messagegrouporder = messageGroupOrder
    self.messageindentlevel = Int16(messageIndentLevel)
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
