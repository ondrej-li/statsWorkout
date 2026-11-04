// Mean absolute luminance difference between two PNGs, 0…1.
//
//   swift tools/png-difference.swift <a.png> <b.png> [max]
//
// The capture script takes two frames a moment apart and keeps the second only
// when both look the same, which means the screen has settled: no launch screen,
// no skeleton cards and no scroll animation mid-flight. Exits 1 when the
// difference exceeds `max` (default 0.004).

import CoreGraphics
import Foundation
import ImageIO

let args = CommandLine.arguments
guard args.count >= 3 else {
    FileHandle.standardError.write(Data("usage: png-difference <a.png> <b.png> [max]\n".utf8))
    exit(2)
}
let maxDifference = args.count >= 4 ? Double(args[3]) ?? 0.004 : 0.004

func luminance(_ path: String, width: Int, height: Int) -> [Double]? {
    guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    guard let context = pixels.withUnsafeMutableBytes({ buffer in
        CGContext(
            data: buffer.baseAddress, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
    }) else { return nil }
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

    var values = [Double](repeating: 0, count: width * height)
    for index in 0..<(width * height) {
        let offset = index * 4
        values[index] = (0.2126 * Double(pixels[offset])
            + 0.7152 * Double(pixels[offset + 1])
            + 0.0722 * Double(pixels[offset + 2])) / 255
    }
    return values
}

// 200 x 200 keeps thin text visible while smoothing away antialiasing noise.
let width = 200
let height = 200
guard let a = luminance(args[1], width: width, height: height),
      let b = luminance(args[2], width: width, height: height) else {
    FileHandle.standardError.write(Data("cannot read both images\n".utf8))
    exit(1)
}

let difference = zip(a, b).reduce(0.0) { $0 + abs($1.0 - $1.1) } / Double(a.count)
print(String(format: "%.5f", difference))
exit(difference <= maxDifference ? 0 : 1)
