//
//  File.swift
//
//
//  Created by Tibor Bodecs on 03/05/2024.
//

import Markdown

/// NOTE: https://www.markdownguide.org/basic-syntax/

private extension Markup {

    var isInsideList: Bool {
        self is ListItemContainer || parent?.isInsideList == true
    }
}

public struct ToC {

    public let level: Int
    public let text: String
    public let fragment: String
    
    public init(
        level: Int,
        text: String,
        fragment: String
    ) {
        self.level = level
        self.text = text
        self.fragment = fragment
    }
}

public struct ToCTree {
    public let level: Int
    public let text: String
    public let fragment: String
    public var children: [ToCTree]

    public init(
        level: Int,
        text: String,
        fragment: String,
        children: [ToCTree] = []
    ) {
        self.level = level
        self.text = text
        self.fragment = fragment
        self.children = children
    }
    
    static func buildToCTree(from tocList: [ToC]) -> [ToCTree] {
        func addChild(_ parent: inout ToCTree, child: ToCTree) {
            for i in 0..<parent.children.count {
                if parent.children[i].level < child.level {
                    addChild(&parent.children[i], child: child)
                    return
                }
            }
            parent.children.append(child)
        }

        var result: [ToCTree] = []

        for toc in tocList {
            let newNode = ToCTree(
                level: toc.level,
                text: toc.text,
                fragment: toc.fragment
            )
            
            if result.isEmpty {
                result.append(newNode)
            } else {
                var inserted = false
                for i in 0..<result.count {
                    if result[i].level < newNode.level {
                        addChild(&result[i], child: newNode)
                        inserted = true
                        break
                    }
                }
                if !inserted {
                    result.append(newNode)
                }
            }
        }

        return result
    }
}

struct MarkupToToCVisitor: MarkupVisitor {
    
    typealias Result = [ToC]
    
    // MARK: - visitor functions
    
    mutating func defaultVisit(_ markup: any Markup) -> Result {
        var result: [ToC] = []
        for child in markup.children {
            result += visit(child)
        }
        return result
    }
    
    // MARK: - elements
    
    mutating func visitHeading(
        _ heading: Heading
    ) -> Result {
        guard [2, 3].contains(heading.level) else {
            return []
        }
        let fragment = heading.plainText.lowercased().slugify()
        return [
            .init(
                level: heading.level,
                text: heading.plainText,
                fragment: fragment
            )
        ]
    }
    
}