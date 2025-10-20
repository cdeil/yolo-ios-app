# SpriteKit Skeleton Visualization for YOLO Pose Estimation

This document explains how to use the SpriteKit-based skeleton visualization system for YOLO pose estimation, including coordinate conversion, anti-crossing logic, and smooth animations.

## Overview

The SpriteKit skeleton system provides real-time visualization of human pose estimation results using SpriteKit nodes and joints. It includes:

- **Coordinate System Matching**: Proper conversion between camera coordinates and SpriteKit scene coordinates
- **Anti-Crossing Logic**: Prevents impossible joint configurations and smooths out jittery movements
- **Smooth Animations**: Provides fluid skeleton movements with configurable animation settings
- **Performance Optimization**: Efficient rendering with FPS monitoring and adaptive updates

## Key Components

### 1. SpriteKitSkeletonRenderer

The core renderer that handles skeleton visualization:

```swift
let skeletonRenderer = SpriteKitSkeletonRenderer(
    scene: spriteKitScene,
    cameraBounds: cameraBounds,
    skeletonConfig: .default,
    antiCrossingConfig: .default
)
```

**Features:**
- Converts pose keypoints to SpriteKit coordinates
- Applies anti-crossing logic to prevent impossible joint configurations
- Manages skeleton nodes (joints and bones)
- Handles multiple people simultaneously

### 2. YOLOSpriteKitIntegration

Integration layer between YOLO pose estimation and SpriteKit:

```swift
let integration = YOLOSpriteKitIntegration(
    scene: spriteKitScene,
    cameraPreviewLayer: cameraPreviewLayer,
    animationSettings: .default
)
```

**Features:**
- Seamless integration with YOLO results
- Coordinate system matching between camera and SpriteKit
- Performance monitoring and adaptive updates
- Smooth animation transitions

### 3. Skeleton Configuration

Customizable settings for skeleton visualization:

```swift
let skeletonConfig = SkeletonConfiguration(
    jointRadius: 8.0,
    boneWidth: 4.0,
    jointColor: .systemBlue,
    boneColor: .systemGreen,
    confidenceThreshold: 0.5,
    animationDuration: 0.1
)
```

## Usage Examples

### Basic Integration

```swift
class ViewController: UIViewController {
    private var yoloSpriteKitIntegration: YOLOSpriteKitIntegration!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup SpriteKit scene
        let scene = SKScene(size: spriteKitView.bounds.size)
        spriteKitView.presentScene(scene)
        
        // Setup YOLO integration
        yoloSpriteKitIntegration = YOLOSpriteKitIntegration(
            scene: scene,
            cameraPreviewLayer: cameraPreviewLayer,
            animationSettings: .default
        )
    }
    
    func onYOLOResult(_ result: YOLOResult) {
        // Update skeleton with pose estimation results
        yoloSpriteKitIntegration.updateSkeleton(with: result)
    }
}
```

### Advanced Configuration

```swift
// Custom skeleton configuration
let skeletonConfig = SkeletonConfiguration(
    jointRadius: 12.0,
    boneWidth: 6.0,
    jointColor: .systemRed,
    boneColor: .systemYellow,
    confidenceThreshold: 0.7,
    animationDuration: 0.2
)

// Custom anti-crossing configuration
let antiCrossingConfig = AntiCrossingConfiguration(
    minimumJointDistance: 15.0,
    smoothingFactor: 0.5,
    constraintStrength: 0.8,
    enableAngleConstraints: true
)

// Custom animation settings
let animationSettings = AnimationSettings(
    enableAnimations: true,
    transitionDuration: 0.15,
    smoothingFactor: 0.9,
    enableGlowEffects: true
)
```

## Coordinate System Conversion

The system automatically handles coordinate conversion between different coordinate systems:

### Camera to SpriteKit Conversion

```swift
let spriteKitPoint = CoordinateSystemConverter.cameraToSpriteKit(
    cameraPoint: cameraPoint,
    cameraBounds: cameraBounds,
    spriteKitScene: spriteKitScene
)
```

### Aspect Ratio Correction

```swift
let correction = CoordinateSystemConverter.calculateAspectRatioCorrection(
    cameraBounds: cameraBounds,
    spriteKitScene: spriteKitScene
)
```

## Anti-Crossing Logic

The anti-crossing system prevents impossible joint configurations:

### Features:
- **Distance Constraints**: Ensures joints maintain realistic distances
- **Angle Constraints**: Prevents impossible joint angles (e.g., elbow bending backwards)
- **Smoothing**: Reduces jittery movements with smoothing algorithms
- **Constraint Strength**: Configurable strength for constraint enforcement

### Example Configuration:

```swift
let antiCrossingConfig = AntiCrossingConfiguration(
    minimumJointDistance: 10.0,    // Minimum distance between joints
    smoothingFactor: 0.3,          // Smoothing strength (0.0-1.0)
    constraintStrength: 0.5,       // Constraint enforcement strength
    enableAngleConstraints: true   // Enable angle-based constraints
)
```

## Performance Optimization

### FPS Monitoring

```swift
let performanceMonitor = SkeletonPerformanceMonitor()

// Update frame
performanceMonitor.updateFrame()

// Check performance
let fps = performanceMonitor.getCurrentFPS()
let isGoodPerformance = performanceMonitor.isPerformanceGood()
```

### Adaptive Updates

The system automatically adjusts update frequency based on performance:

```swift
// Target FPS for skeleton updates
let targetFPS: Double = 30.0

// Adaptive update logic
private func shouldUpdate() -> Bool {
    let currentTime = CACurrentMediaTime()
    let timeSinceLastUpdate = currentTime - lastUpdateTime
    let targetInterval = 1.0 / targetFPS
    
    return timeSinceLastUpdate >= targetInterval
}
```

## Skeleton Structure

The system supports the standard COCO pose keypoint format (17 keypoints):

```
0: nose
1: left_eye
2: right_eye
3: left_ear
4: right_ear
5: left_shoulder
6: right_shoulder
7: left_elbow
8: right_elbow
9: left_wrist
10: right_wrist
11: left_hip
12: right_hip
13: left_knee
14: right_knee
15: left_ankle
16: right_ankle
```

### Bone Connections

The system automatically creates bone connections between joints:

```swift
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
```

## Integration with Existing YOLO System

### ViewController Extension

The system includes a ViewController extension for easy integration:

```swift
extension ViewController {
    // Setup skeleton visualization
    func setupSpriteKitSkeleton() {
        // Implementation details...
    }
    
    // Update skeleton with YOLO results
    func updateSpriteKitSkeleton(with result: YOLOResult) {
        // Implementation details...
    }
}
```

### Usage in Existing Code

```swift
class ViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup SpriteKit skeleton
        setupSpriteKitSkeleton()
    }
    
    override func onResults(result: YOLOResult) {
        // Call original method
        super.onResults(result: result)
        
        // Update skeleton
        updateSpriteKitSkeleton(with: result)
    }
}
```

## Demo Implementation

A complete demo is available in `SpriteKitSkeletonDemoViewController`:

```swift
let demoVC = SpriteKitSkeletonDemoViewController()
present(demoVC, animated: true)
```

The demo includes:
- Real-time skeleton visualization
- Performance monitoring
- Settings configuration
- Anti-crossing demonstration

## Best Practices

1. **Performance**: Monitor FPS and adjust settings accordingly
2. **Coordinate Systems**: Ensure proper camera bounds updates
3. **Anti-Crossing**: Tune parameters based on your use case
4. **Animations**: Use smooth transitions for better user experience
5. **Memory**: Clear skeleton nodes when not needed

## Troubleshooting

### Common Issues:

1. **Skeleton not appearing**: Check coordinate system matching
2. **Jittery movements**: Adjust anti-crossing smoothing factor
3. **Performance issues**: Reduce update frequency or simplify skeleton
4. **Coordinate mismatch**: Verify camera bounds are correctly set

### Debug Tools:

```swift
// Enable debug information
spriteKitView.showsFPS = true
spriteKitView.showsNodeCount = true

// Check performance
let fps = performanceMonitor.getCurrentFPS()
print("Current FPS: \(fps)")
```

## License

This implementation is part of the Ultralytics YOLO Package and is licensed under AGPL-3.0. For commercial use, refer to Ultralytics licensing: https://ultralytics.com/license
