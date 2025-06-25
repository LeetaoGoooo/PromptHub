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
    public var prompt: String = "prompt_template";
    
    @AppStorage("baseURL")
    public var baseURL: String = "https://api.openai.com/v1";
    
    @AppStorage("isTestPassed")
    public var isTestPassed: Bool = false;
    
    @AppStorage("model")
    public var model: String = OpenAIModels.first!;
    
    @AppStorage("lastShownWhatsNewVersion")
    public var lastShownWhatsNewVersion: String = "2.2.1" 
}
