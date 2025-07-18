//
//  DefaultServices.swift
//  prompthub
//
//  Created by leetao on 2025/7/7.
//

import Foundation
import GenKit
import SharedKit

extension Defaults {

    public static let anthropic =
        Service(
            id: .anthropic,
            name: "Anthropic"
        )

    public static let deepseek =
        Service(
            id: .deepseek,
            name: "DeepSeek",
            host: "https://api.deepseek.com/v1"
        )

    public static let grok =
        Service(
            id: .grok,
            name: "Grok",
            host: "https://api.x.ai/v1"
        )

    public static let groq =
        Service(
            id: .groq,
            name: "Groq",
            host: "https://api.groq.com/openai/v1"
        )

    public static let llama =
        Service(
            id: .llama,
            name: "Llama"
        )

    public static let mistral =
        Service(
            id: .mistral,
            name: "Mistral"
        )

    public static let ollama =
        Service(
            id: .ollama,
            name: "Ollama",
            host: "http://127.0.0.1:11434/api"
        )

    public static let openAI =
        Service(
            id: .openAI,
            name: "OpenAI",
            host: "https://api.openai.com/v1"
        )
}
