import Foundation
import IOKit
import IOKit.hid

/// One observed upload to the physical S98. Opens the TFT HID service without seizing it,
/// so the boot-keyboard interface keeps working. Feature reports use report ID 9.
enum TftTransport {
    static let vendorID = 0x258A
    static let productID = 0x022B
    private static let gap: TimeInterval = 0.2

    static func upload(frame: Data, onProgress: ((Int, Int) -> Void)? = nil) throws {
        let sequence = try TftUpload.uploadPayloads(rgb565: frame)
        let service = try matchingService()
        guard let created = IOHIDDeviceCreate(kCFAllocatorDefault, service) else {
            IOObjectRelease(service)
            throw TftEncodingError(description: "IOHIDDeviceCreate failed")
        }
        IOObjectRelease(service)
        let device = created
        let opened = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
        guard opened == kIOReturnSuccess else {
            let reason = opened == kIOReturnNotPermitted
                ? "not permitted. macOS Input Monitoring must allow the app that launches rk-s98"
                : String(format: "0x%08X", opened)
            throw TftEncodingError(description: "Open failed: \(reason)")
        }
        defer { IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone)) }

        let acks = InputAcks()
        acks.install(on: device)
        defer { acks.remove(from: device) }

        acks.arm()
        var sendTime = try send(TftUpload.passwordPayload(), to: device, label: "password")
        let reply = try readFeature(from: device)
        log("password response \(reply.count) bytes \(hex(reply.prefix(18)))")
        _ = acks.wait(timeout: gap)

        let started = Date()
        sendTime = 0
        acks.arm()
        sendTime += try send(sequence.start, to: device, label: "start")
        _ = acks.wait(timeout: gap)
        onProgress?(0, sequence.blocks.count)
        for (index, block) in sequence.blocks.enumerated() {
            acks.arm()
            sendTime += try send(block, to: device, label: "block \(index)")
            _ = acks.wait(timeout: gap)
            if index % 50 == 0 || index == sequence.blocks.count - 1 {
                log("block \(index + 1)/\(sequence.blocks.count)")
            }
            onProgress?(index + 1, sequence.blocks.count)
        }
        acks.arm()
        sendTime += try send(sequence.end, to: device, label: "end")
        _ = acks.wait(timeout: gap)
        let elapsed = Date().timeIntervalSince(started)
        log(String(format: "upload finished in %.2fs, setReport %.2fs, acks %d, ack mark %d, waits without ack %d",
                   elapsed, sendTime, acks.advances, acks.ackMark, acks.timeouts))
    }

    private static func matchingService() throws -> io_service_t {
        var iterator: io_iterator_t = 0
        let status = IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOHIDDevice"), &iterator)
        guard status == KERN_SUCCESS else {
            throw TftEncodingError(description: "HID enumeration failed: \(status)")
        }
        defer { IOObjectRelease(iterator) }
        var found: io_service_t = 0
        var matches = 0
        while true {
            let service = IOIteratorNext(iterator)
            if service == 0 { break }
            var reference: Unmanaged<CFMutableDictionary>?
            guard IORegistryEntryCreateCFProperties(service, &reference, kCFAllocatorDefault, 0) == KERN_SUCCESS,
                  let properties = reference?.takeRetainedValue() as? [String: Any] else {
                IOObjectRelease(service)
                continue
            }
            let vendor = (properties["VendorID"] as? NSNumber)?.intValue
            let product = (properties["ProductID"] as? NSNumber)?.intValue
            let feature = (properties["MaxFeatureReportSize"] as? NSNumber)?.intValue ?? 0
            if vendor == vendorID && product == productID && feature >= TftUpload.payloadBytes {
                matches += 1
                if found != 0 { IOObjectRelease(found) }
                found = service
            } else {
                IOObjectRelease(service)
            }
        }
        guard matches == 1, found != 0 else {
            if found != 0 { IOObjectRelease(found) }
            throw TftEncodingError(description: "Expected one \(String(format: "%04X:%04X", vendorID, productID)) TFT interface, found \(matches)")
        }
        return found
    }

    private static func send(_ payload: Data, to device: IOHIDDevice, label: String) throws -> TimeInterval {
        let started = Date()
        guard payload.count == TftUpload.payloadBytes else {
            throw TftEncodingError(description: "\(label) payload is \(payload.count) bytes")
        }
        var buffer = [UInt8](repeating: 0, count: payload.count + 1)
        buffer[0] = TftUpload.reportID
        for (offset, byte) in payload.enumerated() {
            buffer[offset + 1] = byte
        }
        var attempts = 0
        while true {
            let result = buffer.withUnsafeBufferPointer { pointer in
                IOHIDDeviceSetReport(device, kIOHIDReportTypeFeature, CFIndex(TftUpload.reportID), pointer.baseAddress!, buffer.count)
            }
            if result == kIOReturnSuccess { return Date().timeIntervalSince(started) }
            let busy = result == kIOReturnBusy || result == kIOReturnNotReady
            if busy && attempts < 40 {
                attempts += 1
                Thread.sleep(forTimeInterval: 0.005)
                continue
            }
            throw TftEncodingError(description: String(format: "%@ failed: 0x%08X", label, result))
        }
    }

    private static func readFeature(from device: IOHIDDevice) throws -> Data {
        var buffer = [UInt8](repeating: 0, count: 64)
        var length = CFIndex(buffer.count)
        let result = buffer.withUnsafeMutableBufferPointer { pointer in
            IOHIDDeviceGetReport(device, kIOHIDReportTypeFeature, CFIndex(TftUpload.reportID), pointer.baseAddress!, &length)
        }
        guard result == kIOReturnSuccess else {
            throw TftEncodingError(description: String(format: "Feature read failed: 0x%08X", result))
        }
        return Data(buffer.prefix(Int(length)))
    }

    private static func log(_ message: String) {
        FileHandle.standardError.write(Data("rk-s98: \(message)\n".utf8))
    }

    private static func hex(_ bytes: Data.SubSequence) -> String {
        bytes.map { String(format: "%02x", $0) }.joined()
    }
}

/// Listens for the block advance the official driver expects: report 9, payload byte 1 == 6 and byte 2 == 1.
private final class InputAcks {
    private let storage = UnsafeMutablePointer<UInt8>.allocate(capacity: 64)
    private var advance = false
    private(set) var advances = 0
    private(set) var ackMark = 0
    private var lastSequence: UInt8?
    private(set) var reports = 0
    private(set) var timeouts = 0
    private var logged = 0

    deinit { storage.deallocate() }

    func install(on device: IOHIDDevice) {
        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDDeviceRegisterInputReportCallback(device, storage, 64, { context, result, _, _, reportID, report, length in
            guard let context, result == kIOReturnSuccess else { return }
            let ack = Unmanaged<InputAcks>.fromOpaque(context).takeUnretainedValue()
            let count = max(0, Int(length))
            ack.receive(id: reportID, bytes: Array(UnsafeBufferPointer(start: report, count: count)))
        }, context)
        IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
    }

    func remove(from device: IOHIDDevice) {
        IOHIDDeviceRegisterInputReportCallback(device, storage, 64, nil, nil)
        IOHIDDeviceUnscheduleFromRunLoop(device, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
    }

    func arm() { advance = false }

    func waitUntil(advancesAtLeast target: Int, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while advances < target && Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.002))
        }
        if advances >= target { return true }
        timeouts += 1
        return false
    }

    func wait(timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !advance && Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.002))
        }
        if advance {
            advance = false
            return true
        }
        timeouts += 1
        return false
    }

    private func receive(id: UInt32, bytes: [UInt8]) {
        reports += 1
        if logged < 4 {
            logged += 1
            let hex = bytes.prefix(8).map { String(format: "%02x", $0) }.joined(separator: " ")
            FileHandle.standardError.write(Data("rk-s98: input id \(id) \(bytes.count) bytes \(hex)\n".utf8))
        }
        // The buffer starts with report ID 9. The driver's payload check is byte 1 == 6 and byte 2 == 1.
        guard id == 9, bytes.count >= 5, bytes[2] == 6, bytes[3] == 1 else { return }
        advances += 1
        advance = true
        noteSequence(bytes[4])
    }

    private func noteSequence(_ value: UInt8) {
        if let last = lastSequence {
            let delta = Int(value &- last)
            if delta > 0 && delta < 128 { ackMark += delta }
        } else {
            ackMark = Int(value)
        }
        lastSequence = value
    }
}
