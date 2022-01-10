/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The implementation of the application's view controller, responsible for coordinating
 the user interface, video feed, and PoseNet model.
*/

import AVFoundation
import UIKit
import VideoToolbox
import SceneKit
import VRMKit
import VRMSceneKit
import SocketIO
import Foundation

struct Rad:Codable {
    let JointA:String
    let JointB:String
    let Angle:Double
}

struct Point {
    var x:CGFloat
    var y:CGFloat
}


class ViewController: UIViewController {
    
    struct JointSegment {
        let jointA: Joint.Name
        let jointB: Joint.Name
    }

    /// An array of joint-pairs that define the lines of a pose's wireframe drawing.
    static let jointSegments = [
        // The connected joints that are on the left side of the body.
        JointSegment(jointA: .leftShoulder, jointB: .rightShoulder),
        JointSegment(jointA: .leftEye, jointB: .rightEye),
        JointSegment(jointA: .leftShoulder, jointB: .leftElbow),
        JointSegment(jointA: .leftWrist, jointB: .leftElbow),
        JointSegment(jointA: .rightShoulder, jointB: .rightElbow),
        JointSegment(jointA: .rightWrist, jointB: .rightElbow),
        JointSegment(jointA: .leftHip, jointB: .rightHip),
        JointSegment(jointA: .leftHip, jointB: .leftKnee),
        JointSegment(jointA: .leftKnee, jointB: .leftAnkle),
        JointSegment(jointA: .rightHip, jointB: .rightKnee),
        JointSegment(jointA: .rightKnee, jointB: .rightAnkle)
    ]

    //相手
    var user: User?
    //自分のニックネーム
    var nickName: String?
    
    /// VRMKit
    @IBOutlet weak var scnView: SCNView! {
        didSet {
            scnView.autoenablesDefaultLighting = true
            scnView.allowsCameraControl = true
            scnView.showsStatistics = false
            scnView.backgroundColor = UIColor(white: 0, alpha: 0.0)
        }
    }
    
    /// VRMKit
    @IBOutlet weak var scnView2: SCNView! {
        didSet {
            scnView2.autoenablesDefaultLighting = true
            scnView2.allowsCameraControl = true
            scnView2.showsStatistics = false
            scnView2.backgroundColor = UIColor(white: 0, alpha: 0.0)
        }
    }
    
    //自分のモデル読み込み
    let loader = try! VRMSceneLoader(named: "AliciaSolid.vrm")
    //相手のモデル読み込み
    let loader2 = try! VRMSceneLoader(named: "きりたん.vrm")
    
    /// The view the controller uses to visualize the detected poses.
    @IBOutlet private var previewImageView: PoseImageView!

    private let videoCapture = VideoCapture()

    private var poseNet: PoseNet!

    /// The frame the PoseNet model is currently making pose predictions from.
    private var currentFrame: CGImage?

    /// The algorithm the controller uses to extract poses from the current frame.
    private var algorithm: Algorithm = .multiple

    /// The set of parameters passed to the pose builder when detecting poses.
    private var poseBuilderConfiguration = PoseBuilderConfiguration()

    private var popOverPresentationManager: PopOverPresentationManager?
    

    
    // MARK: - viewDidLoad
    override func viewDidLoad() {
        super.viewDidLoad()
   
        //画面ロックされないようにアイドルタイマー無効
        UIApplication.shared.isIdleTimerDisabled = true
        
        do {
            poseNet = try PoseNet()
            //Socket受信部起動
            SocketHelper.shared.getPosition()

        } catch {
            return
        }

        poseNet.delegate = self
        setupAndBeginCapturingVideoFrames()
    }//ここまでViewDidLoad
    
    // MARK: - 自分のモデル・Socket送信
    //角度を算出
    func BoneAngle(a:Point, b:Point) -> Double {
        var r = atan2(b.y - a.y, b.x - a.x)
        if r < 0 {
            r = r + 2 * .pi
        }
        return Double(floor(r * 360 / (2 * .pi)))
    }
    
    //ラジアン値に変換
    func radianFrom(Angle angle: Double) -> CGFloat {
        return CGFloat(.pi / 180 * Double(angle))
    }
    
    //joint取得・送信
    func PoseValue(poses: [Pose]){
        
        for pose in poses{
            
            for segment in ViewController.jointSegments {
                let jointA = pose[segment.jointA]
                let jointB = pose[segment.jointB]
                

                guard jointA.isValid, jointB.isValid else {
                    continue
                }
                
                let PointA = Point(x: jointA.position.x, y: jointA.position.y)
                let PointB = Point(x: jointB.position.x, y: jointB.position.y)
                
                let angle = BoneAngle(a: PointA, b: PointB)
                let radian = radianFrom(Angle: angle)
                
                let JointA:String = String(describing:jointA.name)
                let JointB:String = String(describing:jointB.name)
                let Angle:Double = Double(radian)
                
                let record = Rad(JointA: JointA, JointB: JointB, Angle: Angle)
                
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                encoder.dateEncodingStrategy = .iso8601
                let data = try! encoder.encode(record)
                let jsonstr:String = String(data: data, encoding: .utf8)!
                
                //socket送信
                //自分のニックネーム
                guard let nickname = nickName else {
                return
                }
                SocketHelper.shared.sendData(message: jsonstr, withNickname: nickname)
                
                do{
                //自分のモデル
                let scene = try loader.loadScene()
                setupScene(scene)
                scnView.scene = scene
                scnView.delegate = self
                let node = scene.vrmNode
                //node.setBlendShape(value: 1.0, for: .preset(.joy))
                //node.setBlendShape(value: 1.0, for: .custom("><"))
                node.humanoid.node(for: .hips)?.rotation.y = Float.pi
                
                    //背骨
                    if record.JointA == "leftShoulder" && record.JointB == "rightShoulder"{
                        //左 -.pi/2以上、右.pi/2以下
                        if (.pi / 2 * -1)...(.pi / 2) ~= record.Angle - .pi{
                            node.humanoid.node(for: .spine)?.eulerAngles.z = Float(record.Angle - .pi)
                            print("spineは",record.Angle - .pi)
                        }else{
                            node.humanoid.node(for: .spine)?.eulerAngles.z = Float(0.0)
                            print("spineは適応範囲外です")
                        }
                    //首
                    }else if record.JointA == "leftEye" && record.JointB == "rightEye"{
                        //左 -.pi/2以上、右.pi/2以下
                        if (.pi / 2 * -1)...(.pi / 2) ~= record.Angle - .pi{
                            node.humanoid.node(for: .neck)?.eulerAngles.z = Float(record.Angle  - .pi)
                            print("neckは",record.Angle - .pi)
                        }else{
                            node.humanoid.node(for: .neck)?.eulerAngles.z = Float(0.0)
                            print("neckは適応範囲外です")
                        }
                    //左上腕
                    }else if record.JointA == "leftShoulder" && record.JointB == "leftElbow"{
                        //上 -1.2以上、下1.2以下
                        if (1.2 * -1)...1.2 ~= record.Angle{
                            node.humanoid.node(for: .leftUpperArm)?.eulerAngles.z = Float( record.Angle)
                            print("leftUpperArmは",record.Angle)
                        }else{
                            //node.humanoid.node(for: .leftUpperArm)?.eulerAngles.z = Float(0.0)
                            print("leftUpperArmは適応範囲外です")
                        }
                    //左腕
                    }else if record.JointA == "leftWrist" && record.JointB == "leftElbow"{
                        node.humanoid.node(for: .leftLowerArm)?.eulerAngles.z = Float( record.Angle - .pi * 5 / 4)
                        print("leftLowerArmは",record.Angle - .pi * 5 / 4)
                    //右上腕
                    }else if record.JointA == "rightShoulder" && record.JointB == "rightElbow"{
                        //下 -1.2以上、上1.2以下
                        if (1.2 * -1)...1.2 ~= record.Angle - .pi{
                            node.humanoid.node(for: .rightUpperArm)?.eulerAngles.z = Float(record.Angle - .pi)
                            print("rightUpperArmは",record.Angle - .pi)
                        }else{
                            node.humanoid.node(for: .rightUpperArm)?.eulerAngles.z = Float(0.0)
                            print("rightUpperArmは適応範囲外です")
                        }
                    //右腕
                    }else if record.JointA == "rightWrist" && record.JointB == "rightElbow"{
                        node.humanoid.node(for: .rightLowerArm)?.eulerAngles.z = Float(record.Angle + .pi / 4)
                        print("rightLowerArmは",record.Angle + .pi / 4)
                    //尻
                    }//else if decodeData.JointA == "leftHip" && decodeData.JointB == "rightHip"{
                        //node.humanoid.node(for: .hips)?.eulerAngles.z = Float(decodeData.Angle - .pi)
                        //print("hipsは",decodeData.Angle - .pi)
                    //}
                    //左太もも
                    else if record.JointA == "leftHip" && record.JointB == "leftKnee"{
                        //下 0以上、上1.2以下
                        if 0...1.2 ~= record.Angle - .pi / 2{
                            node.humanoid.node(for: .leftUpperLeg)?.eulerAngles.z = Float(record.Angle - .pi / 2)
                            print("leftUpperLegは",record.Angle - .pi / 2)
                        }else{
                            node.humanoid.node(for: .leftUpperLeg)?.eulerAngles.z = Float(0.0)
                            print("leftUpperLegは適応範囲外です")
                        }
                    //左脚
                    }else if record.JointA == "leftKnee" && record.JointB == "leftAnkle"{
                        //右 -1.2以上、左1.2以下
                        if (1.2 * -1)...1.2 ~= record.Angle - .pi / 2{
                            node.humanoid.node(for: .leftLowerLeg)?.eulerAngles.z = Float(record.Angle - .pi / 2)
                            print("leftLowerLegは",record.Angle)
                        }else{
                            node.humanoid.node(for: .leftLowerLeg)?.eulerAngles.z = Float(0.0)
                            print("leftLowerLegは適応範囲外です")
                        }
                    //右太もも
                    }else if record.JointA == "rightHip" && record.JointB == "rightKnee"{
                        //下 0以上、上1.2以下
                        if 0...1.2 ~= record.Angle - .pi / 2{
                            node.humanoid.node(for: .rightUpperLeg)?.eulerAngles.z = Float(record.Angle - .pi / 2)
                            print("rightUpperLegは",record.Angle - .pi / 2)
                        }else{
                            node.humanoid.node(for: .rightUpperLeg)?.eulerAngles.z = Float(0.0)
                            print("rightUpperLegは適応範囲外です")
                        }
                    //右脚
                    }else if record.JointA == "rightKnee" && record.JointB == "rightAnkle"{
                        //右 -1.2以上、左1.2以下
                        if (1.2 * -1)...1.2 ~= record.Angle - .pi / 2{
                            node.humanoid.node(for: .rightLowerLeg)?.eulerAngles.z = Float(record.Angle - .pi / 2)
                            print("rightLowerLegは",record.Angle)
                        }else{
                            node.humanoid.node(for: .rightLowerLeg)?.eulerAngles.z = Float(0.0)
                            print("rightLowerLegは適応範囲外です")
                        }
                    }
                
                } catch {
                    fatalError("Failed to load model. \(error.localizedDescription)")
                }//ここまでdo
            }//ここまでfor segment in ViewController.jointSegments
        }//ここまでpose
    }//ここまでPoseValue
    
    // MARK: - 相手のモデル・受信したデータを反映
    //受信したjointDataをモデルに反映
    func getPose(){
        do {
            /// VRMKit
            ///2体目
            let scene2 = try loader2.loadScene()
            setupScene(scene2)
            scnView2.scene = scene2
            scnView2.delegate = self
            let node2 = scene2.vrmNode
            
            node2.humanoid.node(for: .hips)?.rotation.y = Float.pi
            
            guard let user = user,
                  let nickName = SocketHelper.shared.nickName,
                  let jointData = SocketHelper.shared.jointData else{
                return
            }

            let decodeData = try! JSONDecoder().decode(Rad.self, from: jointData)
                
                //相手のニックネームだったら
                if nickName == user.nickname{
                    
                    //背骨
                    if decodeData.JointA == "leftShoulder" && decodeData.JointB == "rightShoulder"{
                        //左 -.pi/2以上、右.pi/2以下
                        if (.pi / 2 * -1)...(.pi / 2) ~= decodeData.Angle - .pi{
                            node2.humanoid.node(for: .spine)?.eulerAngles.z = Float(decodeData.Angle - .pi)
                            //node2.humanoid.node(for: .spine)?.eulerAngles.z = Float(decodeData.Angle - .pi)
                            print("spineは",decodeData.Angle - .pi)
                        }else{
                            node2.humanoid.node(for: .spine)?.eulerAngles.z = Float(0.0)
                            //node2.humanoid.node(for: .spine)?.eulerAngles.z = Float(0.0)
                            print("spineは適応範囲外です")
                        }
                    //首
                    }else if decodeData.JointA == "leftEye" && decodeData.JointB == "rightEye"{
                        //左 -.pi/2以上、右.pi/2以下
                        if (.pi / 2 * -1)...(.pi / 2) ~= decodeData.Angle - .pi{
                            node2.humanoid.node(for: .neck)?.eulerAngles.z = Float(decodeData.Angle  - .pi)
                            //node2.humanoid.node(for: .neck)?.eulerAngles.z = Float(decodeData.Angle  - .pi)
                            print("neckは",decodeData.Angle - .pi)
                        }else{
                            node2.humanoid.node(for: .neck)?.eulerAngles.z = Float(0.0)
                            //node2.humanoid.node(for: .neck)?.eulerAngles.z = Float(0.0)
                            print("neckは適応範囲外です")
                        }
                    //左上腕
                    }else if decodeData.JointA == "leftShoulder" && decodeData.JointB == "leftElbow"{
                        //上 -1.2以上、下1.2以下
                        if (1.2 * -1)...1.2 ~= decodeData.Angle{
                            node2.humanoid.node(for: .leftUpperArm)?.eulerAngles.z = Float( decodeData.Angle)
                            //node2.humanoid.node(for: .leftUpperArm)?.eulerAngles.z = Float( decodeData.Angle)
                            print("leftUpperArmは",decodeData.Angle)
                        }else{
                            node2.humanoid.node(for: .leftUpperArm)?.eulerAngles.z = Float(0.0)
                            //node2.humanoid.node(for: .leftUpperArm)?.eulerAngles.z = Float(0.0)
                            print("leftUpperArmは適応範囲外です")
                        }
                    //左腕
                    }else if decodeData.JointA == "leftWrist" && decodeData.JointB == "leftElbow"{
                        node2.humanoid.node(for: .leftLowerArm)?.eulerAngles.z = Float( decodeData.Angle - .pi * 5 / 4)
                        //node2.humanoid.node(for: .leftLowerArm)?.eulerAngles.z = Float( decodeData.Angle - .pi * 5 / 4)
                        print("leftLowerArmは",decodeData.Angle - .pi * 5 / 4)
                    //右上腕
                    }else if decodeData.JointA == "rightShoulder" && decodeData.JointB == "rightElbow"{
                        //下 -1.2以上、上1.2以下
                        if (1.2 * -1)...1.2 ~= decodeData.Angle - .pi{
                            node2.humanoid.node(for: .rightUpperArm)?.eulerAngles.z = Float(decodeData.Angle - .pi)
                            //node2.humanoid.node(for: .rightUpperArm)?.eulerAngles.z = Float(decodeData.Angle - .pi)
                            print("rightUpperArmは",decodeData.Angle - .pi)
                        }else{
                            node2.humanoid.node(for: .rightUpperArm)?.eulerAngles.z = Float(0.0)
                            //node2.humanoid.node(for: .rightUpperArm)?.eulerAngles.z = Float(0.0)
                            print("rightUpperArmは適応範囲外です")
                        }
                    //右腕
                    }else if decodeData.JointA == "rightWrist" && decodeData.JointB == "rightElbow"{
                        node2.humanoid.node(for: .rightLowerArm)?.eulerAngles.z = Float(decodeData.Angle + .pi / 4)
                        //node2.humanoid.node(for: .rightLowerArm)?.eulerAngles.z = Float(decodeData.Angle + .pi / 4)
                        print("rightLowerArmは",decodeData.Angle + .pi / 4)
                    //尻
                    }//else if decodeData.JointA == "leftHip" && decodeData.JointB == "rightHip"{
                        //node.humanoid.node(for: .hips)?.eulerAngles.z = Float(decodeData.Angle - .pi)
                        //print("hipsは",decodeData.Angle - .pi)
                    //}
                    //左太もも
                    else if decodeData.JointA == "leftHip" && decodeData.JointB == "leftKnee"{
                        //下 0以上、上1.2以下
                        if 0...1.2 ~= decodeData.Angle - .pi / 2{
                            node2.humanoid.node(for: .leftUpperLeg)?.eulerAngles.z = Float(decodeData.Angle - .pi / 2)
                            //node2.humanoid.node(for: .leftUpperLeg)?.eulerAngles.z = Float(decodeData.Angle - .pi / 2)
                            print("leftUpperLegは",decodeData.Angle - .pi / 2)
                        }else{
                            node2.humanoid.node(for: .leftUpperLeg)?.eulerAngles.z = Float(0.0)
                            //node2.humanoid.node(for: .leftUpperLeg)?.eulerAngles.z = Float(0.0)
                            print("leftUpperLegは適応範囲外です")
                        }
                    //左脚
                    }else if decodeData.JointA == "leftKnee" && decodeData.JointB == "leftAnkle"{
                        //右 -1.2以上、左1.2以下
                        if (1.2 * -1)...1.2 ~= decodeData.Angle - .pi / 2{
                            node2.humanoid.node(for: .leftLowerLeg)?.eulerAngles.z = Float(decodeData.Angle - .pi / 2)
                            //node2.humanoid.node(for: .leftLowerLeg)?.eulerAngles.z = Float(decodeData.Angle - .pi / 2)
                            print("leftLowerLegは",decodeData.Angle)
                        }else{
                            node2.humanoid.node(for: .leftLowerLeg)?.eulerAngles.z = Float(0.0)
                            //node2.humanoid.node(for: .leftLowerLeg)?.eulerAngles.z = Float(0.0)
                            print("leftLowerLegは適応範囲外です")
                        }
                    //右太もも
                    }else if decodeData.JointA == "rightHip" && decodeData.JointB == "rightKnee"{
                        //下 0以上、上1.2以下
                        if 0...1.2 ~= decodeData.Angle - .pi / 2{
                            node2.humanoid.node(for: .rightUpperLeg)?.eulerAngles.z = Float(decodeData.Angle - .pi / 2)
                            //node2.humanoid.node(for: .rightUpperLeg)?.eulerAngles.z = Float(decodeData.Angle - .pi / 2)
                            print("rightUpperLegは",decodeData.Angle - .pi / 2)
                        }else{
                            node2.humanoid.node(for: .rightUpperLeg)?.eulerAngles.z = Float(0.0)
                            //node2.humanoid.node(for: .rightUpperLeg)?.eulerAngles.z = Float(0.0)
                            print("rightUpperLegは適応範囲外です")
                        }
                    //右脚
                    }else if decodeData.JointA == "rightKnee" && decodeData.JointB == "rightAnkle"{
                        //右 -1.2以上、左1.2以下
                        if (1.2 * -1)...1.2 ~= decodeData.Angle - .pi / 2{
                            node2.humanoid.node(for: .rightLowerLeg)?.eulerAngles.z = Float(decodeData.Angle - .pi / 2)
                            //node2.humanoid.node(for: .rightLowerLeg)?.eulerAngles.z = Float(decodeData.Angle - .pi / 2)
                            print("rightLowerLegは",decodeData.Angle)
                        }else{
                            node2.humanoid.node(for: .rightLowerLeg)?.eulerAngles.z = Float(0.0)
                            //node2.humanoid.node(for: .rightLowerLeg)?.eulerAngles.z = Float(0.0)
                            print("rightLowerLegは適応範囲外です")
                        }
                    }
                }else{
                    print("自分のデータです")
                }//ここまでif nickName == user.nickname
        
        } catch {
            fatalError("Failed to load model. \(error.localizedDescription)")
        }//ここまでdo
    }//ここまでgetPose

    private func setupAndBeginCapturingVideoFrames() {
        videoCapture.setUpAVCapture { error in
            if let error = error {
                print("Failed to setup camera with error \(error)")
                return
            }

            self.videoCapture.delegate = self

            self.videoCapture.startCapturing()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        videoCapture.stopCapturing {
            super.viewWillDisappear(animated)
        }
    }

    override func viewWillTransition(to size: CGSize,
                                     with coordinator: UIViewControllerTransitionCoordinator) {
        // Reinitilize the camera to update its output stream with the new orientation.
        setupAndBeginCapturingVideoFrames()
    }

    @IBAction func onCameraButtonTapped(_ sender: Any) {
        videoCapture.flipCamera { error in
            if let error = error {
                print("Failed to flip camera with error \(error)")
            }
        }
    }

    @IBAction func onAlgorithmSegmentValueChanged(_ sender: UISegmentedControl) {
        guard let selectedAlgorithm = Algorithm(
            rawValue: sender.selectedSegmentIndex) else {
                return
        }

        algorithm = selectedAlgorithm
    }
        
    //ChatDetailViewへ移動
    @IBAction private func moveToChatDetail(_ sender: UIButton){
        self.dismiss(animated: true, completion: nil)
    }
    
    // MARK: - VRMKit
    /// VRMKit
    private func setupScene(_ scene: SCNScene) {
        //        let enviromentLightNode = SCNNode()
        //        let enviromentLight = SCNLight()
        //        enviromentLightNode.light = enviromentLight
        //        enviromentLight.type = .ambient
        //        enviromentLight.color = UIColor.white
        //        scene.rootNode.addChildNode(enviromentLightNode)
        //
        //        let pointLightNode = SCNNode()
        //        let pointLight = SCNLight()
        //        pointLightNode.light = pointLight
        //        pointLight.type = .spot
        //        pointLight.color = UIColor.white
        //        enviromentLight.intensity = 1000
        //        enviromentLightNode.position = SCNVector3(x: 0, y: 0, z: -2)
        //        scene.rootNode.addChildNode(pointLightNode)

                let cameraNode = SCNNode()
                cameraNode.camera = SCNCamera()
                scene.rootNode.addChildNode(cameraNode)

                cameraNode.position = SCNVector3(0, 0.8, -2.3)
                cameraNode.rotation = SCNVector4(0, 1, 0, Float.pi)
                
                //cameraNode.camera?.fieldOfView = 18
                //cameraNode.position = SCNVector3(0, 1.25, -1.8)
                //cameraNode.rotation = SCNVector4(0, 1, 0, Float.pi)
                
            }

}//ここまでClass:ViewController

/// VRMKit
extension ViewController: SCNSceneRendererDelegate {
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        (renderer.scene as! VRMScene).vrmNode.update(at: time)
        
    }
    
}

// MARK: - Navigation

extension ViewController {
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let uiNavigationController = segue.destination as? UINavigationController else {
            return
        }
        guard let configurationViewController = uiNavigationController.viewControllers.first
            as? ConfigurationViewController else {
                    return
        }

        configurationViewController.configuration = poseBuilderConfiguration
        configurationViewController.algorithm = algorithm
        configurationViewController.delegate = self

        popOverPresentationManager = PopOverPresentationManager(presenting: self,
                                                                presented: uiNavigationController)
        segue.destination.modalPresentationStyle = .custom
        segue.destination.transitioningDelegate = popOverPresentationManager
    }
}

// MARK: - ConfigurationViewControllerDelegate

extension ViewController: ConfigurationViewControllerDelegate {
    func configurationViewController(_ viewController: ConfigurationViewController,
                                     didUpdateConfiguration configuration: PoseBuilderConfiguration) {
        poseBuilderConfiguration = configuration
    }

    func configurationViewController(_ viewController: ConfigurationViewController,
                                     didUpdateAlgorithm algorithm: Algorithm) {
        self.algorithm = algorithm
    }
}

// MARK: - VideoCaptureDelegate

extension ViewController: VideoCaptureDelegate {
    func videoCapture(_ videoCapture: VideoCapture, didCaptureFrame capturedImage: CGImage?) {
        guard currentFrame == nil else {
            return
        }
        guard let image = capturedImage else {
            fatalError("Captured image is null")
        }

        currentFrame = image
        poseNet.predict(image)
    }
}

// MARK: - PoseNetDelegate

extension ViewController: PoseNetDelegate {
    func poseNet(_ poseNet: PoseNet, didPredict predictions: PoseNetOutput) {
        defer {
            // Release `currentFrame` when exiting this method.
            self.currentFrame = nil
        }

        guard let currentFrame = currentFrame else {
            return
        }

        let poseBuilder = PoseBuilder(output: predictions,
                                      configuration: poseBuilderConfiguration,
                                      inputImage: currentFrame)


        let poses = algorithm == .single
            ? [poseBuilder.pose]
            : poseBuilder.poses
        
        //点と線の描画(ループされる)
        previewImageView.show(poses: poses, on: currentFrame)
        //自分のモデル・データ送信(ループされる)
        PoseValue(poses: poses)
        //相手のモデル・データ反映(ループされる)
        getPose()
    }
}
