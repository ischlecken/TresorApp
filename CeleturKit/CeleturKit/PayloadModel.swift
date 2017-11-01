//
//  PayloadModel.swift
//  CeleturKit
//
//  Created by Feldmaus on 31.10.17.
//  Copyright © 2017 prisnoc. All rights reserved.
//

public typealias PayloadModelType = [String:Any]

public class PayloadModel {

  public class func jsonData(model:PayloadModelType) -> Data? {
    var result : Data?
    
    do {
      result = try JSONSerialization.data(withJSONObject: model, options: [])
    } catch {
      celeturKitLogger.error("Error while serializing json object", error: error)
    }
    
    return result
  }
  
  public class func model(jsonData:Data) -> PayloadModelType? {
    var result : [String:Any]?
    
    do {
      result = try JSONSerialization.jsonObject(with: jsonData, options: []) as? PayloadModelType
    } catch {
      celeturKitLogger.error("Error serializing metainfo json",error:error)
    }
  
    return result
    
  }
}
