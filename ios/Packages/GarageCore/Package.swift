// swift-tools-version: 5.9
import PackageDescription

// Pure Swift: models and the maintenance/mileage/cost logic ported from the web
// app's src/lib. No UI and no Supabase dependency, so `swift test` runs it on the Mac.
let package = Package(
    name: "GarageCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "GarageCore", targets: ["GarageCore"])],
    targets: [
        .target(name: "GarageCore"),
        .testTarget(
            name: "GarageCoreTests",
            dependencies: ["GarageCore"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
