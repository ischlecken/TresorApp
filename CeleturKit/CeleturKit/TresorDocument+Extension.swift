//
//  TresorDocument+Extension.swift
//  CeleturKit
//

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
  
  convenience init(context:NSManagedObjectContext, tresor:Tresor) throws {
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
                          model: Payload
    ) throws {
    try self.init(context: context, tresor: tresor)
    
    if let payload = PayloadSerializer.jsonData(model: model),
      let currentDeviceKey = masterKey.accessToken {
      
      self.setMetaInfo(model: model)
      
      for case let userDevice as TresorUserDevice in tresor.userdevices! {
        let isUserDeviceCurrentDevice = currentDeviceInfo?.isCurrentDevice(tresorUserDevice: userDevice) ?? false
        
        if let key = isUserDeviceCurrentDevice ? currentDeviceKey : userDevice.messagekey {
          let tdi = TresorDocumentItem(context: context, tresorDocument: self, userDevice: userDevice)
          
          let _ = tdi.encryptPayload(key: key, payload: payload, status: isUserDeviceCurrentDevice ? .encrypted : .shouldBeEncryptedByDevice)
          
          celeturKitLogger.debug(" tdi:\(tdi)")
        }
      }
      
      celeturKitLogger.debug("create of complete tresordocument finished")
    }
  }
  
  public func setMetaInfo(model: Payload) {
    var metaInfo = [ "title":model.title ]
  
    if let d = model.description {
      metaInfo["description"] = d
    }
    
    do {
      self.metainfo = try JSONSerialization.data(withJSONObject: metaInfo, options: [])
    } catch {
      celeturKitLogger.error("Error serializing metainfo json",error:error)
    }
  }
  
  public func getMetaInfo() -> [String:String]? {
    var result : [String:String]?
    
    if let m = self.metainfo {
      do {
        result = try JSONSerialization.jsonObject(with: m, options: []) as? [String:String]
      } catch {
        celeturKitLogger.error("Error serializing metainfo json",error:error)
      }
    }
    
    return result
  }
  
  public func deleteTresorDocument() {
    if let context = self.managedObjectContext {
    
      if let docItems = self.documentitems {
        for item in docItems {
          if let o = item as? NSManagedObject {
            context.delete(o)
          }
        }
      }
      
      context.delete(self)
    }
  }
  
  
}
