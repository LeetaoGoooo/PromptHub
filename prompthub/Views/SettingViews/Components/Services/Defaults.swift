//
//  Defaults.swift
//  prompthub
//
//  Created by leetao on 2025/7/7.
//


import Foundation
import GenKit

public struct Defaults {

    public static let services: [Service] = [
        anthropic,
        deepseek,
        grok,
        groq,
        llama,
        mistral,
        ollama,
        openAI
    ]
}
