//
//  Created by Feldmaus on 23.07.17.
//  Copyright © 2017 prisnoc. All rights reserved.
//

import Foundation

private let kCipherRandomUtilStringGeneratorCharset: [Character] = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".characters.map {$0}


public extension String {
  
  public init(withRandomData length: Int) {
    self.init()
    
    for _ in (1...length) {
      self.append(kCipherRandomUtilStringGeneratorCharset[Int(arc4random_uniform(UInt32(kCipherRandomUtilStringGeneratorCharset.count) - 1))])
    }
  }
  
  public static func uuid() -> String {
    return UUID().uuidString
  }
  
}
