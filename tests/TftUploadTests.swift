import Foundation

@main
struct TftUploadTests {
    static func main() {
        var tests = 0
        func check(_ condition: @autoclosure () -> Bool, _ message: String) {
            guard condition() else { fatalError(message) }
            tests += 1
        }
        func hex(_ data: Data, _ count: Int) -> String {
            data.prefix(count).map { String(format: "%02x", $0) }.joined()
        }
        func tailIsZero(_ data: Data, from index: Int) -> Bool {
            data.dropFirst(index).allSatisfy { $0 == 0 }
        }

        let redPixel = TftUpload.rgb565(red: 255, green: 0, blue: 0)
        check(redPixel == (0xF8, 0x00), "Pure red is RGB565 F800")
        check(TftUpload.rgb565(red: 0, green: 255, blue: 0) == (0x07, 0xE0), "Pure green is 07E0")
        check(TftUpload.rgb565(red: 0, green: 0, blue: 255) == (0x00, 0x1F), "Pure blue is 001F")
        check(TftUpload.rgb565(red: 255, green: 255, blue: 255) == (0xFF, 0xFF), "White is FFFF")

        let password = TftUpload.passwordPayload()
        check(password.count == 519, "Password payload is 519 bytes")
        check(hex(password, 6) == "82010001000a", "Password header matches the connect capture")
        check(tailIsZero(password, from: 6), "Password payload is zero after the header")

        let red = TftUpload.solidRGB565(red: 255, green: 0, blue: 0)
        check(red.count == 110_080, "320x172 RGB565 is 110080 bytes")
        let upload = try! TftUpload.uploadPayloads(rgb565: red)
        check(upload.blocks.count == 215, "The red frame is 215 blocks")
        check(upload.start.count == 519 && upload.end.count == 519, "Control payloads are 519 bytes")
        check(upload.blocks.allSatisfy { $0.count == 519 }, "Every data payload is 519 bytes")
        check(hex(upload.start, 11) == "0d00000100050040010000", "Start control matches the capture")
        check(tailIsZero(upload.start, from: 11), "Start control is zero after the header")
        check(hex(upload.end, 11) == "0d00000100050000010000", "End control uses mode 0 and one frame")
        check(hex(upload.blocks[0], 9) == "0c000000000002f800", "Block 0 header and first red pixel")
        check(hex(upload.blocks[1], 9) == "0c000001000002f800", "Block 1 keeps the index in one byte")
        check(hex(upload.blocks[16], 9) == "0c000010000002f800", "Block 16 is index 0x10, not a 16-bit field")
        check(hex(upload.blocks[214], 9) == "0c0000d6000000f800", "Last block declares length 0 and still carries pixels")
        check(upload.blocks[214][5] == 0 && upload.blocks[214][6] == 0, "Declared length is the zero field")
        let lastPixels = upload.blocks[214].dropFirst(7)
        check(lastPixels.count == 512 && lastPixels.allSatisfy { $0 == 0xF8 || $0 == 0x00 }, "Last block is filled")
        check(stride(from: 0, to: 512, by: 2).allSatisfy { lastPixels[lastPixels.startIndex + $0] == 0xF8 }, "Red high bytes survive")
        check(!upload.blocks.contains { $0.first == 0x09 }, "Report ID 9 is not a payload byte")

        var marked = Data(count: 110_080)
        marked[0] = 0x01
        marked[110_080 - 512] = 0x07
        let mixed = try! TftUpload.uploadPayloads(rgb565: marked)
        check(mixed.blocks[0][4] == 0x01, "Checksum sums the pixel bytes in the block")
        check(mixed.blocks[214][4] == 0x07, "Last-block checksum covers the placed pixels, not the zero length")
        check(mixed.blocks[1][4] == 0, "An empty block checksums to zero")

        do {
            _ = try TftUpload.uploadPayloads(rgb565: Data(count: 4))
            fatalError("Short frame accepted")
        } catch {
            tests += 1
        }
        print("PASS: \(tests) offline TFT upload assertions")
    }
}
