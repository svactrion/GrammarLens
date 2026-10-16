// Read-only OCR evidence for actual native screenshots. No image modification.
import Foundation
import Vision
import ImageIO

var records: [[String: Any]] = []
for path in CommandLine.arguments.dropFirst() {
    let url = URL(fileURLWithPath: path)
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.recognitionLanguages = ["en-US"]
    request.usesLanguageCorrection = false
    try VNImageRequestHandler(url: url).perform([request])
    let lines = (request.results ?? []).compactMap { result -> [String: Any]? in
        guard let text = result.topCandidates(1).first else { return nil }
        let b = result.boundingBox
        return ["text": text.string, "confidence": text.confidence,
                "x": b.minX, "y": b.minY, "width": b.width, "height": b.height]
    }
    records.append(["file": url.lastPathComponent, "lines": lines])
}
let json = try JSONSerialization.data(withJSONObject: records, options: [.prettyPrinted, .sortedKeys])
FileHandle.standardOutput.write(json)
