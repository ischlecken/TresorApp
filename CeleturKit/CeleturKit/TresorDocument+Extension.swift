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
}
