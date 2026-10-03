import Foundation

/// Utilidad para consultar las interfaces de red del sistema macOS.
public enum NetworkInterfaceHelper {
    
    /// Obtiene la dirección IPv4 primaria de la red local del Mac (por ejemplo, `192.168.1.49`).
    ///
    /// Se excluyen las direcciones de bucle local (`127.x.x.x`) y direcciones de enlace local (`169.254.x.x`).
    /// Se priorizan interfaces físicas comunes de macOS como `en0` (Wi-Fi/Ethernet principal) y `en1`.
    public static func primaryLocalIPv4() -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }
        
        var candidates: [String: String] = [:]
        
        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ptr.pointee
            let addrFamily = interface.ifa_addr.pointee.sa_family
            guard addrFamily == UInt8(AF_INET) else { continue }
            
            let name = String(cString: interface.ifa_name)
            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                           &hostname, socklen_t(hostname.count),
                           nil, 0, NI_NUMERICHOST) == 0 {
                let ip = String(cString: hostname)
                if !ip.hasPrefix("127.") && !ip.hasPrefix("169.254.") && !ip.isEmpty {
                    candidates[name] = ip
                }
            }
        }
        
        if let en0 = candidates["en0"] { return en0 }
        if let en1 = candidates["en1"] { return en1 }
        return candidates.values.first
    }
}
