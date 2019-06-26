//
//  stationTests.swift
//  stationTests
//
//  Created by Elias Berg on 19/05/2018.
//  Copyright © 2018 Ruuvi Innovations Oy. All rights reserved.
//

import XCTest
@testable import station

class stationTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testBackgroundPersistenceUserDefaultsBGIsBiasedToNotUsed() {
        let b = BackgroundPersistenceUserDefaults()
        var set = Set<Int>()
        for _ in b.bgMinIndex...b.bgMaxIndex {
            let random = b.biasedToNotUsedRandom()
            XCTAssert(!set.contains(random))
            set.insert(random)
        }
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
}
