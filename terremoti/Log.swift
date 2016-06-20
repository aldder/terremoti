//
//  Log.swift
//  terremoti
//
//  Created by Aldo D'Eramo on 20/12/15.
//  Copyright © 2015 SapienzaApps. All rights reserved.
//

import Foundation

class Log: UITableViewController {
    
    /* Initialize last log activity */
    var firstLog: LogEntry = SharedLog.sharedInstance().readLog()[0]
    
    var updateTimer: NSTimer = NSTimer()
    
    override func viewDidLoad() {
        updateTimer = NSTimer.scheduledTimerWithTimeInterval(
            1.0, target: self, selector: "updateData", userInfo: nil, repeats: true)
    }
    
    /* //MARK: - Overrided Functions */
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return SharedLog.sharedInstance().readLog().count
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("LogCell", forIndexPath: indexPath)
        cell.textLabel?.attributedText = SharedLog.sharedInstance().readLog()[indexPath.row].text
        cell.detailTextLabel?.attributedText = SharedLog.sharedInstance().readLog()[indexPath.row].time
        return cell
    }
    
    override func viewWillDisappear(animated: Bool) {
        updateTimer.invalidate()
    }
    
    /* //MARK: User Functions
    * check if last log activity is changed, if so update the tableView with animation
    */
    func updateData() {
        let lastText = SharedLog.sharedInstance().readLog()[0].text
        let lastTime = SharedLog.sharedInstance().readLog()[0].time
        if (!firstLog.text.isEqual(lastText) || !firstLog.time.isEqual(lastTime)) {
            firstLog = SharedLog.sharedInstance().readLog()[0]
            self.tableView.reloadSections(NSIndexSet(index: 0), withRowAnimation: UITableViewRowAnimation.Fade)
        }
    }
    
}
