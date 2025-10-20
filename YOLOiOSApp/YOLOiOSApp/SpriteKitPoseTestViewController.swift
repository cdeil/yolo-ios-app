// Ultralytics 🚀 AGPL-3.0 License - https://ultralytics.com/license

//  This file is part of the Ultralytics YOLO Package, providing a test view controller for SpriteKit pose integration.
//  Licensed under AGPL-3.0. For commercial use, refer to Ultralytics licensing: https://ultralytics.com/license
//  Access the source code: https://github.com/ultralytics/yolo-ios-app
//
//  This test view controller demonstrates how to use the SpriteKit skeleton system
//  with your existing YOLO iOS app for Pose models.

import UIKit
import SpriteKit
import YOLO

/// Test view controller demonstrating SpriteKit skeleton integration for Pose models
class SpriteKitPoseTestViewController: UIViewController {
    
    // MARK: - IBOutlets
    
    @IBOutlet weak var testLabel: UILabel!
    @IBOutlet weak var instructionLabel: UILabel!
    
    // MARK: - Properties
    
    private var testResult: YOLOResult?
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        createTestPoseData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        showInstructions()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // Setup test label
        testLabel.text = "SpriteKit Pose Test"
        testLabel.font = .boldSystemFont(ofSize: 24)
        testLabel.textAlignment = .center
        
        // Setup instruction label
        instructionLabel.text = "This test demonstrates SpriteKit skeleton integration for Pose models"
        instructionLabel.font = .systemFont(ofSize: 16)
        instructionLabel.textAlignment = .center
        instructionLabel.numberOfLines = 0
        
        // Add test button
        let testButton = UIButton(type: .system)
        testButton.setTitle("Run Pose Test", for: .normal)
        testButton.backgroundColor = .systemBlue
        testButton.setTitleColor(.white, for: .normal)
        testButton.layer.cornerRadius = 8
        testButton.addTarget(self, action: #selector(runPoseTest), for: .touchUpInside)
        testButton.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(testButton)
        
        NSLayoutConstraint.activate([
            testButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            testButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            testButton.widthAnchor.constraint(equalToConstant: 200),
            testButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    private func showInstructions() {
        let alert = UIAlertController(
            title: "SpriteKit Pose Test",
            message: """
            This test demonstrates the SpriteKit skeleton system for Pose models.
            
            To test the integration:
            1. Go to your main YOLO app
            2. Select 'Pose' from the task segmented control
            3. Tap the blue 'Skeleton: ON' button
            4. Point camera at a person to see the skeleton!
            
            The system includes:
            • Real-time skeleton visualization
            • Anti-crossing logic for realistic movements
            • Smooth animations and visual effects
            • Performance monitoring
            """,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Got it!", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - Test Methods
    
    @objc private func runPoseTest() {
        // Create test pose data
        createTestPoseData()
        
        // Show test results
        showTestResults()
    }
    
    private func createTestPoseData() {
        // Create sample keypoints for a standing person
        let testKeypoints = createSampleKeypoints()
        
        // Create test bounding box
        let testBox = Box(
            index: 0,
            cls: "person",
            conf: 0.9,
            xywh: CGRect(x: 200, y: 100, width: 200, height: 400),
            xywhn: CGRect(x: 0.3, y: 0.2, width: 0.4, height: 0.8)
        )
        
        // Create test YOLO result
        testResult = YOLOResult(
            orig_shape: CGSize(width: 640, height: 480),
            boxes: [testBox],
            keypointsList: [testKeypoints],
            speed: 0.1,
            names: ["person"]
        )
    }
    
    private func createSampleKeypoints() -> Keypoints {
        // Create sample keypoints for a standing person
        let samplePoints: [(x: Float, y: Float)] = [
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
        
        let confidences = Array(repeating: Float(0.9), count: samplePoints.count)
        
        return Keypoints(
            xyn: samplePoints,
            xy: samplePoints.map { (x: $0.x * 640, y: $0.y * 480) },
            conf: confidences
        )
    }
    
    private func showTestResults() {
        guard let result = testResult else { return }
        
        let alert = UIAlertController(
            title: "Test Results",
            message: """
            ✅ Test pose data created successfully!
            
            Keypoints: \(result.keypointsList.count)
            Bounding boxes: \(result.boxes.count)
            Confidence: \(result.boxes.first?.conf ?? 0.0)
            
            The SpriteKit skeleton system will:
            • Convert these keypoints to SpriteKit coordinates
            • Apply anti-crossing logic for realistic movements
            • Render smooth skeleton visualization
            • Handle coordinate system matching
            """,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - Integration Example

extension SpriteKitPoseTestViewController {
    
    /// Example of how to integrate SpriteKit skeleton with your existing ViewController
    func demonstrateIntegration() {
        /*
         // In your ViewController.swift, add this import:
         import SpriteKit
         
         // The system automatically:
         // 1. Detects when you're in Pose mode
         // 2. Shows skeleton toggle button
         // 3. Handles coordinate conversion
         // 4. Applies anti-crossing logic
         // 5. Renders smooth skeleton animations
         
         // No additional code needed in your ViewController!
         // The extension handles everything automatically.
         */
    }
}
