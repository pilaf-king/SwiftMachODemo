//
//  ViewController.swift
//  SwiftDemo
//
//  Created by 邓竹立 on 2021/2/26.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        let myTest = MyTestClass.init()

        var result = myTest.oriFunc(_name: "before")
        print("return \(result)")
        
        WBOCTest.replace(SubTestClass.self);
        
        result = myTest.oriFunc(_name: "after")
        print("return \(result)")
    }
}

class MyTestClass {
       
    func repFunc1(_name:String) -> String {
        print("call repFunc \(_name)")
        return "repFunc "
    }
    
    func repFunc2(_name:String) -> String {
        print("call repFunc \(_name)")
        return "repFunc "
    }
    
    func oriFunc(_name:String) -> String {
        print("call oriFunc \(_name)")
        return "oriFunc "
    }

    func repFunc(_name:String) -> String {
        print("call repFunc \(_name)")
        return "repFunc "
    }
}


class SubTestClass : MyTestClass {
    
    override func oriFunc(_name:String) -> String {
        print("subclass oriFunc run \(_name)")
        return "oriFunc"
    }
    
//    override func repFunc(_name:String) -> String {
//        print("subclass repFunc run \(_name)")
//        return "repFunc"
//    }
}

class SubSubTestClass : SubTestClass {
    
    override func oriFunc(_name:String) -> String {
        print("subclass oriFunc run \(_name)")
        return "oriFunc"
    }
    
    override func repFunc(_name:String) -> String {
        print("subclass repFunc run \(_name)")
        return "repFunc"
    }
}
