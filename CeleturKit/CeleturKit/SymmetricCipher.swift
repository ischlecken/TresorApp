//
//  SymmeticCryptor.swift
//  CeleturKit
//
//  Created by Feldmaus on 23.07.17.
//  Copyright © 2017 prisnoc. All rights reserved.
//

import Foundation
import CKCommonCrypto

public class SymmetricCipher {

  var algorithm: SymmetricCipherAlgorithm
  var options: SymmetricCipherOptions
  var iv: Data?
  
  public init(algorithm: SymmetricCipherAlgorithm, options: SymmetricCipherOptions) {
    self.algorithm = algorithm
    self.options = options
  }
  
  public convenience init(algorithm: SymmetricCipherAlgorithm, options: SymmetricCipherOptions, iv: String, encoding: String.Encoding = String.Encoding.utf8) {
    self.init(algorithm: algorithm, options: options)
    self.iv = iv.data(using: encoding)
  }
  
  public func crypt(string: String, key: String) throws -> Data {
    do {
      if let data = string.data(using: String.Encoding.utf8) {
        return try self.cryptoOperation(data, key: key, operation: CCOperation(kCCEncrypt))
      } else { throw CeleturKitError.cipherWrongInputData }
    } catch {
      throw(error)
    }
  }
  
  public func crypt(data: Data, key: String) throws -> Data {
    do {
      return try self.cryptoOperation(data, key: key, operation: CCOperation(kCCEncrypt))
    } catch {
      throw(error)
    }
  }
  
  public func decrypt(_ data: Data, key: String) throws -> Data  {
    do {
      return try self.cryptoOperation(data, key: key, operation: CCOperation(kCCDecrypt))
    } catch {
      throw(error)
    }
  }
  
  internal func cryptoOperation(_ inputData: Data, key: String, operation: CCOperation) throws -> Data {
    print("cryptoOperation() key:\(key)")
    
    // Validation checks.
    if iv == nil && !self.options.contains(SymmetricCipherOptions.ECBMode) {
      throw(CeleturKitError.cipherMissingIV)
    }
    
    // Prepare data parameters
    let keyData: Data! = key.data(using: String.Encoding.utf8, allowLossyConversion: false)!
    let keyBytes = keyData.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) -> UnsafePointer<UInt8> in
      return bytes
    }
    //let keyBytes         = keyData.bytes.bindMemory(to: Void.self, capacity: keyData.count)
    let keyLength        = size_t(algorithm.requiredKeySize())
    let dataLength       = Int(inputData.count)
    let dataBytes        = inputData.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) -> UnsafePointer<UInt8> in
      return bytes
    }
    var bufferData       = Data(count: Int(dataLength) + algorithm.requiredBlockSize())
    let bufferPointer    = bufferData.withUnsafeMutableBytes { (bytes: UnsafeMutablePointer<UInt8>) -> UnsafeMutablePointer<UInt8> in
      return bytes
    }
    let bufferLength     = size_t(bufferData.count)
    let ivBuffer: UnsafePointer<UInt8>? = (iv == nil) ? nil : iv!.withUnsafeBytes({ (bytes: UnsafePointer<UInt8>) -> UnsafePointer<UInt8> in
      return bytes
    })
    var bytesDecrypted   = Int(0)
    // Perform operation
    let cryptStatus = CCCrypt(
      operation,                  // Operation
      algorithm.ccAlgorithm(),    // Algorithm
      options.rawValue,           // Options
      keyBytes,                   // key data
      keyLength,                  // key length
      ivBuffer,                   // IV buffer
      dataBytes,                  // input data
      dataLength,                 // input length
      bufferPointer,              // output buffer
      bufferLength,               // output buffer length
      &bytesDecrypted)            // output bytes decrypted real length
    if Int32(cryptStatus) == Int32(kCCSuccess) {
      bufferData.count = bytesDecrypted // Adjust buffer size to real bytes
      return bufferData as Data
    } else {
      print("Error in crypto operation: \(cryptStatus)")
      throw(CeleturKitError.cipherOperationFailed)
    }
  }
  
}
