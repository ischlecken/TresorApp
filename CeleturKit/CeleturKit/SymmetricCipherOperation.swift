//
//  Created by Feldmaus on 23.07.17.
//  Copyright © 2017 prisnoc. All rights reserved.
//

import Foundation
import CKCommonCrypto

public class SymmetricCipherOperation : Operation {
  
  public let key: Data
  public let inputData: Data
  public var iv: Data?
  public var outputData: Data?
  public var error: Error?
  
  public init(key:Data, inputData:Data, iv: Data?) {
    self.key = key
    self.inputData = inputData
    self.iv = iv
  }
  
  public convenience init(key:Data, inputString:String, iv: Data?) {
    self.init(key:key, inputData:inputString.data(using: String.Encoding.utf8)!, iv:iv)
  }
  
  public func createRandomIV() throws {
    assert(false,"Not implemented")
  }
  
  internal func cryptoOperation(algorithm: SymmetricCipherAlgorithm, options: SymmetricCipherOptions, operation: CCOperation) {
    let ivCondition = self.iv != nil || options.contains(SymmetricCipherOptions.ECBMode)
    guard ivCondition else {
      self.error = CeleturKitError.cipherMissingIV
      return
    }
    
    celeturKitLogger.debug("SymmetricCipherOperation.cryptoOperation(operation:\(operation)) key:\(self.key.hexEncodedString())")
    
    // Prepare data parameters
    let keyData: Data! = self.key
    let keyBytes = keyData.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) -> UnsafePointer<UInt8> in
      return bytes
    }
    
    //let keyBytes         = keyData.bytes.bindMemory(to: Void.self, capacity: keyData.count)
    let keyLength        = size_t(algorithm.requiredKeySize())
    let dataLength       = Int(self.inputData.count)
    let dataBytes        = self.inputData.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) -> UnsafePointer<UInt8> in
      return bytes
    }
    var bufferData       = Data(count: Int(dataLength) + algorithm.requiredBlockSize())
    let bufferPointer    = bufferData.withUnsafeMutableBytes { (bytes: UnsafeMutablePointer<UInt8>) -> UnsafeMutablePointer<UInt8> in
      return bytes
    }
    
    let bufferLength     = size_t(bufferData.count)
    let ivBuffer: UnsafePointer<UInt8>? = (self.iv == nil) ? nil : self.iv!.withUnsafeBytes({ (bytes: UnsafePointer<UInt8>) -> UnsafePointer<UInt8> in
      return bytes
    })
    
    var bytesProcessed   = Int(0)
    
    sleep(5)
    
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
      &bytesProcessed)            // output bytes decrypted real length
    
    
    if cryptStatus == kCCSuccess {
      bufferData.count = bytesProcessed // Adjust buffer size to real bytes
      
      self.outputData = bufferData as Data
    } else {
      self.error = CeleturKitError.cipherOperationFailed(ccError: cryptStatus)
    }
  }
  
  public func jsonOutputObject() throws -> [String:Any]? {
    var result : [String:Any]?
    
    if let d = self.outputData {
      do {
        result = try JSONSerialization.jsonObject(with: d, options: []) as? [String:Any]
      } catch {
        celeturKitLogger.error("Error while decoding json",error:error)
        
        throw error
      }
    }
    
    return result
  }
}

public class AES256EncryptionOperation : SymmetricCipherOperation {
  
  let algorithm = SymmetricCipherAlgorithm.aes_256
  let options:SymmetricCipherOptions =  [.PKCS7Padding]
  
  public override func createRandomIV() throws {
    self.iv = try Data(withRandomData:self.algorithm.requiredBlockSize())
  }
  
  public override func main() {
    guard !self.isCancelled else { return }
    
    self.cryptoOperation(algorithm: algorithm, options: options, operation: CCOperation(kCCEncrypt))
  }
}

public class AES256DecryptionOperation : SymmetricCipherOperation {
  
  let algorithm = SymmetricCipherAlgorithm.aes_256
  let options:SymmetricCipherOptions =  [.PKCS7Padding]
  
  public override func main() {
    guard !self.isCancelled else { return }
    
    self.cryptoOperation(algorithm:algorithm, options:options, operation: CCOperation(kCCDecrypt))
  }
}
