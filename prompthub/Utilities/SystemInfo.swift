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
