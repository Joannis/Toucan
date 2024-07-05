//
//  File.swift
//  
//
//  Created by Tibor Bodecs on 27/06/2024.
//

import Foundation
import FileManagerKit

/// A structure responsible for loading contents data.
struct SourceMaterialLoader {
    
    /// An enumeration representing possible errors that can occur while loading the content.
    enum Error: Swift.Error {
        /// Indicates an error related to a content.
        case material(Swift.Error)
    }

    /// The configuration for loading contents.
    let config: SourceConfig
    /// The file manager used for file operations.
    let fileManager: FileManager
    /// The front matter parser used for parsing markdown files.
    let frontMatterParser: FrontMatterParser

    /// The current date.
    let now: Date = .init()
    
    // TODO: move this to the config + toucan urls also
    private var contentsUrl: URL {
        config.sourceUrl.appendingPathComponent(
            config.contents.folder
        )
    }

    // MARK: - Private Methods

    private
    func loadMaterial(
        at url: URL,
        baseUrl: URL,
        slugPrefix: String?,
        template: String
    ) throws -> SourceMaterial? {
        guard fileManager.fileExists(at: url) else {
            return nil
        }

        do {
            let cmp = url.pathComponents.dropFirst(baseUrl.pathComponents.count)
            let fileName = url.lastPathComponent
            let location = String(url.path.dropLast(fileName.count))

            let id = fileName.droppingEverythingAfterLastOccurrence(of: ".")
            var defaultSlug = id
            if !cmp.isEmpty {
                defaultSlug = cmp.joined(separator: "/")
                    .droppingEverythingAfterLastOccurrence(of: ".")
            }
            
            let lastModification = try fileManager.modificationDate(at: url)
            
            let dirUrl = URL(fileURLWithPath: location)

            // MARK: - load markdown + front matter data

            let rawMarkdown = try String(contentsOf: url, encoding: .utf8)
            var frontMatter = try frontMatterParser.parse(markdown: rawMarkdown)

            // TODO: use url
            for c in [id + ".yaml", id + ".yml"] {
                let url = dirUrl.appendingPathComponent(c)
                guard fileManager.fileExists(at: url) else {
                    continue
                }
                let yaml = try String(contentsOf: url, encoding: .utf8)
                let fm = try frontMatterParser.load(yaml: yaml)
                frontMatter = frontMatter.recursivelyMerged(with: fm)
            }
            
            var data: [[String: Any]] = []
            for d in [id + ".data.yaml", id + ".data.yml"] {
                let url = dirUrl.appendingPathComponent(d)
                guard fileManager.fileExists(at: url) else {
                    continue
                }
                let yaml = try String(contentsOf: url, encoding: .utf8)
                let da = try frontMatterParser.load(yaml: yaml, as: [[String: Any]].self) ?? []
                data += da
            }
            
            // MARK: - load data & filter based on draft, publication, expiration
            
            let draft = frontMatter.value("draft", as: Bool.self) ?? false
            
            /// filter out draft
            if draft {
                return nil
            }
            let dateFormatter = DateFormatters.contentLoader

            var publication: Date = now
            if
                let rawDate = frontMatter["publication"] as? String,
                let date = dateFormatter.date(from: rawDate)
            {
                publication = date
            }
            
            /// filter out unpublished
            if publication > now {
                return nil
            }
            
            var expiration: Date? = nil
            if
                let rawDate = frontMatter["expiration"] as? String,
                let date = dateFormatter.date(from: rawDate)
            {
                expiration = date
            }
            
            /// filter out expired
            if let expiration, expiration < now {
                return nil
            }
            
            
            // MARK: - load material metadata
            
            let slug = frontMatter.string("slug")?.emptyToNil ?? defaultSlug
            let title = frontMatter.string("title") ?? ""
            let description = frontMatter.string("description") ?? ""
            let image = frontMatter.string("image")?.emptyToNil
            
            let template = frontMatter.string("template") ?? template
            let assetsPath = frontMatter.string("assets.path")?.emptyToNil
            let userDefined = frontMatter.dict("userDefined")
            let redirects = frontMatter.value(
                "redirects.from",
                as: [String].self
            ) ?? []
            let noindex = frontMatter.value("noindex", as: Bool.self) ?? false
            let canonical = frontMatter.string("canonical")?.emptyToNil
            
            var hreflang = frontMatter.value(
                "hreflang",
                as: [[String: String]].self
            )?.compactMap { dict -> Context.Metadata.Hreflang? in
                guard
                    let lang = dict["lang"]?.emptyToNil,
                    let url = dict["url"]?.emptyToNil
                else {
                    return nil
                }
                return .init(lang: lang, url: url)
            }
            /// fallback to empty array if key is explicitly defined
            if hreflang == nil, frontMatter["hreflang"] != nil {
                hreflang = []
            }

            let assetsUrl = dirUrl
                .appendingPathComponent(assetsPath ?? id)
            
            let styleCss = assetsUrl
                .appendingPathComponent("style.css")
            
            let mainJs = assetsUrl
                .appendingPathComponent("main.js")
            
            // NOTE: hacky solution...
            var imageUrl: String? = nil
            if let image, fileManager.fileExists(
                at: dirUrl.appendingPathComponent(
                    image
                )
            ) {
                imageUrl = image
            }
            
//            print(image)
//            print(imageUrl)
//            print("---")
            
            var css: [String] = []
            if fileManager.fileExists(at: styleCss) {
                let cssFile = "./" + id + "/style.css"
                css.append(cssFile)
            }
            let cssFiles = frontMatter.value(
                "css",
                as: [String].self
            ) ?? []
            css += cssFiles
            
            var js: [String] = []
            if fileManager.fileExists(at: mainJs) {
                let jsFile = "./" + id + "/main.js"
                js.append(jsFile)
            }

            let jsFiles = frontMatter.value(
                "css",
                as: [String].self
            ) ?? []
            js += jsFiles

//                print(id)
//                print(fileName)
//                print(slug)
//                print(location)
//                print(assetsFolder ?? id)
//                print("---")
            
            // TODO: proper asset resolution
            let assets = fileManager.recursivelyListDirectory(at: assetsUrl)
            
            return .init(
                url: .init(fileURLWithPath: location),
                slug: slug.safeSlug(prefix: slugPrefix),
                title: title,
                description: description,
                image: imageUrl,
                draft: draft,
                publication: publication,
                expiration: expiration,
                css: css,
                js: js,
                template: template,
                assetsPath: assetsPath ?? id,
                lastModification: lastModification,
                redirects: redirects,
                userDefined: userDefined,
                data: data,
                frontMatter: frontMatter,
                markdown: rawMarkdown.dropFrontMatter(),
                assets: assets,
                noindex: noindex,
                canonical: canonical,
                hreflang: hreflang
            )
        }
        catch {
            throw Error.material(error)
        }
    }
    
    private
    func markdownUrl(
        using path: String
    ) -> URL {
        let baseUrl = contentsUrl
            .appendingPathComponent(path)
        
        let mdUrl = baseUrl.appendingPathExtension("md")
        if fileManager.fileExists(at: mdUrl) {
            return mdUrl
        }
        return baseUrl.appendingPathExtension("markdown")
    }
    
    private
    func loadMaterial(
        using path: String,
        slugPrefix: String?,
        template: String
    ) throws -> SourceMaterial? {
        let baseUrl = contentsUrl
            .appendingPathComponent(path)

        return try loadMaterial(
            at: markdownUrl(
                using: path
            ),
            baseUrl: baseUrl,
            slugPrefix: slugPrefix,
            template: template
        )
    }
    
    private
    func loadMaterials(
        using config: SourceConfig.Content,
        template: String
    ) throws -> [SourceMaterial] {
        let customPagesDirectoryUrl = contentsUrl
            .appendingPathComponent(config.folder)

        return fileManager
            .getURLs(
                at: customPagesDirectoryUrl,
                for: ["md", "markdown"]
            )
            .compactMap {
                try? loadMaterial(
                    at: $0,
                    baseUrl: customPagesDirectoryUrl,
                    slugPrefix: config.slugPrefix,
                    template: template
                )
            }
    }
    
    // MARK: -
    
    private
    func loadMainHomePageContent(
        
    ) throws -> SourceMaterial {
        // TODO: exception
        guard let home = try loadMaterial(
            using: config.pages.main.home.path,
            slugPrefix: nil,
            template: "main.home"
        ) else {
            fatalError("Couldn't load not home page.")
        }
        return home.updated(slug: "")
    }
    
    private
    func loadMainNotFoundPageContent(
        
    ) throws -> SourceMaterial {
        // TODO: exception
        guard let notFound = try loadMaterial(
            using: config.pages.main.notFound.path,
            slugPrefix: nil,
            template: "main.404"
        ) else {
            fatalError("Couldn't load not found page.")
        }
        return notFound.updated(slug: "404")
    }

    private
    func loadPagesMaterials(
        
    ) throws -> SourceMaterials.Pages {
        
        let mainHomePage = try loadMainHomePageContent()
        let mainNotFoundPage = try loadMainNotFoundPageContent()
        
        let blogHomePage = try loadMaterial(
            using: config.pages.blog.home.path,
            slugPrefix: nil,
            template: "blog.home"
        )
        
        let blogAuthorsPage = try loadMaterial(
            using: config.pages.blog.authors.path,
            slugPrefix: nil,
            template: "blog.authors"
        )
        let blogTagsPage = try loadMaterial(
            using: config.pages.blog.tags.path,
            slugPrefix: nil,
            template: "blog.tags"
        )
        let blogPostsPage = try loadMaterial(
            using: config.pages.blog.posts.path,
            slugPrefix: nil,
            template: "blog.posts"
        )
        let docsHomePage = try loadMaterial(
            using: config.pages.docs.home.path,
            slugPrefix: nil,
            template: "docs.home"
        )
        let docsCategoriesPage = try loadMaterial(
            using: config.pages.docs.categories.path,
            slugPrefix: nil,
            template: "docs.categories"
        )
        let docsGuidesPage = try loadMaterial(
            using: config.pages.docs.guides.path,
            slugPrefix: nil,
            template: "docs.guides"
        )

        return .init(
            main: .init(
                home: mainHomePage,
                notFound: mainNotFoundPage
            ),
            blog: .init(
                home: blogHomePage,
                authors: blogAuthorsPage,
                tags: blogTagsPage,
                posts: blogPostsPage
            ),
            docs: .init(
                home: docsHomePage,
                categories: docsCategoriesPage,
                guides: docsGuidesPage
            ),
            custom: try loadMaterials(
                using: config.contents.pages.custom,
                template: "pages.single.page"
            )
        )
    }
    
    private
    func loadBlogMaterials(
        
    ) throws -> SourceMaterials.Blog {
        .init(
            authors: try loadMaterials(
                using: config.contents.blog.authors,
                template: "blog.single.author"
            ),
            tags: try loadMaterials(
                using: config.contents.blog.tags,
                template: "blog.single.tag"
            ),
            posts: try loadMaterials(
                using: config.contents.blog.posts,
                template: "blog.single.post"
            )
        )
    }
    
    private
    func loadDocsMaterials(
        
    ) throws -> SourceMaterials.Docs {
        .init(
            categories: try loadMaterials(
                using: config.contents.docs.categories,
                template: "docs.single.category"
            ),
            guides: try loadMaterials(
                using: config.contents.docs.guides,
                template: "docs.single.guide"
            )
        )
    }
    
    // MARK: -
    
    /// Loads the contents asynchronously.
    ///
    /// - Returns: A `Contents` object containing the loaded contents.
    /// - Throws: An error if loading the contents fails.
    func load(
        
    ) throws -> SourceMaterials {
        .init(
            blog: try loadBlogMaterials(),
            docs: try loadDocsMaterials(),
            pages: try loadPagesMaterials()
        )
    }
    
}