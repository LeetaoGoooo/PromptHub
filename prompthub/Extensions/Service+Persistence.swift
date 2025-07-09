//
//  Service+Persistence.swift
//  prompthub
//
//  Created by leetao on 2025/7/8.
//
// Service+Persistence.swift

import Foundation
import GenKit

extension Service: Codable {

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case host
        case token
        case preferredChatModel
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(host, forKey: .host)
        try container.encode(token, forKey: .token)
        try container.encodeIfPresent(preferredChatModel, forKey: .preferredChatModel)
         }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let idRawValue = try container.decode(String.self, forKey: .id)
        let name = try container.decode(String.self, forKey: .name)
        let host = try container.decode(String.self, forKey: .host)
        let token = try container.decode(String.self, forKey: .token)
        let preferredChatModel = try container.decodeIfPresent(String.self, forKey: .preferredChatModel)
        guard let serviceID = Service.ServiceID(rawValue: idRawValue) else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: container, debugDescription: "Invalid service ID string: \(idRawValue)")
        }


        self.init(
            id: serviceID,
            name: name,
            host: host,
            token: token,
            models: [],
            preferredChatModel: preferredChatModel,
        )
    }
}
