// Prints the mean luminance of a PNG, 0…1, so the capture script can tell the
// black launch screen from a real frame.
//
//   swift tools/png-brightness.swift <in.png>
//
// Exits 1 when the image is darker than the threshold passed as the second
// argument (default 0.2) or when no threshold is given and the frame is
// uniformly dark.

import CoreGraphics
import Foundation
import ImageIO

let args = CommandLine.arguments
guard args.count >= 2 else {
    FileHandle.standardError.write(Data("usage: png-brightness <in.png> [threshold]\n".utf8))
    exit(2)
}
let threshold = args.count >= 3 ? Double(args[2]) ?? 0.2 : 0.2

guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: args[1]) as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
    FileHandle.standardError.write(Data("cannot read \(args[1])\n".utf8))
    exit(1)
}

// A small thumbnail is plenty: only the overall lightness matters here.
let width = 64
let height = 64
var pixels = [UInt8](repeating: 0, count: width * height * 4)
guard let context = pixels.withUnsafeMutableBytes({ buffer in
    CGContext(
        data: buffer.baseAddress, width: width, height: height,
        bitsPerComponent: 8, bytesPerRow: width * 4,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )
}) else {
    exit(1)
}
context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

var total = 0.0
for index in stride(from: 0, to: pixels.count, by: 4) {
    let r = Double(pixels[index]) / 255
    let g = Double(pixels[index + 1]) / 255
    let b = Double(pixels[index + 2]) / 255
    total += 0.2126 * r + 0.7152 * g + 0.0722 * b
}
let mean = total / Double(width * height)
print(String(format: "%.3f", mean))
exit(mean < threshold ? 1 : 0)
