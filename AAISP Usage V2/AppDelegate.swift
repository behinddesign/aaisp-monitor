//
//  AppDelegate.swift
//  AAISP Usage V2
//
//  Created by Graham Davies on 08/08/2016.
//  Copyright © 2016 Graham Davies. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    let defaults = NSUserDefaults.standardUserDefaults()
    let statusItem = NSStatusBar.systemStatusBar().statusItemWithLength(-1)
    var emailAddress = ""
    var password = ""
    var updateFreq = 0
    var timer = NSTimer.init()
    
    let statusIconBlack = NSImage(named: "statusIconBlack")
    let statusIconWhite = NSImage(named: "statusIconWhite")
    
    @IBOutlet weak var window: NSWindow!
    @IBOutlet weak var statusMenu: NSMenu!
    @IBOutlet weak var settingsMenu: NSWindow!
    
    @IBAction func menuClicked(sender: NSMenuItem) {
        [refreshUsageRemaining()]
    }
    
    @IBOutlet weak var emailAddressField: NSTextField!
    @IBOutlet weak var passwordField: NSSecureTextField!
    @IBOutlet weak var updateFreqField: NSTextField!
    @IBAction func settingsClicked(sender: AnyObject) {
        emailAddressField.stringValue = emailAddress
        passwordField.stringValue = password
        updateFreqField.stringValue = String(updateFreq)
        
        settingsMenu.setIsVisible(true)
    }
    
    @IBAction func saveClicked(sender: AnyObject) {
        if (updateFreqField.integerValue <= 5) {
            let alert : NSAlert = NSAlert();
            alert.messageText = "Message";
            alert.informativeText = "You must enter a value greater than 5";
            alert.runModal();
            
            return;
        }
        
        settingsMenu.setIsVisible(false)
        
        defaults.setObject(emailAddressField.stringValue, forKey: "emailAddressField")
        defaults.setObject(passwordField.stringValue, forKey: "passwordField")
        defaults.setInteger(updateFreqField.integerValue, forKey: "updateFreqField")
        
        emailAddress = emailAddressField.stringValue
        password = passwordField.stringValue
        updateFreq = updateFreqField.integerValue
        
        [refreshUsageRemaining()]
        [buildTimer()]
    }
    
    @IBAction func quitClicked(sender: AnyObject) {
        NSApplication.sharedApplication().terminate(self)
    }

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        statusItem.title = "..."
        statusItem.menu = statusMenu
        
        //Load settings
        if let emailAddressStore = defaults.stringForKey("emailAddressField") {
            emailAddress = emailAddressStore
        }
        
        if let passwordStore = defaults.stringForKey("passwordField") {
            password = passwordStore
        }
        
        if let updateFreqStore : Int = defaults.integerForKey("updateFreqField") {
            updateFreq = updateFreqStore
        } else {
            updateFreq = 3600
        }
        
        [refreshUsageRemaining()]
        [buildTimer()]
    }
    
    func refreshUsageRemaining() {
        if (emailAddress == "" || password == "") {
            statusItem.title = "Run Settings"
            return;
        }
        
        statusItem.title = "...."
        
        if NSUserDefaults.standardUserDefaults().stringForKey("AppleInterfaceStyle") == "Light" {
            statusItem.image = statusIconBlack
        } else {
            statusItem.image = statusIconWhite
        }
        
        print ("Starting usage update")
        // Setup the session to make REST GET call.  Notice the URL is https NOT http!!
        let infoEndpoint: String = "https://chaos.aa.net.uk/info?JSON=1"
        let loginString = NSString(format: "%@:%@", emailAddress, password)
        let loginData: NSData = loginString.dataUsingEncoding(NSUTF8StringEncoding)!
        let base64LoginString = loginData.base64EncodedStringWithOptions([])
        
        let session = NSURLSession.sharedSession()
        let url = NSURL(string: infoEndpoint)!
        let request = NSMutableURLRequest(URL: url)
        request.setValue("Basic \(base64LoginString)", forHTTPHeaderField: "Authorization")
        
        session.dataTaskWithRequest(request, completionHandler: { ( data: NSData?, response: NSURLResponse?, error: NSError?) -> Void in
            
            guard let realResponse = response as? NSHTTPURLResponse where
                realResponse.statusCode == 200 else {
                    print("Not a 200 response")
                    return
            }

            do {
                let json = try NSJSONSerialization.JSONObjectWithData(data!, options: .AllowFragments)
                    
                guard let elLogins = json["login"] as? [AnyObject],
                    let elLogin = elLogins[0] as? [String: AnyObject],
                    let elBroadbands = elLogin["broadband"] as? [AnyObject],
                    let elBroadband = elBroadbands[0] as? [String: AnyObject] else {
                        self.statusItem.title = "Invalid Details"
                        print ("invalid details")
                    return
                }
                    
                let quotaLeft: Int = Int((elBroadband["quota_left"] as! String))!
                    
                let quotaLeftGb = quotaLeft / 1000000000
                
                self.statusItem.title = "\(quotaLeftGb)gb"
                
                print ("Finishing usage update")
                    
            } catch {
                print ("error reading JSON : \(error)")
            }
            
        }).resume()
    }
    
    func buildTimer() {
        let timeInterval = NSTimeInterval(updateFreq)
        
        timer.invalidate()
        
        timer = NSTimer.scheduledTimerWithTimeInterval(timeInterval, target:self, selector: #selector(AppDelegate.refreshUsageRemaining), userInfo: nil, repeats: true)
    }

}

