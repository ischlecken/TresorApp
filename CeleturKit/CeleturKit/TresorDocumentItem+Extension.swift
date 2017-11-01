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

  convenience init(context: NSManagedObjectContext,
                   tresorDocument:TresorDocument,
                   userDevice:TresorUserDevice) {
    
    self.init(context: context)
    
    let doc = context.object(with: tresorDocument.objectID) as? TresorDocument
    let ud = context.object(with: userDevice.objectID) as? TresorUserDevice
    
    self.createts = Date()
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
                      status: TresorDocumentItemStatus,
                      completion: @escaping ()->Void ) {
    if let context = self.managedObjectContext {
      do {
        self.status = TresorDocumentItemStatus.pending.rawValue
        context.performSave(contextInfo: "pending tresor documentitem")
        
        let operation = AES256EncryptionOperation(key:key, inputData: payload, iv:nil)
        try operation.createRandomIV()
        
        operation.completionBlock = {
          self.changets = Date()
          self.type = "main"
          self.mimetype = "application/json"
          self.status = status.rawValue
          self.payload = operation.outputData
          self.nonce = operation.iv
          
          context.performSave(contextInfo: "tresor documentitem") {
            completion()
          }
        }
        
        SymmetricCipherOperation.cipherQueue.addOperation(operation)
      } catch {
        celeturKitLogger.error("error while encryption payload",error:error)
      }
    }
  }
  
  func encryptMessagePayload(masterKey:TresorKey, completion: @escaping ()->Void) {
    if let ud = self.userdevice,
      let payload = self.payload,
      let nonce = self.nonce,
      let messageKey = ud.messagekey,
      currentDeviceInfo?.isCurrentDevice(tresorUserDevice: ud) ?? false {
      
      celeturKitLogger.debug("item \(self.id ?? "-") should be encrypted by device...")
      
      let operation = AES256DecryptionOperation(key: messageKey, inputData: payload, iv:nonce)
      operation.completionBlock = {
        if let d = PayloadModel.model(jsonData: operation.outputData!) {
          celeturKitLogger.debug("payload:\(d)")
          
          self.encryptPayload(key: masterKey.accessToken!, payload: operation.outputData!, status: TresorDocumentItemStatus.encrypted) {
            completion()
          }
        }
      }
      
      SymmetricCipherOperation.cipherQueue.addOperation(operation)
    }
  }
  
  public func decryptPayload(masterKey:TresorKey, completion: ((SymmetricCipherOperation?)->Void)?) {
    if let payload = self.payload, let nonce = self.nonce {
      let operation = AES256DecryptionOperation(key:masterKey.accessToken!, inputData: payload, iv:nonce)
      
      if let c = completion {
        operation.completionBlock = {
          c(operation)
        }
      }
      
      SymmetricCipherOperation.cipherQueue.addOperation(operation)
    } else {
      if let c = completion {
        c(nil)
      }
    }
  }
}


