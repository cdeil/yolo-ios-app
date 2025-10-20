// Ultralytics 🚀 AGPL-3.0 License - https://ultralytics.com/license

//  This file is part of the Ultralytics YOLO Package, implementing SpriteKit-based skeleton visualization.
//  Licensed under AGPL-3.0. For commercial use, refer to Ultralytics licensing: https://ultralytics.com/license
//  Access the source code: https://github.com/ultralytics/yolo-ios-app
//
//  The SpriteKitSkeletonRenderer class provides real-time skeleton visualization using SpriteKit
//  with proper coordinate conversion, anti-crossing logic, and smooth animations for pose estimation.

import SpriteKit
import UIKit
import CoreGraphics

/// SpriteKit-based skeleton renderer for pose estimation visualization
public class SpriteKitSkeletonRenderer: NSObject {
    
    // MARK: - Properties
    
    /// The SpriteKit scene for rendering
    public let scene: SKScene
    
    /// Camera view bounds for coordinate conversion
    private let cameraBounds: CGRect
    
    /// Skeleton configuration
    private let skeletonConfig: SkeletonConfiguration
    
    /// Current skeleton nodes
    private var skeletonNodes: [String: SKSkeletonNode] = [:]
    
    /// Anti-crossing configuration
    private let antiCrossingConfig: AntiCrossingConfiguration
    
    // MARK: - Initialization
    
    public init(scene: SKScene, cameraBounds: CGRect, skeletonConfig: SkeletonConfiguration = .default, antiCrossingConfig: AntiCrossingConfiguration = .default) {
        self.scene = scene
        self.cameraBounds = cameraBounds
        self.skeletonConfig = skeletonConfig
        self.antiCrossingConfig = antiCrossingConfig
        super.init()
        setupScene()
    }
    
    // MARK: - Setup
    
    private func setupScene() {
        scene.backgroundColor = .clear
        scene.scaleMode = .aspectFill
    }
    
    // MARK: - Public Methods
    
    /// Update skeleton with new pose data
    public func updateSkeleton(with keypointsList: [Keypoints], boundingBoxes: [Box]) {
        // Clear existing skeletons
        clearAllSkeletons()
        
        // Process each detected person
        for (index, keypoints) in keypointsList.enumerated() {
            guard index < boundingBoxes.count else { continue }
            let boundingBox = boundingBoxes[index]
            
            // Create or update skeleton for this person
            let skeletonId = "person_\(index)"
            updateSkeletonForPerson(id: skeletonId, keypoints: keypoints, boundingBox: boundingBox)
        }
    }
    
    /// Clear all skeleton visualizations
    public func clearAllSkeletons() {
        skeletonNodes.values.forEach { $0.removeFromParent() }
        skeletonNodes.removeAll()
    }
    
    // MARK: - Private Methods
    
    private func updateSkeletonForPerson(id: String, keypoints: Keypoints, boundingBox: Box) {
        // Get or create skeleton node
        let skeletonNode = getOrCreateSkeletonNode(id: id)
        
        // Convert coordinates and apply anti-crossing
        let processedKeypoints = processKeypointsWithAntiCrossing(keypoints, boundingBox: boundingBox)
        
        // Update skeleton visualization
        skeletonNode.updateSkeleton(with: processedKeypoints, boundingBox: boundingBox, config: skeletonConfig)
    }
    
    private func getOrCreateSkeletonNode(id: String) -> SKSkeletonNode {
        if let existingNode = skeletonNodes[id] {
            return existingNode
        }
        
        let skeletonNode = SKSkeletonNode()
        skeletonNodes[id] = skeletonNode
        scene.addChild(skeletonNode)
        return skeletonNode
    }
    
    private func processKeypointsWithAntiCrossing(_ keypoints: Keypoints, boundingBox: Box) -> ProcessedKeypoints {
        let convertedPoints = convertKeypointsToSpriteKit(keypoints, boundingBox: boundingBox)
        let antiCrossedPoints = applyAntiCrossingLogic(convertedPoints)
        return ProcessedKeypoints(points: antiCrossedPoints, confidences: keypoints.conf)
    }
    
    private func convertKeypointsToSpriteKit(_ keypoints: Keypoints, boundingBox: Box) -> [CGPoint] {
        return keypoints.xy.map { point in
            // Convert from image coordinates to SpriteKit scene coordinates
            let normalizedX = point.x / Float(cameraBounds.width)
            let normalizedY = point.y / Float(cameraBounds.height)
            
            // Convert to SpriteKit coordinates (flip Y axis)
            let spriteKitX = CGFloat(normalizedX) * scene.size.width
            let spriteKitY = scene.size.height - (CGFloat(normalizedY) * scene.size.height)
            
            return CGPoint(x: spriteKitX, y: spriteKitY)
        }
    }
    
    private func applyAntiCrossingLogic(_ points: [CGPoint]) -> [CGPoint] {
        guard points.count >= 17 else { return points } // Standard COCO pose has 17 keypoints
        
        var processedPoints = points
        
        // Apply anti-crossing for specific joint pairs
        let jointPairs = [
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
        
        for (joint1, joint2) in jointPairs {
            if joint1 < processedPoints.count && joint2 < processedPoints.count {
                let point1 = processedPoints[joint1]
                let point2 = processedPoints[joint2]
                
                // Check for crossing and apply correction
                if shouldApplyAntiCrossing(point1: point1, point2: point2, joint1: joint1, joint2: joint2) {
                    let correctedPoints = applyAntiCrossingCorrection(point1: point1, point2: point2, joint1: joint1, joint2: joint2)
                    processedPoints[joint1] = correctedPoints.0
                    processedPoints[joint2] = correctedPoints.1
                }
            }
        }
        
        return processedPoints
    }
    
    private func shouldApplyAntiCrossing(point1: CGPoint, point2: CGPoint, joint1: Int, joint2: Int) -> Bool {
        // Check if points are too close (indicating potential crossing)
        let distance = sqrt(pow(point1.x - point2.x, 2) + pow(point1.y - point2.y, 2))
        let minDistance = antiCrossingConfig.minimumJointDistance
        
        // Check for impossible angles (e.g., elbow bending backwards)
        if isImpossibleAngle(point1: point1, point2: point2, joint1: joint1, joint2: joint2) {
            return true
        }
        
        return distance < minDistance
    }
    
    private func isImpossibleAngle(point1: CGPoint, point2: CGPoint, joint1: Int, joint2: Int) -> Bool {
        // Define impossible angle ranges for specific joint pairs
        let impossibleAngles: [Int: (min: Double, max: Double)] = [
            7: (0, 180),    // left_elbow should not bend backwards
            8: (0, 180),    // right_elbow should not bend backwards
            13: (0, 180),   // left_knee should not bend backwards
            14: (0, 180)    // right_knee should not bend backwards
        ]
        
        guard let angleRange = impossibleAngles[joint1] else { return false }
        
        let angle = calculateAngle(point1: point1, point2: point2)
        return angle < angleRange.min || angle > angleRange.max
    }
    
    private func calculateAngle(point1: CGPoint, point2: CGPoint) -> Double {
        let dx = point2.x - point1.x
        let dy = point2.y - point1.y
        return atan2(Double(dy), Double(dx)) * 180 / .pi
    }
    
    private func applyAntiCrossingCorrection(point1: CGPoint, point2: CGPoint, joint1: Int, joint2: Int) -> (CGPoint, CGPoint) {
        // Apply smoothing and constraint-based correction
        let smoothingFactor = antiCrossingConfig.smoothingFactor
        let constraintStrength = antiCrossingConfig.constraintStrength
        
        // Calculate midpoint
        let midX = (point1.x + point2.x) / 2
        let midY = (point1.y + point2.y) / 2
        
        // Apply smoothing
        let newPoint1 = CGPoint(
            x: point1.x + (midX - point1.x) * smoothingFactor,
            y: point1.y + (midY - point1.y) * smoothingFactor
        )
        
        let newPoint2 = CGPoint(
            x: point2.x + (midX - point2.x) * smoothingFactor,
            y: point2.y + (midY - point2.y) * smoothingFactor
        )
        
        // Apply constraints
        return applyConstraints(point1: newPoint1, point2: newPoint2, joint1: joint1, joint2: joint2, strength: constraintStrength)
    }
    
    private func applyConstraints(point1: CGPoint, point2: CGPoint, joint1: Int, joint2: Int, strength: CGFloat) -> (CGPoint, CGPoint) {
        // Define maximum distances for joint pairs
        let maxDistances: [Int: CGFloat] = [
            5: 100,   // shoulder width
            6: 100,   // shoulder width
            11: 80,   // hip width
            12: 80,   // hip width
            7: 60,    // upper arm length
            8: 60,    // upper arm length
            9: 50,    // forearm length
            10: 50,   // forearm length
            13: 80,   // thigh length
            14: 80,   // thigh length
            15: 60,   // shin length
            16: 60    // shin length
        ]
        
        let maxDistance = maxDistances[joint1] ?? 100
        let distance = sqrt(pow(point1.x - point2.x, 2) + pow(point1.y - point2.y, 2))
        
        if distance > maxDistance {
            let ratio = maxDistance / distance
            let newPoint1 = CGPoint(
                x: point1.x + (point2.x - point1.x) * (1 - ratio) * strength,
                y: point1.y + (point2.y - point1.y) * (1 - ratio) * strength
            )
            let newPoint2 = CGPoint(
                x: point2.x + (point1.x - point2.x) * (1 - ratio) * strength,
                y: point2.y + (point1.y - point2.y) * (1 - ratio) * strength
            )
            return (newPoint1, newPoint2)
        }
        
        return (point1, point2)
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

/// SpriteKit node for skeleton visualization
public class SKSkeletonNode: SKNode {
    
    private var jointNodes: [SKShapeNode] = []
    private var boneNodes: [SKShapeNode] = []
    
    public func updateSkeleton(with processedKeypoints: ProcessedKeypoints, boundingBox: Box, config: SkeletonConfiguration) {
        // Clear existing nodes
        jointNodes.forEach { $0.removeFromParent() }
        boneNodes.forEach { $0.removeFromParent() }
        jointNodes.removeAll()
        boneNodes.removeAll()
        
        // Create joint nodes
        for (index, point) in processedKeypoints.points.enumerated() {
            guard index < processedKeypoints.confidences.count,
                  processedKeypoints.confidences[index] >= config.confidenceThreshold else { continue }
            
            let jointNode = createJointNode(at: point, config: config)
            jointNodes.append(jointNode)
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
            guard joint1 < processedKeypoints.points.count,
                  joint2 < processedKeypoints.points.count,
                  joint1 < processedKeypoints.confidences.count,
                  joint2 < processedKeypoints.confidences.count,
                  processedKeypoints.confidences[joint1] >= config.confidenceThreshold,
                  processedKeypoints.confidences[joint2] >= config.confidenceThreshold else { continue }
            
            let point1 = processedKeypoints.points[joint1]
            let point2 = processedKeypoints.points[joint2]
            
            let boneNode = createBoneNode(from: point1, to: point2, config: config)
            boneNodes.append(boneNode)
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
