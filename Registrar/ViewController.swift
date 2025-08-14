//
//  ViewController.swift
//  Registrar
//
//  Created by asc on 8/14/25.
//

import UIKit
import Vision
import VisionKit
import CoreLocation

class ViewController: UIViewController {

    
    var images = [UIImage]()
    let cellReuseIdentifier = "cell"
    
    private let locationManager = CLLocationManager()
    
    private var current_location: CLLocation?{
        willSet(loc){
            // print("Set current location \(loc)")
        }
    }
    
    var isDataScannerAvailable: Bool {
        DataScannerViewController.isAvailable &&
        DataScannerViewController.isSupported
    }
    
    @IBOutlet var captureButton: UIBarButtonItem!
    
    @IBOutlet var scanButton: UIBarButtonItem!
    
    @IBOutlet var saveButton: UIBarButtonItem!
    
    @IBOutlet var textView: UITextView!
        
    @IBOutlet weak var collectionView: UICollectionView!
    
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
    }


}

extension ViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return images.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
                
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellReuseIdentifier, for: indexPath)
        
            // cell.contentView.printAllSubviews()
    
            if let imageView = cell.viewWithTag(100) as? UIImageView {
                imageView.image = images[indexPath.row]
            }

            return cell

        }
}

extension UIView {
    func printAllSubviews() {
        print("SUBVIEWS")
        for subview in subviews {
            print("Subview: \(subview)")
            subview.printAllSubviews()
        }
    }
}

extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        
        if let image = info[.originalImage] as? UIImage {
            // imageView.image = image
            
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
    
    func showUnavailableAlert() {
        let alert = UIAlertController(
            title: "Your device is not compatible!",
            message: "To use, open app on a devices with iOS 16 or above and accept the terms.",
            preferredStyle: UIAlertController.Style.alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
    
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
            // self.addNewRow(withText: text.transcript)
            print(text.transcript)
            textView.text = text.transcript
            
        case .barcode(let barcode):
            
            if barcode.payloadStringValue != nil {
                // print("barcode: \(barcode.payloadStringValue ?? "unknown")")
                // self.addNewRow(withText: barcode.payloadStringValue!)
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
