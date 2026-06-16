// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Bedrock",
    products: [
        .library(
            name: "Bedrock",
            targets: ["Bedrock"]
        ),
        .executable(
            name: "OrderedDictionaryBenchmark",
            targets: ["OrderedDictionaryBenchmark"]
        ),
    ],
    targets: [
        .target(
            name: "Bedrock"
        ),
        .executableTarget(
            name: "OrderedDictionaryBenchmark",
            dependencies: ["Bedrock"],
            path: "Benchmarks/OrderedDictionaryBenchmark",
            exclude: ["README.md"]
        ),
        .testTarget(
            name: "BedrockTests",
            dependencies: ["Bedrock"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
