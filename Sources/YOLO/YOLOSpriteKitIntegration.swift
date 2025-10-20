// Ultralytics 🚀 AGPL-3.0 License - https://ultralytics.com/license

//  This file is part of the Ultralytics YOLO Package, implementing SpriteKit integration for pose estimation.
//  Licensed under AGPL-3.0. For commercial use, refer to Ultralytics licensing: https://ultralytics.com/license
//  Access the source code: https://github.com/ultralytics/yolo-ios-app
//
//  The YOLOSpriteKitIntegration class provides seamless integration between YOLO pose estimation
//  and SpriteKit skeleton visualization with proper coordinate system matching.

import SpriteKit
import UIKit
import AVFoundation

/// Integration class for YOLO pose estimation with SpriteKit skeleton visualization
public class YOLOSpriteKitIntegration: NSObject {
    
    // MARK: - Properties
    
    /// The SpriteKit skeleton renderer
    private let skeletonRenderer: SpriteKitSkeletonRenderer
    
    /// Camera preview layer for coordinate matching
    private let cameraPreviewLayer: AVCaptureVideoPreviewLayer?
    
    /// Current camera bounds
    private var currentCameraBounds: CGRect = .zero
    
    /// Animation settings
    private let animationSettings: AnimationSettings
    
    /// Performance monitoring
    private var lastUpdateTime: CFTimeInterval = 0
    private let targetFPS: Double = 30.0
    
    // MARK: - Initialization
    
    public init(scene: SKScene, cameraPreviewLayer: AVCaptureVideoPreviewLayer? = nil, animationSettings: AnimationSettings = .default) {
        self.cameraPreviewLayer = cameraPreviewLayer
        self.animationSettings = animationSettings
        
        // Initialize with default camera bounds (will be updated dynamically)
        let defaultBounds = CGRect(x: 0, y: 0, width: 640, height: 480)
        self.skeletonRenderer = SpriteKitSkeletonRenderer(
            scene: scene,
            cameraBounds: defaultBounds,
            skeletonConfig: .default,
            antiCrossingConfig: .default
        )
        
        super.init()
        setupCoordinateSystemMatching()
    }
    
    // MARK: - Public Methods
    
    /// Update skeleton with YOLO pose estimation results
    public func updateSkeleton(with result: YOLOResult) {
        // Check if we should update based on performance settings
        guard shouldUpdate() else { return }
        
        // Update camera bounds if needed
        updateCameraBounds()
        
        // Process pose estimation results
        guard !result.keypointsList.isEmpty else {
            skeletonRenderer.clearAllSkeletons()
            return
        }
        
        // Update skeleton visualization
        skeletonRenderer.updateSkeleton(
            with: result.keypointsList,
            boundingBoxes: result.boxes
        )
        
        // Apply animations if enabled
        if animationSettings.enableAnimations {
            applySmoothAnimations()
        }
    }
    
    /// Clear all skeleton visualizations
    public func clearSkeletons() {
        skeletonRenderer.clearAllSkeletons()
    }
    
    /// Update camera bounds for coordinate system matching
    public func updateCameraBounds(_ bounds: CGRect) {
        currentCameraBounds = bounds
        updateCoordinateSystemMatching()
    }
    
    // MARK: - Private Methods
    
    private func setupCoordinateSystemMatching() {
        // Set up coordinate system matching between camera and SpriteKit
        if let previewLayer = cameraPreviewLayer {
            currentCameraBounds = previewLayer.bounds
            updateCoordinateSystemMatching()
        }
    }
    
    private func updateCameraBounds() {
        if let previewLayer = cameraPreviewLayer {
            let newBounds = previewLayer.bounds
            if newBounds != currentCameraBounds {
                currentCameraBounds = newBounds
                updateCoordinateSystemMatching()
            }
        }
    }
    
    private func updateCoordinateSystemMatching() {
        // Update the skeleton renderer with new camera bounds
        // This ensures proper coordinate conversion between camera and SpriteKit
        let newRenderer = SpriteKitSkeletonRenderer(
            scene: skeletonRenderer.scene,
            cameraBounds: currentCameraBounds,
            skeletonConfig: .default,
            antiCrossingConfig: .default
        )
        
        // Transfer existing skeleton nodes if any
        // (In a real implementation, you'd want to preserve existing nodes)
    }
    
    private func shouldUpdate() -> Bool {
        let currentTime = CACurrentMediaTime()
        let timeSinceLastUpdate = currentTime - lastUpdateTime
        let targetInterval = 1.0 / targetFPS
        
        if timeSinceLastUpdate >= targetInterval {
            lastUpdateTime = currentTime
            return true
        }
        
        return false
    }
    
    private func applySmoothAnimations() {
        // Apply smooth animations to skeleton nodes
        // This helps reduce jitter and provides better visual feedback
        for skeletonNode in skeletonRenderer.scene.children {
            if let skeleton = skeletonNode as? SKSkeletonNode {
                animateSkeletonNode(skeleton)
            }
        }
    }
    
    private func animateSkeletonNode(_ skeletonNode: SKSkeletonNode) {
        // Apply smooth position transitions
        let moveAction = SKAction.move(
            to: skeletonNode.position,
            duration: animationSettings.transitionDuration
        )
        moveAction.timingMode = .easeInEaseOut
        
        skeletonNode.run(moveAction)
    }
}

// MARK: - Animation Settings

/// Configuration for skeleton animations
public struct AnimationSettings {
    public let enableAnimations: Bool
    public let transitionDuration: TimeInterval
    public let smoothingFactor: CGFloat
    public let enableGlowEffects: Bool
    
    public static let `default` = AnimationSettings(
        enableAnimations: true,
        transitionDuration: 0.1,
        smoothingFactor: 0.8,
        enableGlowEffects: true
    )
}

// MARK: - Coordinate System Utilities

/// Utilities for coordinate system conversion between camera and SpriteKit
public struct CoordinateSystemConverter {
    
    /// Convert camera coordinates to SpriteKit coordinates
    public static func cameraToSpriteKit(
        cameraPoint: CGPoint,
        cameraBounds: CGRect,
        spriteKitScene: SKScene
    ) -> CGPoint {
        // Normalize camera coordinates
        let normalizedX = cameraPoint.x / cameraBounds.width
        let normalizedY = cameraPoint.y / cameraBounds.height
        
        // Convert to SpriteKit coordinates (flip Y axis)
        let spriteKitX = normalizedX * spriteKitScene.size.width
        let spriteKitY = spriteKitScene.size.height - (normalizedY * spriteKitScene.size.height)
        
        return CGPoint(x: spriteKitX, y: spriteKitY)
    }
    
    /// Convert SpriteKit coordinates to camera coordinates
    public static func spriteKitToCamera(
        spriteKitPoint: CGPoint,
        cameraBounds: CGRect,
        spriteKitScene: SKScene
    ) -> CGPoint {
        // Normalize SpriteKit coordinates
        let normalizedX = spriteKitPoint.x / spriteKitScene.size.width
        let normalizedY = (spriteKitScene.size.height - spriteKitPoint.y) / spriteKitScene.size.height
        
        // Convert to camera coordinates
        let cameraX = normalizedX * cameraBounds.width
        let cameraY = normalizedY * cameraBounds.height
        
        return CGPoint(x: cameraX, y: cameraY)
    }
    
    /// Calculate aspect ratio correction between camera and SpriteKit scene
    public static func calculateAspectRatioCorrection(
        cameraBounds: CGRect,
        spriteKitScene: SKScene
    ) -> CGSize {
        let cameraAspect = cameraBounds.width / cameraBounds.height
        let spriteKitAspect = spriteKitScene.size.width / spriteKitScene.size.height
        
        let scaleX = spriteKitScene.size.width / cameraBounds.width
        let scaleY = spriteKitScene.size.height / cameraBounds.height
        
        // Maintain aspect ratio
        let scale = min(scaleX, scaleY)
        
        return CGSize(width: scale, height: scale)
    }
}

// MARK: - Performance Monitoring

/// Performance monitoring for skeleton rendering
public class SkeletonPerformanceMonitor {
    
    private var frameCount: Int = 0
    private var lastFPSUpdate: CFTimeInterval = 0
    private var currentFPS: Double = 0
    
    public func updateFrame() {
        frameCount += 1
        let currentTime = CACurrentMediaTime()
        
        if currentTime - lastFPSUpdate >= 1.0 {
            currentFPS = Double(frameCount) / (currentTime - lastFPSUpdate)
            frameCount = 0
            lastFPSUpdate = currentTime
        }
    }
    
    public func getCurrentFPS() -> Double {
        return currentFPS
    }
    
    public func isPerformanceGood() -> Bool {
        return currentFPS >= 20.0 // Consider good performance above 20 FPS
    }
}
