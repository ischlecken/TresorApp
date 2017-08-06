//
//  CeleturError.swift
//  CeleturKit
//
//  Created by Feldmaus on 23.07.17.
//  Copyright © 2017 prisnoc. All rights reserved.
//

public enum CeleturKitError: Error {
  case cipherMissingIV
  case cipherOperationFailed
  case cipherWrongInputData
  case cipherUnknownError
  
  case dataSaveFailed(coreDataError:Error)
  case creationOfFetchResultsControllerFailed(coreDataError:Error)
  
  case keychainError(keychainError:OSStatus)
  case keychainError1(keychainError:Error)
  
}
