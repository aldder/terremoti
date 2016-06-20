//
//  SharedLogswift.swift
//  terremoti
//
//  Created by Aldo D'Eramo on 27/12/15.
//  Copyright © 2015 SapienzaApps. All rights reserved.
//

import Foundation

class SharedLog {
    static var instance: SharedLog!
    
    var arrayLog = [LogEntry]()
    
    /* Shared Instance */
    class func sharedInstance() -> SharedLog {
        self.instance = (self.instance ?? SharedLog())
        return self.instance
    }
    
    /* //MARK: User Functions */
    func readLog() -> [LogEntry] {
        return self.arrayLog
    }
    
    func insertTop(entry: LogEntry) {
        self.arrayLog.insert(entry, atIndex: 0)
    }
}
