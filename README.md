# Registrar

Experimental iOS application for gathering exhibition object photos and wall label data and embedding the latter in the `UserComment` EXIF tag of the former.

## Motivation

This is an experimental iOS application for gathering exhibition object photos and wall label data and embedding the latter in the `UserComment` EXIF tag of the former. The idea is to use the `DataScanner` and `FoundationModel` frameworks to scan and then convert camera-imagery of wall label text in to structured data (embedding it in one or more photos).

The idea is to speed up data collection for use in generating embeddings or other ML-related products (LLMs) to allow causual in-terminal photos to be paired with the canonical record for that object using ML/AI techniques.

The data collection piece _mostly_ works (as of August 2025). What that means is that photo capture, data scanning (mostly), list views, EXIF updates and saving photos to the device all work. The `FoundationModel` piece to convert the scanned data (text) in to structured data only sometimes works. When it doesn't work there are no errors triggered or reported but the on-device models are unable to derive any structured data.

While the data scanning framework is generally stable I have observed that from time to time is will just stop returning text that it has scanned to the application using it.

Given that iPadOS 26 and the `FoundationModel` model are still in beta it is unclear whether these problems are caused by resource contrainsts on the device (an 11" iPad mini), in the OS (iPad OS 26b6), in the model itself or some combination of all of the above.

The same data and prompt (instructions) used to convert text data in to structured data seems to work fine using other models, for example `Ollama:devstral` or `llama.cpp:gpt-oss-20b-GGUF`. For example (using `llama.cpp:gpt-oss-20b-GGUF`):

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

That is the state of things as of this writing. Possible next steps include:

* Simply waiting for iPadOS26 is released and seeing if that fixes the problem (whatever "the problem" is...)
* Getting feedback from someone at Apple (unlikely)
* Trying to build the application using the [llama.cpp XCFramework](https://github.com/ggml-org/llama.cpp?tab=readme-ov-file#xcframework) which feels like it might become an exercise in "yak-shaving"...

Depending on how the pipeline for generating ML embeddings and other related byproducts is structured it may be enough to remove, or disable, the on-device ML and simply derive structured data in a separate server-side piece after the imagery has been collected. This remains to be determined. 

## See also

* [sfomuseum/go-registrar](https://github.com/sfomuseum/go-registrar) - Tools for extracting data written to the `UserComment` EXIF tag in photos exported by the `Registrar` application.