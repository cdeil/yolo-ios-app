// Ultralytics 🚀 AGPL-3.0 License - https://ultralytics.com/license

//  This file is part of the Ultralytics YOLO Package, implementing SpriteKit skeleton visualization.
//  Licensed under AGPL-3.0. For commercial use, refer to Ultralytics licensing: https://ultralytics.com/license
//  Access the source code: https://github.com/ultralytics/yolo-ios-app
//
//  The SpriteKitSkeletonViewController provides a view controller that integrates SpriteKit
//  skeleton visualization with YOLO pose estimation for real-time skeleton tracking.

import UIKit
import SpriteKit
import AVFoundation

/// View controller for SpriteKit-based skeleton visualization
public class SpriteKitSkeletonViewController: UIViewController {
    
    // MARK: - IBOutlets
    
    @IBOutlet weak var spriteKitView: SKView!
    @IBOutlet weak var cameraPreviewView: UIView!
    @IBOutlet weak var skeletonToggleButton: UIButton!
    @IBOutlet weak var settingsButton: UIButton!
    
    // MARK: - Properties
    
    /// SpriteKit scene for skeleton rendering
    private var skeletonScene: SKScene!
    
    /// YOLO SpriteKit integration
    private var yoloSpriteKitIntegration: YOLOSpriteKitIntegration!
    
    /// Camera preview layer
    private var cameraPreviewLayer: AVCaptureVideoPreviewLayer?
    
    /// Skeleton rendering settings
    private var skeletonSettings: SkeletonSettings = .default
    
    /// Performance monitor
    private var performanceMonitor: SkeletonPerformanceMonitor!
    
    /// YOLO predictor for pose estimation
    private var yoloPredictor: PoseEstimator?
    
    // MARK: - Lifecycle
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        setupSpriteKitScene()
        setupCameraPreview()
        setupYOLOIntegration()
        setupUI()
        setupPerformanceMonitoring()
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startCameraSession()
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopCameraSession()
    }
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateCameraPreviewFrame()
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
    
    private func setupCameraPreview() {
        // Setup camera preview layer
        cameraPreviewLayer = AVCaptureVideoPreviewLayer()
        cameraPreviewLayer?.videoGravity = .resizeAspectFill
        cameraPreviewView.layer.addSublayer(cameraPreviewLayer!)
    }
    
    private func setupYOLOIntegration() {
        // Initialize YOLO SpriteKit integration
        yoloSpriteKitIntegration = YOLOSpriteKitIntegration(
            scene: skeletonScene,
            cameraPreviewLayer: cameraPreviewLayer,
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
    }
    
    private func setupPerformanceMonitoring() {
        performanceMonitor = SkeletonPerformanceMonitor()
    }
    
    // MARK: - Camera Management
    
    private func startCameraSession() {
        // Start camera session for pose estimation
        // This would integrate with your existing camera setup
        setupYOLOPredictor()
    }
    
    private func stopCameraSession() {
        // Stop camera session
        yoloPredictor = nil
    }
    
    private func setupYOLOPredictor() {
        // Initialize YOLO pose estimator
        // This would integrate with your existing YOLO setup
        yoloPredictor = PoseEstimator()
        
        // Set up result callback
        yoloPredictor?.setOnResultsListener { [weak self] result in
            DispatchQueue.main.async {
                self?.handleYOLOResult(result)
            }
        }
    }
    
    // MARK: - YOLO Result Handling
    
    private func handleYOLOResult(_ result: YOLOResult) {
        // Update performance monitoring
        performanceMonitor.updateFrame()
        
        // Update skeleton visualization
        yoloSpriteKitIntegration.updateSkeleton(with: result)
        
        // Update UI based on performance
        updatePerformanceUI()
    }
    
    private func updatePerformanceUI() {
        let fps = performanceMonitor.getCurrentFPS()
        let isGoodPerformance = performanceMonitor.isPerformanceGood()
        
        // Update button colors based on performance
        skeletonToggleButton.backgroundColor = isGoodPerformance ? .systemBlue : .systemRed
    }
    
    // MARK: - UI Updates
    
    private func updateCameraPreviewFrame() {
        cameraPreviewLayer?.frame = cameraPreviewView.bounds
    }
    
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
        } else {
            sender.setTitle("Skeleton: OFF", for: .normal)
            sender.backgroundColor = .systemGray
            yoloSpriteKitIntegration.clearSkeletons()
        }
    }
    
    @IBAction func settingsTapped(_ sender: UIButton) {
        presentSettingsViewController()
    }
    
    // MARK: - Settings
    
    private func presentSettingsViewController() {
        let settingsVC = SkeletonSettingsViewController()
        settingsVC.settings = skeletonSettings
        settingsVC.delegate = self
        
        let navController = UINavigationController(rootViewController: settingsVC)
        present(navController, animated: true)
    }
}

// MARK: - SkeletonSettingsViewController

class SkeletonSettingsViewController: UIViewController {
    
    var settings: SkeletonSettings = .default
    weak var delegate: SkeletonSettingsDelegate?
    
    @IBOutlet weak var jointRadiusSlider: UISlider!
    @IBOutlet weak var boneWidthSlider: UISlider!
    @IBOutlet weak var confidenceThresholdSlider: UISlider!
    @IBOutlet weak var antiCrossingSwitch: UISwitch!
    @IBOutlet weak var animationSwitch: UISwitch!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupSliders()
        setupSwitches()
        setupNavigationBar()
    }
    
    private func setupSliders() {
        jointRadiusSlider.value = Float(settings.jointRadius)
        boneWidthSlider.value = Float(settings.boneWidth)
        confidenceThresholdSlider.value = settings.confidenceThreshold
    }
    
    private func setupSwitches() {
        antiCrossingSwitch.isOn = settings.enableAntiCrossing
        animationSwitch.isOn = settings.enableAnimations
    }
    
    private func setupNavigationBar() {
        title = "Skeleton Settings"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelTapped)
        )
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .save,
            target: self,
            action: #selector(saveTapped)
        )
    }
    
    @objc private func cancelTapped() {
        dismiss(animated: true)
    }
    
    @objc private func saveTapped() {
        // Update settings from UI
        settings.jointRadius = CGFloat(jointRadiusSlider.value)
        settings.boneWidth = CGFloat(boneWidthSlider.value)
        settings.confidenceThreshold = confidenceThresholdSlider.value
        settings.enableAntiCrossing = antiCrossingSwitch.isOn
        settings.enableAnimations = animationSwitch.isOn
        
        delegate?.skeletonSettingsDidChange(settings)
        dismiss(animated: true)
    }
}

// MARK: - Skeleton Settings

public struct SkeletonSettings {
    public var isEnabled: Bool
    public var jointRadius: CGFloat
    public var boneWidth: CGFloat
    public var confidenceThreshold: Float
    public var enableAntiCrossing: Bool
    public var enableAnimations: Bool
    public var jointColor: UIColor
    public var boneColor: UIColor
    
    public static let `default` = SkeletonSettings(
        isEnabled: true,
        jointRadius: 8.0,
        boneWidth: 4.0,
        confidenceThreshold: 0.5,
        enableAntiCrossing: true,
        enableAnimations: true,
        jointColor: .systemBlue,
        boneColor: .systemGreen
    )
}

// MARK: - Skeleton Settings Delegate

protocol SkeletonSettingsDelegate: AnyObject {
    func skeletonSettingsDidChange(_ settings: SkeletonSettings)
}

// MARK: - View Controller Extension

extension SpriteKitSkeletonViewController: SkeletonSettingsDelegate {
    func skeletonSettingsDidChange(_ settings: SkeletonSettings) {
        self.skeletonSettings = settings
        
        // Update skeleton configuration
        let skeletonConfig = SkeletonConfiguration(
            jointRadius: settings.jointRadius,
            boneWidth: settings.boneWidth,
            jointColor: settings.jointColor,
            boneColor: settings.boneColor,
            confidenceThreshold: settings.confidenceThreshold,
            animationDuration: 0.1
        )
        
        // Recreate integration with new settings
        yoloSpriteKitIntegration = YOLOSpriteKitIntegration(
            scene: skeletonScene,
            cameraPreviewLayer: cameraPreviewLayer,
            animationSettings: AnimationSettings(
                enableAnimations: settings.enableAnimations,
                transitionDuration: 0.1,
                smoothingFactor: 0.8,
                enableGlowEffects: true
            )
        )
    }
}
