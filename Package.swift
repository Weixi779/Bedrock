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
        .executable(
            name: "OrderedSetBenchmark",
            targets: ["OrderedSetBenchmark"]
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
        .executableTarget(
            name: "OrderedSetBenchmark",
            dependencies: ["Bedrock"],
            path: "Benchmarks/OrderedSetBenchmark",
            exclude: ["README.md"]
        ),
        .testTarget(
            name: "BedrockTests",
            dependencies: ["Bedrock"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
