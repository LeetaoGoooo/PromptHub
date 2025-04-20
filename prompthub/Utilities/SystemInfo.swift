//
//  SystemInfo.swift
//  OnlySwitch
//
//  Created by Jacklandrin on 2021/12/5.
//  Source: https://github.com/jacklandrin/OnlySwitch/blob/e75cba28374176c281bdc2213421e6467e68f86b/OnlySwitch/Utilities/SystemInfo.swift

import Foundation
struct SystemInfo{
    static let infoDictionary = Bundle.main.infoDictionary
    static var appDisplayName:AnyObject? {
        infoDictionary!["CFBundleDisplayName"] as AnyObject //app name
    }
    static var majorVersion :AnyObject? {
        infoDictionary!["CFBundleShortVersionString"] as AnyObject//major version
    }
    static var minorVersion :AnyObject? {
        infoDictionary!["CFBundleVersion"] as AnyObject//build version
    }
    //device information
    static let isiOSAppOnMac = ProcessInfo.processInfo.isiOSAppOnMac
}


public let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter
}()


public let OpenAIModels =  [
    "gpt-3.5-turbo",
    "gpt-3.5-turbo-0125",
    "gpt-3.5-turbo-0613",
    "gpt-3.5-turbo-1106",
    "gpt-3.5-turbo-16k",
    "gpt-3.5-turbo-16k-0613",
    "gpt-3.5-turbo-instruct",
    "gpt-4",
    "gpt-4-0125-preview",
    "gpt-4-0613",
    "gpt-4-1106-preview",
    "gpt-4-32k",
    "gpt-4-32k-0613",
    "gpt-4-turbo",
    "gpt-4-turbo-2024-04-09",
    "gpt-4-turbo-preview",
    "gpt-4-vision-preview",
    "gpt-4.128",
    "gpt-4.1-2025-04-14",
    "gpt-4o",
    "gpt-4o-2024-05-13",
    "gpt-4o-2024-08-06",
    "gpt-4o-2024-11-20",
    "gpt-4o-mini",
    "gpt-4o-mini-2024-07-18"
]
