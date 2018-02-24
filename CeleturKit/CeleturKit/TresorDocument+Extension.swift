//
//  TresorDocument+Extension.swift
//  CeleturKit
//

public enum TresorDocumentMetaInfoKey:String {
  case title
  case description
  case iconname
}

public typealias TresorDocumentMetaInfo =  [String:String]

extension TresorDocument {
  
  public var modifyts: Date {
    get {
      var result = self.createts!
      
      if let c = self.changets {
        result = c
      }
      
      return result
    }
  }
  
  public convenience init(context:NSManagedObjectContext, tresor:Tresor) throws {
    self.init(context: context)
    
    self.createts = Date()
    self.changets = self.createts
    self.id = String.uuid()
    self.ckuserid = tresor.ckuserid
    self.tresor = context.object(with: tresor.objectID) as? Tresor
    self.nonce = try Data(withRandomData:SymmetricCipherAlgorithm.aes_256.requiredBlockSize())
  }
  
  public convenience init(context: NSManagedObjectContext,
                          masterKey: TresorKey,
                          tresor: Tresor,
                          metaInfo: TresorDocumentMetaInfo,
                          model: Payload) throws {
    
    var logEntries = [TresorLogInfo]()
    
    try self.init(context: context, tresor: tresor)
    
    logEntries.append(TresorLogInfo(messageIndentLevel: 0, messageName: .createObject,messageParameter1:metaInfo[TresorDocumentMetaInfoKey.title.rawValue],
                                    objectType: .TresorDocument, objectId: self.id!))
    
    if let payload = PayloadSerializer.jsonData(model: model),
      let currentDeviceKey = masterKey.accessToken {
      
      self.setMetaInfo(metaInfo: metaInfo)
      
      for case let userDevice as TresorUserDevice in tresor.userdevices! {
        let isUserDeviceCurrentDevice = currentDeviceInfo?.isCurrentDevice(tresorUserDevice: userDevice) ?? false
        
        if let key = isUserDeviceCurrentDevice ? currentDeviceKey : userDevice.messagekey {
          let tdi = TresorDocumentItem(context: context, tresorDocument: self, userDevice: userDevice)
          
          logEntries.append(TresorLogInfo(messageIndentLevel: 1, messageName: .createObject,messageParameter1:nil, objectType: .TresorDocumentItem, objectId: tdi.id!))
          
          let _ = tdi.encryptPayload(key: key, payload: payload, status: isUserDeviceCurrentDevice ? .encrypted : .shouldBeEncryptedByDevice)
    
          logEntries.append(TresorLogInfo(messageIndentLevel: 2, messageName: .encryptPayload,messageParameter1:nil, objectType: .TresorDocumentItem, objectId: tdi.id!))
          
          celeturKitLogger.debug(" tdi:\(tdi)")
        }
      }
      
      TresorLog.createLogEntries(context: context, ckUserId: tresor.ckuserid, entries: logEntries)
      
      self.tresor?.changets = Date()
      
      celeturKitLogger.debug("create of complete tresordocument finished")
    }
  }
  
  public func setMetaInfo(metaInfo: TresorDocumentMetaInfo) {
    do {
      self.metainfo = try JSONSerialization.data(withJSONObject: metaInfo, options: [])
    } catch {
      celeturKitLogger.error("Error serializing metainfo json",error:error)
    }
  }
  
  public func getMetaInfo() -> TresorDocumentMetaInfo? {
    var result : TresorDocumentMetaInfo?
    
    if let m = self.metainfo {
      do {
        result = try JSONSerialization.jsonObject(with: m, options: []) as? TresorDocumentMetaInfo
      } catch {
        celeturKitLogger.error("Error serializing metainfo json",error:error)
      }
    }
    
    return result
  }
  
  public func deleteTresorDocument() {
    if let context = self.managedObjectContext {
      var logEntries = [TresorLogInfo]()
      let ckuserid = self.ckuserid
      
      self.deleteTresorDocument(logEntries: &logEntries, intentLevelOffset: 0)
      
      TresorLog.createLogEntries(context: context, ckUserId: ckuserid, entries: logEntries)
    }
  }
  
  public func deleteTresorDocument(logEntries: inout [TresorLogInfo],intentLevelOffset:Int8) {
    if let context = self.managedObjectContext {
      
      logEntries.append(TresorLogInfo(messageIndentLevel: intentLevelOffset+0, messageName: .deleteObject, messageParameter1: self.getMetaInfo()?[TresorDocumentMetaInfoKey.title.rawValue],
                                      objectType: .TresorDocument, objectId: self.id!))
    
      if let docItems = self.documentitems {
        for item in docItems {
          if let o = item as? TresorDocumentItem {
            logEntries.append(TresorLogInfo(messageIndentLevel: intentLevelOffset+1, messageName: .deleteObject,messageParameter1:nil, objectType: .TresorDocumentItem, objectId: o.id!))
            
            context.delete(o)
          }
        }
      }
      
      context.delete(self)
    }
  }
  
  
}
