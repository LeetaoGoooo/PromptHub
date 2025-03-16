//
//  AppData.swift
//  prompthub
//
//  Created by leetao on 2025/3/16.
//

import Foundation
import SwiftUI

@MainActor
class AppSettings: ObservableObject {
    @AppStorage("openaiApiKey")
    public var openaiApiKey: String = "";
    
    @AppStorage("prompt")
    public var prompt: String = """
请按照以下步骤优化用户提供的 prompt，使其更清晰、具体、有效:
1.  **理解目标：**
     * 明确用户希望通过 prompt 达到什么目的？
     * 他们希望获得什么类型的信息或输出？
2.  **分析现有 Prompt：**
     * 识别 prompt 中模糊、含糊或不明确的措辞。
     * 检查prompt中是否包含足够的上下文信息。
3.  **完善 Prompt：**
     * 使用清晰、简洁、具体的语言。
     * 提供必要的背景信息和上下文。
     * 明确指定所需的格式、长度和风格。
     * 使用关键词和短语来引导模型。
     * 如果需要，可添加一些例子来说明。
4.  **优化 Prompt 结构：**
     * 将复杂的 prompt 分解为更小的、更易于管理的步骤。
     * 使用列表、编号或缩进等格式来提高可读性。
     * 确保 prompt 的逻辑流程清晰易懂。
""";
    @AppStorage("baseURL")
    public var baseURL: String = "https://api.openai.com/v1";
    
    @AppStorage("isTestPassed")
    public var isTestPassed: Bool = false;
}
