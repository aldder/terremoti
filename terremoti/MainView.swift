//
//  ViewController.swift
//  terremoti
//
//  Created by Michael Oertel on 23/04/15.
//  Copyright (c) 2015 SapienzaApps. All rights reserved.
//

import UIKit
import CoreMotion
import CoreLocation
import Foundation

class MainView: UIViewController, CLLocationManagerDelegate {
    
    /* Connection with MainView objects */
    @IBOutlet weak var alertLabel: UILabel!
    @IBOutlet weak var statusLabel: UILabel!
    
    /***
     * GYROSCOPE and ACCELEROMETER properties
     * Gyroscope -> X, YUI, Z coordinates
     * Accelerometer -> X, Y coordinates; Z <- Array
     */
    private var gyroX: Double = 0.0
    private var gyroY: Double = 0.0
    private var gyroZ: Double = 0.0
    private var acceleoX: Double = 0.0
    private var acceleoY: Double = 0.0
    private var gravityX: Double = 0.0
    private var gravityY: Double = 0.0
    private var gravityZ: Double = 0.0
    
    /***
     * Accelerometer -> Z:Array
     *   (Calcolo media AcceleoZ)
     */
    private var arrayAcceleoZ = [Double](count:10, repeatedValue: 0.0)
    private let nAvgZ: Int = 10
    private var acceleoZ: Double = 0.0
    private var accumulatorZ: Double = 0.0
    private var iZ: Int = 0
    private var avgAcceleoZ: Double = 0.0
    private var oldAvgAcceleoZ: Double = 0.0
    
    /***
     * Accelerometer -> H:Array
     *   (Calcolo media AcceleoH)
     */
    private var arrayAcceleoH = [Double](count:10,repeatedValue: 0.0)
    private let nAvgH: Int = 10
    private var acceleoH: Double = 0.0
    private var accumulatorH: Double = 0.0
    private var iH: Int = 0
    private var avgAcceleoH: Double = 0.0
    private var oldAvgAcceleoH: Double = 0.0
    
    /* Skip first check about gaps */
    private var skipFirst: Bool = true
    //private var skipFirstZ: Int = 0
    //private var skipFirstH: Int = 0
    private var newMediaAcceleo: Double = 0.0
    private var oldMediaAcceleo: Double = 0.0
    private var gapZ: Double = 0.0
    private var gapH: Double = 0.0
    
    /* Latitude and Longitude Manager */
    private let locationManager = CLLocationManager()
    private var latitude: Double = 0.0
    private var longitude: Double = 0.0
    
    /* Gyroscope and Accelerometer Manager */
    private let motionManager = CMMotionManager()
    
    /* Server response management data */
    private var date = NSDate()
    private var oldTimestamp: NSTimeInterval = 0.0
    private var currentTimestamp: NSTimeInterval = 0.0
    
    /* Avoid sending continuos informations to the server */
    private var status: Bool = false
    
    /* Time to wait between EQ detections */
    private var timeWait: Double = 5.0
    
    /* Timers for updateStatus and updateAlert functions */
    private var statusTimer: NSTimer!
    private var alertTimer: NSTimer!
    
    private var device: UIDevice = UIDevice.currentDevice()
    
    var arrayLog = [LogEntry]()
    
    
    /* //MARK: Overrided Functions */
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //let filePath = NSBundle.mainBundle().pathForResource("Good", ofType: "gif")
        //let gif = NSData(contentsOfFile: filePath!)
        
        /* Activate proximity Sensor to switch screen off */
        if(!device.proximityMonitoringEnabled) {
            device.proximityMonitoringEnabled = true
        }
        
        /* Prevent to screen off when app is running in foreground */
        UIApplication.sharedApplication().idleTimerDisabled = true
        
        /* Alert Notification Layout */
        self.alertLabel.layer.contentsScale = UIScreen.mainScreen().scale
        self.alertLabel.layer.shadowColor = UIColor(red: (247/255), green: (247/255), blue: (247/255), alpha: 1.0).CGColor
        self.alertLabel.layer.shadowOffset = CGSizeZero
        self.alertLabel.layer.shadowRadius = 5.0
        self.alertLabel.layer.shadowOpacity = 1.0
        
        /* Status Notification Layout */
        self.statusLabel.layer.contentsScale = UIScreen.mainScreen().scale
        self.statusLabel.layer.shadowColor = UIColor(red: (247/255), green: (247/255), blue: (247/255), alpha: 1.0).CGColor
        self.statusLabel.layer.shadowOffset = CGSizeZero
        self.statusLabel.layer.shadowRadius = 5.0
        self.statusLabel.layer.shadowOpacity = 1.0
        
        /* Check for Internet connection */
        let reachability: Reachability
        do {
            reachability = try Reachability.reachabilityForInternetConnection()
        } catch {
            self.writeLog("Can't create connection", type: 4)
            return
        }
        if (reachability.isReachable()) {
            if (reachability.isReachableViaWiFi()) {
                self.writeLog("Connected via WiFi", type: 2)
            } else {
                self.writeLog("Connected via Cellular", type: 2)
            }
        } else {
            self.writeLog("Not connected", type: 4)
            let alert = UIAlertView(title: "No Internet Connection", message: "Make sure your device is connected to the internet.", delegate: self, cancelButtonTitle: "Close")
            alert.show()
            return
        }
        do {
            try reachability.startNotifier()
        } catch {
            self.writeLog("Can't start notifier", type: 4)
        }
        
        /* Check for GPS location */
        if (CLLocationManager.locationServicesEnabled()) {
            self.locationManager.delegate = self
            self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
            if #available(iOS 8.0, *) { // on iOS 7- there is no request authorization
                self.locationManager.requestWhenInUseAuthorization()
            }
            self.locationManager.startUpdatingLocation()
            switch(CLLocationManager.authorizationStatus()) {
            case .NotDetermined, .Restricted, .Denied: // Location services active, but not for this app
                let alert = UIAlertView(title: "Location Service Disabled", message: "To enable, please go to Settings and turn on Location Service for this app.", delegate: self, cancelButtonTitle: "Close")
                alert.show()
                return
            case .AuthorizedAlways, .AuthorizedWhenInUse: // Everything is ok
                break
            default:
                break
            }
        } else {
            let alert = UIAlertView(title: "Location Service Disabled", message: "To enable, please go to Settings and turn on Location Service for this app.", delegate: self, cancelButtonTitle: "Close")
            alert.show()
            return
        }
        
        /* Main */
        if motionManager.deviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 0.2
            motionManager.startDeviceMotionUpdates()
            statusTimer = NSTimer.scheduledTimerWithTimeInterval(
                0.2, target: self, selector: "updateStatus", userInfo: nil, repeats: true)
            alertTimer =  NSTimer.scheduledTimerWithTimeInterval(
                0.1, target: self, selector: "updateAlert", userInfo: nil, repeats: true)
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    /* //MARK: User Functions */
    /***
    * function Update STATUS Label
    * sends infos to alive.php (POST)
    * info: Device ID:Int
    *       Latitude:Double
    *       Longitude:Double
    *       Move:Bool
    */
    func updateStatus() {
        let motion = motionManager.deviceMotion
        if (motion != nil) {
            let rotationRate = motion!.rotationRate
            let gravity = motion!.gravity
            let userAcc = motion!.userAcceleration
            //let attitude = motion!.attitude
            
            gyroX = abs(rotationRate.x)
            gyroY = abs(rotationRate.y)
            gyroZ = abs(rotationRate.z)
            
            acceleoX = userAcc.x
            acceleoY = userAcc.y
            acceleoZ = userAcc.z
            
            gravityX = abs(gravity.x)
            gravityY = abs(gravity.y)
            gravityZ = abs(gravity.z)
            
            if(gyroX < 0.01 && gyroY < 0.01 && gyroZ < 0.01 && gravityZ > 0.998000) {
                /* Phone is "Flat on the table" */
                if(!status) {
                    dispatch_async(dispatch_get_main_queue(), {
                        self.skipFirst = true
                        self.status = true
                        
                        self.writeLog("Flat and monitoring", type: 3)
                        
                        UIView.animateWithDuration(0.2, delay: 0.0, options: UIViewAnimationOptions.CurveEaseOut, animations: {
                            self.statusLabel.alpha = 0.3
                            }, completion: {
                                (finished: Bool) -> Void in
                                
                                /* Green text */
                                self.statusLabel.textColor = UIColor(red: (88/255), green: (189/255), blue: (112/255), alpha: 1.0)
                                self.statusLabel.text = "Active and monitoring"
                                UIView.animateWithDuration(0.3, delay: 0.0, options: UIViewAnimationOptions.CurveEaseIn, animations: {
                                    self.statusLabel.alpha = 1.0
                                    }, completion: nil)
                        })
                        let url: NSURL = NSURL(string:"http://www.sapienzaapps.it/seismocloud/alive.php")!
                        let request:NSMutableURLRequest = NSMutableURLRequest(URL:url)
                        let bodyData = "deviceid=\(self.device.identifierForVendor!.UUIDString)&lat=\(self.latitude)&lon=\(self.longitude)&model=galileo1&version=0.0"
                        request.HTTPMethod = "POST"
                        request.HTTPBody = bodyData.dataUsingEncoding(NSUTF8StringEncoding);
                        NSURLConnection.sendAsynchronousRequest(request, queue: NSOperationQueue.mainQueue()) {
                            (response, data, error) in
                            if (error != nil) {
                                print(error)
                                self.writeLog("Error connecting to server", type: 4)
                            }
                        }
                    })
                }
            }
            else {
                /*
                * Phone is moving:
                *   Conditions: gyroX>=0.01 OR gyroY>=0.01 OR gyro>=0.01 OR gravityZ<=0.998
                *   REAL Condition: gravityZ<=0.998
                */
                if(gravityZ <= 0.998000) {
                    if(status) {
                        dispatch_async(dispatch_get_main_queue(), {
                            self.skipFirst = true
                            self.status = false
                            
                            self.writeLog("Moving, not monitoring", type: 1)
                            
                            UIView.animateWithDuration(0.2, delay: 0.0, options: UIViewAnimationOptions.CurveEaseOut, animations: {
                                self.statusLabel.alpha = 0.3
                                }, completion: {
                                    (finished: Bool) -> Void in
                                    
                                    /* Black text */
                                    self.statusLabel.textColor = UIColor.blackColor()
                                    self.statusLabel.text = "Inactive, not monitoring"
                                    UIView.animateWithDuration(0.3, delay: 0.0, options: UIViewAnimationOptions.CurveEaseIn, animations: {
                                        self.statusLabel.alpha = 1.0
                                        }, completion: nil)
                            })
                            
                            let url: NSURL = NSURL(string:"http://www.sapienzaapps.it/seismocloud/alive.php")!
                            let request:NSMutableURLRequest = NSMutableURLRequest(URL:url)
                            let bodyData = "deviceid=\(self.device.identifierForVendor!.UUIDString)&lat=\(self.latitude)&lon=\(self.longitude)&model=galileo1&version=0.0&move=1"
                            request.HTTPMethod = "POST"
                            request.HTTPBody = bodyData.dataUsingEncoding(NSUTF8StringEncoding);
                            NSURLConnection.sendAsynchronousRequest(request, queue: NSOperationQueue.mainQueue()) {
                                (response, data, error) in
                                if (error != nil) {
                                    print(error)
                                    self.writeLog("Error connecting to server", type: 4)
                                }
                            }
                        })
                    }
                }
            }
        }
    }
    
    /***
     * function Update DETECT Label
     */
    func updateAlert() {
        self.date = NSDate()
        
        let motion = motionManager.deviceMotion
        
        if (motion != nil) {
            let gravity = motion!.gravity
            gravityZ = abs(gravity.z)
            
            
            if(status && (gravityZ > 0.998000)) { //phone is flat
                calculateAvgZ(&iZ,acceleo: acceleoZ,arrayAcceleo: &arrayAcceleoZ,accumulator: &accumulatorZ)
                self.acceleoH = sqrt(acceleoX*acceleoX + acceleoY*acceleoY)
                calculateAvgH(&iH,acceleo: acceleoH,arrayAcceleo: &arrayAcceleoH,accumulator: &accumulatorH)
                
                self.gapZ = abs(self.avgAcceleoZ/self.oldAvgAcceleoZ)
                self.gapH = abs(self.oldAvgAcceleoH - self.avgAcceleoH)
                
                if((self.gapZ > 1.5 || self.gapH > 0.01) && (gravityZ > 0.998000) && status) { // Phone is detecting
                    dispatch_async(dispatch_get_main_queue(), {
                        if (self.skipFirst) {
                            self.skipFirst = false
                            return
                        }
                        self.currentTimestamp = self.date.timeIntervalSince1970
                        if(self.currentTimestamp - self.oldTimestamp > self.timeWait) { // Skip next $timeWait seconds
                            self.oldTimestamp = self.currentTimestamp
                            
                            self.writeLog("Vibration detected", type: 4)
                            
                            self.statusLabel.hidden = true
                            self.alertLabel.hidden = false
                            self.alertLabel.text = "Vibration detected!"
                            
                            let delay = self.timeWait * Double(NSEC_PER_SEC)
                            let time = dispatch_time(DISPATCH_TIME_NOW, Int64(delay))
                            dispatch_after(time, dispatch_get_main_queue(), {
                                
                                UIView.animateWithDuration(0.2, delay: 0.0, options: UIViewAnimationOptions.CurveEaseOut, animations: {
                                    self.alertLabel.alpha = 0.0
                                    }, completion: {
                                        (finished: Bool) -> Void in
                                        
                                        self.alertLabel.hidden = true
                                        self.statusLabel.hidden = false
                                        self.alertLabel.alpha = 1.0
                                        self.statusLabel.alpha = 0.0
                                        UIView.animateWithDuration(0.3, delay: 0.0, options: UIViewAnimationOptions.CurveEaseIn, animations: {
                                            self.statusLabel.alpha = 1.0
                                            }, completion: nil)
                                })
                            })
                            let url : NSURL = NSURL(string:"http://www.sapienzaapps.it/seismocloud/terremoto.php")!
                            let request : NSMutableURLRequest = NSMutableURLRequest(URL : url)
                            let bodyData = "deviceid=\(self.device.identifierForVendor!.UUIDString)&tsstart=\(self.currentTimestamp)&lat=\(self.latitude)&lon=\(self.longitude)"
                            request.HTTPMethod = "POST"
                            request.HTTPBody = bodyData.dataUsingEncoding(NSUTF8StringEncoding);
                            NSURLConnection.sendAsynchronousRequest(request, queue: NSOperationQueue.mainQueue()) {
                                (response, data, error) in
                                if (error != nil) {
                                    self.writeLog("Error connecting to server", type: 4)
                                }
                                else {
                                    // Take server response
                                    if(data != nil) {
                                        let respString : String = String(data: data!, encoding: NSUTF8StringEncoding)!
                                        let respDouble : Double? = Double(respString)
                                        if((respDouble) != nil) {
                                            //print("respDouble = \(respDouble!)")
                                            if (respDouble != self.timeWait) {
                                                self.timeWait = respDouble!
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    })
                }
                else { //phone is not detecting
                    dispatch_async(dispatch_get_main_queue(), {
                        //nothing
                    })
                }
            }
        }
    }
    
    func calculateAvgZ(inout i: Int, acceleo:Double,inout arrayAcceleo:[Double],inout accumulator: Double) {
        if(i < nAvgZ) {
            arrayAcceleo[i]=abs(acceleo)
            accumulator += arrayAcceleo[i]
            i++
        }
        else {
            self.oldAvgAcceleoZ = self.avgAcceleoZ
            accumulator -= arrayAcceleo[i%nAvgZ]
            arrayAcceleo[i%nAvgZ]=abs(acceleo)
            accumulator += arrayAcceleo[i%nAvgZ]
            self.avgAcceleoZ = accumulator/Double(nAvgZ)
            i++
            if(i>20) { i -= 10 } //Controllo incremento i per evitare Buffer Overflow
        }
    }
    
    func calculateAvgH(inout i: Int,acceleo:Double,inout arrayAcceleo:[Double],inout accumulator: Double) {
        if(i < nAvgH) {
            arrayAcceleo[i]=acceleo
            accumulator += arrayAcceleo[i]
            i++
        }
        else {
            oldAvgAcceleoH = avgAcceleoH
            accumulator -= arrayAcceleo[i%nAvgH]
            arrayAcceleo[i%nAvgH]=acceleo
            accumulator += arrayAcceleo[i%nAvgH]
            avgAcceleoH = accumulator/Double(nAvgH)
            i++
            if(i>20) { i-=10 } //Controllo incremento i per evitare Buffer Overflow
        }
    }
    
    /***
     * Location Manager Delegate Methods
     */
    func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let location = locations.last
        self.latitude = location!.coordinate.latitude
        self.longitude = location!.coordinate.longitude
        
        //print("latitude: \(self.latitude) - longitude: \(self.longitude)")
        //self.locationManager.stopUpdatingLocation()
    }
    
    func locationManager(manager: CLLocationManager, didFailWithError error: NSError) {
        print("Error: " + error.localizedDescription)
    }
    
    func exitApp() {
        exit(0)
    }
    
    func alertView(alertView: UIAlertView, clickedButtonAtIndex buttonIndex: Int) {
        exitApp()
    }
    
    /* function Write Log
    * type: 1 -> normal (black text)
    *       2 -> control (blue text)
    *       3 -> success (green text)
    *       4 -> alert (red text)
    */
    func writeLog(text : String, type : Int) {
        let currentTimeInterval = NSDate.timeIntervalSinceReferenceDate()
        let currentTimeString = stringFromTimeInterval(currentTimeInterval)
        print(currentTimeString+" "+text)
        
        let attrTime = NSAttributedString(string: currentTimeString, attributes: [
            NSFontAttributeName: UIFont(name: "Courier", size: 14)!,
            NSForegroundColorAttributeName: UIColor.grayColor()
            ])
        
        var attrText = NSAttributedString()
        switch(type) {
        case 1:
            attrText = NSAttributedString(string: text, attributes: [
                NSFontAttributeName: UIFont(name: "Helvetica", size: 15)!,
                NSForegroundColorAttributeName: UIColor.blackColor()
                ])
            break
        case 2:
            attrText = NSAttributedString(string: text, attributes: [
                NSFontAttributeName: UIFont(name: "Helvetica", size: 15)!,
                NSForegroundColorAttributeName: UIColor.blueColor()
                ])
            break
        case 3:
            attrText = NSAttributedString(string: text, attributes: [
                NSFontAttributeName: UIFont(name: "Helvetica", size: 15)!,
                NSForegroundColorAttributeName: UIColor(red: 88/255, green: 189/255, blue: 112/255, alpha: 1.0)
                ])
            break
        case 4:
            attrText = NSAttributedString(string: text, attributes: [
                NSFontAttributeName: UIFont(name: "Helvetica", size: 15)!,
                NSForegroundColorAttributeName: UIColor.redColor()
                ])
            break
        default:
            break
        }
        
        SharedLog.sharedInstance().insertTop(LogEntry(time: attrTime, text: attrText))
        //self.arrayLog.insert(appendAttributedString(attrTime, text: attrText), atIndex: 0)
        //self.arrayLog.insert(LogEntry(time: attrTime, text: attrText), atIndex: 0)
    }
    
    func stringFromTimeInterval(interval:NSTimeInterval) -> String {
        let ti = NSInteger(interval)
        let seconds = ti % 60
        let minutes = (ti / 60) % 60
        let hours = (ti / 3600) % 24 + 1 // UTG+1
        return String(format: "[%0.2d:%0.2d:%0.2d]",hours,minutes,seconds)
    }
    
    func appendAttributedString (time: NSAttributedString, text: NSAttributedString) -> NSAttributedString {
        let result = NSMutableAttributedString()
        result.appendAttributedString(time)
        result.appendAttributedString(NSAttributedString(string: " "))
        result.appendAttributedString(text)
        return result
    }
    
}
