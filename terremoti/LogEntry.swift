//
//  LogEntry.swift
//  terremoti
//
//  Created by Aldo D'Eramo on 27/12/15.
//  Copyright © 2015 SapienzaApps. All rights reserved.
//

import Foundation

class LogEntry {
    var time: NSAttributedString = NSAttributedString()
    var text: NSAttributedString = NSAttributedString()
    
    init(time: NSAttributedString, text: NSAttributedString) {
        self.time = time
        self.text = text
    }
}