import Foundation

/// Offline framing for the S98 image upload observed on 2026-10-01.
/// Payloads are the 519 bytes passed to sendFeatureReport; the report ID 9 stays outside.
/// Nothing in this type opens a device.
enum TftUpload {
    static let width = 320
    static let height = 172
    static let payloadBytes = 519
    static let blockBytes = 512
    static let reportID: UInt8 = 9

    struct Sequence {
        var start: Data
        var blocks: [Data]
        var end: Data
    }

    /// Connection packet observed once, before the image, not repeated at save time.
    static func passwordPayload() -> Data {
        var payload = Data(repeating: 0, count: payloadBytes)
        payload[0] = 0x82
        payload[1] = 0x01
        payload[3] = 0x01
        payload[5] = 0x0A
        return payload
    }

    static func rgb565(red: UInt8, green: UInt8, blue: UInt8) -> (UInt8, UInt8) {
        let value = (UInt16(red >> 3) << 11) | (UInt16(green >> 2) << 5) | UInt16(blue >> 3)
        return (UInt8(value >> 8), UInt8(value & 0xFF))
    }

    static func solidRGB565(red: UInt8, green: UInt8, blue: UInt8) -> Data {
        let pixel = rgb565(red: red, green: green, blue: blue)
        var frame = Data(count: width * height * 2)
        for offset in stride(from: 0, to: frame.count, by: 2) {
            frame[offset] = pixel.0
            frame[offset + 1] = pixel.1
        }
        return frame
    }

    /// One still frame, matching the red upload: start, 215 data blocks, end.
    /// The last block keeps its pixels but declares length 0, as the official driver did
    /// when the frame divides evenly by 512. The checksum covers the pixels placed in
    /// the packet; the all-red capture cannot tell that apart from a sum over length 0.
    static func uploadPayloads(rgb565 frame: Data) throws -> Sequence {
        let expected = width * height * 2
        guard frame.count == expected else {
            throw TftEncodingError(description: "RGB565 frame must be \(expected) bytes, got \(frame.count)")
        }
        guard expected.isMultiple(of: blockBytes) else {
            throw TftEncodingError(description: "Frame is not a whole number of \(blockBytes)-byte blocks")
        }
        let blockCount = expected / blockBytes
        guard blockCount <= 256 else {
            throw TftEncodingError(description: "Block index does not fit in one byte")
        }
        var blocks: [Data] = []
        blocks.reserveCapacity(blockCount)
        for index in 0..<blockCount {
            let range = (index * blockBytes)..<((index + 1) * blockBytes)
            let declaredLength = index == blockCount - 1 ? 0 : blockBytes
            blocks.append(dataPacket(blockIndex: index, pixels: frame.subdata(in: range), declaredLength: declaredLength))
        }
        return Sequence(
            start: controlPacket(mode: 1, frameCount: 1),
            blocks: blocks,
            end: controlPacket(mode: 0, frameCount: 1)
        )
    }

    private static func controlPacket(mode: UInt8, frameCount: UInt8) -> Data {
        var payload = Data(repeating: 0, count: payloadBytes)
        payload[0] = 0x0D
        payload[3] = 0x01
        payload[5] = 0x05
        payload[7] = mode << 6
        payload[8] = frameCount
        return payload
    }

    private static func dataPacket(blockIndex: Int, pixels: Data, declaredLength: Int) -> Data {
        var payload = Data(repeating: 0, count: payloadBytes)
        payload[0] = 0x0C
        payload[3] = UInt8(blockIndex)
        payload[4] = checksum(pixels)
        payload[5] = UInt8(declaredLength & 0xFF)
        payload[6] = UInt8((declaredLength >> 8) & 0xFF)
        payload.replaceSubrange(7..<(7 + pixels.count), with: pixels)
        return payload
    }

    private static func checksum(_ pixels: Data) -> UInt8 {
        pixels.reduce(0) { $0 &+ $1 }
    }
}

struct TftEncodingError: Error, CustomStringConvertible {
    let description: String
}
