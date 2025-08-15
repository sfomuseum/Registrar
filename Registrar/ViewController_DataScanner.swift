import UIKit
import Vision
import VisionKit

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
