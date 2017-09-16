//
//  TresorDocumentItem+Extension.swift
//  CeleturKit
//

extension TresorDocumentItem {

  class func createPendingTresorDocumentItem(context:NSManagedObjectContext,
                                             tresorDocument:TresorDocument,
                                             userDevice:TresorUserDevice) -> TresorDocumentItem {
    let result = TresorDocumentItem(context: context)
    
    result.createts = Date()
    result.id = String.uuid()
    result.status = "pending"
    result.document = tresorDocument
    result.userdevice = userDevice
    
    return result
  }

}


