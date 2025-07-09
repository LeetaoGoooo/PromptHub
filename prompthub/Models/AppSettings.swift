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
    private let promptDefaultKey = "prompt_template"
    
    @AppStorage("prompt")
    public var prompt: String = "prompt_template";
    
    
    @AppStorage("isTestPassed")
    public var isTestPassed: Bool = false;
    
    
    @AppStorage("lastShownWhatsNewVersion")
    public var lastShownWhatsNewVersion: String = "2.5.0"
    
    
    init() {
          if prompt == promptDefaultKey {
              prompt = NSLocalizedString(promptDefaultKey, comment: "The default prompt template for the AI.")
          }
      }
      
      func resetPromptToDefault() {
          prompt = NSLocalizedString(promptDefaultKey, comment: "The default prompt template for the AI.")
      }

}
