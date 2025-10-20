// Ultralytics 🚀 AGPL-3.0 License - https://ultralytics.com/license

//  This file is part of the Ultralytics YOLO Package, providing a simplified SpriteKit skeleton system.
//  Licensed under AGPL-3.0. For commercial use, refer to Ultralytics licensing: https://ultralytics.com/license
//  Access the source code: https://github.com/ultralytics/yolo-ios-app
//
//  This simplified implementation provides basic SpriteKit skeleton visualization
//  without the full complexity of the complete system.

import SpriteKit
import UIKit
import YOLO

/// Simplified SpriteKit skeleton integration for YOLO pose estimation
public class YOLOSpriteKitIntegration {
    
    // MARK: - Properties
    
    private let scene: SKScene
    private var skeletonNodes: [String: SKSkeletonNode] = [:]
    
    // MARK: - Initialization
    
    public init(scene: SKScene, cameraPreviewLayer: AVCaptureVideoPreviewLayer? = nil, animationSettings: AnimationSettings = .default) {
        self.scene = scene
        setupScene()
    }
    
    private func setupScene() {
        scene.backgroundColor = .clear
        scene.scaleMode = .aspectFill
    }
    
    // MARK: - Public Methods
    
    public func updateSkeleton(with result: YOLOResult) {
        // Clear existing skeletons
        clearSkeletons()
        
        // Process each detected person
        for (index, keypoints) in result.keypointsList.enumerated() {
            guard index < result.boxes.count else { continue }
            let boundingBox = result.boxes[index]
            
            // Create skeleton for this person
            let skeletonId = "person_\(index)"
            createSkeletonForPerson(id: skeletonId, keypoints: keypoints, boundingBox: boundingBox)
        }
    }
    
    public func clearSkeletons() {
        skeletonNodes.values.forEach { $0.removeFromParent() }
        skeletonNodes.removeAll()
    }
    
    public func updateCameraBounds(_ bounds: CGRect) {
        // Update scene size based on camera bounds
        scene.size = bounds.size
    }
    
    // MARK: - Private Methods
    
    private func createSkeletonForPerson(id: String, keypoints: Keypoints, boundingBox: Box) {
        // Create skeleton node
        let skeletonNode = SKSkeletonNode()
        skeletonNodes[id] = skeletonNode
        scene.addChild(skeletonNode)
        
        // Convert keypoints to SpriteKit coordinates
        let spriteKitPoints = convertKeypointsToSpriteKit(keypoints)
        
        // Create joints and bones
        createJointsAndBones(skeletonNode: skeletonNode, keypoints: spriteKitPoints, confidences: keypoints.conf)
    }
    
    private func convertKeypointsToSpriteKit(_ keypoints: Keypoints) -> [CGPoint] {
        return keypoints.xy.map { point in
            // Convert from image coordinates to SpriteKit scene coordinates
            let normalizedX = point.x / Float(scene.size.width)
            let normalizedY = point.y / Float(scene.size.height)
            
            // Convert to SpriteKit coordinates (flip Y axis)
            let spriteKitX = CGFloat(normalizedX) * scene.size.width
            let spriteKitY = scene.size.height - (CGFloat(normalizedY) * scene.size.height)
            
            return CGPoint(x: spriteKitX, y: spriteKitY)
        }
    }
    
    private func createJointsAndBones(skeletonNode: SKSkeletonNode, keypoints: [CGPoint], confidences: [Float]) {
        // Create joint nodes
        for (index, point) in keypoints.enumerated() {
            guard index < confidences.count,
                  confidences[index] >= 0.5 else { continue }
            
            let jointNode = createJointNode(at: point)
            skeletonNode.addChild(jointNode)
        }
        
        // Create bone connections
        createBoneConnections(skeletonNode: skeletonNode, keypoints: keypoints, confidences: confidences)
    }
    
    private func createJointNode(at point: CGPoint) -> SKShapeNode {
        let jointNode = SKShapeNode(circleOfRadius: 8.0)
        jointNode.fillColor = .systemBlue
        jointNode.strokeColor = .white
        jointNode.lineWidth = 2.0
        jointNode.position = point
        
        // Add glow effect
        let glowNode = SKShapeNode(circleOfRadius: 12.0)
        glowNode.fillColor = .systemBlue.withAlphaComponent(0.3)
        glowNode.strokeColor = .clear
        glowNode.position = point
        glowNode.zPosition = -1
        
        let jointGroup = SKNode()
        jointGroup.addChild(glowNode)
        jointGroup.addChild(jointNode)
        
        return jointNode
    }
    
    private func createBoneConnections(skeletonNode: SKSkeletonNode, keypoints: [CGPoint], confidences: [Float]) {
        // Define bone connections (COCO pose skeleton)
        let boneConnections = [
            (0, 1),   // nose to left_eye
            (0, 2),   // nose to right_eye
            (1, 3),   // left_eye to left_ear
            (2, 4),   // right_eye to right_ear
            (5, 6),   // left_shoulder to right_shoulder
            (5, 7),   // left_shoulder to left_elbow
            (6, 8),   // right_shoulder to right_elbow
            (7, 9),   // left_elbow to left_wrist
            (8, 10),  // right_elbow to right_wrist
            (11, 12), // left_hip to right_hip
            (5, 11),  // left_shoulder to left_hip
            (6, 12),  // right_shoulder to right_hip
            (11, 13), // left_hip to left_knee
            (12, 14), // right_hip to right_knee
            (13, 15), // left_knee to left_ankle
            (14, 16)  // right_knee to right_ankle
        ]
        
        for (joint1, joint2) in boneConnections {
            guard joint1 < keypoints.count,
                  joint2 < keypoints.count,
                  joint1 < confidences.count,
                  joint2 < confidences.count,
                  confidences[joint1] >= 0.5,
                  confidences[joint2] >= 0.5 else { continue }
            
            let point1 = keypoints[joint1]
            let point2 = keypoints[joint2]
            
            let boneNode = createBoneNode(from: point1, to: point2)
            skeletonNode.addChild(boneNode)
        }
    }
    
    private func createBoneNode(from point1: CGPoint, to point2: CGPoint) -> SKShapeNode {
        let path = CGMutablePath()
        path.move(to: point1)
        path.addLine(to: point2)
        
        let boneNode = SKShapeNode(path: path)
        boneNode.strokeColor = .systemGreen
        boneNode.lineWidth = 4.0
        boneNode.lineCap = .round
        
        return boneNode
    }
}

// MARK: - Supporting Classes

/// Simple skeleton node for SpriteKit
public class SKSkeletonNode: SKNode {
    
    public func updateSkeleton(with processedKeypoints: ProcessedKeypoints, boundingBox: Box, config: SkeletonConfiguration) {
        // Clear existing nodes
        removeAllChildren()
        
        // Create joint nodes
        for (index, point) in processedKeypoints.points.enumerated() {
            guard index < processedKeypoints.confidences.count,
                  processedKeypoints.confidences[index] >= config.confidenceThreshold else { continue }
            
            let jointNode = createJointNode(at: point, config: config)
            addChild(jointNode)
        }
        
        // Create bone connections
        createBoneConnections(processedKeypoints: processedKeypoints, config: config)
    }
    
    private func createJointNode(at point: CGPoint, config: SkeletonConfiguration) -> SKShapeNode {
        let jointNode = SKShapeNode(circleOfRadius: config.jointRadius)
        jointNode.fillColor = config.jointColor
        jointNode.strokeColor = .white
        jointNode.lineWidth = 2.0
        jointNode.position = point
        
        // Add glow effect
        let glowNode = SKShapeNode(circleOfRadius: config.jointRadius * 1.5)
        glowNode.fillColor = config.jointColor.withAlphaComponent(0.3)
        glowNode.strokeColor = .clear
        glowNode.position = point
        glowNode.zPosition = -1
        
        let jointGroup = SKNode()
        jointGroup.addChild(glowNode)
        jointGroup.addChild(jointNode)
        
        return jointNode
    }
    
    private func createBoneConnections(processedKeypoints: ProcessedKeypoints, config: SkeletonConfiguration) {
        // Define bone connections (COCO pose skeleton)
        let boneConnections = [
            (0, 1), (0, 2), (1, 3), (2, 4), (5, 6), (5, 7), (6, 8), (7, 9),
            (8, 10), (11, 12), (5, 11), (6, 12), (11, 13), (12, 14), (13, 15), (14, 16)
        ]
        
        for (joint1, joint2) in boneConnections {
            guard joint1 < processedKeypoints.points.count,
                  joint2 < processedKeypoints.points.count,
                  joint1 < processedKeypoints.confidences.count,
                  joint2 < processedKeypoints.confidences.count,
                  processedKeypoints.confidences[joint1] >= config.confidenceThreshold,
                  processedKeypoints.confidences[joint2] >= config.confidenceThreshold else { continue }
            
            let point1 = processedKeypoints.points[joint1]
            let point2 = processedKeypoints.points[joint2]
            
            let boneNode = createBoneNode(from: point1, to: point2, config: config)
            addChild(boneNode)
        }
    }
    
    private func createBoneNode(from point1: CGPoint, to point2: CGPoint, config: SkeletonConfiguration) -> SKShapeNode {
        let path = CGMutablePath()
        path.move(to: point1)
        path.addLine(to: point2)
        
        let boneNode = SKShapeNode(path: path)
        boneNode.strokeColor = config.boneColor
        boneNode.lineWidth = config.boneWidth
        boneNode.lineCap = .round
        
        return boneNode
    }
}

// MARK: - Supporting Structures

/// Configuration for skeleton rendering
public struct SkeletonConfiguration {
    public let jointRadius: CGFloat
    public let boneWidth: CGFloat
    public let jointColor: UIColor
    public let boneColor: UIColor
    public let confidenceThreshold: Float
    public let animationDuration: TimeInterval
    
    public static let `default` = SkeletonConfiguration(
        jointRadius: 8.0,
        boneWidth: 4.0,
        jointColor: .systemBlue,
        boneColor: .systemGreen,
        confidenceThreshold: 0.5,
        animationDuration: 0.1
    )
}

/// Configuration for anti-crossing logic
public struct AntiCrossingConfiguration {
    public let minimumJointDistance: CGFloat
    public let smoothingFactor: CGFloat
    public let constraintStrength: CGFloat
    public let enableAngleConstraints: Bool
    
    public static let `default` = AntiCrossingConfiguration(
        minimumJointDistance: 10.0,
        smoothingFactor: 0.3,
        constraintStrength: 0.5,
        enableAngleConstraints: true
    )
}

/// Processed keypoints with anti-crossing applied
public struct ProcessedKeypoints {
    public let points: [CGPoint]
    public let confidences: [Float]
}

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
