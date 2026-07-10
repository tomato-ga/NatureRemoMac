import Foundation
import Security

protocol TokenStoring {
    func readToken() throws -> String?
    func saveToken(_ token: String) throws
    func deleteToken() throws
}

enum KeychainTokenError: LocalizedError {
    case unexpectedStatus(OSStatus)
    case invalidData

    var errorDescription: String? {
        switch self {
        case .unexpectedStatus(let status):
            return "Keychain returned status \(status)."
        case .invalidData:
            return "The saved token could not be read."
        }
    }
}

final class KeychainTokenStore: TokenStoring {
    private let service: String
    private let account = "nature-remo-access-token"
    private let legacyServices = ["com.codex.NatureRemoMac"]

    init(service: String = AppMetadata.bundleIdentifier) {
        self.service = service
    }

    func readToken() throws -> String? {
        if let token = try readToken(service: service) {
            return token
        }

        for legacyService in legacyServices where legacyService != service {
            guard let token = try readToken(service: legacyService) else {
                continue
            }

            try saveToken(token)
            try deleteToken(service: legacyService)
            return token
        }

        return nil
    }

    private func readToken(service: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw KeychainTokenError.unexpectedStatus(status)
        }

        guard let data = item as? Data, let token = String(data: data, encoding: .utf8) else {
            throw KeychainTokenError.invalidData
        }

        return token
    }

    func saveToken(_ token: String) throws {
        let data = Data(token.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }

        guard updateStatus == errSecItemNotFound else {
            throw KeychainTokenError.unexpectedStatus(updateStatus)
        }

        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw KeychainTokenError.unexpectedStatus(addStatus)
        }
    }

    func deleteToken() throws {
        try deleteToken(service: service)
        for legacyService in legacyServices where legacyService != service {
            try deleteToken(service: legacyService)
        }
    }

    private func deleteToken(service: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        if status == errSecSuccess || status == errSecItemNotFound {
            return
        }

        throw KeychainTokenError.unexpectedStatus(status)
    }
}
