// Ultralytics 🚀 AGPL-3.0 License - https://ultralytics.com/license

//  This file is part of the Ultralytics YOLO Package, extending ViewController with SpriteKit skeleton support.
//  Licensed under AGPL-3.0. For commercial use, refer to Ultralytics licensing: https://ultralytics.com/license
//  Access the source code: https://github.com/ultralytics/yolo-ios-app
//
//  This extension adds SpriteKit-based skeleton visualization capabilities to the main ViewController,
//  providing real-time skeleton tracking with anti-crossing logic and smooth animations.

import UIKit
import SpriteKit
import YOLO

// MARK: - ViewController SpriteKit Skeleton Extension

extension ViewController {
    
    // MARK: - SpriteKit Skeleton Properties
    
    /// SpriteKit view for skeleton visualization
    private var spriteKitSkeletonView: SKView? {
        return view.subviews.first { $0 is SKView } as? SKView
    }
    
    /// SpriteKit scene for skeleton rendering
    private var skeletonScene: SKScene? {
        return spriteKitSkeletonView?.scene
    }
    
    /// YOLO SpriteKit integration
    private var yoloSpriteKitIntegration: YOLOSpriteKitIntegration? {
        return objc_getAssociatedObject(self, &AssociatedKeys.yoloSpriteKitIntegration) as? YOLOSpriteKitIntegration
    }
    
    /// Skeleton settings
    private var skeletonSettings: SkeletonSettings {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.skeletonSettings) as? SkeletonSettings ?? .default
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.skeletonSettings, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    /// Skeleton toggle button
    private var skeletonToggleButton: UIButton? {
        return view.subviews.first { $0.tag == 999 } as? UIButton
    }
    
    // MARK: - SpriteKit Skeleton Setup
    
    /// Setup SpriteKit skeleton visualization
    func setupSpriteKitSkeleton() {
        guard skeletonSettings.isEnabled else { return }
        
        // Create SpriteKit view
        let spriteKitView = createSpriteKitView()
        view.addSubview(spriteKitView)
        
        // Create SpriteKit scene
        let scene = createSkeletonScene()
        spriteKitView.presentScene(scene)
        
        // Setup YOLO integration
        setupYOLOSpriteKitIntegration(scene: scene)
        
        // Add skeleton toggle button
        addSkeletonToggleButton()
    }
    
    private func createSpriteKitView() -> SKView {
        let spriteKitView = SKView()
        spriteKitView.translatesAutoresizingMaskIntoConstraints = false
        spriteKitView.showsFPS = false
        spriteKitView.showsNodeCount = false
        spriteKitView.ignoresSiblingOrder = true
        
        // Position behind camera preview
        NSLayoutConstraint.activate([
            spriteKitView.topAnchor.constraint(equalTo: view.topAnchor),
            spriteKitView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            spriteKitView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            spriteKitView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        return spriteKitView
    }
    
    private func createSkeletonScene() -> SKScene {
        let scene = SKScene(size: view.bounds.size)
        scene.backgroundColor = .clear
        scene.scaleMode = .aspectFill
        return scene
    }
    
    private func setupYOLOSpriteKitIntegration(scene: SKScene) {
        let integration = YOLOSpriteKitIntegration(
            scene: scene,
            cameraPreviewLayer: nil, // Will be set when camera is available
            animationSettings: .default
        )
        
        objc_setAssociatedObject(self, &AssociatedKeys.yoloSpriteKitIntegration, integration, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
    
    private func addSkeletonToggleButton() {
        let button = UIButton(type: .system)
        button.tag = 999
        button.setTitle("Skeleton: ON", for: .normal)
        button.backgroundColor = .systemBlue.withAlphaComponent(0.8)
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        
        button.addTarget(self, action: #selector(skeletonToggleTapped), for: .touchUpInside)
        
        view.addSubview(button)
        
        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            button.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            button.widthAnchor.constraint(equalToConstant: 120),
            button.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    // MARK: - SpriteKit Skeleton Actions
    
    @objc private func skeletonToggleTapped() {
        skeletonSettings.isEnabled.toggle()
        
        if skeletonSettings.isEnabled {
            skeletonToggleButton?.setTitle("Skeleton: ON", for: .normal)
            skeletonToggleButton?.backgroundColor = .systemBlue.withAlphaComponent(0.8)
            setupSpriteKitSkeleton()
        } else {
            skeletonToggleButton?.setTitle("Skeleton: OFF", for: .normal)
            skeletonToggleButton?.backgroundColor = .systemGray.withAlphaComponent(0.8)
            removeSpriteKitSkeleton()
        }
    }
    
    private func removeSpriteKitSkeleton() {
        spriteKitSkeletonView?.removeFromSuperview()
        objc_setAssociatedObject(self, &AssociatedKeys.yoloSpriteKitIntegration, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
    
    // MARK: - YOLO Result Integration
    
    /// Update skeleton with YOLO pose estimation results
    func updateSpriteKitSkeleton(with result: YOLOResult) {
        guard skeletonSettings.isEnabled,
              let integration = yoloSpriteKitIntegration else { return }
        
        // Only process pose estimation results
        guard !result.keypointsList.isEmpty else {
            integration.clearSkeletons()
            return
        }
        
        // Update skeleton visualization
        integration.updateSkeleton(with: result)
    }
    
    // MARK: - Camera Integration
    
    /// Update camera bounds for coordinate system matching
    func updateSpriteKitCameraBounds(_ bounds: CGRect) {
        yoloSpriteKitIntegration?.updateCameraBounds(bounds)
    }
}

// MARK: - Associated Keys

private struct AssociatedKeys {
    static var yoloSpriteKitIntegration = "yoloSpriteKitIntegration"
    static var skeletonSettings = "skeletonSettings"
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

// MARK: - ViewController Integration

extension ViewController {
    
    /// Override the existing onResults method to include skeleton updates
    override func onResults(result: YOLOResult) {
        // Call the original onResults method
        super.onResults(result: result)
        
        // Update SpriteKit skeleton if enabled
        updateSpriteKitSkeleton(with: result)
    }
    
    /// Override viewDidLayoutSubviews to update skeleton scene size
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // Update skeleton scene size
        if let scene = skeletonScene {
            scene.size = view.bounds.size
            updateSpriteKitCameraBounds(view.bounds)
        }
    }
}
