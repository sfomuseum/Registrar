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
                
                guard let documentsURL = FileManager.default.urls(for: .documentDirectory,
                                                                  in: .userDomainMask).first else {
                    fatalError("Unable to locate Documents directory")
                }
                
                // This is way too big for an iOS device...
                // let model_name = "ggml-org_gpt-oss-20b-GGUF_gpt-oss-20b-mxfp4.gguf"
                let model_name = "ggml-org_SmolVLM-500M-Instruct-GGUF_SmolVLM-500M-Instruct-Q8_0.gguf"
                
                let model_url = documentsURL.appendingPathComponent(model_name)
                let model_path = model_url.absoluteString.replacingOccurrences(of: "file://", with: "")
                
                print(model_path)
                
                var params = llama_model_params()
                params.n_gpu_layers = 0
                
                let model = llama_model_load_from_file(model_path, params)
                
                var ctx_params = llama_context_params()
                ctx_params.n_ctx = 512
                ctx_params.n_batch = 8
                ctx_params.n_threads = Int32(ProcessInfo.processInfo.activeProcessorCount)
                
                let ctx = llama_init_from_model(model, ctx_params)
                
                // START OF vibe-coding...
                
                // Define the input prompt
                let prompt = "What is the capital of France?"

                // Convert the prompt to UTF-8 byte array (required by llama_tokenize)
                let promptUtf8 = Array(prompt.utf8)

                // Preallocate space for token output (extra buffer for BOS and special tokens)
                var tokens = [llama_token](repeating: 0, count: promptUtf8.count + 4)

                // Tokenize the prompt using llama.cpp's tokenizer
                let nTokens = tokens.withUnsafeMutableBufferPointer { buffer in
                    llama_tokenize(
                        ctx,                        // model context
                        promptUtf8,                 // input bytes
                        Int32(promptUtf8.count),   // input length
                        buffer.baseAddress,        // output token buffer
                        Int32(buffer.count),       // max number of tokens to write
                        true,                      // add_bos: prepend beginning-of-sequence token
                        true                       // special: allow special tokens like <eos>
                    )
                }

                // Trim the token array to the actual number of tokens returned
                tokens = Array(tokens.prefix(Int(nTokens)))

                // Initialize counters for context tracking
                var nPast: Int32 = 0       // number of tokens already processed by the model
                var nConsumed: Int32 = 0   // number of tokens already fed into llama_decode

                // Feed the prompt tokens into the model context
                while nConsumed < nTokens {
                    // Create a batch from the remaining tokens
                    let batch = makeBatch(tokens: Array(tokens[Int(nConsumed)...]), nPast: nPast)

                    // Decode the batch into the model's internal state
                    let decodeResult = llama_decode(ctx, batch)

                    // Free the batch memory
                    llama_batch_free(batch)

                    // Check for decoding failure
                    guard decodeResult == 0 else {
                        print("Decoding failed")
                        break
                    }

                    // Update context position and consumption count
                    nPast += Int32(tokens.count - Int(nConsumed))
                    nConsumed = Int32(tokens.count)
                }

                // Get the vocabulary size for sampling
                let vocabSize = llama_vocab_n_tokens(ctx)

                // Initialize the response string
                var ll_response = ""

                // Sampling parameters
                let temperature: Float = 0.8
                let topK: Int = 40

                // Generate up to 64 tokens autoregressively
                for _ in 0..<64 {
                    // Get pointer to logits from the last decode step
                    guard let logitsPtr = llama_get_logits(ctx) else {
                        print("Failed to get logits")
                        break
                    }

                    // Build candidate list from logits
                    var candidates = [llama_token_data]()
                    for tokenId in 0..<vocabSize {
                        let logit = logitsPtr[Int(tokenId)]
                        candidates.append(llama_token_data(id: tokenId, logit: logit, p: 0))
                    }

                    // Sort candidates by descending logit value
                    candidates.sort { $0.logit > $1.logit }

                    // Keep only the top-k candidates
                    let topCandidates = candidates.prefix(topK)

                    // Apply temperature scaling to logits
                    let scaledLogits = topCandidates.map { exp($0.logit / temperature) }

                    // Normalize to get probabilities
                    let sum = scaledLogits.reduce(0, +)
                    let probs = scaledLogits.map { $0 / sum }

                    // Sample a token from the probability distribution
                    let sample = Float.random(in: 0..<1)
                    var cumulative: Float = 0
                    var selectedToken: llama_token = topCandidates.last!.id

                    for (i, candidate) in topCandidates.enumerated() {
                        cumulative += probs[i]
                        if sample < cumulative {
                            selectedToken = candidate.id
                            break
                        }
                    }

                    // Stop if end-of-sequence token is generated
                    if selectedToken == llama_vocab_eos(ctx) {
                        break
                    }

                    // Allocate buffer to decode token into string
                    let bufferSize = 32
                    let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: bufferSize)
                    defer { buffer.deallocate() }

                    // Convert token to string and append to response
                    _ = llama_token_to_piece(ctx, selectedToken, buffer, Int32(bufferSize), 0, true)
                    ll_response += String(cString: buffer)

                    // Feed the sampled token back into the model context
                    let batch = makeBatch(tokens: [selectedToken], nPast: nPast)
                    let decodeResult = llama_decode(ctx, batch)
                    llama_batch_free(batch)

                    // Stop if decoding fails
                    guard decodeResult == 0 else {
                        print("Decoding failed during generation")
                        break
                    }

                    // Advance context position
                    nPast += 1
                }
                
                print("Response: \(ll_response)")
                
                // END OF vibe-coding
                
                
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
    
    func makeBatch(tokens: [llama_token], nPast: Int32) -> llama_batch {
        // Initialize batch
        var batch = llama_batch_init(Int32(tokens.count), 0, 1)
        
        for (i, token) in tokens.enumerated() {
            // Allocate memory for sequence ID
            let seqId = UnsafeMutablePointer<Int32>.allocate(capacity: 1)
            seqId.initialize(to: 0)
            
            // Fill in batch fields manually
            batch.token[i] = token
            batch.pos[i] = Int32(nPast + Int32(i))
            batch.n_seq_id[i] = 1
            batch.seq_id[i] = seqId
            batch.logits[i] = Int8(false ? 1 : 0)
        }
        
        return batch
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










