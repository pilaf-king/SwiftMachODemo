//
//  File.swift
//  SwiftDynamicRun
//
//  Created by 蒋演 on 2020/11/2.
//  Copyright © 2020 蒋演. All rights reserved.
//
import UIKit
import Foundation

 class MyClass  {
    
    var p:Int = 0
    
    init() {
        self.helloSwift()
        print("init")
    }
    
    func helloSwift() -> Int {
        print("helloSwift")
        return 100
    }

    func helloSwift1() -> Int {
        print("helloSwift1")
        return 100
    }
    
    func helloSwift2() -> Int {
        print("helloSwift2")
        return 100
    }
}

class FireClass : NSObject {
    @objc func fire() {
        let myClass = MyClass.init()
        myClass.helloSwift2()
    }
}

class YourClass:MyClass  {
  
   override func helloSwift() -> Int {
       print("YourClass helloSwift")
       return 100
   }

   func helloSwift5() -> Int {
       print("helloSwift5")
       return 100
   }
}
