//
//  GalleryPrompt.swift
//  prompthub
//
//  Created by leetao on 2025/6/1.
//

class GalleryPrompt : Identifiable{
    var id: String;
    var name:String;
    var description: String?;
    var prompt: String;
    var link: String?;
    
    init(id: String, name: String, description: String? = nil, prompt: String, link: String? = nil) {
        self.id = id
        self.name = name
        self.description = description
        self.prompt = prompt
        self.link = link
    }
}
