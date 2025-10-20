// Ultralytics 🚀 AGPL-3.0 License - https://ultralytics.com/license

//  This file is part of the Ultralytics YOLO Package, extending ViewController with SpriteKit skeleton support for Pose models.
//  Licensed under AGPL-3.0. For commercial use, refer to Ultralytics licensing: https://ultralytics.com/license
//  Access the source code: https://github.com/ultralytics/yolo-ios-app
//
//  This extension adds SpriteKit-based skeleton visualization specifically for Pose estimation models,
//  providing real-time skeleton tracking with anti-crossing logic and smooth animations.

import UIKit
import SpriteKit
import YOLO

// MARK: - ViewController SpriteKit Pose Extension

extension ViewController {
    
    // MARK: - SpriteKit Pose Properties
    
    /// SpriteKit view for skeleton visualization (only for Pose models)
    private var spriteKitPoseView: SKView? {
        return view.subviews.first { $0.tag == 1001 } as? SKView
    }
    
    /// SpriteKit scene for skeleton rendering
    private var poseSkeletonScene: SKScene? {
        return spriteKitPoseView?.scene
    }
    
    /// YOLO SpriteKit integration for pose estimation
    private var poseSpriteKitIntegration: YOLOSpriteKitIntegration? {
        return objc_getAssociatedObject(self, &AssociatedKeys.poseSpriteKitIntegration) as? YOLOSpriteKitIntegration
    }
    
    /// Pose skeleton settings
    private var poseSkeletonSettings: PoseSkeletonSettings {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.poseSkeletonSettings) as? PoseSkeletonSettings ?? .default
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.poseSkeletonSettings, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    /// Pose skeleton toggle button
    private var poseSkeletonToggleButton: UIButton? {
        return view.subviews.first { $0.tag == 1002 } as? UIButton
    }
    
    // MARK: - SpriteKit Pose Setup
    
    /// Setup SpriteKit skeleton visualization for Pose models
    func setupSpriteKitPoseSkeleton() {
        // Only setup for Pose models
        guard currentTask.lowercased() == "pose" else { return }
        
        // Create SpriteKit view
        let spriteKitView = createSpriteKitPoseView()
        view.addSubview(spriteKitView)
        
        // Create SpriteKit scene
        let scene = createPoseSkeletonScene()
        spriteKitView.presentScene(scene)
        
        // Setup YOLO integration
        setupPoseYOLOSpriteKitIntegration(scene: scene)
        
        // Add pose skeleton toggle button
        addPoseSkeletonToggleButton()
    }
    
    private func createSpriteKitPoseView() -> SKView {
        let spriteKitView = SKView()
        spriteKitView.tag = 1001
        spriteKitView.translatesAutoresizingMaskIntoConstraints = false
        spriteKitView.showsFPS = false
        spriteKitView.showsNodeCount = false
        spriteKitView.ignoresSiblingOrder = true
        spriteKitView.backgroundColor = .clear
        
        // Position behind camera preview but above other UI elements
        NSLayoutConstraint.activate([
            spriteKitView.topAnchor.constraint(equalTo: view.topAnchor),
            spriteKitView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            spriteKitView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            spriteKitView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        return spriteKitView
    }
    
    private func createPoseSkeletonScene() -> SKScene {
        let scene = SKScene(size: view.bounds.size)
        scene.backgroundColor = .clear
        scene.scaleMode = .aspectFill
        return scene
    }
    
    private func setupPoseYOLOSpriteKitIntegration(scene: SKScene) {
        let integration = YOLOSpriteKitIntegration(
            scene: scene,
            cameraPreviewLayer: nil, // Will be set when camera is available
            animationSettings: .default
        )
        
        objc_setAssociatedObject(self, &AssociatedKeys.poseSpriteKitIntegration, integration, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
    
    private func addPoseSkeletonToggleButton() {
        let button = UIButton(type: .system)
        button.tag = 1002
        button.setTitle("Skeleton: ON", for: .normal)
        button.backgroundColor = .systemBlue.withAlphaComponent(0.8)
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        
        button.addTarget(self, action: #selector(poseSkeletonToggleTapped), for: .touchUpInside)
        
        view.addSubview(button)
        
        // Position button in top-right corner
        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            button.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            button.widthAnchor.constraint(equalToConstant: 120),
            button.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    // MARK: - SpriteKit Pose Actions
    
    @objc private func poseSkeletonToggleTapped() {
        poseSkeletonSettings.isEnabled.toggle()
        
        if poseSkeletonSettings.isEnabled {
            poseSkeletonToggleButton?.setTitle("Skeleton: ON", for: .normal)
            poseSkeletonToggleButton?.backgroundColor = .systemBlue.withAlphaComponent(0.8)
            setupSpriteKitPoseSkeleton()
        } else {
            poseSkeletonToggleButton?.setTitle("Skeleton: OFF", for: .normal)
            poseSkeletonToggleButton?.backgroundColor = .systemGray.withAlphaComponent(0.8)
            removeSpriteKitPoseSkeleton()
        }
    }
    
    private func removeSpriteKitPoseSkeleton() {
        spriteKitPoseView?.removeFromSuperview()
        objc_setAssociatedObject(self, &AssociatedKeys.poseSpriteKitIntegration, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
    
    // MARK: - YOLO Result Integration for Pose
    
    /// Update skeleton with YOLO pose estimation results (only for Pose models)
    func updateSpriteKitPoseSkeleton(with result: YOLOResult) {
        // Only process if we're in Pose mode and skeleton is enabled
        guard currentTask.lowercased() == "pose",
              poseSkeletonSettings.isEnabled,
              let integration = poseSpriteKitIntegration else { return }
        
        // Only process pose estimation results
        guard !result.keypointsList.isEmpty else {
            integration.clearSkeletons()
            return
        }
        
        // Update skeleton visualization
        integration.updateSkeleton(with: result)
    }
    
    // MARK: - Camera Integration for Pose
    
    /// Update camera bounds for coordinate system matching (Pose models only)
    func updateSpriteKitPoseCameraBounds(_ bounds: CGRect) {
        guard currentTask.lowercased() == "pose" else { return }
        poseSpriteKitIntegration?.updateCameraBounds(bounds)
    }
    
    // MARK: - Task Change Handling
    
    /// Handle task changes to show/hide skeleton UI
    func handlePoseTaskChange() {
        if currentTask.lowercased() == "pose" {
            // Show skeleton toggle button for Pose models
            poseSkeletonToggleButton?.isHidden = false
            if poseSkeletonSettings.isEnabled {
                setupSpriteKitPoseSkeleton()
            }
        } else {
            // Hide skeleton UI for non-Pose models
            poseSkeletonToggleButton?.isHidden = true
            removeSpriteKitPoseSkeleton()
        }
    }
}

// MARK: - Associated Keys

private struct AssociatedKeys {
    static var poseSpriteKitIntegration = "poseSpriteKitIntegration"
    static var poseSkeletonSettings = "poseSkeletonSettings"
}

// MARK: - Pose Skeleton Settings

public struct PoseSkeletonSettings {
    public var isEnabled: Bool
    public var jointRadius: CGFloat
    public var boneWidth: CGFloat
    public var confidenceThreshold: Float
    public var enableAntiCrossing: Bool
    public var enableAnimations: Bool
    public var jointColor: UIColor
    public var boneColor: UIColor
    
    public static let `default` = PoseSkeletonSettings(
        isEnabled: false, // Default to disabled
        jointRadius: 8.0,
        boneWidth: 4.0,
        confidenceThreshold: 0.5,
        enableAntiCrossing: true,
        enableAnimations: true,
        jointColor: .systemBlue,
        boneColor: .systemGreen
    )
}

// MARK: - ViewController Integration Override

extension ViewController {
    
    /// Override the existing yoloView didReceiveResult method to include skeleton updates for Pose models
    override func yoloView(_ view: YOLOView, didReceiveResult result: YOLOResult) {
        // Call the original method first
        super.yoloView(view, didReceiveResult: result)
        
        // Update SpriteKit skeleton for Pose models
        updateSpriteKitPoseSkeleton(with: result)
    }
    
    /// Override viewDidLayoutSubviews to update skeleton scene size for Pose models
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // Update skeleton scene size for Pose models
        if currentTask.lowercased() == "pose",
           let scene = poseSkeletonScene {
            scene.size = view.bounds.size
            updateSpriteKitPoseCameraBounds(view.bounds)
        }
    }
    
    /// Override the indexChanged method to handle Pose task changes
    override func indexChanged(_ sender: UISegmentedControl) {
        // Call the original method first
        super.indexChanged(sender)
        
        // Handle Pose task changes
        handlePoseTaskChange()
    }
}
