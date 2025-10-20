// Ultralytics 🚀 AGPL-3.0 License - https://ultralytics.com/license

//  This file is part of the Ultralytics YOLO app, providing the main user interface for model selection and visualization.
//  Licensed under AGPL-3.0. For commercial use, refer to Ultralytics licensing: https://ultralytics.com/license
//  Access the source code: https://github.com/ultralytics/yolo-ios-app
//
//  The ViewController serves as the primary interface for users to interact with YOLO models.
//  It provides the ability to select different models, tasks (detection, segmentation, classification, etc.),
//  and visualize results in real-time. The controller manages the loading of local and remote models,
//  handles UI updates during model loading and inference, and provides functionality for capturing
//  and sharing detection results. Advanced features include model download progress
//  tracking, and adaptive UI layout for different device orientations.

import AVFoundation
import AudioToolbox
import CoreML
import CoreMedia
import SpriteKit
import UIKit
import YOLO

// MARK: - Extensions
extension Result {
  var isSuccess: Bool { if case .success = self { return true } else { return false } }
}

extension Array {
  subscript(safe index: Int) -> Element? {
    return indices.contains(index) ? self[index] : nil
  }
}

/// The main view controller for the YOLO iOS application, handling model selection and visualization.
class ViewController: UIViewController, YOLOViewDelegate {

  // MARK: - External Display Support (Optional)
  // NOTE: The following orientation overrides are part of the OPTIONAL external display feature.
  // These features remain dormant until an external display is connected.
  // See ExternalDisplay/ directory for implementation details.

  // Override supported orientations based on external display connection
  override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
    // Use SceneDelegate's state to determine orientation support
    if SceneDelegate.hasExternalDisplay {
      return [.landscapeLeft, .landscapeRight]
    } else {
      return [.portrait, .landscapeLeft, .landscapeRight]
    }
  }

  override var shouldAutorotate: Bool {
    return true
  }

  @IBOutlet weak var yoloView: YOLOView!
  @IBOutlet weak var View0: UIView!
  @IBOutlet weak var segmentedControl: UISegmentedControl!
  @IBOutlet weak var modelSegmentedControl: UISegmentedControl!
  @IBOutlet weak var labelName: UILabel!
  @IBOutlet weak var labelFPS: UILabel!
  @IBOutlet weak var labelVersion: UILabel!
  @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
  @IBOutlet weak var logoImage: UIImageView!

  let selection = UISelectionFeedbackGenerator()

  // Store current loading entry for external display notification (Optional feature)
  var currentLoadingEntry: ModelEntry?

  // Custom model selection button (created programmatically)
  var customModelButton: UIButton!

  private let downloadProgressView = UIProgressView(progressViewStyle: .default)
  private let downloadProgressLabel = UILabel()

  private var loadingOverlayView: UIView?

  // MARK: - Constants
  private struct Constants {
    static let defaultTaskIndex = 2  // Detect
    static let tableRowHeight: CGFloat = 30
    static let logoURL = "https://www.ultralytics.com"
    static let progressViewWidth: CGFloat = 200
  }

  // MARK: - Loading State Management
  private func setLoadingState(_ loading: Bool, showOverlay: Bool = false) {
    loading ? activityIndicator.startAnimating() : activityIndicator.stopAnimating()
    view.isUserInteractionEnabled = !loading
    if showOverlay && loading { updateLoadingOverlay(true) }
    if !loading { updateLoadingOverlay(false) }
  }

  private func updateLoadingOverlay(_ show: Bool) {
    if show && loadingOverlayView == nil {
      let overlay = UIView(frame: view.bounds)
      overlay.backgroundColor = UIColor.black.withAlphaComponent(0.5)
      view.addSubview(overlay)
      loadingOverlayView = overlay
      view.bringSubviewToFront(downloadProgressView)
      view.bringSubviewToFront(downloadProgressLabel)
    } else if !show {
      loadingOverlayView?.removeFromSuperview()
      loadingOverlayView = nil
    }
  }

  let tasks: [(name: String, folder: String, yoloTask: YOLOTask)] = [
    ("Classify", "ClassifyModels", .classify),
    ("Segment", "SegmentModels", .segment),
    ("Detect", "DetectModels", .detect),
    ("Pose", "PoseModels", .pose),
    ("OBB", "OBBModels", .obb),
  ]

  private var modelsForTask: [String: [String]] = [:]

  var currentModels: [ModelEntry] = []
  private var standardModels: [ModelSelectionManager.ModelSize: ModelSelectionManager.ModelInfo] =
    [:]

  var currentTask: String = ""
  var currentModelName: String = ""

  private var isLoadingModel = false

  override func viewDidLoad() {
    super.viewDidLoad()

    // Debug: Check model folders
    debugCheckModelFolders()

    // MARK: External Display Setup (Optional)
    // NOTE: The following external display setup is OPTIONAL and not required for core app functionality.
    // This code enhances the app for external monitor/TV connections and remains dormant when not in use.
    // See ExternalDisplay/ directory and README for more information.

    // Setup external display notifications
    setupExternalDisplayNotifications()

    // Check for already connected external displays
    checkForExternalDisplays()

    // If external display is already connected, ensure YOLOView doesn't interfere
    if UIScreen.screens.count > 1 {
      print("External display already connected at startup - deferring camera init")
      yoloView.isHidden = true
    }

    // Setup segmented control and load models
    segmentedControl.removeAllSegments()
    tasks.enumerated().forEach { index, task in
      segmentedControl.insertSegment(withTitle: task.name, at: index, animated: false)
      modelsForTask[task.name] = getModelFiles(in: task.folder)
    }

    setupModelSegmentedControl()
    setupCustomModelButton()

    if tasks.indices.contains(Constants.defaultTaskIndex) {
      segmentedControl.selectedSegmentIndex = Constants.defaultTaskIndex
      currentTask = tasks[Constants.defaultTaskIndex].name

      // Always load models initially - external display handling will stop camera if needed
      reloadModelEntriesAndLoadFirst(for: currentTask)

      // Check for external display after initial setup
      if UIScreen.screens.count > 1 {
        print("External display may be connected at startup - will be handled by notifications")
      }
    }

    // Setup gestures and delegates
    logoImage.isUserInteractionEnabled = true
    logoImage.addGestureRecognizer(
      UITapGestureRecognizer(target: self, action: #selector(logoButton)))
    yoloView.shareButton.addTarget(self, action: #selector(shareButtonTapped), for: .touchUpInside)
    yoloView.delegate = self
    [yoloView.labelName, yoloView.labelFPS].forEach { $0?.isHidden = true }

    // Add target to sliders to monitor changes
    yoloView.sliderConf.addTarget(self, action: #selector(sliderValueChanged), for: .valueChanged)
    yoloView.sliderIoU.addTarget(self, action: #selector(sliderValueChanged), for: .valueChanged)
    yoloView.sliderNumItems.addTarget(
      self, action: #selector(sliderValueChanged), for: .valueChanged)

    // Setup labels and version
    [labelName, labelFPS, labelVersion].forEach {
      $0?.textColor = .white
      $0?.overrideUserInterfaceStyle = .dark
    }
    if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
      let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
    {
      labelVersion.text = "v\(version) (\(build))"
    }

    // Setup progress views
    [downloadProgressView, downloadProgressLabel].forEach {
      $0.isHidden = true
      $0.translatesAutoresizingMaskIntoConstraints = false
      view.addSubview($0)
    }
    downloadProgressLabel.textAlignment = .center
    downloadProgressLabel.textColor = .systemGray
    downloadProgressLabel.font = .systemFont(ofSize: 14)

    NSLayoutConstraint.activate([
      downloadProgressView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      downloadProgressView.topAnchor.constraint(
        equalTo: activityIndicator.bottomAnchor, constant: 8),
      downloadProgressView.widthAnchor.constraint(equalToConstant: Constants.progressViewWidth),
      downloadProgressView.heightAnchor.constraint(equalToConstant: 2),
      downloadProgressLabel.centerXAnchor.constraint(equalTo: downloadProgressView.centerXAnchor),
      downloadProgressLabel.topAnchor.constraint(
        equalTo: downloadProgressView.bottomAnchor, constant: 8),
    ])

    ModelDownloadManager.shared.progressHandler = { [weak self] progress in
      guard let self = self else { return }
      DispatchQueue.main.async {
        self.downloadProgressView.progress = Float(progress)
        self.downloadProgressLabel.isHidden = false
        let percentage = Int(progress * 100)
        self.downloadProgressLabel.text = "Downloading \(percentage)%"
      }
    }
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    view.overrideUserInterfaceStyle = .dark
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
  }

  private func getModelFiles(in folderName: String) -> [String] {
    guard let folderURL = Bundle.main.url(forResource: folderName, withExtension: nil),
      let fileURLs = try? FileManager.default.contentsOfDirectory(
        at: folderURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
      )
    else { return [] }

    let modelFiles =
      fileURLs
      .filter { ["mlmodel", "mlpackage"].contains($0.pathExtension) }
      .map { $0.lastPathComponent }

    return folderName == "DetectModels" ? reorderDetectionModels(modelFiles) : modelFiles.sorted()
  }

  private func reorderDetectionModels(_ fileNames: [String]) -> [String] {
    let order: [Character: Int] = ["n": 0, "m": 1, "s": 2, "l": 3, "x": 4]
    let (official, custom) = fileNames.reduce(into: ([String](), [String]())) { result, name in
      let base = (name as NSString).deletingPathExtension.lowercased()
      base.hasPrefix("yolo") && order[base.last ?? "z"] != nil
        ? result.0.append(name) : result.1.append(name)
    }
    return custom.sorted()
      + official.sorted {
        order[($0 as NSString).deletingPathExtension.lowercased().last ?? "z"] ?? 99 < order[
          ($1 as NSString).deletingPathExtension.lowercased().last ?? "z"] ?? 99
      }
  }

  private func reloadModelEntriesAndLoadFirst(for taskName: String) {
    currentModels = makeModelEntries(for: taskName)
    let modelTuples = currentModels.map { ($0.identifier, $0.remoteURL, $0.isLocalBundle) }
    standardModels = ModelSelectionManager.categorizeModels(from: modelTuples)

    let yoloTask = tasks.first(where: { $0.name == taskName })?.yoloTask ?? .detect
    ModelSelectionManager.setupSegmentedControl(
      modelSegmentedControl, standardModels: standardModels, currentTask: yoloTask)

    if let firstSize = ModelSelectionManager.ModelSize.allCases.first,
      let model = standardModels[firstSize]
    {
      let entry = ModelEntry(
        displayName: (model.name as NSString).deletingPathExtension,
        identifier: model.name,
        isLocalBundle: model.isLocal,
        isRemote: model.url != nil,
        remoteURL: model.url
      )
      loadModel(entry: entry, forTask: taskName)
    }
  }

  private func makeModelEntries(for taskName: String) -> [ModelEntry] {
    let localFileNames = modelsForTask[taskName] ?? []
    let localEntries = localFileNames.map { fileName -> ModelEntry in
      let display = (fileName as NSString).deletingPathExtension
      return ModelEntry(
        displayName: display,
        identifier: fileName,
        isLocalBundle: true,
        isRemote: false,
        remoteURL: nil
      )
    }

    // Get local model names for filtering
    let localModelNames = Set(localEntries.map { $0.displayName.lowercased() })

    let remoteList = remoteModelsInfo[taskName] ?? []
    let remoteEntries = remoteList.compactMap { (modelName, url) -> ModelEntry? in
      // Only include remote models if no local model with the same name exists
      guard !localModelNames.contains(modelName.lowercased()) else { return nil }

      return ModelEntry(
        displayName: modelName,
        identifier: modelName,
        isLocalBundle: false,
        isRemote: true,
        remoteURL: url
      )
    }

    return localEntries + remoteEntries
  }

  func loadModel(entry: ModelEntry, forTask task: String) {
    guard !isLoadingModel else {
      print("Model is already loading. Please wait.")
      return
    }
    isLoadingModel = true

    // Check if external display is connected
    let hasExternalDisplay = UIScreen.screens.count > 1 || SceneDelegate.hasExternalDisplay

    // Only reset YOLOView if no external display is connected
    if !hasExternalDisplay {
      yoloView.resetLayers()
      yoloView.setInferenceFlag(ok: false)
    }

    setLoadingState(true, showOverlay: true)
    resetDownloadProgress()

    print("Start loading model: \(entry.displayName)")
    print("  - displayName: \(entry.displayName)")
    print("  - identifier: \(entry.identifier)")
    print("  - isLocalBundle: \(entry.isLocalBundle)")
    print("  - task: \(task)")
    print("  - hasExternalDisplay: \(hasExternalDisplay)")

    // Store current entry for external display notification
    currentLoadingEntry = entry

    let yoloTask = tasks.first(where: { $0.name == task })?.yoloTask ?? .detect

    if entry.isLocalBundle {
      DispatchQueue.global().async { [weak self] in
        guard let self = self else { return }

        guard let folderURL = self.tasks.first(where: { $0.name == task })?.folder,
          let folderPathURL = Bundle.main.url(forResource: folderURL, withExtension: nil)
        else {
          DispatchQueue.main.async { [weak self] in
            self?.finishLoadingModel(success: false, modelName: entry.displayName)
          }
          return
        }

        let modelURL = folderPathURL.appendingPathComponent(entry.identifier)
        DispatchQueue.main.async { [weak self] in
          guard let self = self else { return }
          self.downloadProgressLabel.isHidden = false
          self.downloadProgressLabel.text = "Loading \(entry.displayName)"

          // Check if external display is connected
          let hasExternalDisplay = UIScreen.screens.count > 1 || SceneDelegate.hasExternalDisplay

          if hasExternalDisplay {
            // External display is connected - skip YOLOView loading, just notify external display
            print("External display connected - skipping main YOLOView model load")
            self.finishLoadingModel(success: true, modelName: entry.displayName)
          } else {
            // Normal model loading on main YOLOView
            self.yoloView.setModel(modelPathOrName: modelURL.path, task: yoloTask) { result in
              switch result {
              case .success():
                self.finishLoadingModel(success: true, modelName: entry.displayName)
              case .failure(let error):
                print(error)
                self.finishLoadingModel(success: false, modelName: entry.displayName)
              }
            }
          }
        }
      }
    } else {
      let key = entry.identifier  // "yolov8n", "yolov8m-seg", etc.

      if ModelCacheManager.shared.isModelDownloaded(key: key) {
        loadCachedModelAndSetToYOLOView(
          key: key, yoloTask: yoloTask, displayName: entry.displayName)
      } else {
        guard let remoteURL = entry.remoteURL else {
          self.finishLoadingModel(success: false, modelName: entry.displayName)
          return
        }

        self.downloadProgressView.progress = 0.0
        self.downloadProgressView.isHidden = false
        self.downloadProgressLabel.isHidden = false

        // Set initial downloading message with proper model name
        self.downloadProgressLabel.text = "Downloading \(processString(entry.displayName))"

        let localZipFileName = remoteURL.lastPathComponent  // ex. "yolov8n.mlpackage.zip"

        ModelCacheManager.shared.loadModel(
          from: localZipFileName,
          remoteURL: remoteURL,
          key: key
        ) { [weak self] mlModel, loadedKey in
          guard let self = self else { return }
          if mlModel == nil {
            self.finishLoadingModel(success: false, modelName: entry.displayName)
            return
          }
          self.loadCachedModelAndSetToYOLOView(
            key: loadedKey,
            yoloTask: yoloTask,
            displayName: entry.displayName)
        }
      }
    }
  }

  private func loadCachedModelAndSetToYOLOView(key: String, yoloTask: YOLOTask, displayName: String)
  {
    let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[
      0]
    let localModelURL = documentsDirectory.appendingPathComponent(key).appendingPathExtension(
      "mlmodelc")

    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      self.downloadProgressLabel.isHidden = false
      self.downloadProgressLabel.text = "Loading \(displayName)"

      // Check if external display is connected
      let hasExternalDisplay = UIScreen.screens.count > 1 || SceneDelegate.hasExternalDisplay

      if hasExternalDisplay {
        // External display is connected - skip YOLOView loading, just notify external display
        print("External display connected - skipping main YOLOView cached model load")
        self.finishLoadingModel(success: true, modelName: displayName)
      } else {
        // Normal model loading on main YOLOView
        self.yoloView.setModel(modelPathOrName: localModelURL.path, task: yoloTask) { result in
          switch result {
          case .success():
            self.finishLoadingModel(success: true, modelName: displayName)
          case .failure(let error):
            print(error)
            self.finishLoadingModel(success: false, modelName: displayName)
          }
        }
      }
    }
  }

  private func resetDownloadProgress() {
    downloadProgressView.progress = 0.0
    downloadProgressLabel.text = ""
    [downloadProgressView, downloadProgressLabel].forEach { $0.isHidden = true }
  }

  private func finishLoadingModel(success: Bool, modelName: String) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      self.setLoadingState(false)
      self.isLoadingModel = false
      self.resetDownloadProgress()

      if success {
        let yoloTask = self.tasks.first(where: { $0.name == self.currentTask })?.yoloTask ?? .detect

        ModelSelectionManager.setupSegmentedControl(
          self.modelSegmentedControl,
          standardModels: self.standardModels,
          currentTask: yoloTask,
          preserveSelection: true
        )

        ModelSelectionManager.updateSegmentAppearance(
          self.modelSegmentedControl,
          standardModels: self.standardModels,
          currentTask: yoloTask
        )
      }

      // Notify external display of model change (Optional feature)
      if success {
        // Update currentModelName
        self.currentModelName = processString(modelName)

        let yoloTask = self.tasks.first(where: { $0.name == self.currentTask })?.yoloTask ?? .detect

        // Determine the correct model path for external display
        var fullModelPath = ""

        // Use the stored entry from loadModel
        if let entry = self.currentLoadingEntry {
          if entry.isLocalBundle {
            // For local bundle models
            if let folderURL = self.tasks.first(where: { $0.name == self.currentTask })?.folder,
              let folderPathURL = Bundle.main.url(forResource: folderURL, withExtension: nil)
            {
              let modelURL = folderPathURL.appendingPathComponent(entry.identifier)
              fullModelPath = modelURL.path
              print("📦 External display local model path: \(fullModelPath)")
            }
          } else {
            // For remote/downloaded models, we need to pass the identifier only
            // The external display will handle loading from cache
            fullModelPath = entry.identifier
            print("☁️ External display will load cached model: \(fullModelPath)")

            // Verify the cached model exists locally first
            let documentsDirectory = FileManager.default.urls(
              for: .documentDirectory, in: .userDomainMask)[0]
            let localModelURL =
              documentsDirectory
              .appendingPathComponent(entry.identifier)
              .appendingPathExtension("mlmodelc")

            if !FileManager.default.fileExists(atPath: localModelURL.path) {
              print("❌ Cached model not found at: \(localModelURL.path)")
              return
            }
          }
        }

        // Only notify if we have a valid path
        if !fullModelPath.isEmpty {
          ExternalDisplayManager.shared.notifyModelChange(task: yoloTask, modelName: fullModelPath)
          print("✅ Model loaded successfully and notified to external display: \(modelName)")

          // Also check if external display is waiting for initial model
          self.checkAndNotifyExternalDisplayIfReady()
        } else {
          print("❌ Could not determine model path for external display")
        }
      }

      // Check if external display is connected
      let hasExternalDisplay = UIScreen.screens.count > 1 || SceneDelegate.hasExternalDisplay

      // Only set inference flag on YOLOView if no external display
      if !hasExternalDisplay {
        self.yoloView.setInferenceFlag(ok: success)
      }

      if success {
        // currentModelName is already set above in the notification section
        self.labelName.text = processString(modelName)
      }
    }
  }

  @IBAction func vibrate(_ sender: Any) { selection.selectionChanged() }

  @IBAction func indexChanged(_ sender: UISegmentedControl) {
    selection.selectionChanged()
    guard tasks.indices.contains(sender.selectedSegmentIndex) else { return }

    let newTask = tasks[sender.selectedSegmentIndex].name

    if (modelsForTask[newTask]?.isEmpty ?? true) && (remoteModelsInfo[newTask]?.isEmpty ?? true) {
      let alert = UIAlertController(
        title: "\(newTask) Models not found",
        message: "Please add or define models for \(newTask).", preferredStyle: .alert)
      alert.addAction(
        UIAlertAction(title: "OK", style: .cancel) { _ in alert.dismiss(animated: true) })
      present(alert, animated: true)
      sender.selectedSegmentIndex = tasks.firstIndex { $0.name == currentTask } ?? 0
      return
    }

    currentTask = newTask
    print("🎭 Task changed to: \(currentTask)")

    // Notify external display of task change immediately (Optional external display feature)
    NotificationCenter.default.post(
      name: .taskDidChange,
      object: nil,
      userInfo: ["task": newTask]
    )
    
    // Handle Pose task changes for skeleton UI
    handlePoseTaskChange()
    
    reloadModelEntriesAndLoadFirst(for: currentTask)
  }

  @objc func logoButton() {
    selection.selectionChanged()
    if let link = URL(string: Constants.logoURL) {
      UIApplication.shared.open(link)
    }
  }

  private func setupModelSegmentedControl() {
    modelSegmentedControl.isHidden = false
    modelSegmentedControl.overrideUserInterfaceStyle = .dark
    modelSegmentedControl.apportionsSegmentWidthsByContent = true
    modelSegmentedControl.addTarget(
      self, action: #selector(modelSizeChanged(_:)), for: .valueChanged)

    modelSegmentedControl.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      modelSegmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
      modelSegmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
    ])
  }

  private func setupCustomModelButton() {
    customModelButton = UIButton(type: .system)
    customModelButton.setTitle("Custom", for: .normal)
    customModelButton.titleLabel?.font = UIFont.systemFont(ofSize: 13)
    customModelButton.setTitleColor(.white, for: .normal)
    customModelButton.setTitleColor(.systemBlue, for: .selected)
    customModelButton.backgroundColor = .systemBackground.withAlphaComponent(0.1)
    customModelButton.layer.cornerRadius = 8
    customModelButton.layer.borderWidth = 1
    customModelButton.layer.borderColor = UIColor.systemGray.cgColor
    customModelButton.addTarget(
      self, action: #selector(customModelButtonTapped), for: .touchUpInside)
    customModelButton.translatesAutoresizingMaskIntoConstraints = false

    View0.addSubview(customModelButton)

    modelSegmentedControl.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      modelSegmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
      modelSegmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
    ])
  }

  // MARK: - Actions
  @objc func customModelButtonTapped() {
    selection.selectionChanged()
    // Placeholder action for custom model selection; integrate picker if needed
  }

  func updateModelSegmentedControlAppearance() {
    guard modelSegmentedControl != nil else { return }

    modelSegmentedControl.overrideUserInterfaceStyle = .dark
    modelSegmentedControl.backgroundColor = .clear

    let yoloTask = tasks.first(where: { $0.name == currentTask })?.yoloTask ?? .detect
    ModelSelectionManager.updateSegmentAppearance(
      modelSegmentedControl, standardModels: standardModels, currentTask: yoloTask)
  }

  @objc private func modelSizeChanged(_ sender: UISegmentedControl) {
    selection.selectionChanged()

    if sender.selectedSegmentIndex < ModelSelectionManager.ModelSize.allCases.count {
      let size = ModelSelectionManager.ModelSize.allCases[sender.selectedSegmentIndex]
      if let model = standardModels[size] {
        let entry = ModelEntry(
          displayName: (model.name as NSString).deletingPathExtension,
          identifier: model.name,
          isLocalBundle: model.isLocal,
          isRemote: model.url != nil,
          remoteURL: model.url
        )
        loadModel(entry: entry, forTask: currentTask)
      }
    }
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    adjustLayoutForExternalDisplayIfNeeded()
    
    // Update skeleton scene size for Pose models
    if currentTask.lowercased() == "pose",
       let scene = poseSkeletonScene {
      scene.size = view.bounds.size
      updateSpriteKitPoseCameraBounds(view.bounds)
    }
  }

  @objc func shareButtonTapped() {
    selection.selectionChanged()
    yoloView.capturePhoto { [weak self] image in
      guard let self = self, let image = image else { return print("error capturing photo") }
      DispatchQueue.main.async { [weak self] in
        guard let self = self else { return }
        let vc = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        vc.popoverPresentationController?.sourceView = self.View0
        self.present(vc, animated: true)
      }
    }
  }

  @objc func sliderValueChanged(_ sender: UISlider) {
    // Send threshold values to external display (Optional external display feature)
    let conf = Double(round(100 * yoloView.sliderConf.value)) / 100
    let iou = Double(round(100 * yoloView.sliderIoU.value)) / 100
    let maxItems = Int(yoloView.sliderNumItems.value)

    NotificationCenter.default.post(
      name: .thresholdDidChange,
      object: nil,
      userInfo: [
        "conf": conf,
        "iou": iou,
        "maxItems": maxItems,
      ]
    )

    print("📊 Threshold changed - Conf: \(conf), IoU: \(iou), Max items: \(maxItems)")
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  private func debugCheckModelFolders() {
    print("\n🔍 DEBUG: Checking model folders...")
    let folders = ["DetectModels", "SegmentModels", "ClassifyModels", "PoseModels", "OBBModels"]

    for folder in folders {
      if let folderURL = Bundle.main.url(forResource: folder, withExtension: nil) {
        print("✅ \(folder) found at: \(folderURL.path)")

        do {
          let files = try FileManager.default.contentsOfDirectory(
            at: folderURL, includingPropertiesForKeys: nil)
          let models = files.filter {
            $0.pathExtension == "mlmodel" || $0.pathExtension == "mlpackage"
          }
          print("   📦 Models: \(models.map { $0.lastPathComponent })")
        } catch {
          print("   ❌ Error reading folder: \(error)")
        }
      } else {
        print("❌ \(folder) NOT FOUND in bundle")
      }
    }
    print("\n")
  }

}

// MARK: - YOLOViewDelegate
extension ViewController {
  func yoloView(_ view: YOLOView, didUpdatePerformance fps: Double, inferenceTime: Double) {
    DispatchQueue.main.async { [weak self] in
      self?.labelFPS.text = String(format: "%.1f FPS - %.1f ms", fps, inferenceTime)
      self?.labelFPS.textColor = .white
    }
  }

  func yoloView(_ view: YOLOView, didReceiveResult result: YOLOResult) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      // Share results with external display (Optional external display feature)
      ExternalDisplayManager.shared.shareResults(result)

      // Also send via notification for direct communication (Optional external display feature)
      NotificationCenter.default.post(
        name: .yoloResultsAvailable,
        object: nil,
        userInfo: ["result": result]
      )
      
      // Update SpriteKit skeleton for Pose models
      self.updateSpriteKitPoseSkeleton(with: result)
    }
  }

}

// MARK: - SpriteKit Skeleton Extension for Pose Models

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
    
    // Create SpriteKit view (already added to view in createSpriteKitPoseView)
    let spriteKitView = createSpriteKitPoseView()
    
    // Create SpriteKit scene
    let scene = createPoseSkeletonScene()
    spriteKitView.presentScene(scene)
    
    // Setup YOLO integration
    setupPoseYOLOSpriteKitIntegration(scene: scene)
    
    print("🎭 SpriteKit skeleton setup completed")
  }
  
  private func createSpriteKitPoseView() -> SKView {
    // Check if SpriteKit view already exists
    if let existingView = spriteKitPoseView {
      print("🎭 SpriteKit view already exists, reusing")
      return existingView
    }
    
    print("🎭 Creating new SpriteKit view")
    let spriteKitView = SKView()
    spriteKitView.tag = 1001
    spriteKitView.translatesAutoresizingMaskIntoConstraints = false
    spriteKitView.showsFPS = false
    spriteKitView.showsNodeCount = false
    spriteKitView.ignoresSiblingOrder = true
    spriteKitView.backgroundColor = .clear
    
    // Add to the main view first
    view.addSubview(spriteKitView)
    print("🎭 SpriteKit view added to main view")
    
    // Position behind camera preview but above other UI elements
    NSLayoutConstraint.activate([
      spriteKitView.topAnchor.constraint(equalTo: view.topAnchor),
      spriteKitView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      spriteKitView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      spriteKitView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
    ])
    
    print("🎭 SpriteKit view constraints activated")
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
    print("🎭 addPoseSkeletonToggleButton called")
    
    let button = UIButton(type: .system)
    button.tag = 1002
    button.setTitle("Skeleton: ON", for: .normal)
    button.backgroundColor = .systemBlue.withAlphaComponent(0.8)
    button.setTitleColor(.white, for: .normal)
    button.layer.cornerRadius = 8
    button.translatesAutoresizingMaskIntoConstraints = false
    
    button.addTarget(self, action: #selector(poseSkeletonToggleTapped), for: .touchUpInside)
    
    view.addSubview(button)
    print("🎭 Button added to view")
    
    // Position button in top-right corner
    NSLayoutConstraint.activate([
      button.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
      button.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
      button.widthAnchor.constraint(equalToConstant: 120),
      button.heightAnchor.constraint(equalToConstant: 40)
    ])
    
    print("🎭 Button constraints activated")
    
    // Enable skeleton by default when button is created
    poseSkeletonSettings.isEnabled = true
    print("🎭 Skeleton enabled by default")
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
    print("🎭 Removing SpriteKit skeleton")
    spriteKitPoseView?.removeFromSuperview()
    objc_setAssociatedObject(self, &AssociatedKeys.poseSpriteKitIntegration, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    print("🎭 SpriteKit skeleton removed")
  }
  
  // MARK: - YOLO Result Integration for Pose
  
  /// Update skeleton with YOLO pose estimation results (only for Pose models)
  func updateSpriteKitPoseSkeleton(with result: YOLOResult) {
    print("🎭 updateSpriteKitPoseSkeleton called")
    print("🎭 currentTask: \(currentTask)")
    print("🎭 poseSkeletonSettings.isEnabled: \(poseSkeletonSettings.isEnabled)")
    print("🎭 poseSpriteKitIntegration exists: \(poseSpriteKitIntegration != nil)")
    print("🎭 keypointsList count: \(result.keypointsList.count)")
    
    // Only process if we're in Pose mode and skeleton is enabled
    guard currentTask.lowercased() == "pose",
          poseSkeletonSettings.isEnabled,
          let integration = poseSpriteKitIntegration else { 
            print("🎭 Guard failed - not updating skeleton")
            return 
          }
    
    // Only process pose estimation results
    guard !result.keypointsList.isEmpty else {
      print("🎭 No keypoints found - clearing skeletons")
      integration.clearSkeletons()
      return
    }
    
    print("🎭 Updating skeleton with \(result.keypointsList.count) keypoint sets")
    // Update skeleton visualization
    integration.updateSkeleton(with: result)
    print("🎭 Skeleton updated successfully")
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
    print("🎭 handlePoseTaskChange called with currentTask: \(currentTask)")
    
    if currentTask.lowercased() == "pose" {
      print("🎭 Pose task detected - creating skeleton button")
      // Create and show skeleton toggle button for Pose models
      if poseSkeletonToggleButton == nil {
        addPoseSkeletonToggleButton()
        print("🎭 Skeleton button created")
      }
      poseSkeletonToggleButton?.isHidden = false
      print("🎭 Skeleton button should be visible now")
      
      if poseSkeletonSettings.isEnabled {
        setupSpriteKitPoseSkeleton()
        print("🎭 SpriteKit skeleton setup called")
      }
    } else {
      print("🎭 Non-pose task detected - hiding skeleton button")
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

// MARK: - Simplified SpriteKit Integration

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
        print("🎭 YOLOSpriteKitIntegration.updateSkeleton called")
        print("🎭 KeypointsList count: \(result.keypointsList.count)")
        print("🎭 Boxes count: \(result.boxes.count)")
        
        // Clear existing skeletons
        clearSkeletons()
        
        // Process each detected person
        for (index, keypoints) in result.keypointsList.enumerated() {
            guard index < result.boxes.count else { continue }
            let boundingBox = result.boxes[index]
            
            print("🎭 Creating skeleton for person \(index)")
            // Create skeleton for this person
            let skeletonId = "person_\(index)"
            createSkeletonForPerson(id: skeletonId, keypoints: keypoints, boundingBox: boundingBox)
        }
        
        print("🎭 YOLOSpriteKitIntegration.updateSkeleton completed")
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
        print("🎭 createSkeletonForPerson called for \(id)")
        print("🎭 Keypoints count: \(keypoints.xy.count)")
        print("🎭 Confidences count: \(keypoints.conf.count)")
        
        // Create skeleton node
        let skeletonNode = SKSkeletonNode()
        skeletonNodes[id] = skeletonNode
        scene.addChild(skeletonNode)
        print("🎭 Skeleton node added to scene")
        
        // Convert keypoints to SpriteKit coordinates
        let spriteKitPoints = convertKeypointsToSpriteKit(keypoints)
        print("🎭 Converted \(spriteKitPoints.count) keypoints to SpriteKit coordinates")
        
        // Create joints and bones
        createJointsAndBones(skeletonNode: skeletonNode, keypoints: spriteKitPoints, confidences: keypoints.conf)
        print("🎭 Joints and bones created for \(id)")
    }
    
    private func convertKeypointsToSpriteKit(_ keypoints: Keypoints) -> [CGPoint] {
        print("🎭 Converting keypoints to SpriteKit coordinates")
        print("🎭 Scene size: \(scene.size)")
        
        return keypoints.xy.map { point in
            // Use the original image coordinates directly (they're already in the correct coordinate system)
            let spriteKitX = CGFloat(point.x)
            let spriteKitY = CGFloat(point.y)
            
            print("🎭 Original: (\(point.x), \(point.y)) -> SpriteKit: (\(spriteKitX), \(spriteKitY))")
            return CGPoint(x: spriteKitX, y: spriteKitY)
        }
    }
    
    private func createJointsAndBones(skeletonNode: SKSkeletonNode, keypoints: [CGPoint], confidences: [Float]) {
        print("🎭 Creating joints and bones for \(keypoints.count) keypoints")
        
        // Create joint nodes first
        var validJoints: [Int: CGPoint] = [:]
        for (index, point) in keypoints.enumerated() {
            guard index < confidences.count,
                  confidences[index] >= 0.5 else { continue }
            
            let jointNode = createJointNode(at: point)
            skeletonNode.addChild(jointNode)
            validJoints[index] = point
            print("🎭 Created joint \(index) at \(point)")
        }
        
        // Create bone connections between valid joints
        createBoneConnections(skeletonNode: skeletonNode, keypoints: keypoints, confidences: confidences, validJoints: validJoints)
    }
    
    private func createJointNode(at point: CGPoint) -> SKShapeNode {
        let jointNode = SKShapeNode(circleOfRadius: 15.0)  // Made larger
        jointNode.fillColor = .systemRed  // Made red for visibility
        jointNode.strokeColor = .white
        jointNode.lineWidth = 3.0
        jointNode.position = point
        
        // Add glow effect
        let glowNode = SKShapeNode(circleOfRadius: 20.0)  // Made larger
        glowNode.fillColor = .systemRed.withAlphaComponent(0.5)  // Made more visible
        glowNode.strokeColor = .clear
        glowNode.position = point
        glowNode.zPosition = -1
        
        let jointGroup = SKNode()
        jointGroup.addChild(glowNode)
        jointGroup.addChild(jointNode)
        
        return jointNode
    }
    
    private func createBoneConnections(skeletonNode: SKSkeletonNode, keypoints: [CGPoint], confidences: [Float], validJoints: [Int: CGPoint]) {
        print("🎭 Creating bone connections with \(validJoints.count) valid joints")
        
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
        
        var boneCount = 0
        for (joint1, joint2) in boneConnections {
            guard let point1 = validJoints[joint1],
                  let point2 = validJoints[joint2] else { 
                print("🎭 Skipping bone connection \(joint1)-\(joint2) - missing joints")
                continue 
            }
            
            let boneNode = createBoneNode(from: point1, to: point2)
            skeletonNode.addChild(boneNode)
            boneCount += 1
            print("🎭 Created bone connection \(joint1)-\(joint2)")
        }
        
        print("🎭 Created \(boneCount) bone connections")
    }
    
    private func createBoneNode(from point1: CGPoint, to point2: CGPoint) -> SKShapeNode {
        let path = CGMutablePath()
        path.move(to: point1)
        path.addLine(to: point2)
        
        let boneNode = SKShapeNode(path: path)
        boneNode.strokeColor = .systemYellow  // Made yellow for visibility
        boneNode.lineWidth = 8.0  // Made thicker
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
