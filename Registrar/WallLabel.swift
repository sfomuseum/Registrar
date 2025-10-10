import FoundationModels
import Foundation

/// WallLabel is a struct describing structured wall label data and geolocation data for an image of an object.
@Generable(description: "Metadata properties for a wall label depicting a museum object")
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
    
    /// The Unix timestamp when a photo of an object was captured.
    @Guide(description: "Ignore this property")
    var timestamp: Int?
    
    /// The latitude location coordinate of the camera capturing a photo of an object.
    @Guide(description: "Ignore this property")
    var latitude: Float64?
    
    /// The longitude location coordinate of the camera capturing a photo of an object.
    @Guide(description: "Ignore this property")
    var longitude: Float64?
    
    /// The raw text of a wall label that was parsed in to a WallLabel struct
    @Guide(description: "Ignore this property")
    var input: String
    
    init(_ raw: String) {
        input = raw
    }
 
    // This doesn't work yet because of concurrency issues
    
    /*
    public mutating func Parse() async -> Result<Void, Error> {
        
        let instructions = """
            Parse this text as though it were a wall label in a museum describing an object.
            Wall labels are typically structured as follows: name, date, creator, location, media, creditline and accession number. Usually each property is on a separate line but sometimes, in the case of name and date, they will be combined on the same line. Some properties, like creator, location and media are not always present. Sometimes titles may have leading numbers, Lfollowed by a space, indicating acting as a key between the wall label and the surface the object is mounted on. Remove these numbers if present.
            """
        
        let session = LanguageModelSession(instructions: instructions)
        
        do {
            let response = try await session.respond(
                to: input,
                generating: WallLabel.self
            )
            
            title = response.content.title
            date = response.content.date
            creator = response.content.creator
            location = response.content.location
            accession_number = response.content.accession_number
            medium = response.content.medium
            creditline = response.content.creditline
            
            return .success(())
        } catch {
            return .failure(error)
        }
    }
    */
    
    /// Return the ordered list of keys  to display in a UITableView.
    public func displayKeys() -> [String] {
        
        let keys: [String] = [
            "title",
            "date",
            "creator",
            "location",
            "medium",
            "creditline",
            "accession_number",
            "latitude",
            "longitude",
            "timestamp",
            "input",
        ]
        return keys
    }
    
    /// Function to update (or not) a given property
    public mutating func setProperty(key: String, value: Any) -> Bool {
        
            switch(key) {
            case "title":
                self.title = "\(value)"
            case "date":
                self.date = "\(value)"
            case "creator":
                self.creator = "\(value)"
            case "medium":
                self.medium = "\(value)"
            case "location":
                self.location = "\(value)"
            case "creditline":
                self.creditline = "\(value)"
            case "accession_number":
                self.accession_number = "\(value)"
            /*
            case "latitude":
                self.latitude = value as? Float64
            case "longitude":
                self.longitude = value as? Float64
            case "created":
                self.timestamp = value as? Int
            */
            default:
                return false
            }
            
        return true
        
    }
    
    /// Boolean method signaling whether a given key's value may be edited.
    public func isKeyEditable(key: String) -> Bool {
        
        switch (key) {
        case "title", "date", "creator", "medium", "location", "creditline":
            return true
        default:
            return false
        }
    }
    
    /// Encode the WallLabel instance as JSON.
    public func marshalJSON() -> Result<Data, Error> {
        
        let encoder = JSONEncoder()
        // encoder.outputFormatting = .prettyPrinted
        
        do {
            let enc = try encoder.encode(self)
            return .success(enc)
        } catch {
            return .failure(error)
        }
    }
}
