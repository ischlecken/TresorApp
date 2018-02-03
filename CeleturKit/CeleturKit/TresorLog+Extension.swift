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
  public let messageParameter1:String?
  public let objectType:TresorLogObjectType
  public let objectId:String
  
  public init(messageIndentLevel: Int8,messageName:TresorLogMessageName,messageParameter1:String?,
              objectType:TresorLogObjectType,objectId:String) {
    self.messageIndentLevel = messageIndentLevel
    self.messageName = messageName
    self.messageParameter1 = messageParameter1
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
    let messageGroupTs = Date()
    
    for e in entries {
      let _ = TresorLog(context:context,
                        ckUserId: ckUserId,
                        messageGroupTs:messageGroupTs,
                        messageGroupId:messageGroupId,
                        messageGroupOrder: messageGroupOrder,
                        messageIndentLevel: e.messageIndentLevel,
                        messageName: e.messageName,
                        messageParameter1: e.messageParameter1, messageParameter2: nil, messageParameter3: nil,
                        objectType: e.objectType,objectId: e.objectId)
      
      messageGroupOrder += 1
    }
  }

  public convenience init(context: NSManagedObjectContext,
                          ckUserId: String?,
                          messageName:TresorLogMessageName, messageParameter1:String?,
                          objectType:TresorLogObjectType?,
                          objectId:String?
                          ) {
    
    self.init(context:context,
              ckUserId:ckUserId,
              messageGroupTs:Date(), messageGroupId: String.uuid(), messageGroupOrder: 0, messageIndentLevel: 0,
              messageName:messageName, messageParameter1: messageParameter1, messageParameter2: nil, messageParameter3: nil,
              objectType:objectType, objectId: objectId)
  }
  
  public convenience init(context: NSManagedObjectContext,
                          ckUserId: String?,
                          messageGroupTs: Date,
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
    
    self.id = String.uuid()
    self.messagegroupts = messageGroupTs
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
  
  
  class func createAndFetchTresorLogFetchedResultsController(context: NSManagedObjectContext) throws -> NSFetchedResultsController<TresorLog> {
    let fetchRequest: NSFetchRequest<TresorLog> = TresorLog.fetchRequest()
    
    // Set the batch size to a suitable number.
    fetchRequest.fetchBatchSize = 20
    
    // Edit the sort key as appropriate.
    let sortDescriptor0 = NSSortDescriptor(key: "ckuserid", ascending: false)
    let sortDescriptor2 = NSSortDescriptor(key: "messagegroupts", ascending: false)
    let sortDescriptor3 = NSSortDescriptor(key: "messagegrouporder", ascending: true)
    
    fetchRequest.sortDescriptors = [sortDescriptor0,sortDescriptor2,sortDescriptor3]
    
    let aFetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
                                                               managedObjectContext: context,
                                                               sectionNameKeyPath: "ckuserid",
                                                               cacheName: nil)
    
    do {
      try aFetchedResultsController.performFetch()
    } catch {
      throw CeleturKitError.creationOfFetchResultsControllerFailed(coreDataError: error as NSError)
    }
    
    return aFetchedResultsController
  }
}
