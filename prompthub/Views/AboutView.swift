//
//  AboutView.swift
//  prompthub
//
//  Created by leetao on 2025/3/3.
//
import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack {
            Image("whale")
                .resizable()
                .frame(width: 32, height: 32)
            
            HStack(alignment: .bottom) {
                Text("PromptHub")
                    .fontWeight(.bold)
                    .font(.system(size: 30))
                Text("v\(SystemInfo.majorVersion as! String)")
                    .foregroundColor(Color(NSColor.lightGray))
                    .font(.system(size: 22))
            }
            Text("(Build \(SystemInfo.minorVersion as! String))")
                .font(.footnote)
                .foregroundColor(.gray)
            
            Text("Copyright @ 2025 leetao ")
                .font(.system(size: 15))
            Link(destination: URL(string: "https://leetao.me")!, label: {
                Text("Leetao")
                    .font(.system(size: 15))
            })
            
            Link(destination: URL(string: "https://github.com/LeetaoGoooo/PromptHub")!, label: {
                Text("GitHub")
            })
            
            Link(destination:
                    URL(string: "https://ifdian.net/a/leetao")!,
                 label: {
                Text("Donation")
            })
            .buttonStyle(.bordered)
            .padding(3)
            
            HStack {
                Text("Join:")
                    .font(.system(size: 15))
                Link(destination: URL(string: "https://t.me/leetao_space")!, label: {
                    Image("telegram")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30.0, height: 30.0)
                })
                Link(destination: URL(string: "https://mp.weixin.qq.com/s/fxJXAQ9xapOxYy_97GNfmA")!, label: {
                    Image("wechat")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30.0, height: 30.0)
                })
            }
        }.frame(width: 256, height: 256)
            .padding()
    }
}

#Preview {
    AboutView()
}
