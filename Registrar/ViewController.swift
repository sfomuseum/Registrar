import UIKit
import Vision
import VisionKit
import CoreLocation
import FoundationModels

class ViewController: UIViewController {
    
    let instructions = """
        Parse this text as though it were a wall label in a museum describing an object.
        Wall labels are typically structured as follows: name, date, creator, location, media, creditline and accession number. Usually each property is on a separate line but sometimes, in the case of name and date, they will be combined on the same line. Some properties, like creator, location and media are not always present. Sometimes titles may have leading numbers, Lfollowed by a space, indicating acting as a key between the wall label and the surface the object is mounted on. Remove these numbers if present.
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
        
        let rsp = self.label.marshalJSON()
        var meta: String
        
        switch (rsp) {
        case .failure(let err):
            return
        case .success(let data):
           
            guard let str_data = String(data: data, encoding: .utf8) else {
                return
            }
            
            meta = str_data
        }
        
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
    
    // This was added to account for low-light conditions
    // when using the DataScanner but the DataScanner ends
    // up turning the torch off...
    
    /*
    @IBOutlet weak var lightButton: UIBarButtonItem!
    
    @IBAction func lightButton(_ sender: UIButton) {
        
        guard let device = AVCaptureDevice.default(for: .video) else {
            return
        }
        
        if device.hasTorch {
                do {
                    try device.lockForConfiguration()

                    if device.torchMode == .off {
                        try device.setTorchModeOn(level: AVCaptureDevice.maxAvailableTorchLevel)
                    } else {
                        device.torchMode = .off
                    }

                    device.unlockForConfiguration()
                } catch {
                    print("Torch could not be used")
                }
            } else {
                print("Torch is not available")
            }
    }
    */
    
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
        
        print("Scanned '\(text)'")
        
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










