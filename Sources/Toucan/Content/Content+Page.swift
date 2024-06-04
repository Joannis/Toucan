//
//  File.swift
//
//
//  Created by Tibor Bodecs on 03/05/2024.
//

import struct Foundation.Date

extension Content {

    struct Page: ContentInterface {
        
        static let folder = "pages/custom"
        static let slugPrefix: String? = nil
        
        let id: String
        let slug: String
        let title: String
        let description: String
        let coverImage: String?
        let template: String?
        let lastModification: Date
        let frontMatter: [String: Any]
        let markdown: String
        
        var userDefined: [String: Any] {
            frontMatter.filter {
                ![
                    "slug",
                    "title",
                    "description",
                    "coverImage",
                    "template",
                ]
                    .contains($0.key)
            }
        }
    }
}