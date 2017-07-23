//
//  CryptoEnums.swift
//  CeleturKit
//
//  Created by Feldmaus on 23.07.17.
//  Copyright © 2017 prisnoc. All rights reserved.
//
import CKCommonCrypto

public enum SymmetricCipherAlgorithm {
  case des        // DES standard, 64 bits key
  case des40      // DES, 40 bits key
  case tripledes  // 3DES, 192 bits key
  case rc4_40     // RC4, 40 bits key
  case rc4_128    // RC4, 128 bits key
  case rc2_40     // RC2, 40 bits key
  case rc2_128    // RC2, 128 bits key
  case aes_128    // AES, 128 bits key
  case aes_256    // AES, 256 bits key
  
  // returns the CCAlgorithm associated with this SymmetricCryptorAlgorithm
  public func ccAlgorithm() -> CCAlgorithm {
    switch (self) {
    case .des: return CCAlgorithm(kCCAlgorithmDES)
    case .des40: return CCAlgorithm(kCCAlgorithmDES)
    case .tripledes: return CCAlgorithm(kCCAlgorithm3DES)
    case .rc4_40: return CCAlgorithm(kCCAlgorithmRC4)
    case .rc4_128: return CCAlgorithm(kCCAlgorithmRC4)
    case .rc2_40: return CCAlgorithm(kCCAlgorithmRC2)
    case .rc2_128: return CCAlgorithm(kCCAlgorithmRC2)
    case .aes_128: return CCAlgorithm(kCCAlgorithmAES)
    case .aes_256: return CCAlgorithm(kCCAlgorithmAES)
    }
  }
  
  // Returns the needed size for the IV to be used in the algorithm (0 if no IV is needed).
  public func requiredIVSize(_ options: CCOptions) -> Int {
    // if kCCOptionECBMode is specified, no IV is needed.
    if options & CCOptions(kCCOptionECBMode) != 0 { return 0 }
    // else depends on algorithm
    switch (self) {
    case .des: return kCCBlockSizeDES
    case .des40: return kCCBlockSizeDES
    case .tripledes: return kCCBlockSize3DES
    case .rc4_40: return 0
    case .rc4_128: return 0
    case .rc2_40: return kCCBlockSizeRC2
    case .rc2_128: return kCCBlockSizeRC2
    case .aes_128: return kCCBlockSizeAES128
    case .aes_256: return kCCBlockSizeAES128 // AES256 still requires 256 bits IV
    }
  }
  
  public func requiredKeySize() -> Int {
    switch (self) {
    case .des: return kCCKeySizeDES
    case .des40: return 5 // 40 bits = 5x8
    case .tripledes: return kCCKeySize3DES
    case .rc4_40: return 5
    case .rc4_128: return 16 // RC4 128 bits = 16 bytes
    case .rc2_40: return 5
    case .rc2_128: return kCCKeySizeMaxRC2 // 128 bits
    case .aes_128: return kCCKeySizeAES128
    case .aes_256: return kCCKeySizeAES256
    }
  }
  
  public func requiredBlockSize() -> Int {
    switch (self) {
    case .des: return kCCBlockSizeDES
    case .des40: return kCCBlockSizeDES
    case .tripledes: return kCCBlockSize3DES
    case .rc4_40: return 0
    case .rc4_128: return 0
    case .rc2_40: return kCCBlockSizeRC2
    case .rc2_128: return kCCBlockSizeRC2
    case .aes_128: return kCCBlockSizeAES128
    case .aes_256: return kCCBlockSizeAES128 // AES256 still requires 128 bits IV
    }
  }
}

enum SymmetricCipherOptions {
  case ecb
  case cbc
  
  func options() -> CCOptions {
    switch(self) {
    case .ecb: return CCOptions(kCCOptionECBMode)
    case .cbc: return CCOptions(kCCOptionECBMode)
    }
  }
}
