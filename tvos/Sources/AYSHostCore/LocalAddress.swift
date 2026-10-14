//
//  LocalAddress.swift
//  AYSHostCore
//
//  The board's own LAN IPv4 address, for the direct-connect hint carried by
//  the join QR (docs/Architecture/Multiplayer Host (tvOS).md "Direct-connect
//  hint"). Bonjour stays the primary way phones find a room; this exists for
//  networks that drop multicast (mDNS) but still route unicast between
//  devices — App Review's network among them.
//

import Foundation

public enum LocalAddress {
    /// Picks the best IPv4 address from `(interface, address)` pairs:
    /// private-range addresses first, then any other routable one, preferring
    /// Wi-Fi/Ethernet (`en*`) interfaces. Loopback and link-local
    /// (169.254.x.x) are never returned. Pure, so it's unit-testable.
    public static func pick(from candidates: [(interface: String, address: String)]) -> String? {
        func octets(_ address: String) -> [Int]? {
            let parts = address.split(separator: ".").compactMap { Int($0) }
            return parts.count == 4 && parts.allSatisfy({ (0...255).contains($0) }) ? parts : nil
        }
        func isPrivate(_ o: [Int]) -> Bool {
            o[0] == 10 || (o[0] == 172 && (16...31).contains(o[1])) || (o[0] == 192 && o[1] == 168)
        }
        let usable = candidates.compactMap { candidate -> (String, String, [Int])? in
            guard let o = octets(candidate.address), o[0] != 127, !(o[0] == 169 && o[1] == 254) else {
                return nil
            }
            return (candidate.interface, candidate.address, o)
        }
        func rank(_ c: (String, String, [Int])) -> Int {
            (isPrivate(c.2) ? 0 : 2) + (c.0.hasPrefix("en") ? 0 : 1)
        }
        return usable.min { rank($0) < rank($1) }?.1
    }

    /// The device's current LAN IPv4 address, or nil when it has none.
    public static func primaryIPv4() -> String? {
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let first = head else { return nil }
        defer { freeifaddrs(head) }

        var candidates: [(interface: String, address: String)] = []
        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let entry = cursor {
            defer { cursor = entry.pointee.ifa_next }
            let flags = Int32(entry.pointee.ifa_flags)
            guard flags & IFF_UP != 0, flags & IFF_LOOPBACK == 0,
                  let addr = entry.pointee.ifa_addr, addr.pointee.sa_family == UInt8(AF_INET)
            else { continue }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            guard getnameinfo(addr, socklen_t(addr.pointee.sa_len), &host, socklen_t(host.count),
                              nil, 0, NI_NUMERICHOST) == 0 else { continue }
            candidates.append((String(cString: entry.pointee.ifa_name), String(cString: host)))
        }
        return pick(from: candidates)
    }
}
