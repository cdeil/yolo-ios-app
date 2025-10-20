// Ultralytics 🚀 AGPL-3.0 License - https://ultralytics.com/license

//  This file is part of the Ultralytics YOLO Package, providing a demo of SpriteKit skeleton visualization.
//  Licensed under AGPL-3.0. For commercial use, refer to Ultralytics licensing: https://ultralytics.com/license
//  Access the source code: https://github.com/ultralytics/yolo-ios-app
//
//  The SpriteKitSkeletonDemoViewController demonstrates how to use the SpriteKit skeleton system
//  with YOLO pose estimation, including coordinate conversion, anti-crossing logic, and animations.

import UIKit
import SpriteKit
import YOLO

/// Demo view controller showing SpriteKit skeleton visualization
public class SpriteKitSkeletonDemoViewController: UIViewController {
    
    // MARK: - IBOutlets
    
    @IBOutlet weak var spriteKitView: SKView!
    @IBOutlet weak var cameraPreviewView: UIView!
    @IBOutlet weak var skeletonToggleButton: UIButton!
    @IBOutlet weak var settingsButton: UIButton!
    @IBOutlet weak var performanceLabel: UILabel!
    
    // MARK: - Properties
    
    /// SpriteKit scene for skeleton rendering
    private var skeletonScene: SKScene!
    
    /// YOLO SpriteKit integration
    private var yoloSpriteKitIntegration: YOLOSpriteKitIntegration!
    
    /// YOLO pose estimator
    private var poseEstimator: PoseEstimator?
    
    /// Performance monitor
    private var performanceMonitor: SkeletonPerformanceMonitor!
    
    /// Skeleton settings
    private var skeletonSettings: SkeletonSettings = .default
    
    /// Demo data for testing
    private var demoKeypoints: [Keypoints] = []
    
    // MARK: - Lifecycle
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        setupSpriteKitScene()
        setupYOLOIntegration()
        setupUI()
        setupPerformanceMonitoring()
        setupDemoData()
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startDemo()
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopDemo()
    }
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateSpriteKitSceneSize()
    }
    
    // MARK: - Setup Methods
    
    private func setupSpriteKitScene() {
        // Create SpriteKit scene
        skeletonScene = SKScene(size: spriteKitView.bounds.size)
        skeletonScene.backgroundColor = .clear
        skeletonScene.scaleMode = .aspectFill
        
        // Configure SpriteKit view
        spriteKitView.presentScene(skeletonScene)
        spriteKitView.showsFPS = true
        spriteKitView.showsNodeCount = true
        spriteKitView.ignoresSiblingOrder = true
    }
    
    private func setupYOLOIntegration() {
        // Initialize YOLO SpriteKit integration
        yoloSpriteKitIntegration = YOLOSpriteKitIntegration(
            scene: skeletonScene,
            cameraPreviewLayer: nil,
            animationSettings: .default
        )
    }
    
    private func setupUI() {
        // Configure skeleton toggle button
        skeletonToggleButton.setTitle("Skeleton: ON", for: .normal)
        skeletonToggleButton.backgroundColor = .systemBlue
        skeletonToggleButton.layer.cornerRadius = 8
        
        // Configure settings button
        settingsButton.setTitle("Settings", for: .normal)
        settingsButton.backgroundColor = .systemGray
        settingsButton.layer.cornerRadius = 8
        
        // Configure performance label
        performanceLabel.text = "FPS: --"
        performanceLabel.textColor = .white
        performanceLabel.backgroundColor = .black.withAlphaComponent(0.5)
        performanceLabel.layer.cornerRadius = 4
        performanceLabel.textAlignment = .center
    }
    
    private func setupPerformanceMonitoring() {
        performanceMonitor = SkeletonPerformanceMonitor()
    }
    
    private func setupDemoData() {
        // Create demo keypoints data for testing
        createDemoKeypoints()
    }
    
    private func createDemoKeypoints() {
        // Create sample keypoints for a standing person
        let demoPoints: [(x: Float, y: Float)] = [
            (0.5, 0.1),   // nose
            (0.48, 0.12), // left_eye
            (0.52, 0.12), // right_eye
            (0.46, 0.14), // left_ear
            (0.54, 0.14), // right_ear
            (0.45, 0.25), // left_shoulder
            (0.55, 0.25), // right_shoulder
            (0.42, 0.35), // left_elbow
            (0.58, 0.35), // right_elbow
            (0.4, 0.45),  // left_wrist
            (0.6, 0.45),  // right_wrist
            (0.47, 0.5),  // left_hip
            (0.53, 0.5),  // right_hip
            (0.45, 0.65), // left_knee
            (0.55, 0.65), // right_knee
            (0.43, 0.8),  // left_ankle
            (0.57, 0.8)   // right_ankle
        ]
        
        let confidences = Array(repeating: Float(0.9), count: demoPoints.count)
        
        let keypoints = Keypoints(
            xyn: demoPoints,
            xy: demoPoints.map { (x: $0.x * 640, y: $0.y * 480) },
            conf: confidences
        )
        
        demoKeypoints = [keypoints]
    }
    
    // MARK: - Demo Methods
    
    private func startDemo() {
        // Start demo animation
        animateDemoSkeleton()
    }
    
    private func stopDemo() {
        // Stop demo animation
        skeletonScene.removeAllActions()
    }
    
    private func animateDemoSkeleton() {
        // Create demo YOLO result
        let demoBox = Box(
            index: 0,
            cls: "person",
            conf: 0.9,
            xywh: CGRect(x: 200, y: 100, width: 200, height: 400),
            xywhn: CGRect(x: 0.3, y: 0.2, width: 0.4, height: 0.8)
        )
        
        let demoResult = YOLOResult(
            orig_shape: CGSize(width: 640, height: 480),
            boxes: [demoBox],
            keypointsList: demoKeypoints,
            speed: 0.1,
            names: ["person"]
        )
        
        // Update skeleton
        yoloSpriteKitIntegration.updateSkeleton(with: demoResult)
        
        // Animate keypoints
        animateKeypoints()
    }
    
    private func animateKeypoints() {
        // Create animation that moves the skeleton
        let moveAction = SKAction.sequence([
            SKAction.moveBy(x: 50, y: 0, duration: 2.0),
            SKAction.moveBy(x: -50, y: 0, duration: 2.0)
        ])
        
        let repeatAction = SKAction.repeatForever(moveAction)
        skeletonScene.run(repeatAction)
        
        // Update demo keypoints periodically
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateDemoKeypoints()
        }
    }
    
    private func updateDemoKeypoints() {
        // Update performance monitoring
        performanceMonitor.updateFrame()
        
        // Update performance label
        let fps = performanceMonitor.getCurrentFPS()
        DispatchQueue.main.async { [weak self] in
            self?.performanceLabel.text = String(format: "FPS: %.1f", fps)
        }
        
        // Create new demo result with slight variations
        let time = CACurrentMediaTime()
        let offset = sin(time) * 0.05
        
        let animatedPoints: [(x: Float, y: Float)] = [
            (0.5 + Float(offset), 0.1),
            (0.48 + Float(offset), 0.12),
            (0.52 + Float(offset), 0.12),
            (0.46 + Float(offset), 0.14),
            (0.54 + Float(offset), 0.14),
            (0.45 + Float(offset), 0.25),
            (0.55 + Float(offset), 0.25),
            (0.42 + Float(offset), 0.35),
            (0.58 + Float(offset), 0.35),
            (0.4 + Float(offset), 0.45),
            (0.6 + Float(offset), 0.45),
            (0.47 + Float(offset), 0.5),
            (0.53 + Float(offset), 0.5),
            (0.45 + Float(offset), 0.65),
            (0.55 + Float(offset), 0.65),
            (0.43 + Float(offset), 0.8),
            (0.57 + Float(offset), 0.8)
        ]
        
        let confidences = Array(repeating: Float(0.9), count: animatedPoints.count)
        
        let keypoints = Keypoints(
            xyn: animatedPoints,
            xy: animatedPoints.map { (x: $0.x * 640, y: $0.y * 480) },
            conf: confidences
        )
        
        let demoBox = Box(
            index: 0,
            cls: "person",
            conf: 0.9,
            xywh: CGRect(x: 200, y: 100, width: 200, height: 400),
            xywhn: CGRect(x: 0.3, y: 0.2, width: 0.4, height: 0.8)
        )
        
        let demoResult = YOLOResult(
            orig_shape: CGSize(width: 640, height: 480),
            boxes: [demoBox],
            keypointsList: [keypoints],
            speed: 0.1,
            names: ["person"]
        )
        
        // Update skeleton
        yoloSpriteKitIntegration.updateSkeleton(with: demoResult)
    }
    
    // MARK: - UI Updates
    
    private func updateSpriteKitSceneSize() {
        skeletonScene.size = spriteKitView.bounds.size
        yoloSpriteKitIntegration.updateCameraBounds(spriteKitView.bounds)
    }
    
    // MARK: - IBActions
    
    @IBAction func skeletonToggleTapped(_ sender: UIButton) {
        skeletonSettings.isEnabled.toggle()
        
        if skeletonSettings.isEnabled {
            sender.setTitle("Skeleton: ON", for: .normal)
            sender.backgroundColor = .systemBlue
            startDemo()
        } else {
            sender.setTitle("Skeleton: OFF", for: .normal)
            sender.backgroundColor = .systemGray
            yoloSpriteKitIntegration.clearSkeletons()
        }
    }
    
    @IBAction func settingsTapped(_ sender: UIButton) {
        presentSettingsAlert()
    }
    
    private func presentSettingsAlert() {
        let alert = UIAlertController(title: "Skeleton Settings", message: "Configure skeleton visualization", preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Toggle Anti-Crossing", style: .default) { [weak self] _ in
            self?.skeletonSettings.enableAntiCrossing.toggle()
        })
        
        alert.addAction(UIAlertAction(title: "Toggle Animations", style: .default) { [weak self] _ in
            self?.skeletonSettings.enableAnimations.toggle()
        })
        
        alert.addAction(UIAlertAction(title: "Reset to Default", style: .default) { [weak self] _ in
            self?.skeletonSettings = .default
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
}
