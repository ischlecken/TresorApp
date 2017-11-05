//
//  CeleturKitTests.swift
//  CeleturKitTests
//
//  Created by Feldmaus on 16.07.17.
//  Copyright © 2017 prisnoc. All rights reserved.
//

import XCTest
@testable import CeleturKit

class CeleturKitTests: XCTestCase {
  
  override func setUp() {
    super.setUp()
    // Put setup code here. This method is called before the invocation of each test method in the class.
  }
  
  override func tearDown() {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    super.tearDown()
  }
  
  func testExample() {
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct results.
  }
  
  func testPerformanceExample() {
    // This is an example of a performance test case.
    self.measure {
      // Put the code you want to measure the time of here.
    }
  }
  
  func testDataHexString() {
    let hexString0 = "0011223345bbCCddeeff"
    let hexData = Data(fromHexEncodedString:hexString0)
    
    let hexString1 = hexData!.hexEncodedString()
    
    print("hex0:\(hexString0) hex1:\(hexString1)")
    
    XCTAssert(hexString0.lowercased() == hexString1, "both hexstring should be equal")
  }
  
  func testAES256() {
    let key = Data(fromHexEncodedString:"6d356b687631384a584b46564945543870486130414234485361546573784551")
    let data = "Test, the quick brown fox jumps over the lazy dog, 123,123,123"
    let expectedEncryption = "8e96d94452f14c554b63425f4ac7566d23ee560007ceb4e36b30180971e7bc9708efdc31c2d38bb3474b87f883813253dafa6f236f9f909cbb4b4781fa9ba934"
    
    let encryptor = AES256Encryption(key: key!, inputString: data, iv: nil)
    
    encryptor.options = [SymmetricCipherOptions.PKCS7Padding,SymmetricCipherOptions.ECBMode]
    
    encryptor.execute()
    
    if let encryptionResult = encryptor.outputData {
      XCTAssert(expectedEncryption == encryptionResult.hexEncodedString(), "encrypted result is not equal to expected value")
    
      let decryptor = AES256Decryption(key: key!, inputData: encryptionResult, iv: nil)
      decryptor.options = [SymmetricCipherOptions.PKCS7Padding,SymmetricCipherOptions.ECBMode]
      
      decryptor.execute()
      
      if let decryptionResult = decryptor.outputData {
        XCTAssert(String(data:decryptionResult,encoding:.utf8) == data, "decryption is not equal to original")
        
        return
      }
    }
 
    XCTFail()
  }
  
  func testPayloadModel1() {
    let payloadItem = PayloadItem(name: "test", value: .i(10), attributes: [:])
    let expectedJSON = "{\"name\":\"test\",\"value\":10}"
    
    if let jsonPayloadItem = PayloadModel.toJSON(model:payloadItem),
      let resultJSON = String(data:jsonPayloadItem,encoding:.utf8) {
      
      XCTAssert(expectedJSON == resultJSON, "expected json differs from resulting json")
      
      return
    }
  
    XCTFail()
  }
  
  func testPayloadModel2() {
    let json = "{\"name\":\"test\",\"value\":1}"
    let payloadItem = PayloadModel.toPayloadItem(jsonData:json.data(using:.utf8)!)
    
    XCTAssertNotNil(payloadItem)
    
    XCTAssert(payloadItem!.name == "test")
    XCTAssert(payloadItem!.value == PayloadItem.ValueType.i(1))
    XCTAssert(payloadItem!.attributes.count == 0)
    
    let json1 = PayloadModel.toJSON(model: payloadItem!)
    
    XCTAssertNotNil(json1)
    
    XCTAssert(String(data:json1!,encoding:.utf8) == json)
  }
  
  func testPayloadModel3() {
    let json = "{\"name\":\"model3test\",\"value\":\"bla fasel\",\"attributes\":{\"type\":\"String\",\"maxlength\":1}}"
    let json2 = "{\"name\":\"model3test\",\"value\":\"bla fasel\",\"attributes\":{\"maxlength\":1}}"
    let payloadItem = PayloadModel.toPayloadItem(jsonData:json.data(using:.utf8)!)
    
    XCTAssertNotNil(payloadItem)
    
    XCTAssert(payloadItem!.name == "model3test")
    XCTAssert(payloadItem!.value == PayloadItem.ValueType.s("bla fasel"))
    XCTAssert(payloadItem!.attributes.count == 1)
    
    let json1 = PayloadModel.toJSON(model: payloadItem!)
    
    XCTAssertNotNil(json1)
    
    XCTAssert(String(data:json1!,encoding:.utf8) == json2)
  }
  
  func testPayload() {
    let payloadItem1 = PayloadItem(name: "user", value: .s("hugo"), attributes: [:])
    let payloadItem2 = PayloadItem(name: "password", value: .s("secret123"), attributes: [:])
    
    let payloadSection = PayloadSection(name: "main", items: [payloadItem1,payloadItem2])
    let payloadSections = PayloadSections(sections: [payloadSection])
    
    let payload = Payload(title: "test", description: nil, list: [payloadSections])
    
    if let json = PayloadModel.toJSON(model: payload) {
      celeturKitLogger.debug("json:\(String(data:json,encoding:.utf8) ?? "-")")
    }
  }
}
