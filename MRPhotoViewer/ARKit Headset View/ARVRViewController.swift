

import UIKit
import SceneKit
import ARKit
import Photos

class ARVRViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var sceneViewLeft: ARSCNView!
//    var leftShip: SCNNode?
//    var rightShip: SCNNode?
    @IBOutlet weak var sceneViewRight: ARSCNView!
    @IBOutlet weak var imageViewLeft: UIImageView!
    @IBOutlet weak var imageViewRight: UIImageView!
    @IBOutlet weak var leftTarget: UIView!
    @IBOutlet weak var rightTarget: UIView!
    var selectedNode:SCNNode?
    var nodes:[SCNNode] = []
    let eyeCamera : SCNCamera = SCNCamera()
    var tick = 0
    // Parametres
    let interpupilaryDistance = 0.066 // This is the value for the distance between two pupils (in metres). The Interpupilary Distance (IPD).
    let viewBackgroundColor : UIColor = UIColor.white
    
    // Set eyeFOV and cameraImageScale. Uncomment any of the below lines to change FOV.
    //    let eyeFOV = 38.5; let cameraImageScale = 1.739; // (FOV: 38.5 ± 2.0) Brute-force estimate based on iPhone7+
    let eyeFOV = 60; let cameraImageScale = 3.478; // Calculation based on iPhone7+ // <- Works ok for cheap mobile headsets. Rough guestimate.
    //    let eyeFOV = 90; let cameraImageScale = 6; // (Scale: 6 ± 1.0) Very Rough Guestimate.
    //    let eyeFOV = 120; let cameraImageScale = 8.756; // Rough Guestimate.
    
    override func viewDidLoad() {
        super.viewDidLoad()
        PHCachingImageManager().stopCachingImagesForAllAssets()
        // Set the view's delegate
        sceneView.delegate = self
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = false
        // Create a new scene
        let scene = SCNScene(named: "Viewer.scn")!
        // Set the scene to the view
        sceneView.scene = scene
        
        ////////////////////////////////////////////////////////////////
        // App Setup
        UIApplication.shared.isIdleTimerDisabled = true
        
        // Scene setup
        sceneView.isHidden = true
        self.view.backgroundColor = viewBackgroundColor
        
        ////////////////////////////////////////////////////////////////
        // Set up Left-Eye SceneView
        sceneViewLeft.scene = scene
        sceneViewLeft.showsStatistics = sceneView.showsStatistics
        sceneViewLeft.isPlaying = true
        
        // Set up Right-Eye SceneView
        sceneViewRight.scene = scene
        sceneViewRight.showsStatistics = sceneView.showsStatistics
        sceneViewRight.isPlaying = true
        
        ////////////////////////////////////////////////////////////////
        // Create CAMERA
        eyeCamera.zNear = 0.001
        /*
         Note:
         - camera.projectionTransform was not used as it currently prevents the simplistic setting of .fieldOfView . The lack of metal, or lower-level calculations, is likely what is causing mild latency with the camera.
         - .fieldOfView may refer to .yFov or a diagonal-fov.
         - in a STEREOSCOPIC layout on iPhone7+, the fieldOfView of one eye by default, is closer to 38.5°, than the listed default of 60°
         */
        eyeCamera.fieldOfView = CGFloat(eyeFOV)
        
        ////////////////////////////////////////////////////////////////
        // Setup ImageViews - for rendering Camera Image
        self.imageViewLeft.clipsToBounds = true
        self.imageViewLeft.contentMode = UIViewContentMode.center
        self.imageViewRight.clipsToBounds = true
        self.imageViewRight.contentMode = UIViewContentMode.center

        let count = 40
        let options = PHFetchOptions()
        options.fetchLimit = count
        let result = PHAsset.fetchAssets(with: .image, options: options)
        print(result)
        
        result.enumerateObjects({ (asset, index, stop) -> Void in
            let material = SCNMaterial()
            material.diffuse.contents = self.getAssetThumbnail(asset: asset)
            material.specular.contents = UIColor.white
            let box = SCNBox(width: 0.0, height: 4.0, length: 6.0, chamferRadius: 0.0)
            let node = SCNNode(geometry: box)
            
            node.position = SCNVector3(0,0,4)
            node.pivot = SCNMatrix4MakeTranslation(10.0, 10.0, 10.0)
            node.eulerAngles = SCNVector3(Float(index) * 2 * Float.pi / Float(count / 4),0.0, 0.0)
            
            node.geometry?.firstMaterial = material
            scene.rootNode.addChildNode(node)
            self.nodes.append(node)
        })
        
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        
        // Run the view's session
        sceneView.session.run(configuration)

    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // Pause the view's session
        sceneView.session.pause()
//         PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }

    // MARK: - ARSCNViewDelegate
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        
        DispatchQueue.main.async {
            self.updateFrame()
        }
    }
    
    func getAssetThumbnail(asset: PHAsset) -> UIImage {
        let manager = PHImageManager.default()
        let option = PHImageRequestOptions()
        var thumbnail = UIImage()
        option.isSynchronous = true
        manager.requestImage(for: asset, targetSize: CGSize(width: 3000, height: 2000), contentMode: .aspectFit, options: option, resultHandler: {(result, info)->Void in
            thumbnail = result!
        })
        return thumbnail
    }
    
    deinit {
//        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }
    
    func updateFrame() {
        /////////////////////////////////////////////
        // CREATE POINT OF VIEWS
        let pointOfView : SCNNode = SCNNode()
        pointOfView.transform = (sceneView.pointOfView?.transform)!
        pointOfView.scale = (sceneView.pointOfView?.scale)!
        // Create POV from Camera
        pointOfView.camera = eyeCamera
        
        // Set PointOfView for SceneView-LeftEye
        sceneViewLeft.pointOfView = pointOfView
        
        // Clone pointOfView for Right-Eye SceneView
        let pointOfView2 : SCNNode = (sceneViewLeft.pointOfView?.clone())!
        // Determine Adjusted Position for Right Eye
        let orientation : SCNQuaternion = pointOfView.orientation
        let orientationQuaternion : GLKQuaternion = GLKQuaternionMake(orientation.x, orientation.y, orientation.z, orientation.w)
        let eyePos : GLKVector3 = GLKVector3Make(1.0, 0.0, 0.0)
        let rotatedEyePos : GLKVector3 = GLKQuaternionRotateVector3(orientationQuaternion, eyePos)
        let rotatedEyePosSCNV : SCNVector3 = SCNVector3Make(rotatedEyePos.x, rotatedEyePos.y, rotatedEyePos.z)
        let mag : Float = Float(interpupilaryDistance)
        pointOfView2.position.x += rotatedEyePosSCNV.x * mag
        pointOfView2.position.y += rotatedEyePosSCNV.y * mag
        pointOfView2.position.z += rotatedEyePosSCNV.z * mag
        
        // Set PointOfView for SceneView-RightEye
        sceneViewRight.pointOfView = pointOfView2
        
        ////////////////////////////////////////////
        // RENDER CAMERA IMAGE
        /*
         Note:
         - as camera.contentsTransform doesn't appear to affect the camera-image at the current time, we are re-rendering the image.
         - for performance, this should be ideally be ported to metal
         */
        // Clear Original Camera-Image
        sceneViewLeft.scene.background.contents = UIColor.clear // This sets a transparent scene bg for all sceneViews - as they're all rendering the same scene.
        
        // Read Camera-Image
        let pixelBuffer : CVPixelBuffer? = sceneView.session.currentFrame?.capturedImage
        if pixelBuffer == nil { return }
        let ciimage = CIImage(cvPixelBuffer: pixelBuffer!)
        // Convert ciimage to cgimage, so uiimage can affect its orientation
        let context = CIContext(options: nil)
        let cgimage = context.createCGImage(ciimage, from: ciimage.extent)
        
        // Determine Camera-Image Scale
        var scale_custom : CGFloat = 1.0
        // let cameraImageSize : CGSize = CGSize(width: ciimage.extent.width, height: ciimage.extent.height) // 1280 x 720 on iPhone 7+
        // let eyeViewSize : CGSize = CGSize(width: self.view.bounds.width / 2, height: self.view.bounds.height) // (736/2) x 414 on iPhone 7+
        // let scale_aspectFill : CGFloat = cameraImageSize.height / eyeViewSize.height // 1.739 // fov = ~38.5 (guestimate on iPhone7+)
        // let scale_aspectFit : CGFloat = cameraImageSize.width / eyeViewSize.width // 3.478 // fov = ~60
        // scale_custom = 8.756 // (8.756) ~ appears close to 120° FOV - (guestimate on iPhone7+)
        // scale_custom = 6 // (6±1) ~ appears close-ish to 90° FOV - (guestimate on iPhone7+)
        scale_custom = CGFloat(cameraImageScale)
        
        // Determine Camera-Image Orientation
        let imageOrientation : UIImageOrientation = (UIApplication.shared.statusBarOrientation == UIInterfaceOrientation.landscapeLeft) ? UIImageOrientation.down : UIImageOrientation.up
        
        // Display Camera-Image
        let uiimage = UIImage(cgImage: cgimage!, scale: scale_custom, orientation: imageOrientation)
        self.imageViewLeft.image = uiimage
        self.imageViewRight.image = uiimage
        
        
        
        if self.nodes.count > 0 {
            for index in 0...self.nodes.count-1 {
                let node = self.nodes[index]
                node.position = SCNVector3(5, Double(index) * 0.55 , 0)
                node.pivot = SCNMatrix4MakeTranslation(-10.0, 0.0, 0.0)
                let rot =  Double(Float(tick) * 0.01 + Float(index) * 2 * Float.pi / Float(self.nodes.count / 4))
                
//                var dec = 0.0
//                if index > 9 {
//                    dec = 0.5
//                } else if index > 19 {
//                    dec = 1.0
//                } else if index > 29 {
//                    dec = 1.5
//                } else if index > 39 {
//                    dec = 2.0
//                }
                
                node.eulerAngles = SCNVector3(0.0, rot, 0.0)
            }
        }
        
  
        self.tick += 1
    }
}

