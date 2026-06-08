import Foundation
import CryptoKit

/// Opaque Bloom-filter membership check for Viewgram verification.
///
/// The client downloads a single compact Bloom filter (`verified.bin`) at most once
/// per day (with `If-None-Match`/`304`), keeps it in memory, and tests peer ids
/// locally. The filter cannot be enumerated, so the set of paying subscribers is
/// never exposed; only an id you already have can be tested.
///
/// Binary format (little-endian), must match the PHP generator byte-for-byte:
///   [0..4)   magic  "VGB1"
///   [4..8)   version uint32
///   [8..12)  k       uint32
///   [12..20) m       uint64 (power of two — number of bits)
///   [20..28) salt    uint64
///   [28..)   bitset  ceil(m/8) bytes
///
/// Hashing for a canonical id (Telegram Bot API id, Int64):
///   block_j = SHA256( salt(8B LE) ++ id(8B signed LE) ++ j(1B) ), j = 0,1,2,...
///   each block yields 8 little-endian uint32 words; index = word & (m - 1).
///   The first k indices (across consecutive blocks) must all be set.
public final class ViewgramVerification {
    public static let shared = ViewgramVerification()

    private struct Bloom {
        let k: Int
        let mask: UInt64
        let salt: UInt64
        let bits: [UInt8]

        init?(data: Data) {
            let bytes = [UInt8](data)
            guard bytes.count >= 28 else { return nil }
            guard bytes[0] == 0x56, bytes[1] == 0x47, bytes[2] == 0x42, bytes[3] == 0x31 else { return nil }
            func u32(_ o: Int) -> UInt32 {
                return UInt32(bytes[o]) | (UInt32(bytes[o + 1]) << 8) | (UInt32(bytes[o + 2]) << 16) | (UInt32(bytes[o + 3]) << 24)
            }
            func u64(_ o: Int) -> UInt64 {
                var v: UInt64 = 0
                for i in 0 ..< 8 { v |= UInt64(bytes[o + i]) << (8 * i) }
                return v
            }
            let kValue = Int(u32(8))
            let m = u64(12)
            self.salt = u64(20)
            self.k = kValue
            self.mask = m &- 1
            let bitBytes = Int(m / 8)
            guard m > 0, bitBytes > 0, bytes.count >= 28 + bitBytes else { return nil }
            self.bits = Array(bytes[28 ..< (28 + bitBytes)])
        }

        func contains(_ id: Int64) -> Bool {
            if k <= 0 || bits.isEmpty { return false }
            let idBits = UInt64(bitPattern: id)
            var prefix = [UInt8]()
            prefix.reserveCapacity(17)
            for i in 0 ..< 8 { prefix.append(UInt8((salt >> (8 * i)) & 0xff)) }
            for i in 0 ..< 8 { prefix.append(UInt8((idBits >> (8 * i)) & 0xff)) }
            var checked = 0
            var j: UInt8 = 0
            while checked < k {
                var input = prefix
                input.append(j)
                let digest = SHA256.hash(data: Data(input))
                let d = Array(digest)
                var w = 0
                while w < 8 && checked < k {
                    let o = w * 4
                    let word = UInt32(d[o]) | (UInt32(d[o + 1]) << 8) | (UInt32(d[o + 2]) << 16) | (UInt32(d[o + 3]) << 24)
                    let idx = UInt64(word) & mask
                    let byteIndex = Int(idx >> 3)
                    if byteIndex >= bits.count { return false }
                    let bit = UInt8(truncatingIfNeeded: 1 << (idx & 7))
                    if (bits[byteIndex] & bit) == 0 { return false }
                    checked += 1
                    w += 1
                }
                j = j &+ 1
            }
            return true
        }
    }

    private let url = URL(string: "https://viewgram.bukva.me/api/verified.bin")!
    private let queue = DispatchQueue(label: "me.viewgram.verification")
    private let lock = NSLock()
    private var bloom: Bloom?
    private var etag: String?
    private var lastFetch: Date?
    private var lastForcedFetch: Date?
    private var isFetching = false
    private let refreshInterval: TimeInterval = 6 * 3600
    private let forcedThrottle: TimeInterval = 30
    private let cacheURL: URL
    private let etagURL: URL

    private init() {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        self.cacheURL = dir.appendingPathComponent("viewgram_verified.bin")
        self.etagURL = dir.appendingPathComponent("viewgram_verified.etag")
    }

    /// Load any cached filter and refresh if it is older than a day. Safe to call repeatedly.
    public func start() {
        queue.async {
            self.loadFromDisk()
            self.refreshIfNeededLocked()
        }
    }

    /// Re-fetch if the cached filter is stale. Call on app foreground.
    public func refreshIfNeeded() {
        queue.async {
            self.refreshIfNeededLocked()
        }
    }

    /// Force a re-download regardless of TTL. `unlimited` (admin/self) bypasses the
    /// anti-spam throttle. `completion(success)` is delivered on the main queue.
    public func forceRefresh(unlimited: Bool, completion: ((Bool) -> Void)? = nil) {
        queue.async {
            if !unlimited, let last = self.lastForcedFetch, Date().timeIntervalSince(last) < self.forcedThrottle {
                DispatchQueue.main.async { completion?(false) }
                return
            }
            self.lastForcedFetch = Date()
            self.performFetch(completion: completion)
        }
    }

    /// Local, fast membership test. `botApiId` is the Telegram Bot API id.
    public func isVerified(botApiId: Int64) -> Bool {
        if botApiId == 0 { return false }
        lock.lock()
        let current = bloom
        lock.unlock()
        return current?.contains(botApiId) ?? false
    }

    // MARK: - internals (run on `queue`)

    private func loadFromDisk() {
        if let data = try? Data(contentsOf: cacheURL), let parsed = Bloom(data: data) {
            lock.lock(); self.bloom = parsed; lock.unlock()
            if let attrs = try? FileManager.default.attributesOfItem(atPath: cacheURL.path), let date = attrs[.modificationDate] as? Date {
                self.lastFetch = date
            }
            self.etag = try? String(contentsOf: etagURL, encoding: .utf8)
        }
    }

    private func refreshIfNeededLocked() {
        if let last = lastFetch, Date().timeIntervalSince(last) < refreshInterval {
            lock.lock(); let have = bloom != nil; lock.unlock()
            if have { return }
        }
        performFetch(completion: nil)
    }

    // Performs the HTTP fetch (honouring ETag). Must run on `queue`.
    private func performFetch(completion: ((Bool) -> Void)?) {
        if isFetching {
            DispatchQueue.main.async { completion?(false) }
            return
        }
        isFetching = true
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.cachePolicy = .reloadIgnoringLocalCacheData
        if let etag = self.etag, !etag.isEmpty {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            self.queue.async {
                self.isFetching = false
                self.lastFetch = Date()
                if error != nil {
                    DispatchQueue.main.async { completion?(false) }
                    return
                }
                guard let http = response as? HTTPURLResponse else {
                    DispatchQueue.main.async { completion?(false) }
                    return
                }
                if http.statusCode == 304 {
                    DispatchQueue.main.async { completion?(true) }
                    return
                }
                if http.statusCode == 200, let data = data, let parsed = Bloom(data: data) {
                    self.lock.lock(); self.bloom = parsed; self.lock.unlock()
                    try? data.write(to: self.cacheURL, options: .atomic)
                    if let newEtag = http.value(forHTTPHeaderField: "Etag") ?? http.value(forHTTPHeaderField: "ETag") {
                        self.etag = newEtag
                        try? newEtag.write(to: self.etagURL, atomically: true, encoding: .utf8)
                    }
                    DispatchQueue.main.async { completion?(true) }
                } else {
                    DispatchQueue.main.async { completion?(false) }
                }
            }
        }
        task.resume()
    }
}
