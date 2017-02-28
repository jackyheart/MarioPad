//
//  ViewController.swift
//  MarioPad
//
//  Created by Jacky on 27/2/17.
//  Copyright © 2017 Jacky. All rights reserved.
//

import UIKit
import MultipeerConnectivity

class ViewController: UIViewController, MCAdvertiserAssistantDelegate, MCSessionDelegate {
    
    @IBOutlet weak var worldScrollView: UIScrollView!
    @IBOutlet weak var advertisingBtn: UIButton!
    @IBOutlet weak var connectionLbl: UILabel!
    @IBOutlet weak var marioImgView: UIImageView!
    
    var walkAnimationArray:[UIImage] = []
    let numWalkFrames = 2
    
    let MAX_JUMP_HEIGHT:CGFloat = 100
    var marioJumpImage:UIImage? = nil
    var isMarioJumping = false
    
    let MAX_WORLD_X:CGFloat = 1300
    let MOVE_RATE:CGFloat = 10.0
    let FPS = 30.0
    var touchMovementDelta:CGFloat = 0.0
    
    //Multipeer Connectivity
    let kServiceType = "multi-peer-chat"
    var myPeerID:MCPeerID! = nil
    var session:MCSession! = nil
    var advertiser:MCAdvertiserAssistant! = nil
    var isAdvertising:Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    
        let spriteSheetImage = UIImage(named: "sprite")
        let spriteSize = CGSize(width: 57.0, height: 93.0)
        
        //=== WALK
        //get walk frames (it's on frame idx 0 to 1)
        for i in 0 ..< numWalkFrames {
            
            let cropRect = CGRect(x: CGFloat(i) * spriteSize.width, y: 0, width: spriteSize.width, height: spriteSize.height)
            
            if let imageRef = spriteSheetImage?.cgImage?.cropping(to: cropRect),
                let spriteSheetImage = spriteSheetImage {

                let frameImage = UIImage(cgImage: imageRef, scale: 1.0, orientation: spriteSheetImage.imageOrientation)
                self.walkAnimationArray.append(frameImage)
            }
        }
        
        //set animation images
        self.marioImgView.animationImages = self.walkAnimationArray
        self.marioImgView.animationDuration = 0.25
        
        //set default mario image
        self.marioImgView.image = self.walkAnimationArray[0]
        
        //=== JUMP
        //get jump frame (it's on frame idx 3, idx 2 is unused)
        let jumpCropRect = CGRect(x: 3.0 * (spriteSize.width + 5.0), y: 0, width: spriteSize.width, height: spriteSize.height)
        if let jumpImageRef = spriteSheetImage?.cgImage?.cropping(to: jumpCropRect),
            let spriteSheetImage = spriteSheetImage {
            
            self.marioJumpImage = UIImage(cgImage: jumpImageRef, scale: 1.0, orientation: spriteSheetImage.imageOrientation)
        }
        
        //=== Start game timer
        Timer.scheduledTimer(timeInterval: 1.0/self.FPS, target: self, selector: #selector(gameTimer(timer:)), userInfo: nil, repeats: true)
        
        
        //=== Multipeer Connectivity
        
        //session
        self.myPeerID = MCPeerID(displayName: UIDevice.current.name)
        self.session = MCSession(peer: self.myPeerID, securityIdentity: nil, encryptionPreference: .required)
        self.session.delegate = self
        self.advertiser = MCAdvertiserAssistant(serviceType: kServiceType, discoveryInfo: nil, session: self.session)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override var supportedInterfaceOrientations : UIInterfaceOrientationMask {
        return UIInterfaceOrientationMask.landscape
    }
    
    override var shouldAutorotate : Bool {
        return false
    }
    
    //MARK: - Timer
    
    func gameTimer(timer:Timer) {
        
        self.updateMarioFrame(withMovementDelta: self.touchMovementDelta)
    }
    
    //MARK: - Gameplay
    
    func updateMarioFrame(withMovementDelta movementDelta:CGFloat) {
        
        let marioX = self.marioImgView.frame.origin.x
        
        if movementDelta > 0 {
            
            //moving right
            self.marioImgView.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
            
            //update world
            if marioX > 100 {
                
                //start scrolling the world if mario has moved 100 px from the left
                if self.worldScrollView.contentOffset.x < 330 {
                    
                    //this value is to limit the scrolling of the scroll view
                    self.worldScrollView.contentOffset = CGPoint(x: self.worldScrollView.contentOffset.x + 3.0, y: 0.0)
                }
            }
        }
        else if movementDelta < 0 {
            
            //movement left
            
            //flip image
            self.marioImgView.transform = CGAffineTransform(scaleX: -1.0, y: 1.0)
            
            //update world
            if marioX < 1000 {
                
                //if mario is on the right side, and he is currently moving left,
                //only scroll the world if he has moved to the area less than 1000 px (from the left)
                if self.worldScrollView.contentOffset.x > 0 {
                    self.worldScrollView.contentOffset = CGPoint(x: self.worldScrollView.contentOffset.x - 3.0, y: 0.0)
                }
            }
        }
        
        var newMarioRect = CGRect.zero
        var marioRect = self.marioImgView.frame
        
        if self.marioImgView.frame.origin.x < 0 {
            marioRect.origin.x = 0
            newMarioRect = marioRect
        }
        else if self.marioImgView.frame.origin.x > MAX_WORLD_X {
            marioRect.origin.x = MAX_WORLD_X
            newMarioRect = marioRect
        }
        else {
            newMarioRect = self.marioImgView.frame.offsetBy(dx: movementDelta * MOVE_RATE, dy: 0.0)
        }
        
        print("origin x: \(newMarioRect.origin.x)\n")
        
        self.marioImgView.frame = newMarioRect
    }
    
    func jump() {
        
        if !self.isMarioJumping {
            
            self.isMarioJumping = true
            
            self.marioImgView.image = self.marioJumpImage
            
            UIView.animate(withDuration: 0.35, delay: 0.0, options: [.curveEaseInOut, .allowUserInteraction], animations: {
                
                self.marioImgView.frame = self.marioImgView.frame.offsetBy(dx: 0.0, dy: -self.MAX_JUMP_HEIGHT)
                
            }, completion: { (finished) in
                
                UIView.animate(withDuration: 0.35, delay: 0.0, options: [.curveEaseInOut, .allowUserInteraction], animations: {
                    
                    self.marioImgView.frame = self.marioImgView.frame.offsetBy(dx: 0.0, dy: self.MAX_JUMP_HEIGHT)
                    
                }, completion: { (finished) in
                    
                    self.isMarioJumping = false
                    
                    //set to default frame
                    self.marioImgView.image = self.walkAnimationArray[0]
                })
            })
        }
    }
    
    //MARK: - IBAction
    
    @IBAction func advertising(_ sender: Any) {
    
        if self.isAdvertising {
            self.advertiser.stop()
        } else {
            self.advertiser.start()
        }
        
        self.isAdvertising = !self.isAdvertising
        
        let btnTitle = self.isAdvertising ? "Stop Advertising" : "Start Advertising"
        self.advertisingBtn.setTitle(btnTitle, for: .normal)
    }
    
    //MARK: - MCAdvertiserAssistantDelegate
    
    func advertiserAssistantDidDismissInvitation(_ advertiserAssistant: MCAdvertiserAssistant) {
        
        print("advertiserAssistantDidDismissInvitation")
        print("connectedPeers: \(self.session.connectedPeers)")
    }
    
    //MARK: - MCSessionDelegate
    
    private func session(session: MCSession, didReceiveCertificate certificate: [AnyObject]?, fromPeer peerID: MCPeerID, certificateHandler: @escaping (Bool) -> Void) {
        
        return certificateHandler(true)
    }
    
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        
        print("myPeerID: \(self.session.myPeerID)")
        print("connectd peerID: \(peerID)")
        
        DispatchQueue.main.async {
            
            switch state {
                
                case .connecting:
                    print("Connecting..")
                    self.connectionLbl.text = "Connecting..."
                    break
                    
                case .connected:
                    print("Connected..")
                    self.connectionLbl.text = "Connected !"
                    
                    print("peers count: \(session.connectedPeers.count)")
                    if (session.connectedPeers.count > 0){
                        let index = self.session.connectedPeers.index(of: peerID)!
                        print("index: \(index)")
                    }
                    break
                    
                case .notConnected:
                    print("Not Connected..")
                    self.connectionLbl.text = "Not Connected"
                    
                    print("peers count: \(session.connectedPeers.count)")
                    
                    break
            }
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        
        DispatchQueue.main.async {
            
            //Do animation on main thread
            
            let peerIndex = self.session.connectedPeers.index(of: peerID)
            
            let dataDict:NSDictionary = NSKeyedUnarchiver.unarchiveObject(with: data as Data) as! NSDictionary
            
            //print("didReceiveData \(dataDict["action"]) from peer:\(peerID.displayName)")
            //print("didReceiveData from peerIdx:\(peerIndex) name:\(peerID.displayName)")
            
            if peerIndex != nil {
                
                let action = dataDict["action"] as! String
                
                //print("receive action \(action) from peer: \(peerID.displayName)")
                
                if action == "move" {
                    
                    //print("receive move from peer: \(peerID.displayName)")
                    
                    self.touchMovementDelta = dataDict["movementDelta"] as! CGFloat
                    print("movementDelta: \(self.touchMovementDelta)")
                    
                    if !self.marioImgView.isAnimating {
                        self.marioImgView.startAnimating()
                    }

                } else if action == "jump" {
                    
                    self.jump()
                }
                else if action == "release" {
                 
                    if self.marioImgView.isAnimating {
                        self.marioImgView.stopAnimating()
                    }
                    
                    self.touchMovementDelta = 0.0
                }
            }
        }
    }
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        
        print("session didStartReceivingResourceWithName")
    }
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL, withError error: Error?) {
        
        print("session didFinishReceivingResourceWithName")
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        
        print("session didReceiveStream")
    }
}

