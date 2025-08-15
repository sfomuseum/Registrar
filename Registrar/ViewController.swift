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
    
    var images = [UIImage]()
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
    
    @IBOutlet var saveButton: UIBarButtonItem!
    
    @IBOutlet var textView: UITextView!
    
    @IBOutlet weak var tableView: UITableView!
    
    @IBOutlet weak var collectionView: UICollectionView!
    
    @IBOutlet weak var progressView: UIActivityIndicatorView!
    
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
        
        var label = WallLabel(text)
        label.timestamp = Int(NSDate().timeIntervalSince1970)
        label.latitude = self.current_location?.coordinate.latitude ?? 0.0
        label.longitude = self.current_location?.coordinate.longitude ?? 0.0
        
        Task {
            do {
                
                // Start of make this a WallLabel method
                // There are "immutable self" errors to work out...
                
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
                
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                let enc = try encoder.encode(label)
                
                DispatchQueue.main.async {
                    
                    self.progressView.stopAnimating()
                    self.progressView.isHidden = true
                    
                    self.updateTableData(label: label)
                    
                    // self.textView.text = String(data: enc, encoding: .utf8)
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










