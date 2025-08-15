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
    
    private let locationManager = CLLocationManager()
    
    private var current_location: CLLocation?
    
    var isDataScannerAvailable: Bool {
        DataScannerViewController.isAvailable &&
        DataScannerViewController.isSupported
    }
    
    @IBOutlet var captureButton: UIBarButtonItem!
    
    @IBOutlet var scanButton: UIBarButtonItem!
    
    @IBOutlet var saveButton: UIBarButtonItem!
    
    @IBOutlet var textView: UITextView!
        
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
            // If the camera is not available, show an alert
            let alert = UIAlertController(title: "Camera Not Available", message: "This device has no camera.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }
    
    @IBAction func scanButton(_ sender: UIButton){
        
        guard isDataScannerAvailable else {
            return showUnavailableAlert()
        }
        
        self.configureDataScanner()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        textView.isEditable = false
        
        locationManager.requestAlwaysAuthorization()
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.startUpdatingLocation()
        locationManager.delegate = self
        
        self.collectionView.dataSource = self
        self.progressView.isHidden = true
        
    }

    func processScannedText(text: String) {
        
        textView.text = text
        
        self.progressView.isHidden = false
        self.progressView.startAnimating()
        
        Task {
            do {
                
                let session = LanguageModelSession(instructions: instructions)
                
                let response = try await session.respond(
                    to: text,
                    generating: WallLabel.self
                )
                
                var label = response.content
                label.input = text
                label.timestamp = Int(NSDate().timeIntervalSince1970)
                label.latitude = self.current_location?.coordinate.latitude ?? 0.0
                label.longitude = self.current_location?.coordinate.longitude ?? 0.0
                
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                
                let enc = try encoder.encode(label)
                
                DispatchQueue.main.async {
                    
                    self.progressView.stopAnimating()
                    self.progressView.isHidden = true
                    
                    self.textView.text = String(data: enc, encoding: .utf8)
                }
                
            } catch {
                DispatchQueue.main.async {
                    self.progressView.stopAnimating()
                    self.progressView.isHidden = true
                }
                
                showUnavailableAlert()
            }
            
        }
    }
    
    func showUnavailableAlert() {
        let alert = UIAlertController(
            title: "Your device is not compatible!",
            message: "To use, open app on a devices with iOS 16 or above and accept the terms.",
            preferredStyle: UIAlertController.Style.alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
}

extension ViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return images.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
                
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellReuseIdentifier, for: indexPath)
    
            if let imageView = cell.viewWithTag(100) as? UIImageView {
                imageView.image = images[indexPath.row]
            }

            return cell

        }
}

extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        
        if let image = info[.originalImage] as? UIImage {
            images.append(image)
            collectionView.reloadData()
        }
        picker.dismiss(animated: true)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}

extension ViewController: DataScannerViewControllerDelegate {
    
    func configureDataScanner() {
        
        let recognitionDataTypes: Set<DataScannerViewController.RecognizedDataType> = [
            .text(languages: ["en-US"]),
            .barcode(symbologies: [.qr, .aztec, .microPDF417, .pdf417, .code128]),
        ]
        
        let dataScanner = DataScannerViewController(
            recognizedDataTypes: recognitionDataTypes,
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        
        dataScanner.delegate = self
        present(dataScanner, animated: true) {
            try? dataScanner.startScanning()
        }
    }
    
    func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
        switch item {
        case .text(let text):

            self.processScannedText(text: text.transcript)
            
        case .barcode(let barcode):
            
            if barcode.payloadStringValue != nil {
                self.processScannedText(text: barcode.payloadStringValue!)
            }
            
        default:
            print("unexpected item")
        }
    }
}

extension ViewController: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        if let lastLocation = locations.last {
            current_location = lastLocation
        }
    }
}
