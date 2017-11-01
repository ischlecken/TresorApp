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

  class func createPendingTresorDocumentItem(context: NSManagedObjectContext,
                                             tresorDocument:TresorDocument,
                                             userDevice:TresorUserDevice) -> TresorDocumentItem {
    
    let result = TresorDocumentItem(context: context)
    
    result.createts = Date()
    result.changets = result.createts
    result.id = String.uuid()
    result.status = TresorDocumentItemStatus.pending.rawValue
    result.document = tresorDocument
    result.userdevice = userDevice
    
    tresorDocument.addToDocumentitems(result)
    userDevice.addToDocumentitems(result)
    
    return result
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
  
  class func createTresorDocumentItem(context: NSManagedObjectContext,
                                      tresorDocument:TresorDocument,
                                      userDevice: TresorUserDevice,
                                      key: Data,
                                      payload: Data,
                                      status: TresorDocumentItemStatus) throws -> TresorDocumentItem? {
    
    var result : TresorDocumentItem?
    
    if let tempTresorDocument = context.object(with: tresorDocument.objectID) as? TresorDocument,
      let tempUserDevice = context.object(with: userDevice.objectID) as? TresorUserDevice {
    
      let tempTDI = TresorDocumentItem.createPendingTresorDocumentItem(context: context,
                                                                       tresorDocument: tempTresorDocument,
                                                                       userDevice: tempUserDevice)
      
      tempTDI.encryptPayload(context: context, key: key, payload: payload, status: status)
      
      result = tempTDI
    }
    
    return result
  }
  
  func encryptPayload(context: NSManagedObjectContext,
                      key: Data,
                      payload: Data,
                      status: TresorDocumentItemStatus) {
    
    do {
      let tdi = context.object(with: self.objectID) as! TresorDocumentItem
      
      tdi.status = TresorDocumentItemStatus.pending.rawValue
      context.performSave(contextInfo: "pending tresor documentitem")
      
      let operation = AES256EncryptionOperation(key:key, inputData: payload, iv:nil)
      try operation.createRandomIV()
      
      operation.completionBlock = {
        tdi.changets = Date()
        tdi.type = "main"
        tdi.mimetype = "application/json"
        tdi.status = status.rawValue
        tdi.payload = operation.outputData
        tdi.nonce = operation.iv
        
        context.performSave(contextInfo: "tresor documentitem")
      }
      
      SymmetricCipherOperation.cipherQueue.addOperation(operation)
    } catch {
      celeturKitLogger.error("Error while encryption payload from edit dialogue",error:error)
    }
  }
  
  func encryptMessagePayload(tresorModel: TresorModel, masterKey:TresorKey) {
    if let ud = self.userdevice,
      let payload = self.payload,
      let nonce = self.nonce,
      let messageKey = ud.messagekey,
      currentDeviceInfo?.isCurrentDevice(tresorUserDevice: ud) ?? false {
      
      celeturKitLogger.debug("item \(self.id ?? "-") should be encrypted by device...")
      
      let operation = AES256DecryptionOperation(key: messageKey,inputData: payload, iv:nonce)
      operation.completionBlock = {
        do {
          if let d = PayloadModel.model(jsonData: payload) {
            celeturKitLogger.debug("payload:\(d)")
            
            let encryptOperation = AES256EncryptionOperation(key:masterKey.accessToken! ,inputData: operation.outputData!, iv:nil)
            try encryptOperation.createRandomIV()
            
            encryptOperation.completionBlock = {
              self.managedObjectContext?.perform {
                self.type = "main"
                self.mimetype = "application/json"
                self.status = TresorDocumentItemStatus.encrypted.rawValue
                self.payload = encryptOperation.outputData
                self.nonce = encryptOperation.iv
                
                tresorModel.saveChanges()
              }
            }
            
            SymmetricCipherOperation.cipherQueue.addOperation(encryptOperation)
          }
        } catch {
          celeturKitLogger.error("error decoding payload", error: error)
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


