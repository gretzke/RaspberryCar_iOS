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
import Foundation

var l = 0.0
var r = 0.0
var outputStream: OutputStream?
var inputStream: InputStream?
var outputStreamAut: OutputStream?
var inputStreamAut: InputStream?

class ViewController: UIViewController, StreamDelegate {
    
    @IBOutlet weak var SwitchLabel: UILabel!
    
    @IBOutlet weak var connectButton: UIButton!
    
    @IBOutlet weak var Switch: UISwitch!
    
    // Geschwindigkeitskontrolle
    
    @IBOutlet weak var Label: UILabel!
    
    @IBOutlet weak var VertSlider: UISlider!
    
    @IBAction func SliderAction(_ sender: UISlider) {
        if round(VertSlider.value * 100) <= 10 && round(VertSlider.value * 100) >= -10{
            self.Label.text = "Stop"
        } else {
            self.Label.text = "\(round(VertSlider.value * 10)*10)%"
        }
    }
    // TCPSocketStream
    
    let addr = "172.24.1.1"
    let port = 4000
    let portAut = 4001
    
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
        self.Label.text = ""
        self.VertSlider.transform = CGAffineTransform(rotationAngle: CGFloat(-M_PI_2))
        Switch.backgroundColor = UIColor.blue
        Switch.layer.cornerRadius = 16.0
        Switch.addTarget(self, action: #selector(ViewController.switchIsChanged), for: UIControlEvents.valueChanged)
    }
    
    @IBAction func connect(_ sender: Any) {
        if inputStream != nil && outputStream != nil {
            inputStream!.close()
            outputStream!.close()
            inputStream!.remove(from: .main, forMode: RunLoopMode.defaultRunLoopMode)
            outputStream!.remove(from: .main, forMode: RunLoopMode.defaultRunLoopMode)
            inputStream!.delegate = nil
            outputStream!.delegate = nil
            inputStream = nil
            outputStream = nil
            self.connectButton.setTitle("Connect", for: .normal)
        } else {
            // Setup TCP SocketStream
            connect(host: addr, port: port)
            
            // MJPEG Stream
            
            VideoStream.frame = CGRect(x: 0, y: 0, width: screenWidth, height: screenHeight)
            streamingController = MjpegStreamingController(imageView: VideoStream)
            url = URL(string: "http://172.24.1.1:8080/?action=stream")
            streamingController.contentURL = url
            streamingController.play()
            
            // Gyrosensor
            
            if manager.isDeviceMotionAvailable {
                manager.deviceMotionUpdateInterval = 0.2
                manager.startDeviceMotionUpdates(to: OperationQueue.main){
                    [weak self] (data: CMDeviceMotion?, error: Error?) in
                    if let gravity = data?.gravity {
                        self?.ywert = gravity.y
                        if (self?.ywert)!<0.0 {
                            self?.Leftspeed = 1
                            self?.Rightspeed = ((self?.ywert)! + 1)
                            if self!.Rightspeed<=0.2{
                                self?.Rightspeed = -1
                            }
                        }
                        if (self?.ywert)!>0.0 {
                            self?.Rightspeed = 1
                            self?.Leftspeed = ((self?.ywert)! - 1) * -1
                            if self!.Leftspeed<=0.2{
                                self?.Leftspeed = -1
                            }
                        }
                        
                        if (self?.ywert)==0.0 {
                            self?.Leftspeed = 1
                            self?.Rightspeed = 1
                        }
                        
                        l = Double(round(100*(self?.Leftspeed!)!)/100) * Double((self?.VertSlider.value)!)
                        r = Double(round(100*(self?.Rightspeed!)!)/100) * Double((self?.VertSlider.value)!)
                        
                        l = round(10*l)/10
                        r = round(10*r)/10+10
                        
                        if round((self?.VertSlider.value)! * 100) <= 20 && round((self?.VertSlider.value)! * 100) >= -20{
                            l = 0
                            r = 10
                        }
                    }
                }
            }
            self.connectButton.setTitle("Disconnect", for: .normal)
        }
    }
    
    
    func connect (host: String, port: Int) {
        Stream.getStreamsToHost(withName: addr, port: port, inputStream: &inputStream, outputStream: &outputStream)
        if outputStream != nil {
            outputStream!.delegate = self
            inputStream!.delegate = self
            outputStream!.schedule(in: .main, forMode: RunLoopMode.defaultRunLoopMode)
            inputStream!.schedule(in: .main, forMode: RunLoopMode.defaultRunLoopMode)
            outputStream!.open()
            inputStream!.open()
        }
    }
    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        if aStream === inputStream {
            switch eventCode {
            case Stream.Event.errorOccurred:
                print("input: ErrorOccurred: \(aStream.streamError?.localizedDescription)")
                self.Label.text = "Disconnected"
            case Stream.Event.openCompleted:
                print("input: OpenCompleted")
            case Stream.Event.hasBytesAvailable:
                print("input: HasBytesAvailable")
                
                // Here you can `read()` from `inputStream`
                
            default:
                break
            }
        }
        else if aStream === outputStream {
            switch eventCode {
            case Stream.Event.errorOccurred:
                print("output: ErrorOccurred: \(aStream.streamError?.localizedDescription)")
                self.Label.text = "Disconnected"
            case Stream.Event.openCompleted:
                print("output: OpenCompleted")
            case Stream.Event.hasSpaceAvailable:
                //                print("output: HasSpaceAvailable")
                // Here you can write() to `outputStream`
                print("L=\(l) R=\(r)")
                self.write(s: "\(l)")
                self.write(s: "\(r)")
                usleep(10000)
            default:
                break
            }
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        self.VertSlider.value = 0
        self.Label.text = "Stop"
        
        // Dispose of any resources that can be recreated.
    }
    
    // Write funktion für TCPSocket
    
    func write(s: String){
        var str = s
        if str.characters.count < 4 {
            str = "\(str)0"
        }
        let data: NSData = str.data(using: String.Encoding.utf8)! as NSData
        let datasent = data.bytes.assumingMemoryBound(to: UInt8.self)
        outputStream!.write(UnsafePointer<UInt8>(datasent), maxLength: str.characters.count)
    }
    
    //Stop-Button
    
    @IBAction func StopButton(_ sender: Any) {
        self.VertSlider.value = 0
        self.Label.text = "Stop"
    }
    
    //Autonom Switch
    
    func switchIsChanged(Switch: UISwitch) {
        //        if Switch.isOn {
        //            SwitchLabel.text = "Manuell"
        //            let s = "aut_off"
        //            write(f: s)
        //        } else {
        //            SwitchLabel.text = "Autonom"
        //            let s = "aut_on"
        //            write(f: s)
        //        }
    }
    override func viewDidAppear(_ animated: Bool) {
        if inputStream != nil && outputStream != nil {
            self.connectButton.setTitle("Connect", for: .normal)
        } else {
            self.connectButton.setTitle("Disconnect", for: .normal)
        }
    }
}
