import UIKit
import Vision
import VisionKit
import CoreLocation
import FoundationModels
import Photos

// This is as far as I've gotten trying to wire in MLX stuff
// https://github.com/ml-explore/mlx-swift-examples/blob/main/Applications/MLXChatExample/README.md
import MLX
import MLXLLM
import MLXLMCommon
import MLXVLM

/*
 
 struct WallLabel: Codable {
     /// The title of the object
     @Guide(description: "The title or name of the object. Sometimes titles may have leading numbers, followed by a space, indicating acting as a key between the wall label and the surface the object is mounted on. Remove these numbers if present.")
     var title: String?

     /// The date attributed to an object, typically when that object was created
     @Guide(description: "The date attributed to an object, typically when that object was created")
     var date: String?

     /// The individual or organization responsible for creating an object.
     @Guide(description: "The individual or organization responsible for creating an object.")
     var creator: String?
     
     /// The name of an individual, persons or organization who donated or are lending an object.
     @Guide(description: "The name of an individual, persons or organization who donated or are lending an object.")
     var creditline: String?
     
     /// The location that an object was produced in.
     @Guide(description: "The location that an object was produced in.")
     var location: String?
     
     /// The medium or media used to create the object.
     @Guide(description: "The medium or media used to create the object.")
     var medium: String?
     
     /// The unique identifier for an object.
     @Guide(description: "The unique identifier for an object.")
     var accession_number: String?
 */

class ViewController: UIViewController {
    
    /// The instructions/guardrails for the LLM prompt
    let instructions = """
        Parse this text as though it were a wall label in a museum describing an object. Wall labels are typically structured as follows: name, date, creator, location, media, credit line and accession number. Usually each property is on a separate line but sometimes, in the case of name and date, they will be combined on the same line. Some properties, like creator, location and media are not always present. Sometimes titles may have leading numbers, followed by a space, acting as a key between the wall label and the surface the object is mounted on. Remove these numbers if present. Generate the result as a JSON-encoded dictionary of key-value pairs, storing all values as strings. Assign the object title the key "title". Assign the object date the key "date". Assign the object creator (artist, manufacturer or company) a "creator" key. Assign the object credit line a "creditline" key. Assign the object location a "location" key. Assign the object media a "medium" key. Assign the accession number (primary identifier) an "accession_number" key. Assign an empty "input" key. Ensure that all keys (title, date, creator, creditline, location, medium, accession_number, input) are present and assigned empty string values if they can not be derived from the source text. Do not assign any besides: title, date, creator, creditline, location, medium, accession_number, input.
        """
    
    /// The current WallLabel instance
    var label = WallLabel("")
    
    /// The list of images captured (and stored to collectionView)
    var images = [UIImage](){
        willSet(i){
            // print("Update images \(i.count)")
        }
    }
    
    /// The cell reuse identifier for the image list
    let cellReuseIdentifier = "cell"
    
    /// CLLocationManager instsance for geolocation
    let locationManager = CLLocationManager()
    
    /// The most recent reported location CLLocationManager
    var current_location: CLLocation?
    
    var keyValuePairs: [(String, String)] = []
    
    /// Boolean value indicating whether data scanner functionality is supported
    var isDataScannerAvailable: Bool {
        DataScannerViewController.isAvailable &&
        DataScannerViewController.isSupported
    }
    
    /// The button that triggers the photo capture dialog
    @IBOutlet var captureButton: UIBarButtonItem!
    
    /// The butten that triggers the data scanning modal dialog
    @IBOutlet var scanButton: UIBarButtonItem!
    
    /// The UITableView where wall label data is displayed
    @IBOutlet weak var tableView: UITableView!
    
    /// The UICollectionView where captured images are displayed
    @IBOutlet weak var collectionView: UICollectionView!
    
    @IBOutlet weak var progressView: UIActivityIndicatorView!
    
    /// The button which purges image and captured wall label data
    @IBOutlet weak var resetButton: UIBarButtonItem!
    
    /// The button which will trigger the function to write wall label data to each photos' EXIF data before exporting the photo to device's Photo application
    @IBOutlet var exportButton: UIBarButtonItem!
    
    //MARK: Button actions/functions
    
    /// Encode wall label data as JSON and write to each photos' EXIF data before exporting the photo to device's Photo library
    @IBAction func exportRecords(_ sender: UIButton){
        
        self.progressView.startAnimating()
        self.progressView.isHidden = false
        
        let rsp = self.label.marshalJSON()
        var meta: String
        
        switch (rsp) {
        case .failure(let error):
            
            self.progressView.stopAnimating()
            self.progressView.isHidden = true
            
            self.showAlert(title: "Failed to export metadata", message: "Unable to export metadata because \(error)")
            return
        case .success(let data):
            
            guard let str_data = String(data: data, encoding: .utf8) else {
                return
            }
            
            meta = str_data
        }
        
        for im in images {
            self.saveImage(image: im, meta: meta)
        }
        
        // Note: The actual saving of images happens asynchronously
        // so it's kind of hard to know when everything has actually
        // been completed. I guess we could watch PHObjectChangeDetails,
        // maybe?
        self.progressView.stopAnimating()
        self.progressView.isHidden = true
    }
    
    /// Purges all images and captured wall label data and their corresponding display views
    @IBAction func resetButton(_ sender: UIButton) {
        
        let alertController = UIAlertController(title: "Confirm Action", message: "Are you sure you want to reset everything?", preferredStyle: .alert)
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        
        let okAction = UIAlertAction(title: "OK", style: .default) { _ in
            
            self.clearCollectionView()
            self.clearTable()
        }
        
        alertController.addAction(cancelAction)
        alertController.addAction(okAction)
        
        present(alertController, animated: true, completion: nil)
    }
    
    /// Trigger the camera capture modal dialog
    @IBAction func captureButton(_ sender: UIButton) {
        
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            let imagePicker = UIImagePickerController()
            imagePicker.delegate = self
            imagePicker.sourceType = .camera
            imagePicker.allowsEditing = false
            present(imagePicker, animated: true)
        } else {
            self.showAlert(title: "Camera Not Available", message: "This device has no camera.")
        }
    }
    
    /// Trigger the data scanning modal dialog
    @IBAction func scanButton(_ sender: UIButton){
        
        guard isDataScannerAvailable else {
            return showAlert(title: "DataScanner is not available", message: "Unable to scan data because DataScanner functionality is not available.")
        }
        
        self.configureDataScanner()
    }
    
    //MARK: On load
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        locationManager.requestAlwaysAuthorization()
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.startUpdatingLocation()
        locationManager.delegate = self
        
        tableView.register(KeyValueTableViewCell.self, forCellReuseIdentifier: "KeyValueCell")
        tableView.dataSource = self
        tableView.delegate = self
        tableView.layer.borderWidth = 1.0
        tableView.layer.borderColor = UIColor.black.cgColor
        
        self.collectionView.dataSource = self
        self.progressView.isHidden = true
    }
    
    //MARK: Text processing
    
    /// Process text scanned by the data scanner modal dialog using the on-device FoundationModel framework.
    func processScannedText(text: String) {
        
        self.progressView.isHidden = false
        self.progressView.startAnimating()
        
        label = WallLabel(text)
        label.timestamp = Int(NSDate().timeIntervalSince1970)
        label.latitude = self.current_location?.coordinate.latitude ?? 0.0
        label.longitude = self.current_location?.coordinate.longitude ?? 0.0
        
        // Something something something MLX
        // https://github.com/ml-explore/mlx-swift-examples/blob/main/Applications/MLXChatExample/README.md
        // https://github.com/ml-explore/mlx-swift-examples/blob/main/Tools/llm-tool/README.md
        
        let mlxService = MLXService()
        let selectedModel: LMModel = MLXService.availableModels.first!
   
        let prompt: String = instructions + " The text to parse is: " + text
        var result: String = ""
        var generateTask: Task<Void, any Error>?

        // print("PROMPT \(prompt)")
        // print("MODEL \(selectedModel)")
        
        var messages: [Message] = [
            .system("You are a helpful assistant!")
        ]
        
        messages.append(.user(prompt))
        messages.append(.assistant(""))

        generateTask = Task {

            print("START...")
            
            for await generation in try await mlxService.generate(
                messages: messages, model: selectedModel)
            {
                switch generation {
                case .chunk(let chunk):
                    result += chunk
                case .info(let info):
                    print("INFO \(info)")
                case .toolCall(let call):
                    // print("TOOL \(call)")
                    break
                }
            }
        }

        Task {
            
            do {
                // Handle task completion and cancellation
                try await withTaskCancellationHandler {
                    try await generateTask?.value
                } onCancel: {
                    Task { @MainActor in
                        generateTask?.cancel()
                        
                        // Mark message as cancelled
                        if let assistantMessage = messages.last {
                            assistantMessage.content += "\n[Cancelled]"
                        }
                    }
                }
                
                print("DONE \(result)")
                
                let data = result.data(using: .utf8)
                
                do {
                    let l = try JSONDecoder().decode(WallLabel.self, from: data!)
                    
                    print("LABEL \(l)")
                } catch {
                    print("FAILED TO LABEL \(error)")
                }
                
            } catch {
                
                DispatchQueue.main.async {
                    self.progressView.stopAnimating()
                    self.progressView.isHidden = true
                }
                
                self.showAlert(title: "Failed to parse text", message: "Failed to parse text \(error)")
            }
        }
        
        /*
        Task {
            do {
                
                // This doesn't work yet because of concurrency issues
                // let rsp = await label.Parse()
                
                // Start of make this a WallLabel method
                
                let session = LanguageModelSession(instructions: instructions)
                
                let response = try await session.respond(
                    to: text,
                    generating: WallLabel.self
                )
                
                label.title = response.content.title
                label.date = response.content.date
                label.creator = response.content.creator
                label.location = response.content.location
                label.accession_number = response.content.accession_number
                label.medium = response.content.medium
                label.creditline = response.content.creditline
                
                // End of make this a WallLabel method
                
                DispatchQueue.main.async {
                    
                    self.progressView.stopAnimating()
                    self.progressView.isHidden = true
                    self.updateTableData(label: self.label)
                }
                
            } catch {
                DispatchQueue.main.async {
                    self.progressView.stopAnimating()
                    self.progressView.isHidden = true
                }
                
                self.showAlert(title: "Failed to parse text", message: "Failed to parse text \(error)")
            }
            
        }
         */
        
    }
    
    //MARK: Image saving
    
    /// Write metadata to an image's "UserComment" EXIF header and then export the photo the device's Photo library.
    func saveImage(image: UIImage, meta: String) {
        
        let imageData: Data = image.jpegData(compressionQuality: 1)!
        
        let cgImgSource: CGImageSource = CGImageSourceCreateWithData(imageData as CFData, nil)!
        let uti: CFString = CGImageSourceGetType(cgImgSource)!
        let dataWithEXIF: NSMutableData = NSMutableData(data: imageData)
        
        let destination: CGImageDestination = CGImageDestinationCreateWithData((dataWithEXIF as CFMutableData), uti, 1, nil)!
        
        let imageProperties = CGImageSourceCopyPropertiesAtIndex(cgImgSource, 0, nil)! as NSDictionary
        let mutable: NSMutableDictionary = imageProperties.mutableCopy() as! NSMutableDictionary
        
        let EXIFDictionary: NSMutableDictionary = (mutable[kCGImagePropertyExifDictionary as String] as? NSMutableDictionary)!
        
        EXIFDictionary[kCGImagePropertyExifUserComment as String] = meta
        
        mutable[kCGImagePropertyExifDictionary as String] = EXIFDictionary
        
        CGImageDestinationAddImageFromSource(destination, cgImgSource, 0, (mutable as CFDictionary))
        
        guard CGImageDestinationFinalize(destination) else {
            self.showAlert(title: "Failed to prepare image for exporting", message: "Unable to prepare image for exporting.")
            return
        }
        
        let jpeg_data = dataWithEXIF as Data
        
        PHPhotoLibrary.shared().performChanges({
            let creationRequest = PHAssetCreationRequest.forAsset()
            creationRequest.addResource(with: .photo, data: jpeg_data, options: nil)
        }, completionHandler: { success, error in
            if success {
                print("Image saved successfully")
            } else if let error = error {
                self.showAlert(title: "Failed to save image", message: "Failed to save image: \(error)")
                print("Failed to save image: \(error.localizedDescription)")
            }
        })
    }
    
    //MARK: Feedback and alerts
    
    /// Display a model alert dialog
    func showAlert(title: String, message: String) {
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: UIAlertController.Style.alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
}










