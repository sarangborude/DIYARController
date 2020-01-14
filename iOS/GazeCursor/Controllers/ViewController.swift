//
//  ViewController.swift
//  GazeCursor
//
//  Created by Sarang Borude on 6/24/19.
//  Copyright © 2019 Sarang Borude. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import CoreBluetooth

class ViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var bluetoothIndicator: UIView!
    @IBOutlet weak var buttonState: UIView!
    @IBOutlet weak var startButton: UIButton!
    
    // Properties
    var isButtonPressed = false {
        didSet{
            
        }
    }
    
    var isBoxGrabbed = false
    
    let bluetoothManager = BluetoothManager()
    
    var cursorPoint: CGPoint!
    var cursorNode: SCNNode!
    var cursorGeometry: SCNGeometry?
    
    var grabbedBoxNode: SCNNode?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        self.bluetoothIndicator.backgroundColor = UIColor.black
        self.buttonState.backgroundColor = UIColor.black
        
        buttonState.layer.cornerRadius = 8
        bluetoothIndicator.layer.cornerRadius = 8
        startButton.layer.cornerRadius = 8
        
        let gesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(sender:)))
        sceneView.addGestureRecognizer(gesture)
        sceneView.autoenablesDefaultLighting = true
        
        // Add observers for notifications coming from the bluetooth devices to monitor device connection and button press status
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(peripheralStateChanged), name: .peripheralStateChanged, object: nil)
        nc.addObserver(self, selector: #selector(buttonStateChanged), name: .buttonStateChanged, object: nil)
        
        // Add observer for changes in device orientation
        nc.addObserver(self, selector: #selector(orientationChanged), name: UIDevice.orientationDidChangeNotification, object: nil)
        
        cursorPoint = CGPoint(x: view.center.x, y: view.center.y)
        
        loadModels()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        
        configuration.planeDetection = [.horizontal]

        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    @IBAction func startButtonTapped(_ sender: Any) {
        hideARPlaneNodes()
        suspendARPlaneDetection()
        startButton.isHidden = true
    }
    // MARK: - Custom Functions
    func loadModels() {
        guard let cursorScene = SCNScene(named: "art.scnassets/Cursor.scn") else { return }
        cursorNode = cursorScene.rootNode.childNode(withName: "cursor", recursively: false)
        cursorGeometry = cursorNode.geometry
        sceneView.scene.rootNode.addChildNode(cursorNode)
    }
    
    // MARK: - ARSCNViewDelegate functions
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        updateCursorNode()
        
        if isButtonPressed {
            // grab box node //  change it's color
            // Move it
            if !isBoxGrabbed {
                pickUpBox(at: cursorPoint)
            } else {
                updateBoxNode()
            }
        } else {
            // release box node
            if isBoxGrabbed {
                dropTheBox()
            }
        }
        
    }
    
    func pickUpBox(at point: CGPoint) {
        let results = sceneView.hitTest(point, options: nil)
        let boxNodes = results.filter { (result) -> Bool in
            result.node.name == "box"
        }
        guard let boxNode =  boxNodes.first?.node else { return }
        isBoxGrabbed = true
        grabbedBoxNode = boxNode
        boxNode.geometry?.materials.first?.diffuse.contents = UIColor.red
        boxNode.physicsBody?.isAffectedByGravity = false
    }
    
    func updateBoxNode() {
        guard let grabbedBoxNode = grabbedBoxNode else { return }
        grabbedBoxNode.position = SCNVector3(
            cursorNode.position.x,
            cursorNode.position.y + 0.3,
            cursorNode.position.z)
    }
    
    func dropTheBox() {
        grabbedBoxNode?.geometry?.materials.first?.diffuse.contents = UIColor.brown
        grabbedBoxNode?.physicsBody?.isAffectedByGravity = true
        grabbedBoxNode = nil
        isBoxGrabbed = false
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
        let planeNode = createARPlaneNode(planeAnchor: planeAnchor)
        node.addChildNode(planeNode)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
        print("Updating plane Anchor")
        updateARPlaneNode(planeNode: node.childNodes[0], planeAnchor: planeAnchor)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
        print("Removing Plane Anchor")
        removeARPlaneNode(node: node)
    }
    
    func createARPlaneNode(planeAnchor: ARPlaneAnchor) -> SCNNode {
        let planeGeometry = SCNPlane(width: CGFloat(planeAnchor.extent.x), height: CGFloat(planeAnchor.extent.z))
        let planeMaterial = SCNMaterial()
        
        
        if planeAnchor.alignment == .vertical {
            planeMaterial.diffuse.contents = UIColor.red.withAlphaComponent(0.4)
            planeGeometry.materials = [planeMaterial]
            let planeNode = SCNNode(geometry: planeGeometry)
            planeNode.position = SCNVector3Make(planeAnchor.center.x, 0, planeAnchor.center.z)
            planeNode.transform = SCNMatrix4MakeRotation(-Float.pi/2, 1, 0, 0)
            return planeNode
        } else {
            planeMaterial.diffuse.contents = UIColor.yellow.withAlphaComponent(0.4)
            planeGeometry.materials = [planeMaterial]
            let planeNode = SCNNode(geometry: planeGeometry)
            planeNode.position = SCNVector3Make(planeAnchor.center.x, 0, planeAnchor.center.z)
            planeNode.transform = SCNMatrix4MakeRotation(-Float.pi/2, 1, 0, 0)
            planeNode.physicsBody = createARPlanePhysics(geometry: planeGeometry)
            planeNode.physicsBody?.categoryBitMask = 4
            return planeNode
        }
    }
    
    func createARPlanePhysics(geometry: SCNGeometry) -> SCNPhysicsBody {
        let body = SCNPhysicsBody(type: .kinematic, shape: SCNPhysicsShape(geometry: geometry, options: nil))
        body.friction = 0.5
        body.restitution = 0.5
        body.damping = 0.8
        body.angularDamping = 0.8
        return body
    }
    
    func updateARPlaneNode(planeNode: SCNNode, planeAnchor: ARPlaneAnchor) {
        guard let planeGeometry = planeNode.geometry as? SCNPlane else { return }
        planeGeometry.width = CGFloat(planeAnchor.extent.x)
        planeGeometry.height = CGFloat(planeAnchor.extent.z)
        
        planeNode.position = SCNVector3Make(planeAnchor.center.x, 0, planeAnchor.center.z)
        
        planeNode.physicsBody = nil
        planeNode.physicsBody = createARPlanePhysics(geometry: planeGeometry)
    }
    
    func suspendARPlaneDetection() {
        guard let config = sceneView.session.configuration as? ARWorldTrackingConfiguration else { return }
        config.planeDetection = []
        sceneView.session.run(config)
    }
    
    func hideARPlaneNodes() {
        for anchor in (self.sceneView.session.currentFrame?.anchors)! {
            if let node = self.sceneView.node(for: anchor) {
                for child in node.childNodes {
                    //child.removeFromParentNode()
                    //sceneView.session.remove(anchor: anchor)
                    let material = child.geometry?.materials.first!
                    material?.colorBufferWriteMask = []
                }
            }
        }
    }
    
    func removeARPlaneNode(node: SCNNode) {
        for childNode in node.childNodes {
            childNode.removeFromParentNode()
        }
    }
    
    func updateCursorNode() {
        let results = sceneView.hitTest(cursorPoint, types: [.existingPlaneUsingExtent])
        if results.count == 1 {
            guard let match = results.first else { return }
            let transform = match.worldTransform
            
            if isButtonPressed {
                cursorNode.position = SCNVector3(
                    x: transform.columns.3.x,
                    y: transform.columns.3.y,
                    z: transform.columns.3.z)
            } else {
                cursorNode.position = SCNVector3(
                    x: transform.columns.3.x,
                    y: transform.columns.3.y + 0.2, // Add the height of the pyramid to the y position
                    z: transform.columns.3.z)
            }
            
            
            let sphere = SCNSphere(radius: 0.2)
            let material = SCNMaterial()
            material.diffuse.contents = UIColor.green
            material.specular.contents = UIColor.white
            sphere.materials = [material]

            guard let cursorGeometry = cursorGeometry else { return }
            
            DispatchQueue.main.async {
                self.cursorNode.geometry = self.isButtonPressed ? sphere : cursorGeometry
            }
            
            guard !isBoxGrabbed else { return }
            
            let resultNodes = sceneView.hitTest(cursorPoint, options: nil)
            let boxNodesResults = resultNodes.filter { (result) -> Bool in
                result.node.name == "box"
            }
            
            guard let boxNode = boxNodesResults.first?.node else { return }
            
            if isButtonPressed {
                cursorNode.position = SCNVector3(
                    x: transform.columns.3.x,
                    y: boxNode.position.y + 0.1,
                    z: transform.columns.3.z)
            } else {
                cursorNode.position = SCNVector3(
                    x: transform.columns.3.x,
                    y: boxNode.position.y + 0.1, // Add the height of the pyramid to the y position
                    z: transform.columns.3.z)
            }
            
        }
    }
    
    //MARK:- Custom Event Handlers
    @objc func handleTap(sender: UITapGestureRecognizer) {
        // Do hit test
        guard let result = sceneView.hitTest(sender.location(in: sceneView), types: .existingPlaneUsingExtent).first else { return }
        guard let anchor = result.anchor as? ARPlaneAnchor else { return }
        //guard let anchorNode = sceneView.node(for: anchor) else { return }
        //let orientation = anchorNode.worldOrientation
        let transform = result.worldTransform
        let position = SCNVector3Make(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
        
        switch anchor.alignment {
        case .horizontal:
            addBoxNode(at: position)
        default:
            break
        }
    }
    
    func addBoxNode(at position: SCNVector3) {
        let boxScene = SCNScene(named: "art.scnassets/Box.scn")
        guard let boxNode = boxScene?.rootNode.childNode(withName: "box", recursively: false) else { return }
        boxNode.name = "box"
        boxNode.position = SCNVector3(position.x, position.y + 0.05, position.z)
        
        sceneView.scene.rootNode.addChildNode(boxNode)
    }
    
    @objc func peripheralStateChanged(notification: Notification) {
        guard
            let info = notification.userInfo,
            let state = info["State"] as? Bool else { return }
        
        DispatchQueue.main.async {
            self.bluetoothIndicator.backgroundColor = state ? UIColor.blue : UIColor.black
        }
    }
    
    @objc func buttonStateChanged(notification: Notification) {
        guard
            let info = notification.userInfo,
            let state = info["State"] as? Bool else { return }
        isButtonPressed = state
        DispatchQueue.main.async {
            self.buttonState.backgroundColor = state ? UIColor.red : UIColor.black
        }
    }
    
    @objc func orientationChanged() {
        cursorPoint = CGPoint(x: view.center.x, y: view.center.y)
    }
}


