import FoundationModels

@Generable(description: "Metadata properties for a wall label depicting a museum object")
struct WallLabel: Codable {
    @Guide(description: "The title or name of the object. Sometimes titles may have leading numbers, followed by a space, indicating acting as a key between the wall label and the surface the object is mounted on. Remove these numbers if present.")
    var title: String

    @Guide(description: "The year that an object was created")
    var date: Int

    @Guide(description: "The individual or organization responsible for creating an object.")
    var creator: String
    
    @Guide(description: "The name of an individual, persons or organization who donated or are lending an object.")
    var creditline: String
    
    @Guide(description: "The location that an object was produced in.")
    var location: String
    
    @Guide(description: "The medium or media used to create the object.")
    var medium: String
    
    @Guide(description: "The unique identifier for an object.")
    var accession_number: String
    
    @Guide(description: "Ignore this property")
    var timestamp: Int
    
    @Guide(description: "Ignore this property")
    var latitude: Float64
    
    @Guide(description: "Ignore this property")
    var longitude: Float64
    
    @Guide(description: "Ignore this property")
    var input: String
}
