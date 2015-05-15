//
//  ViewController.swift
//  P4P
//
//  Created by Frank Jiang on 6/4/15.
//  Copyright (c) 2015 P4P. All rights reserved.
//

import UIKit
import SwiftyJSON

class ViewController: UIViewController, UITextFieldDelegate {
    //var tabBarController;
    
    var backgroundView: UIImageView?
    var websiteURLbase = ""
    
    var keychainWrapper:KeychainWrapper!
    let createLoginButtonTag = 0
    let loginButtonTag = 1

    @IBOutlet weak var usernameTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var loginButton: UIButton!
    @IBOutlet weak var failedLoginLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
        websiteURLbase = appDelegate.websiteURLBase
        keychainWrapper = appDelegate.keychainWrapper
        
        // Check if the user login info is stored
        let hasLoginKey = NSUserDefaults.standardUserDefaults().boolForKey("hasLoginKey")
        if hasLoginKey == true {
            var userName = keychainWrapper.myObjectForKey(kSecAttrAccount) as! String
            var password = keychainWrapper.myObjectForKey(kSecValueData) as! String
            
            login(userName, password: password)
        }

        // Do any additional setup after loading the view, typically from a nib.
        self.usernameTextField.delegate = self
        self.passwordTextField.delegate = self
        
        backgroundView = UIImageView(image: UIImage(named: "HomeScreen.png"))
        backgroundView!.frame = UIScreen.mainScreen().bounds
        self.view.insertSubview(backgroundView!, atIndex: 0)
    }
    
    override func viewWillAppear(animated: Bool) {
        UIApplication.sharedApplication().statusBarStyle = .LightContent
    }
    
    override func viewWillDisappear(animated: Bool) {
        UIApplication.sharedApplication().statusBarStyle = .Default
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // dismisses iOS keyboard after you open a textfield and touch anywhere else
    override func touchesBegan(touches: Set<NSObject>, withEvent event: UIEvent) {
        view.endEditing(true)
        super.touchesBegan(touches, withEvent: event)
    }
    
    // called when you hit enter in a text field. dismisses keyboard
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        view.endEditing(true)
        
        if textField === self.passwordTextField && self.usernameTextField.text != "" {
            self.login(self)
        }
        return false
    }

    @IBAction func login(sender: AnyObject) {
        if self.failedLoginLabel.alpha != 0.0 {
            dispatch_async(dispatch_get_main_queue()) {
                UIView.animateWithDuration(0.1, delay: 0, options: UIViewAnimationOptions.CurveEaseOut, animations: {
                    self.failedLoginLabel.alpha = 0.0
                    }, completion: nil)
            }
        }
        login(self.usernameTextField.text.lowercaseString, password: self.passwordTextField.text)
    }
    
    func login(username:String, password:String) {
        usernameTextField.text = ""
        passwordTextField.text = ""

        let deviceID: String = (UIApplication.sharedApplication().delegate as! AppDelegate).deviceToken
        let pwHash: String = password.MD5P4P()
        let url = NSURL(string: self.websiteURLbase + "/mobileLogin.php?un=" + username + "&pwHash=" + pwHash + "&deviceID=" + deviceID)
        
        var loginViewController = self;
        let task = NSURLSession.sharedSession().dataTaskWithURL(url!) {(data, response, error) in
            let json = JSON(data: data)
            if let authResult = json.array {
                
                if count(authResult) > 0 {
                    dispatch_async(dispatch_get_main_queue()) {
                        
                        let hasLoginKey = NSUserDefaults.standardUserDefaults().boolForKey("hasLoginKey")
                        if hasLoginKey == false {
                            NSUserDefaults.standardUserDefaults().setValue(true, forKey: "hasLoginKey")
                            NSUserDefaults.standardUserDefaults().synchronize()
                            self.keychainWrapper.mySetObject(username, forKey:kSecAttrAccount)
                            self.keychainWrapper.mySetObject(password, forKey:kSecValueData)
                        }
                        
                        let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
                        appDelegate.userNetid = username
                        appDelegate.pwHash = pwHash
                        
                        if let firstName = json["firstName"].string {
                            appDelegate.firstName = firstName
                        }
                        if let lastName = json["lastName"].string {
                            appDelegate.lastName = lastName
                        }
                        appDelegate.loggedIn = true
                        
                        // Open dashboard
                        self.performSegueWithIdentifier("openDash", sender: self)
                        
                    }
                } else {
                    dispatch_async(dispatch_get_main_queue()) {
                        UIView.animateWithDuration(0.5, delay: 0, options: UIViewAnimationOptions.CurveEaseOut, animations: {
                            self.failedLoginLabel.alpha = 1.0
                            
                            }, completion: nil)
                    }
                }
            } else {
                dispatch_async(dispatch_get_main_queue()) {
                    UIView.animateWithDuration(0.5, delay: 0, options: UIViewAnimationOptions.CurveEaseOut, animations: {
                        self.failedLoginLabel.alpha = 1.0
                        
                        }, completion: nil)
                }
            }
            
        }
        task.resume()
    }
}

extension Int {
    func hexStringP4P() -> String {
        return NSString(format:"%02x", self) as String
    }
}

extension NSData {
    func hexStringP4P() -> String {
        var string = String()
        for i in UnsafeBufferPointer<UInt8>(start: UnsafeMutablePointer<UInt8>(bytes), count: length) {
            string += Int(i).hexStringP4P()
        }
        return string
    }
    
    func MD5P4P() -> NSData {
        let result = NSMutableData(length: Int(CC_MD5_DIGEST_LENGTH))!
        CC_MD5(bytes, CC_LONG(length), UnsafeMutablePointer<UInt8>(result.mutableBytes))
        return NSData(data: result)
    }
}

extension String {
    func MD5P4P() -> String {
        return (self as NSString).dataUsingEncoding(NSUTF8StringEncoding)!.MD5P4P().hexStringP4P()
    }
}

