import CoreNFC
import Foundation

/// Reads the hardware identifier (UID) of one NFC tag.
///
/// Works with blank or read-only tags and stickers (NTAG/MIFARE, ISO 15693,
/// ISO 7816), because it doesn't need NDEF data. Needs the
/// `com.apple.developer.nfc.readersession.formats` entitlement with `TAG`. The
/// app checks for it before scanning, and `.entitlementMissing` is a fallback.
final class NFCTagScanner: NSObject, NFCTagReaderSessionDelegate {
    enum ScanError: LocalizedError {
        case unsupported
        case entitlementMissing
        case cancelled
        case timedOut
        case busy
        case unreadable
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .unsupported: return "This device can't read NFC tags."
            case .entitlementMissing: return "This copy of the app wasn't signed with the NFC Tag Reading entitlement."
            case .cancelled: return "Scan cancelled."
            case .timedOut: return "No tag was found in time. Hold the top edge of your iPhone against the tag and try again."
            case .busy: return "The NFC reader is busy. Try again in a moment."
            case .unreadable: return "This tag doesn't have a stable ID the app can use."
            case .failed(let reason): return reason
            }
        }
    }

    private var session: NFCTagReaderSession?
    private var continuation: CheckedContinuation<Data, Error>?

    /// Shows the system scan sheet and returns the tag's UID.
    @MainActor
    func scan(prompt: String) async throws -> Data {
        guard NFCTagReaderSession.readingAvailable else { throw ScanError.unsupported }
        guard continuation == nil else { throw ScanError.busy }

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            self.session = NFCTagReaderSession(pollingOption: [.iso14443, .iso15693], delegate: self, queue: .main)
            guard let session = self.session else {
                finish(.failure(ScanError.unsupported))
                return
            }
            session.alertMessage = prompt
            session.begin()
        }
    }

    // MARK: NFCTagReaderSessionDelegate (called on the main queue)

    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {}

    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        self.session = nil
        finish(.failure(Self.map(error)))
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard tags.count == 1, let tag = tags.first else {
            session.alertMessage = "More than one tag found. Hold just one tag near your iPhone."
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)) { session.restartPolling() }
            return
        }

        session.connect(to: tag) { [weak self] error in
            guard let self else { return }
            if let error {
                session.invalidate(errorMessage: "Couldn't read that tag. Try again.")
                self.finish(.failure(ScanError.failed(error.localizedDescription)))
                return
            }
            guard let identifier = Self.identifier(of: tag), !identifier.isEmpty else {
                session.invalidate(errorMessage: "This tag doesn't have a usable ID.")
                self.finish(.failure(ScanError.unreadable))
                return
            }
            session.alertMessage = "Tag read."
            session.invalidate()
            self.finish(.success(identifier))
        }
    }

    // MARK: Helpers

    private func finish(_ result: Result<Data, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(with: result)
    }

    private static func identifier(of tag: NFCTag) -> Data? {
        switch tag {
        case .miFare(let tag): return tag.identifier
        case .iso7816(let tag): return tag.identifier
        case .iso15693(let tag): return tag.identifier
        case .feliCa(let tag): return tag.currentIDm
        @unknown default: return nil
        }
    }

    private static func map(_ error: Error) -> ScanError {
        guard let error = error as? NFCReaderError else { return .failed(error.localizedDescription) }
        switch error.code {
        case .readerSessionInvalidationErrorUserCanceled: return .cancelled
        case .readerSessionInvalidationErrorSessionTimeout: return .timedOut
        case .readerSessionInvalidationErrorSystemIsBusy: return .busy
        case .readerErrorSecurityViolation: return .entitlementMissing
        case .readerErrorUnsupportedFeature: return .unsupported
        default: return .failed(error.localizedDescription)
        }
    }
}
