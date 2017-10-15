//
//  Bundle+extension.swift
//  CeleturKit
//
//  Created by Feldmaus on 15.10.17.
//  Copyright © 2017 prisnoc. All rights reserved.
//

extension Bundle {
  
  func coreDataModelURL(modelName:String) -> URL {
    guard let url = self.url(forResource: modelName, withExtension: "momd") else { celeturKitLogger.fatal("could not find coredata model") }
    
    return url
  }
  
}
