# Registrar

Experimental iOS application for gathering exhibition object photos and wall label data and embedding the latter in the `UserComment` EXIF tag of the former.

## Motivation

This is an experimental iOS application for gathering exhibition object photos and wall label data and embedding the latter in the `UserComment` EXIF tag of the former. The idea is to use the `DataScanner` and `FoundationModel` frameworks to scan and then convert camera-imagery of wall label text in to structured data (embedding it in one or more photos).

The idea is to speed up data collection for use in generating embeddings or other ML-related products (LLMs) to allow causual in-terminal photos to be paired with the canonical record for that object using ML/AI techniques.

The data collection piece _mostly_ works. What that means is that photo capture, data scanning (mostly), list views, EXIF updates and saving photos to the device all work. The `FoundationModel` piece to convert the scanned data (text) in to structured data only sometimes works. When it doesn't work there are no errors triggered or reported but the on-device models are unable to derive any structured data.

While the data scanning framework is generally stable I have observed that from time to time is will just stop returning text that it has scanned to the application using it.  Processing scanned data on an recent (2023-ish) iPad mini takes a noticeable amount of time, usually measured in seconds.

Maybe better results could be optained by using a [FoundationModel adapter](https://developer.apple.com/apple-intelligence/foundation-models-adapter/) but the same data and prompt (instructions) used to convert text data in to structured data seems to work fine using other models, like `Ollama:devstral` or `llama.cpp:gpt-oss-20b-GGUF`. For example (using `llama.cpp:gpt-oss-20b-GGUF`):

```
Parse the following text as though it were a museum wall label in to unique key value pairs denoting the properties of the wall label, such as: title, date, location, creator, medium, accession number. Keep in mind that their may be other properties as well. Here is the text in question: "Virgin America flight attendant uniform 2007
cotton, polyester, plastic, wool, metal
Collection of SFO Museum Gift of Sirena Lam
Belt: gift of Lisa Larsen
2018.071.017, 2019.032.012, 013, 015, 019
L2023.1401.072-.076"

{
  "title": "Virgin America flight attendant uniform",
  "date": "2007",
  "medium": ["cotton","polyester","plastic","wool","metal"],
  "item_type": "Uniform",
  "collection": "SFO Museum",
  "provenance": "Gift of Sirena Lam",
  "belt_provenance": "Gift of Lisa Larsen",
  "accession_numbers": [
    "2018.071.017",
    "2019.032.012",
    "2018.071.013",
    "2018.071.015",
    "2018.071.019",
    "L2023.1401.072-076"
  ],
  "location": "San Francisco International Airport Museum",
  "creator": "Virgin America",
  "notes": "Includes belt component"
}
```

_This also works with smaller models like `Qwen_Qwen3-1.7B-GGUF_Qwen3-1.7B-Q8_0.gguf` (described below)._

## llama.cpp

There is a separate `llama-cpp` branch with code to use the [llama.cpp XCFramework Swift bindings](https://github.com/ggml-org/llama.cpp?tab=readme-ov-file#xcframework) with an on-device llama.cpp-compatible model copied to the application's Documents folder.

This work compiles and accepts (canned) prompts but, as of this writing, returns gibberish. I suspect this is because I am "doing it wrong" but I have yet to untangle how the llama.cpp code needs to be structured. When the goal is, when using the same model run behind the `llama-server` tool (for example: `Qwen_Qwen3-1.7B-GGUF_Qwen3-1.7B-Q8_0.gguf`), to produce output like this:

```
Parse this text as though it were a wall label in a museum describing an object in to a JSON dictionary of descriptive key-value pairs. Wall labels are typically structured as follows: name, date, creator, location, media, creditline and accession number. Usually each property is on a separate line but sometimes, in the case of name and date, they will be combined on the same line. Some properties, like creator, location and media are not always present. Sometimes titles may have leading numbers, followed by a space, acting as a key between the wall label and the surface the object is mounted on. Remove these numbers if present. This is text in question: Virgin America flight attendant uniform 2007
cotton, polyester, plastic, wool, metal
Collection of SFO Museum Gift of Sirena Lam
Belt: gift of Lisa Larsen
2018.071.017, 2019.032.012, 013, 015, 019
L2023.1401.072-.076

{
"name": "Virgin America flight attendant uniform",
"date": "2007",
"creator": "",
"location": "Collection of SFO Museum Gift of Sirena Lam",
"media": "cotton, polyester, plastic, wool, metal",
"creditline": "Collection of SFO Museum Gift of Sirena Lam",
"accession numbers": ["2018.071.017", "2019.032.012", "013", "015", "019", "L2023.1401.072-.076"]
}
```

## Related

* [sfomuseum/go-registrar](https://github.com/sfomuseum/go-registrar) - Tools for extracting data written to the `UserComment` EXIF tag in photos exported by the `Registrar` application.

## See also

* https://developer.apple.com/documentation/technologyoverviews/foundation-models/
* https://developer.apple.com/documentation/visionkit/datascannerviewcontroller
* https://developer.apple.com/documentation/photokit
* https://developer.apple.com/documentation/corelocation/