//
//  TresorDocumentItem+Extension.swift
//  CeleturKit
//

public enum TresorDocumentItemStatus : String {
  case pending
  case failed
  case encrypted
  case shouldBeEncryptedByDevice
}


extension TresorDocumentItem {

  public var modifyts: Date {
    get {
      var result = self.createts!
      
      if let c = self.changets {
        result = c
      }
      
      return result
    }
  }
  
  
  convenience init(context: NSManagedObjectContext,
                   tresorDocument:TresorDocument,
                   userDevice:TresorUserDevice) {
    
    self.init(context: context)
    
    let doc = context.object(with: tresorDocument.objectID) as? TresorDocument
    let ud = context.object(with: userDevice.objectID) as? TresorUserDevice
    
    self.createts = Date()
    self.ckuserid = tresorDocument.ckuserid
    self.changets = self.createts
    self.id = String.uuid()
    self.status = TresorDocumentItemStatus.pending.rawValue
    self.document = doc
    self.userdevice = ud
    
    doc?.addToDocumentitems(self)
    ud?.addToDocumentitems(self)
  }

  
  class func createAndFetchTresorDocumentItemFetchedResultsController(context:NSManagedObjectContext,
                                                                      tresor:Tresor?) throws -> NSFetchedResultsController<TresorDocumentItem> {
    let fetchRequest: NSFetchRequest<TresorDocumentItem> = TresorDocumentItem.fetchRequest()
    
    // Set the batch size to a suitable number.
    fetchRequest.fetchBatchSize = 20
    fetchRequest.predicate = NSPredicate(format: "document.tresor.id = %@", (tresor?.id)!)
    
    
    // Edit the sort key as appropriate.
    let sortDescriptor = NSSortDescriptor(key: "createts", ascending: false)
    
    fetchRequest.sortDescriptors = [sortDescriptor]
    
    let aFetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
                                                               managedObjectContext: context,
                                                               sectionNameKeyPath: "document.id",
                                                               cacheName: nil)
    
    do {
      try aFetchedResultsController.performFetch()
    } catch {
      throw CeleturKitError.creationOfFetchResultsControllerFailed(coreDataError: error as NSError)
    }
    
    return aFetchedResultsController
  }
  
  public var itemStatus: TresorDocumentItemStatus? {
    get {
      var result : TresorDocumentItemStatus?
      
      if let s=self.status {
        result = TresorDocumentItemStatus(rawValue:s)
      }
      
      return result
    }
  }
  
  public var itemStatusColor: UIColor {
    get {
      var result = UIColor.lightGray
      
      if let s = self.itemStatus {
        switch s {
        case .pending:
          result = UIColor.blue
        case .encrypted:
          result = UIColor.black
        case .shouldBeEncryptedByDevice:
          result = UIColor.magenta
        case .failed:
          result = UIColor.red
        }
      }
      
      return result
    }
  }
  
  // MARK: - Crypto Operations
  
  func encryptPayload(key: Data,
                      payload: Data,
                      status: TresorDocumentItemStatus) -> Data? {
    var result : Data?
    
    do {
      self.type = "main"
      self.mimetype = "application/json"
      self.status = status.rawValue
      
      let s = String(data: payload, encoding: String.Encoding.utf8)
      celeturKitLogger.debug("encryptPayload(\(s ?? "-")): status=\(status)")
      
      let operation = AES256Encryption(key:key, inputData:payload, iv:nil)
      try operation.createRandomIV()
      
      operation.execute()
      if let _ = operation.outputData {
        self.changets = Date()
        self.payload = operation.outputData
        self.nonce = operation.iv
      }
      
      result = operation.outputData
    } catch {
      celeturKitLogger.error("error while encryption payload",error:error)
    }
    
    return result
  }
  
  func encryptMessagePayload(masterKey:TresorKey) -> Data? {
    var result : Data?
    
    if let ud = self.userdevice,
      let payload = self.payload,
      let nonce = self.nonce,
      let messageKey = ud.messagekey,
      currentDeviceInfo?.isCurrentDevice(tresorUserDevice: ud) ?? false {
      
      celeturKitLogger.debug("item \(self.id ?? "-") should be encrypted by device...")
      
      let operation = AES256Decryption(key: messageKey, inputData: payload, iv:nonce)
      operation.execute()
      if let d = PayloadSerializer.payload(jsonData: operation.outputData!) {
        celeturKitLogger.debug("payload:\(d)")
        
        result = self.encryptPayload(key: masterKey.accessToken!, payload: operation.outputData!, status: TresorDocumentItemStatus.encrypted)
      }
    }
    
    return result
  }
  
  public func decryptPayload(masterKey:TresorKey) -> Data? {
    if let payload = self.payload, let nonce = self.nonce {
      let operation = AES256Decryption(key:masterKey.accessToken!, inputData: payload, iv:nonce)
      
      operation.execute()
      
      return operation.outputData
    }
    
    return nil
  }
}


