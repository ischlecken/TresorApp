//
//  CipherRandomUtil.swift
//  CeleturKit
//
//  Created by Feldmaus on 23.07.17.
//  Copyright © 2017 prisnoc. All rights reserved.
//

import Foundation

private let kCipherRandomUtilStringGeneratorCharset: [Character] = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".characters.map {$0}

public class CipherRandomUtil {
  
  
  public class func randomDataOfLength(_ length: Int) -> Data? {
    var mutableData = Data(count: length)
    let bytes = mutableData.withUnsafeMutableBytes { (bytes: UnsafeMutablePointer<UInt8>) -> UnsafeMutablePointer<UInt8> in
      return bytes
    }
    let status = SecRandomCopyBytes(kSecRandomDefault, length, bytes)
    return status == 0 ? mutableData as Data : nil
  }
  
  public class func randomStringOfLength(_ length:Int) -> String {
    var string = ""
    for _ in (1...length) {
      string.append(kCipherRandomUtilStringGeneratorCharset[Int(arc4random_uniform(UInt32(kCipherRandomUtilStringGeneratorCharset.count) - 1))])
    }
    return string
  }
  
}
