import Foundation
import IOKit

struct RegistryInspectionError: Error, CustomStringConvertible {
    let description: String
}

/// Uses only cached IORegistry metadata. No device open, event subscription or HID transaction.
struct RegistryInspector {
    let vendorID: Int
    let includeIdentifiers: Bool
    private let keys = [
        "VendorID", "ProductID", "VersionNumber", "Manufacturer", "Product", "Transport",
        "PrimaryUsagePage", "PrimaryUsage", "DeviceUsagePairs", "MaxInputReportSize",
        "MaxOutputReportSize", "MaxFeatureReportSize", "ReportInterval", "LocationID",
        "CountryCode", "BootProtocol", "bInterfaceNumber", "bAlternateSetting",
        "bInterfaceClass", "bInterfaceSubClass", "bInterfaceProtocol", "bNumEndpoints",
        "idVendor", "idProduct", "bcdDevice", "bcdUSB", "bDeviceClass", "bDeviceSubClass",
        "bDeviceProtocol", "bNumConfigurations", "bConfigurationValue", "bmAttributes",
        "bMaxPower", "USB Product Name", "USB Vendor Name", "locationID",
        "Device Speed", "USB Address", "ReportDescriptor", "USB Device Descriptor",
        "USB Configuration Descriptor", "bEndpointAddress", "bmAttributes", "wMaxPacketSize", "bInterval"
    ]

    private func properties(_ entry: io_registry_entry_t) throws -> [String: Any] {
        var reference: Unmanaged<CFMutableDictionary>?
        let status = IORegistryEntryCreateCFProperties(entry, &reference, kCFAllocatorDefault, 0)
        guard status == KERN_SUCCESS, let reference else {
            throw RegistryInspectionError(description: "IORegistry property read failed: \(status)")
        }
        return reference.takeRetainedValue() as NSDictionary as? [String: Any] ?? [:]
    }

    private func normalized(_ value: Any) -> Any {
        if let data = value as? Data { return ["hex": data.map { String(format: "%02x", $0) }.joined(), "byte_count": data.count] }
        if let dictionary = value as? [String: Any] { return dictionary.mapValues(normalized) }
        if let array = value as? [Any] { return array.map(normalized) }
        if value is String || value is NSNumber { return value }
        return String(describing: value)
    }

    private func record(_ entry: io_registry_entry_t, properties: [String: Any]) -> [String: Any] {
        var identifier: UInt64 = 0
        let idStatus = IORegistryEntryGetRegistryEntryID(entry, &identifier)
        var name = [CChar](repeating: 0, count: 128)
        let nameStatus = IORegistryEntryGetName(entry, &name)
        var path = [CChar](repeating: 0, count: 4096)
        let pathStatus = IORegistryEntryGetPath(entry, kIOServicePlane, &path)
        var selected: [String: Any] = [:]
        for key in keys {
            if !includeIdentifiers && ["LocationID", "locationID", "USB Address"].contains(key) { continue }
            if let value = properties[key] { selected[key] = normalized(value) }
        }
        if includeIdentifiers {
            for key in ["SerialNumber", "USB Serial Number", "iSerialNumber"] {
                if let value = properties[key] { selected[key] = normalized(value) }
            }
        }
        var output: [String: Any] = ["properties": selected]
        if includeIdentifiers && idStatus == KERN_SUCCESS { output["registry_entry_id"] = String(identifier) }
        if nameStatus == KERN_SUCCESS { output["registry_name"] = String(cString: name) }
        if includeIdentifiers && pathStatus == KERN_SUCCESS { output["registry_path"] = String(cString: path) }
        if let descriptor = properties["ReportDescriptor"] as? Data {
            output["report_descriptor_summary"] = summarizeHIDDescriptor(descriptor).json
        }
        return output
    }

    func inspect() throws -> [String: Any] {
        var iterator: io_iterator_t = 0
        let status = IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOHIDDevice"), &iterator)
        guard status == KERN_SUCCESS else {
            throw RegistryInspectionError(description: "IOHIDDevice enumeration failed: \(status)")
        }
        defer { IOObjectRelease(iterator) }
        var matches: [[String: Any]] = []
        var warnings: [String] = []
        while true {
            let service = IOIteratorNext(iterator)
            if service == 0 { break }
            defer { IOObjectRelease(service) }
            let values: [String: Any]
            do { values = try properties(service) }
            catch { warnings.append(String(describing: error)); continue }
            guard (values["VendorID"] as? NSNumber)?.intValue == vendorID else { continue }
            var item = record(service, properties: values)
            item["snapshot_service_index"] = matches.count + 1
            item["identity_status"] = "Vendor match only; physical model and TFT interface not confirmed"
            var ancestry: [[String: Any]] = []
            var current = service
            var owned = false
            // Ancestors stop at the USB device; never dump unrelated machine properties.
            for _ in 0..<12 {
                var parent: io_registry_entry_t = 0
                let result = IORegistryEntryGetParentEntry(current, kIOServicePlane, &parent)
                if owned { IOObjectRelease(current) }
                owned = false
                if result != KERN_SUCCESS { break }
                current = parent
                owned = true
                do {
                    let parentValues = try properties(parent)
                    ancestry.append(record(parent, properties: parentValues))
                    if IOObjectConformsTo(parent, "IOUSBHostDevice") != 0 || IOObjectConformsTo(parent, "IOUSBDevice") != 0 { break }
                } catch { warnings.append(String(describing: error)); break }
            }
            if owned { IOObjectRelease(current) }
            item["ancestors"] = ancestry
            if values["ReportDescriptor"] == nil {
                item["descriptor_status"] = "Not published on this HID service; inspect ancestors, no active fallback"
            }
            matches.append(item)
        }
        matches.sort { String(describing: $0["registry_entry_id"] ?? "") < String(describing: $1["registry_entry_id"] ?? "") }
        return ["schema_version": 1, "mode": "read-only-cached-registry",
                "timestamp_utc": ISO8601DateFormatter().string(from: Date()),
                "host_os": ProcessInfo.processInfo.operatingSystemVersionString,
                "vendor_filter": String(format: "0x%04X", vendorID), "identifiers_included": includeIdentifiers,
                "matching_hid_service_count": matches.count, "hid_services": matches, "warnings": warnings,
                "limitations": ["Registry snapshot, not a complete USB descriptor capture",
                    "No device opened; no input, output or feature reports requested or sent",
                    "Report IDs and sizes describe declared formats, not TFT command semantics",
                    "Endpoint descriptors may not be published in IORegistry",
                    "Missing entries can mean disconnected device, different VID or unavailable registry metadata"]]
    }
}
