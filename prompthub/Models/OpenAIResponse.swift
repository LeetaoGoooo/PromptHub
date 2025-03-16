//
//  OpenAIResponse.swift
//  prompthub
//
//  Created by leetao on 2025/3/14.
//

struct OpenAIStreamingChatResponse: Codable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [Choice]
}

struct Choice: Codable {
    let index: Int
    let delta: Delta?
    let finish_reason: String?
}

struct Delta: Codable {
    let content: String?
}
