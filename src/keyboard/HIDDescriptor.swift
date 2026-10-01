import Foundation

/// Offline structural summary, not a protocol decoder or device validator.
struct HIDDescriptorSummary {
    var reports: [[String: Any]] = []
    var collections: [[String: Any]] = []
    var warnings: [String] = []

    var json: [String: Any] {
        ["reports": reports, "collections": collections, "warnings": warnings,
         "complete": warnings.isEmpty]
    }
}

func summarizeHIDDescriptor(_ data: Data) -> HIDDescriptorSummary {
    struct Globals {
        var page: UInt64 = 0
        var size: UInt64 = 0
        var count: UInt64 = 0
        var id: UInt64 = 0
    }
    let bytes = [UInt8](data)
    var result = HIDDescriptorSummary()
    var globals = Globals()
    var stack: [Globals] = []
    var localUsage: UInt64?
    var bits: [String: UInt64] = [:]
    var ids: [String: UInt64] = [:]
    var kinds: [String: String] = [:]
    var reportCollections: [String: Set<Int>] = [:]
    var reportsOutsideCollections: Set<String> = []
    var topLevelCollectionIndex: Int?
    var depth = 0
    var offset = 0
    while offset < bytes.count {
        let start = offset
        let prefix = bytes[offset]
        offset += 1
        if prefix == 0xFE {
            guard offset + 2 <= bytes.count else {
                result.warnings.append("Truncated long-item header at \(start)")
                break
            }
            let length = Int(bytes[offset])
            offset += 2
            guard offset + length <= bytes.count else {
                result.warnings.append("Truncated long item at \(start)")
                break
            }
            result.warnings.append("Unsupported long item at \(start); summary may be incomplete")
            offset += length
            continue
        }
        let sizeCode = Int(prefix & 3)
        let length = sizeCode == 3 ? 4 : sizeCode
        guard offset + length <= bytes.count else {
            result.warnings.append("Truncated short item at \(start)")
            break
        }
        var value: UInt64 = 0
        for index in 0..<length { value |= UInt64(bytes[offset + index]) << (index * 8) }
        offset += length
        let type = (prefix >> 2) & 3
        let tag = prefix >> 4
        if type == 1 {
            switch tag {
            case 0: globals.page = value
            case 7: globals.size = value
            case 8:
                if value == 0 || value > 255 { result.warnings.append("Invalid Report ID at \(start)") }
                globals.id = value
            case 9: globals.count = value
            case 10: stack.append(globals)
            case 11:
                if let restored = stack.popLast() { globals = restored }
                else { result.warnings.append("Global POP without PUSH at \(start)") }
            default: break
            }
        } else if type == 2 {
            if (tag == 0 || tag == 1) && localUsage == nil {
                localUsage = length == 4 ? value : (globals.page << 16) | value
            }
            if tag == 10 { result.warnings.append("Local delimiter unsupported at \(start)") }
        } else if type == 0 {
            switch tag {
            case 8, 9, 11:
                let kind = tag == 8 ? "input" : tag == 9 ? "output" : "feature"
                let key = "\(kind):\(globals.id)"
                let product = globals.size.multipliedReportingOverflow(by: globals.count)
                let total = (bits[key] ?? 0).addingReportingOverflow(product.partialValue)
                if product.overflow || total.overflow || total.partialValue > UInt64(Int.max - 8) {
                    result.warnings.append("Report bit count overflow at \(start)")
                } else {
                    bits[key] = total.partialValue
                    ids[key] = globals.id
                    kinds[key] = kind
                    if let collectionIndex = topLevelCollectionIndex {
                        reportCollections[key, default: []].insert(collectionIndex)
                    } else {
                        reportsOutsideCollections.insert(key)
                    }
                }
            case 10:
                let collectionIndex = result.collections.count
                if depth == 0 { topLevelCollectionIndex = collectionIndex }
                var collection: [String: Any] = ["index": collectionIndex, "depth": depth, "type": value, "offset": start]
                if let usage = localUsage {
                    collection["usage_page"] = usage >> 16
                    collection["usage"] = usage & 0xFFFF
                }
                result.collections.append(collection)
                depth += 1
            case 12:
                if depth == 0 { result.warnings.append("END_COLLECTION without COLLECTION at \(start)") }
                else {
                    depth -= 1
                    if depth == 0 { topLevelCollectionIndex = nil }
                }
            default: result.warnings.append("Unknown main item at \(start)")
            }
            localUsage = nil
        } else {
            result.warnings.append("Reserved item type at \(start)")
        }
    }
    if depth != 0 { result.warnings.append("Unclosed collection(s): \(depth)") }
    if !stack.isEmpty { result.warnings.append("Unbalanced global PUSH/POP") }
    if ids.values.contains(0) && ids.values.contains(where: { $0 != 0 }) {
        result.warnings.append("Mixed numbered and unnumbered reports")
    }
    for key in bits.keys.sorted() {
        let count = bits[key]!
        let id = ids[key]!
        let payload = (count + 7) / 8
        let collections = (reportCollections[key] ?? []).sorted().map { result.collections[$0] }
        result.reports.append(["type": kinds[key]!, "report_id": id,
                               "top_level_collections": collections,
                               "has_fields_outside_collection": reportsOutsideCollections.contains(key),
                               "payload_bits": count, "payload_bytes": payload,
                               "wire_bytes_including_report_id": payload + (id == 0 ? 0 : 1)])
    }
    return result
}
