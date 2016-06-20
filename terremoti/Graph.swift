//
//  ViewController.swift
//  SeismographSwift
//
//  Created by Nikolay Diyanov on 12/19/14.
//  Copyright (c) 2014 Telerik. All rights reserved.
//

import UIKit
import Foundation
import CoreGraphics
import CoreMotion


private let coefficient: Double = 10
private var play: Bool = true

class Graph: UIViewController {
    
    /* Connection with GraphView objects */
    @IBOutlet var chart: TKChart!
    @IBOutlet weak var playpauseButton: UIButton!
    @IBOutlet weak var resetButton: UIButton!
    @IBOutlet weak var backgroundLegend: UIView!
    @IBOutlet weak var backgroundControl: UIView!
    @IBOutlet weak var statusLabel: UILabel!
    
    /* Collections of graph points */
    private var dataPointsX = [TKChartDataPoint]()
    private var dataPointsY = [TKChartDataPoint]()
    private var dataPointsZ = [TKChartDataPoint]()
    
    private var run: Bool = false
    private let motionManager: CMMotionManager = CMMotionManager()
    private var updateTimer: NSTimer!
    private var xCounter: Int = 0
    
    private var firstLog: LogEntry = SharedLog.sharedInstance().readLog()[0]
    private var updateStatusTimer: NSTimer = NSTimer()
    
    private var status: Bool = false
    private var detection: Bool = false
    
    private var lastTime = SharedLog.sharedInstance().readLog()[0].time
    
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
    private var newMediaAcceleo: Double = 0.0
    private var oldMediaAcceleo: Double = 0.0
    private var gapZ: Double = 0.0
    private var gapH: Double = 0.0
    
    /* Server response management data */
    private var date = NSDate()
    private var oldTimestamp: NSTimeInterval = 0.0
    private var currentTimestamp: NSTimeInterval = 0.0
    
    
    /* //MARK: Overrided Functions */
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.backgroundLegend.layer.borderColor = UIColor.grayColor().CGColor
        self.backgroundLegend.layer.borderWidth = 0.5
        self.backgroundControl.layer.borderColor = UIColor.grayColor().CGColor
        self.backgroundControl.layer.borderWidth = 0.5
        
        self.startOperations()
    }
    
    override func viewWillDisappear(animated: Bool) {
        dataPointsX.removeAll(keepCapacity: true)
        dataPointsY.removeAll(keepCapacity: true)
        dataPointsZ.removeAll(keepCapacity: true)
        chart.removeAllData()
        stopOperations()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    /* //MARK: User Functions */
    func startOperations() {
        if(!self.run) {
            self.run = true
            
            if motionManager.deviceMotionAvailable {
                motionManager.deviceMotionUpdateInterval = 0.2
                motionManager.startDeviceMotionUpdates()
                updateTimer = NSTimer.scheduledTimerWithTimeInterval(
                    0.2, target: self, selector: "buildChartWithPoint", userInfo: nil, repeats: true)
                updateStatusTimer = NSTimer.scheduledTimerWithTimeInterval(
                    0.2, target: self, selector: "updateStatus", userInfo: nil, repeats: true)
            }
        }
    }
    
    func stopOperations() {
        self.run = false
        updateTimer.invalidate()
        motionManager.stopDeviceMotionUpdates()
        NSOperationQueue.currentQueue()!.cancelAllOperations()
    }
    
    /***
     * X: Red
     * Y: Green
     * Z: Blue
     */
    func buildChartWithPoint() {
        
        self.chart.removeAllData()
        self.chart.removeAllAnnotations()
        
        let pointX : Double = (motionManager.deviceMotion?.userAcceleration.x)! * (coefficient * 3)
        let pointY : Double = (motionManager.deviceMotion?.userAcceleration.y)! * (coefficient * 3)
        let pointZ : Double = (motionManager.deviceMotion?.userAcceleration.z)! * (coefficient * 3)
        
        //print("X: \(pointX)\nY: \(pointY)\nZ: \(pointZ)\ncounter: \(self.xCounter)")
        
        /* y Axis */
        let yAxis = TKChartNumericAxis(minimum: -coefficient, andMaximum: coefficient)
        yAxis.position = TKChartAxisPosition.Left
        yAxis.majorTickInterval = 2
        yAxis.style.lineHidden = false
        yAxis.style.labelStyle.firstLabelTextAlignment = TKChartAxisLabelAlignment.Left
        yAxis.style.labelStyle.textAlignment = TKChartAxisLabelAlignment.Left
        yAxis.style.labelStyle.textOffset.horizontal = 5
        yAxis.style.labelStyle.firstLabelTextOffset.horizontal = 0
        self.chart.yAxis = yAxis
        
        /* Line Series */
        let seriesX = TKChartLineSeries(items: self.dataPointsX)
        seriesX.style.palette = TKChartPalette()
        let strokeRed = TKStroke(color: UIColor.redColor(), width: 1.5)
        seriesX.style.palette!.addPaletteItem(TKChartPaletteItem(stroke: strokeRed))
        chart.addSeries(seriesX)
        let seriesY = TKChartLineSeries(items: self.dataPointsY)
        seriesY.style.palette = TKChartPalette()
        let strokeGreen = TKStroke(color: UIColor(red: 0.0, green: (150/255), blue: 0.0, alpha: 1.0), width: 1.5)
        seriesY.style.palette!.addPaletteItem(TKChartPaletteItem(stroke: strokeGreen))
        chart.addSeries(seriesY)
        let seriesZ = TKChartLineSeries(items: self.dataPointsZ)
        seriesZ.style.palette = TKChartPalette()
        let strokeBlue = TKStroke(color: UIColor.blueColor(), width: 1.5)
        seriesZ.style.palette!.addPaletteItem(TKChartPaletteItem(stroke: strokeBlue))
        chart.addSeries(seriesZ)
        
        /* x Axis */
        let axisColor = TKStroke(color: UIColor.blackColor(), width: 1)
        chart.xAxis!.style.lineStroke = axisColor
        chart.xAxis!.style.majorTickStyle.ticksHidden = true
        chart.xAxis!.style.labelStyle.textHidden = true
        chart.xAxis!.style.lineHidden = true
        
        /* range (blue, lighblue) */
        let annotationBandLightBlue = TKChartBandAnnotation(range: TKRange(minimum: -5, andMaximum: 5), forAxis: chart.yAxis!)
        annotationBandLightBlue.style.fill = TKSolidFill(color: UIColor(red: 175/255, green: 191/255, blue: 227/255, alpha: 0.3))
        chart.addAnnotation(annotationBandLightBlue)
        
        let annotationBandBlue = TKChartBandAnnotation(range: TKRange(minimum: -3, andMaximum: 3), forAxis: chart.yAxis!)
        annotationBandBlue.style.fill = TKSolidFill(color: UIColor(red: 175/255, green: 191/255, blue: 227/255, alpha: 0.7))
        chart.addAnnotation(annotationBandBlue)
        
        /* linee tratteggiate */
        let dashStroke = TKStroke(color: UIColor(red: 0, green: 0, blue: 0, alpha: 0.5), width: 0.5)
        dashStroke.dashPattern = [6, 1]
        /* linea tratteggiata > 0 */
        let positiveDashAnnotation = TKChartGridLineAnnotation(value: 1.5, forAxis: chart.yAxis!)
        positiveDashAnnotation.style.stroke = dashStroke
        chart.addAnnotation(positiveDashAnnotation)
        /* linea tratteggiata < 0 */
        let negativeDashAnnotation = TKChartGridLineAnnotation(value: -1.5, forAxis: chart.yAxis!)
        negativeDashAnnotation.style.stroke = dashStroke
        chart.addAnnotation(negativeDashAnnotation)
        
        let lastPointX = TKChartDataPoint(x: self.xCounter, y: pointX)
        self.dataPointsX.append(lastPointX)
        let lastPointY = TKChartDataPoint(x: self.xCounter, y: pointY)
        self.dataPointsY.append(lastPointY)
        let lastPointZ = TKChartDataPoint(x: self.xCounter, y: pointZ)
        self.dataPointsZ.append(lastPointZ)
        
        if self.dataPointsX.count > 25 {
            self.dataPointsX.removeAtIndex(0)
        }
        if self.dataPointsY.count > 25 {
            self.dataPointsY.removeAtIndex(0)
        }
        if self.dataPointsZ.count > 25 {
            self.dataPointsZ.removeAtIndex(0)
        }
        
        /* posizione cursore */
        if self.dataPointsX.count > 1 {
            let curX = NeedleAnnotation(point: lastPointX, forSeries: seriesX)
            curX.zPosition = TKChartAnnotationZPosition.AboveSeries
            chart.addAnnotation(curX)
        }
        if self.dataPointsY.count > 1 {
            let curY = NeedleAnnotation(point: lastPointY, forSeries: seriesY)
            curY.zPosition = TKChartAnnotationZPosition.AboveSeries
            chart.addAnnotation(curY)
        }
        if self.dataPointsZ.count > 1 {
            let curZ = NeedleAnnotation(point: lastPointZ, forSeries: seriesZ)
            curZ.zPosition = TKChartAnnotationZPosition.AboveSeries
            chart.addAnnotation(curZ)
        }
        
        self.xCounter = ++self.xCounter % 100
    }
    
    func updateStatus()
    {
        if(!self.detection)
        {
            let rotationRate = motionManager.deviceMotion?.rotationRate
            let gravity = motionManager.deviceMotion?.gravity
            
            let gyroX = abs(rotationRate!.x)
            let gyroY = abs(rotationRate!.y)
            let gyroZ = abs(rotationRate!.z)
            
            let gravityZ = abs(gravity!.z)
            
            if(gyroX < 0.01 && gyroY < 0.01 && gyroZ < 0.01 && gravityZ > 0.998000)
            {
                /* Phone is "Flat on the table" */
                /*if(!status)
                {*/
                    self.status = true
                    
                    self.statusLabel.text = "Active and monitoring"
                    
                    print(SharedLog.sharedInstance().readLog()[0].text.string)
                    
                    if(SharedLog.sharedInstance().readLog()[0].text.string == "Vibration detected")
                    {
                        print("1")
                        
                        let realTime = SharedLog.sharedInstance().readLog()[0].time
                        
                        if(realTime.string != lastTime.string)
                        {
                            lastTime = realTime
                            
                            // Phone is detecting
                            
                            self.statusLabel.text = "Vibraction detected!"
                            
                            self.detection = true
                            
                            self.currentTimestamp = self.date.timeIntervalSince1970
                            if(self.currentTimestamp - self.oldTimestamp > 5)
                            {
                                self.oldTimestamp = self.currentTimestamp
                                let delay = 5 * Double(NSEC_PER_SEC)
                                let time = dispatch_time(DISPATCH_TIME_NOW, Int64(delay))
                                dispatch_after(time, dispatch_get_main_queue(), {
                                    if(self.status){
                                        self.statusLabel.text = "Active and monitoring"
                                    }
                                    else
                                    {
                                        self.statusLabel.text = "Inactive, not monitoring"
                                    }
                                    self.detection = false
                                })
                            }
                        }
                    }
                //}
            }
            else
            {
                /*
                * Phone is moving:
                *   Conditions: gyroX>=0.01 OR gyroY>=0.01 OR gyro>=0.01 OR gravityZ<=0.998
                *   REAL Condition: gravityZ<=0.998
                */
                if(gravityZ <= 0.998000)
                {
                    /*if(self.status)
                    {
                        */self.status = false
                        self.statusLabel.text = "Inactive, not monitoring"
                    //}
                }
                
            }
        }
    }
    
    /* //MARK: Buttons Actions */
    @IBAction func reset(sender: AnyObject) {
        // mette il bottone a pause e fa Reset
        self.playpauseButton.setImage(UIImage(named: "pause"), forState: .Normal)
        self.dataPointsX.removeAll(keepCapacity: true)
        self.dataPointsY.removeAll(keepCapacity: true)
        self.dataPointsZ.removeAll(keepCapacity: true)
        self.chart.removeAllData()
        self.startOperations()
        play = true
    }
    
    @IBAction func playpause(sender: AnyObject) {
        if (play == true) {
            //il bottone è in pause, lo mette a play e fa Stop
            self.playpauseButton.setImage(UIImage(named: "play"), forState: .Normal)
            self.stopOperations()
            play = false
        } else {
            //il bottone è in play, lo mette a pause e fa Start
            self.playpauseButton.setImage(UIImage(named: "pause"), forState: .Normal)
            self.startOperations()
            play = true
        }
    }
    
    
}

