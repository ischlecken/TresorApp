//
//  TresorDocument+Extension.swift
//  CeleturKit
//

extension TresorDocument {
  
  class func createTresorDocument(context:NSManagedObjectContext, tresor:Tresor) throws -> TresorDocument {
    let newTresorDocument = TresorDocument(context: context)
    newTresorDocument.createts = Date()
    newTresorDocument.changets = newTresorDocument.createts
    newTresorDocument.id = String.uuid()
    newTresorDocument.tresor = tresor
    newTresorDocument.nonce = try Data(withRandomData:SymmetricCipherAlgorithm.aes_256.requiredBlockSize())
    
    return newTresorDocument
  }
  
  public func setMetaInfo(title:String, description: String?) {
    var metaInfo = [ "title":title ]
  
    if let d = description {
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
}
