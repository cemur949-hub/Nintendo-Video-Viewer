import Foundation

/// Reads the entitlements blob from a Mach-O executable's code signature.
///
/// These are the entitlements iOS enforces for the running binary. If SideStore
/// had to drop an entitlement (for example Family Controls on a free Apple ID),
/// it won't be here, whatever the project's .entitlements file asked for.
enum CodeSignature {
    private static let machOMagic64: UInt32 = 0xFEED_FACF
    private static let fatMagic: UInt32 = 0xCAFE_BABE
    private static let cpuTypeARM64: UInt32 = 0x0100_000C
    private static let loadCommandCodeSignature: UInt32 = 0x1D
    private static let superBlobMagic: UInt32 = 0xFADE_0CC0
    private static let entitlementsBlobMagic: UInt32 = 0xFADE_7171
    private static let entitlementsSlot: UInt32 = 5

    /// Returns nil if the file has no entitlements blob or can't be parsed.
    static func entitlements(ofExecutableAt url: URL?) -> [String: Any]? {
        guard let url, let data = try? Data(contentsOf: url, options: .alwaysMapped) else { return nil }
        let bytes = ByteReader(data: data)
        guard let slice = machOSliceOffset(bytes),
              let signature = codeSignatureOffset(bytes, sliceOffset: slice)
        else { return nil }
        return entitlements(bytes, superBlobOffset: signature)
    }

    /// Offset of the arm64 slice (or the only slice, for thin binaries).
    private static func machOSliceOffset(_ bytes: ByteReader) -> Int? {
        if bytes.le32(0) == machOMagic64 { return 0 }
        guard bytes.be32(0) == fatMagic, let count = bytes.be32(4) else { return nil }

        var fallback: Int?
        for index in 0..<Int(min(count, 16)) {
            let entry = 8 + index * 20 // struct fat_arch
            guard let cpuType = bytes.be32(entry), let offset = bytes.be32(entry + 8) else { return nil }
            let sliceOffset = Int(offset)
            guard bytes.le32(sliceOffset) == machOMagic64 else { continue }
            if cpuType == cpuTypeARM64 { return sliceOffset }
            fallback = fallback ?? sliceOffset
        }
        return fallback
    }

    /// File offset of the code signature SuperBlob, from LC_CODE_SIGNATURE.
    private static func codeSignatureOffset(_ bytes: ByteReader, sliceOffset: Int) -> Int? {
        guard let commandCount = bytes.le32(sliceOffset + 16) else { return nil }
        var cursor = sliceOffset + 32 // sizeof(mach_header_64)
        for _ in 0..<Int(min(commandCount, 4096)) {
            guard let command = bytes.le32(cursor), let size = bytes.le32(cursor + 4), size >= 8 else { return nil }
            if command == loadCommandCodeSignature {
                guard let dataOffset = bytes.le32(cursor + 8) else { return nil }
                return sliceOffset + Int(dataOffset)
            }
            cursor += Int(size)
        }
        return nil
    }

    private static func entitlements(_ bytes: ByteReader, superBlobOffset base: Int) -> [String: Any]? {
        guard bytes.be32(base) == superBlobMagic, let count = bytes.be32(base + 8) else { return nil }

        for index in 0..<Int(min(count, 64)) {
            let entry = base + 12 + index * 8 // struct CS_BlobIndex
            guard let type = bytes.be32(entry), let offset = bytes.be32(entry + 4) else { return nil }
            guard type == entitlementsSlot else { continue }

            let blob = base + Int(offset)
            guard bytes.be32(blob) == entitlementsBlobMagic,
                  let length = bytes.be32(blob + 4), length > 8,
                  let plistData = bytes.slice(from: blob + 8, count: Int(length) - 8)
            else { return nil }
            return (try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil)) as? [String: Any]
        }
        return nil
    }
}

/// Bounds-checked integer reads from a byte buffer.
private struct ByteReader {
    let data: Data

    func le32(_ offset: Int) -> UInt32? {
        guard let b = bytes(at: offset) else { return nil }
        return UInt32(b.0) | UInt32(b.1) << 8 | UInt32(b.2) << 16 | UInt32(b.3) << 24
    }

    func be32(_ offset: Int) -> UInt32? {
        guard let b = bytes(at: offset) else { return nil }
        return UInt32(b.0) << 24 | UInt32(b.1) << 16 | UInt32(b.2) << 8 | UInt32(b.3)
    }

    func slice(from offset: Int, count: Int) -> Data? {
        guard offset >= 0, count >= 0, offset + count <= data.count else { return nil }
        let start = data.startIndex + offset
        return data.subdata(in: start..<(start + count))
    }

    private func bytes(at offset: Int) -> (UInt8, UInt8, UInt8, UInt8)? {
        guard offset >= 0, offset + 4 <= data.count else { return nil }
        let i = data.startIndex + offset
        return (data[i], data[i + 1], data[i + 2], data[i + 3])
    }
}
