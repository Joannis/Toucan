import ArgumentParser
import ToucanSDK

@main
struct Entrypoint: ParsableCommand {

    static var configuration = CommandConfiguration(
        commandName: "toucan",
        abstract: """
            Toucan
            """,
        discussion: """
            A markdown-based Static Site Generator (SSG) written in Swift.
            """,
        version: "0.1.0",
        subcommands: [
            Generate.self,
            Serve.self,
            Watch.self,
        ]
    )
}
