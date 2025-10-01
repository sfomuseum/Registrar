import UIKit
import Vision
import VisionKit
import CoreLocation
import FoundationModels
import Photos

import llama


class ViewController: UIViewController {
    
    let instructions = """
        Parse this text as though it were a wall label in a museum describing an object.
        Wall labels are typically structured as follows: name, date, creator, location, media, creditline and accession number. Usually each property is on a separate line but sometimes, in the case of name and date, they will be combined on the same line. Some properties, like creator, location and media are not always present. Sometimes titles may have leading numbers, followed by a space, acting as a key between the wall label and the surface the object is mounted on. Remove these numbers if present.
        """
    
    var label = WallLabel("")
    
    var images = [UIImage](){
        willSet(i){
            // print("Update images \(i.count)")
        }
    }
    
    let cellReuseIdentifier = "cell"
    
    let locationManager = CLLocationManager()
    
    var current_location: CLLocation?
    
    var keyValuePairs: [(String, String)] = []
    
    var isDataScannerAvailable: Bool {
        DataScannerViewController.isAvailable &&
        DataScannerViewController.isSupported
    }
    
    @IBOutlet var captureButton: UIBarButtonItem!
    
    @IBOutlet var scanButton: UIBarButtonItem!
    
    @IBOutlet weak var tableView: UITableView!
    
    @IBOutlet weak var collectionView: UICollectionView!
    
    @IBOutlet weak var progressView: UIActivityIndicatorView!
    
    @IBOutlet weak var resetButton: UIBarButtonItem!
    
    @IBOutlet var exportButton: UIBarButtonItem!
    
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
    
    @IBAction func scanButton(_ sender: UIButton){
        
        guard isDataScannerAvailable else {
            return showAlert(title: "DataScanner is not available", message: "Unable to scan data because DataScanner functionality is not available.")
        }
        
        self.configureDataScanner()
    }
    
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
    
    func processScannedText(text: String) {
        
        self.progressView.isHidden = false
        self.progressView.startAnimating()
        
        label = WallLabel(text)
        label.timestamp = Int(NSDate().timeIntervalSince1970)
        label.latitude = self.current_location?.coordinate.latitude ?? 0.0
        label.longitude = self.current_location?.coordinate.longitude ?? 0.0
        
        Task {
            do {
                
                // This doesn't work yet because of concurrency issues
                // let rsp = await label.Parse()
                
                let model_path = "foo"
                let params = llama_model_params()
                let model = llama_model_load_from_file(model_path, params)
                
                let ctx_params = llama_context_params()
                let ctx = llama_init_from_model(model, ctx_params)
                
                
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
    }
    
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










