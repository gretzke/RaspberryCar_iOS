//
//  ViewController.swift
//  RaspberryCar
//
//  Created by Daniel Gretzke on 29.11.16.
//  Copyright © 2016 Daniel Gretzke. All rights reserved.
//

import UIKit
import CoreMotion
import MjpegStreamingKit


class ViewController: UIViewController {
    
    @IBOutlet weak var SwitchLabel: UILabel!
    
    @IBOutlet weak var Switch: UISwitch!
    
// Geschwindigkeitskontrolle
    
    @IBOutlet weak var Label: UILabel!

    @IBOutlet weak var VertSlider: UISlider!
    
    @IBAction func SliderAction(_ sender: UISlider) {
        if round(VertSlider.value * 100) <= 10 && round(VertSlider.value * 100) >= -10{
            self.Label.text = "Stop"
        } else {
        self.Label.text = "\(round(VertSlider.value * 100))%"
        }
    }
// TCPSocketStream
    
    let addr = "127.0.0.1"
    let port = 5000
    var out: OutputStream?
    
    var Leftspeed: Double!
    var Rightspeed: Double!
    
    var xwert: Double?
    var ywert: Double?
    var zwert: Double?

// Gyrosensor
    
    let manager = CMMotionManager()

// MJPEG Stream
    
    @IBOutlet weak var VideoStream: UIImageView!
    
    
    var url: URL?
    var streamingController: MjpegStreamingController!
    
    var screenWidth = UIScreen.main.bounds.width
    var screenHeight = UIScreen.main.bounds.height
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor.black
        self.Label.text = ""
        self.VertSlider.transform = CGAffineTransform(rotationAngle: CGFloat(-M_PI_2))

        Switch.addTarget(self, action: #selector(ViewController.switchIsChanged), for: UIControlEvents.valueChanged)
        
// MJPEG Stream
        
        VideoStream.frame = CGRect(x: 0, y: 0, width: screenWidth, height: screenHeight)
        streamingController = MjpegStreamingController(imageView: VideoStream)
        url = URL(string: "http://80.32.204.149:8080/mjpg/video.mjpg")
        streamingController.contentURL = url
        streamingController.play()

// Gyrosensor

        if manager.isDeviceMotionAvailable {
            print("accelerometer available")
            manager.deviceMotionUpdateInterval = 0.05
            manager.startDeviceMotionUpdates(to: OperationQueue.main){
                [weak self] (data: CMDeviceMotion?, error: Error?) in
                if let gravity = data?.gravity {
                    self!.ywert = gravity.y
                    print(gravity.y)
                    if (self!.ywert!)>0.0 {
                        self!.Leftspeed = 1
                        self!.Rightspeed = ((self!.ywert!) - 1) * -1
                        if self!.Rightspeed<0.2{
                            self!.Rightspeed = -1
                        }
                    }
                    if (self!.ywert!)<0.0 {
                        self!.Rightspeed = 1
                        self!.Leftspeed = ((self!.ywert!) + 1)
                        if self!.Leftspeed<0.2{
                            self!.Leftspeed = -1
                        }
                    }
                    
                    if (self!.ywert!)==0.0 {
                        self!.Leftspeed = 1
                        self!.Rightspeed = 1
                    }
                    
                    var l = Double(round(100*self!.Leftspeed!)/100) * Double((self?.VertSlider.value)!)
                    var r = Double(round(100*self!.Rightspeed!)/100) * Double((self?.VertSlider.value)!)
                    
                    l = round(100*l)/100
                    r = round(100*r)/100+10
                    
                    if round((self?.VertSlider.value)! * 100) <= 20 && round((self?.VertSlider.value)! * 100) >= -20{
                        l = 0
                        r = 0
                    }
                    
                    print("L=\(l) R=\(r-10)")
                    
                    self!.write(s: "\(l)")
                    self!.write(s: "\(r)")
                    
                    let rotation = atan2(gravity.x, gravity.y) - M_PI - 1.5
                    self?.VideoStream.transform = CGAffineTransform(rotationAngle: CGFloat(rotation))
                    
                }
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

// Write funktion für TCPSocket
    
    func write(s: String){
        Stream.getStreamsToHost(withName: addr, port: port, inputStream: nil, outputStream: &out)
        let outputStream = out!
        outputStream.open()
        let data: NSData = s.data(using: String.Encoding.utf8)! as NSData
        let datasent = data.bytes.assumingMemoryBound(to: UInt8.self)
        outputStream.write(UnsafePointer<UInt8>(datasent), maxLength: 15)
    }

    //Stop-Button
    
    @IBAction func StopButton(_ sender: Any) {
        write(s: "0")
        write(s: "10")
    }
    
    //Autonom Switch
    
    func switchIsChanged(Switch: UISwitch) {
        if Switch.isOn {
            SwitchLabel.text = "autonom an"
            let s = "aut_on"
            write(s: s)
        } else {
            SwitchLabel.text = "autonom aus"
            let s = "aut_off"
            write(s: s)
        }
    }
    
    
}
