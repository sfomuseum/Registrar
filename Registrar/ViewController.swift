import UIKit
import Vision
import VisionKit
import CoreLocation
import FoundationModels
import Photos

import Logging
import WallLabel

class ViewController: UIViewController {

    let parser_uri = "mlx://?model=llama3.2:1b"

    /// The current WallLabel instance
    var label: WallLabel?
    
    /// The list of images captured (and stored to collectionView)
    var images = [UIImage](){
        willSet(i){
            // print("Update images \(i.count)")
        }
    }
    
    let logger = Logger(label: "org.sfomuseum.registar")
    
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
        
        let rsp = self.label?.marshalJSON()
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
        default:
            self.progressView.stopAnimating()
            self.progressView.isHidden = true
            
            self.showAlert(title: "Failed to export metadata", message: "Unable to marshal metadata to export")
            return
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
         
        Task {
            do {
                
                var label_parser: Parser
                
                do {
                    label_parser = try NewParser(self.parser_uri, logger: self.logger)
                } catch {
                    throw error
                }
                
                let parse_rsp = await label_parser.parse(text: text)
                
                switch parse_rsp {
                case .success(let label_rsp):
                    
                    label = label_rsp

                    DispatchQueue.main.async {
                        
                        self.progressView.stopAnimating()
                        self.progressView.isHidden = true
                        self.updateTableData(label: self.label!)
                    }
                    
                case .failure(let err):
                    throw err
                }
                                
                // End of make this a WallLabel method

                
            } catch {
                DispatchQueue.main.async {
                    self.progressView.stopAnimating()
                    self.progressView.isHidden = true
                }
                
                self.showAlert(title: "Failed to parse text", message: "Failed to parse text \(error)")
            }
            
        }

        
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










