import Foundation

@main
struct HIDDescriptorTests {
    static func main() {
        var tests = 0
        func check(_ condition: @autoclosure () -> Bool, _ message: String) {
            guard condition() else { fatalError(message) }
            tests += 1
        }
        // Boot keyboard: 8 input bytes, 5 LED bits plus 3 padding output bits.
        let keyboard: [UInt8] = [
            0x05,0x01,0x09,0x06,0xA1,0x01,0x05,0x07,0x19,0xE0,0x29,0xE7,
            0x15,0x00,0x25,0x01,0x75,0x01,0x95,0x08,0x81,0x02,
            0x95,0x01,0x75,0x08,0x81,0x01,
            0x95,0x05,0x75,0x01,0x05,0x08,0x19,0x01,0x29,0x05,0x91,0x02,
            0x95,0x01,0x75,0x03,0x91,0x01,
            0x95,0x06,0x75,0x08,0x15,0x00,0x25,0x65,0x05,0x07,0x19,0x00,0x29,0x65,0x81,0x00,0xC0
        ]
        let boot = summarizeHIDDescriptor(Data(keyboard))
        check(boot.warnings.isEmpty, "Valid boot descriptor should parse completely")
        check(boot.reports.count == 2, "Input and output must remain separate")
        check(boot.reports[0]["payload_bytes"] as? UInt64 == 8, "Input fields accumulate, including padding")
        check(boot.reports[1]["payload_bits"] as? UInt64 == 8, "Output padding must count")
        check(boot.collections[0]["usage_page"] as? UInt64 == 1, "Collection usage page")
        check(boot.collections[0]["usage"] as? UInt64 == 6, "Collection usage")
        check(boot.reports[0]["wire_bytes_including_report_id"] as? UInt64 == 8, "ID zero has no wire prefix")
        let numbered = summarizeHIDDescriptor(Data([0x85,0x05,0x75,0x08,0x96,0x00,0x01,0xB1,0x02]))
        check(numbered.reports[0]["payload_bytes"] as? UInt64 == 256, "16-bit Report Count")
        check(numbered.reports[0]["wire_bytes_including_report_id"] as? UInt64 == 257, "Numbered report prefix")
        check(numbered.reports[0]["report_id"] as? UInt64 == 5, "Feature report ID")
        let pushed = summarizeHIDDescriptor(Data([0x75,0x08,0x95,0x02,0xA4,0x75,0x01,0x95,0x01,0x81,0x02,0xB4,0x81,0x02]))
        check(pushed.reports[0]["payload_bits"] as? UInt64 == 17, "Global PUSH/POP restores size/count")
        check(pushed.reports[0]["payload_bytes"] as? UInt64 == 3, "Round up only after aggregating fields")
        check(!summarizeHIDDescriptor(Data([0x75])).warnings.isEmpty, "Truncated item rejected")
        check(!summarizeHIDDescriptor(Data([0xFE,0x05,0x01])).warnings.isEmpty, "Truncated long item rejected")
        check(!summarizeHIDDescriptor(Data([0xFE,0x01,0x01,0x00])).warnings.isEmpty, "Long item cannot silently mark summary complete")
        check(!summarizeHIDDescriptor(Data([0xB4])).warnings.isEmpty, "Stack underflow reported")
        check(!summarizeHIDDescriptor(Data([0xC0])).warnings.isEmpty, "Collection underflow reported")
        check(!summarizeHIDDescriptor(Data([0xA1,0x01])).warnings.isEmpty, "Unclosed collection reported")
        check(!summarizeHIDDescriptor(Data([0x85,0x00])).warnings.isEmpty, "Explicit ID zero invalid")
        let overflow = summarizeHIDDescriptor(Data([0x77,0xFF,0xFF,0xFF,0xFF,0x97,0xFF,0xFF,0xFF,0xFF,0x81,0x02]))
        check(!overflow.warnings.isEmpty, "Host-size overflow must not crash")
        let extended = summarizeHIDDescriptor(Data([0x05,0x01,0x0B,0x02,0x00,0x00,0xFF,0xA1,0x01,0xC0]))
        check(extended.collections[0]["usage_page"] as? UInt64 == 0xFF00, "32-bit usage carries own page")
        // Distinct vendor collections, including a nested collection and one shared report ID.
        let vendorCollections = summarizeHIDDescriptor(Data([
            0x06,0x00,0xFF,0x09,0x01,0xA1,0x01,
            0x85,0x05,0x75,0x08,0x95,0x02,0xB1,0x02,
            0x09,0x03,0xA1,0x00,0x85,0x06,0xB1,0x02,0xC0,0xC0,
            0x06,0x02,0xFF,0x09,0x02,0xA1,0x01,
            0x85,0x09,0xB1,0x02,0x85,0x05,0xB1,0x02,0xC0
        ]))
        func vendorReport(_ id: UInt64) -> [String: Any] {
            vendorCollections.reports.first { $0["report_id"] as? UInt64 == id }!
        }
        let fiveCollections = vendorReport(5)["top_level_collections"] as! [[String: Any]]
        let sixCollections = vendorReport(6)["top_level_collections"] as! [[String: Any]]
        let nineCollections = vendorReport(9)["top_level_collections"] as! [[String: Any]]
        check(vendorCollections.warnings.isEmpty, "Vendor collection descriptor parses")
        check(nineCollections.count == 1 && nineCollections[0]["usage_page"] as? UInt64 == 0xFF02,
              "Feature 9 belongs to FF02, not neighboring FF00")
        check(nineCollections[0]["usage"] as? UInt64 == 2, "Feature 9 top-level usage")
        // Offset is the COLLECTION item (0xA1), not the preceding usage value byte.
        check(nineCollections[0]["index"] as? Int == 2 && nineCollections[0]["offset"] as? Int == 30,
              "Collection index and descriptor offset locate the exact declaration")
        check(sixCollections.count == 1 && sixCollections[0]["usage_page"] as? UInt64 == 0xFF00,
              "Nested collection associates report with its top-level collection")
        check(sixCollections[0]["usage"] as? UInt64 == 1, "Nested usage does not replace top-level usage")
        check(fiveCollections.count == 2 && vendorReport(5)["payload_bytes"] as? UInt64 == 4,
              "Report shared by collections retains all owners and aggregated size")
        check(numbered.reports[0]["has_fields_outside_collection"] as? Bool == true,
              "Missing collection is explicit rather than inferred")
        let json = try! JSONSerialization.data(withJSONObject: boot.json, options: [.sortedKeys])
        check((try! JSONSerialization.jsonObject(with: json)) is [String: Any], "Summary serializes as JSON")
        if CommandLine.arguments.count == 2 {
            let cliData = try! Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
            let cliJSON = try! JSONSerialization.jsonObject(with: cliData) as! [String: Any]
            let cliReports = cliJSON["reports"] as! [[String: Any]]
            check(cliReports[0]["payload_bytes"] as? Int == 64, "CLI reads binary descriptors")
            check(cliReports[0]["report_id"] as? Int == 5, "CLI JSON preserves report ID")
        }
        print("PASS: \(tests) offline descriptor assertions")
    }
}
