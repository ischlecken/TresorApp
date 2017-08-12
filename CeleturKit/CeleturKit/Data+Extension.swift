//
//  Created by Feldmaus on 23.07.17.
//  Copyright © 2017 prisnoc. All rights reserved.
//

import Foundation

public extension Data {
  
  public func hexEncodedString() -> String {
    return self.map { String(format: "%02hhx", $0) }.joined()
  }
  
  public init?(withRandomData length: Int) {
   self.init(count: length)
    
    let bytes = self.withUnsafeMutableBytes { (bytes: UnsafeMutablePointer<UInt8>) -> UnsafeMutablePointer<UInt8> in
      return bytes
    }
    
    let status = SecRandomCopyBytes(kSecRandomDefault, length, bytes)
    
    guard status == 0 else { return nil }
  }
  
  public init?(fromHexEncodedString string: String) {
    
    // Convert 0 ... 9, a ... f, A ...F to their decimal value,
    // return nil for all other input characters
    func decodeNibble(u: UInt16) -> UInt8? {
      switch(u) {
      case 0x30 ... 0x39:
        return UInt8(u - 0x30)
      case 0x41 ... 0x46:
        return UInt8(u - 0x41 + 10)
      case 0x61 ... 0x66:
        return UInt8(u - 0x61 + 10)
      default:
        return nil
      }
    }
    
    self.init(capacity: string.utf16.count/2)
    var even = true
    var byte: UInt8 = 0
    
    for c in string.utf16 {
      guard let val = decodeNibble(u: c) else { return nil }
    
      if even {
        byte = val << 4
      } else {
        byte += val
        self.append(byte)
      }
      even = !even
    }
    
    guard even else { return nil }
  }
}
