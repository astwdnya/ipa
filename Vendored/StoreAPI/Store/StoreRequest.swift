//
//  StoreRequest.swift
//  StoreAPI
//
//  Created by Majd Alfhaily on 22.05.21.
//

import Foundation
import Networking

enum StoreRequest {
    case authenticate(email: String, password: String, code: String? = nil)
    case download(appIdentifier: String, directoryServicesIdentifier: String)
    case purchase(
        appIdentifier: String,
        directoryServicesIdentifier: String,
        passwordToken: String,
        countryCode: String
    )
}

extension StoreRequest: HTTPRequest {
    var endpoint: HTTPEndpoint {
        switch self {
        case let .authenticate(_, _, code):
            return StoreEndpoint.authenticate(prefix: (code == nil) ? "p25" : "p71", guid: guid)
        case .download:
            return StoreEndpoint.download(guid: guid)
        case .purchase:
            return StoreEndpoint.purchase
        }
    }

    var method: HTTPMethod {
        return .post
    }

    var headers: [String: String] {
        var headers: [String: String] = [
            "User-Agent": "Configurator/2.15 (Macintosh; OS X 11.0.0; 16G29) AppleWebKit/2603.3.8",
            "Content-Type": "application/x-www-form-urlencoded"
        ]

        switch self {
        case .authenticate:
            break
        case let .download(_, directoryServicesIdentifier):
            headers["X-Dsid"] = directoryServicesIdentifier
            headers["iCloud-DSID"] = directoryServicesIdentifier
        case let .purchase(_, directoryServicesIdentifier, passwordToken, countryCode):
            headers["X-Dsid"] = directoryServicesIdentifier
            headers["iCloud-DSID"] = directoryServicesIdentifier
            headers["Content-Type"] = "application/x-apple-plist"
            headers["X-Apple-Store-Front"] = Storefront(countryCode: countryCode)?.rawValue
            headers["X-Token"] = passwordToken
        }

        return headers
    }

    var payload: HTTPPayload? {
        switch self {
        case let .authenticate(email, password, code):
            return .xml([
                "appleId": email,
                "attempt": "\(code == nil ? "4" : "2")",
                "createSession": "true",
                "guid": guid,
                "password": "\(password)\(code ?? "")",
                "rmp": "0",
                "why": "signIn"
            ])
        case let .download(appIdentifier, _):
            return .xml([
                "creditDisplay": "",
                "guid": guid,
                "salableAdamId": "\(appIdentifier)"
            ])
        case let .purchase(appIdentifier, _, _, _):
            return .xml([
                "appExtVrsId": "0",
                "hasAskedToFulfillPreorder": "true",
                "buyWithoutAuthorization": "true",
                "hasDoneAgeCheck": "true",
                "guid": guid,
                "needDiv": "0",
                "origPage": "Software-" + appIdentifier,
                "origPageLocation": "Buy",
                "price": "0",
                "pricingParameters": "STDQ",
                "productType": "C",
                "salableAdamId": appIdentifier
            ])
        }
    }
}

extension StoreRequest {
    // This identifier is calculated by reading the MAC address of the device
    // and stripping the nonalphabetic characters from the string.
    // https://stackoverflow.com/a/31838376
    // iOS patch: in a sandboxed app the MAC address may be unreadable, so on
    // failure we fall back to a stable random identifier generated once and
    // persisted, keeping the guid consistent per device (never crash).
    private var guid: String {
        let MAC_ADDRESS_LENGTH = 6
        let bsds: [String] = ["en0", "en1"]
        var bsd: String = bsds[0]

        var length: size_t = 0
        var buffer: [CChar]

        var bsdIndex = Int32(if_nametoindex(bsd))
        if bsdIndex == 0 {
            bsd = bsds[1]
            bsdIndex = Int32(if_nametoindex(bsd))
            guard bsdIndex != 0 else { return StoreRequest.persistedFallbackIdentifier() }
        }

        let bsdData = Data(bsd.utf8)
        var managementInfoBase = [CTL_NET, AF_ROUTE, 0, AF_LINK, NET_RT_IFLIST, bsdIndex]

        guard sysctl(&managementInfoBase, 6, nil, &length, nil, 0) >= 0 else {
            return StoreRequest.persistedFallbackIdentifier()
        }

        buffer = [CChar](unsafeUninitializedCapacity: length, initializingWith: {buffer, initializedCount in
            for x in 0..<length { buffer[x] = 0 }
            initializedCount = length
        })

        guard sysctl(&managementInfoBase, 6, &buffer, &length, nil, 0) >= 0 else {
            return StoreRequest.persistedFallbackIdentifier()
        }

        let infoData = Data(bytes: buffer, count: length)
        let indexAfterMsghdr = MemoryLayout<if_msghdr>.stride + 1
        guard let rangeOfToken = infoData[indexAfterMsghdr...].range(of: bsdData) else {
            return StoreRequest.persistedFallbackIdentifier()
        }
        let lower = rangeOfToken.upperBound
        let upper = lower + MAC_ADDRESS_LENGTH
        guard upper <= infoData.count else {
            return StoreRequest.persistedFallbackIdentifier()
        }
        let macAddressData = infoData[lower..<upper]
        let addressBytes = macAddressData.map { String(format: "%02x", $0) }
        let identifier = addressBytes.joined().uppercased()
        return identifier.isEmpty ? StoreRequest.persistedFallbackIdentifier() : identifier
    }

    private static func persistedFallbackIdentifier() -> String {
        let key = "com.ipasaver.fallbackGuid"
        if let saved = UserDefaults.standard.string(forKey: key), saved.count == 12 {
            return saved
        }

        let characters = "0123456789ABCDEF"
        let identifier = String((0..<12).map { _ in characters.randomElement()! })
        UserDefaults.standard.set(identifier, forKey: key)
        return identifier
    }
}
