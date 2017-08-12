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
  
}
