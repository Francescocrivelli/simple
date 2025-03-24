//
//  Package.swift
//  simple
//
//  Created by Francesco Crivelli on 3/23/25.
//

// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "simple",
    platforms: [
        .iOS(.v15)
    ],
    dependencies: [
        .package(url: "https://github.com/supabase-community/supabase-swift.git", .upToNextMajor(from: "0.3.0"))
    ],
    targets: [
        .target(
            name: "simple",
            dependencies: [
                .product(name: "Supabase", package: "supabase-swift")
            ]
        )
    ]
)
