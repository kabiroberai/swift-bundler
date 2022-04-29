import Foundation
import ArgumentParser
import Version
import Parsing

/// A utility for interacting with the Swift package manager and performing some other package related operations.
enum SwiftPackageManager {
  /// The path to the swift executable.
  static let swiftExecutable = "/usr/bin/swift"

  /// Creates a new package using the given directory as the package's root directory.
  /// - Parameters:
  ///   - directory: The package's root directory (will be created if it doesn't exist).
  ///   - name: The name for the package.
  /// - Returns: If an error occurs, a failure is returned.
  static func createPackage(
    in directory: URL,
    name: String
  ) -> Result<Void, SwiftPackageManagerError> {
    // Create the package directory if it doesn't exist
    let createPackageDirectory: () -> Result<Void, SwiftPackageManagerError> = {
      if !FileManager.default.itemExists(at: directory, withType: .directory) {
        do {
          try FileManager.default.createDirectory(at: directory)
        } catch {
          return .failure(.failedToCreatePackageDirectory(directory, error))
        }
      }
      return .success()
    }

    // Run the init command
    let runInitCommand: () -> Result<Void, SwiftPackageManagerError> = {
      let arguments = [
        "package", "init",
        "--type=executable",
        "--name=\(name)"
      ]

      let process = Process.create(
        Self.swiftExecutable,
        arguments: arguments,
        directory: directory)
      process.setOutputPipe(Pipe())

      return process.runAndWait()
        .mapError { error in
          .failedToRunSwiftInit(command: "\(Self.swiftExecutable) \(arguments.joined(separator: " "))", error)
        }
    }

    // Create the configuration file
    let createConfigurationFile: () -> Result<Void, SwiftPackageManagerError> = {
      Configuration.createConfigurationFile(in: directory, app: name, product: name)
        .mapError { error in
          .failedToCreateConfigurationFile(error)
        }
    }

    // Compose the function
    let create = flatten(
      createPackageDirectory,
      runInitCommand,
      createConfigurationFile)

    return create()
  }

  /// Builds the specified product of a Swift package.
  /// - Parameters:
  ///   - product: The product to build.
  ///   - packageDirectory: The root directory of the package containing the product.
  ///   - configuration: The build configuration to use.
  ///   - architectures: The set of architectures to build for.
  ///   - platform: The platform to build for.
  /// - Returns: If an error occurs, returns a failure.
  static func build(
    product: String,
    packageDirectory: URL,
    configuration: BuildConfiguration,
    architectures: [BuildArchitecture],
    platform: Platform
  ) -> Result<Void, SwiftPackageManagerError> {
    log.info("Starting \(configuration.rawValue) build")

    let arguments = createBuildArguments(
      product: product,
      packageDirectory: packageDirectory,
      configuration: configuration,
      architectures: architectures,
      platform: platform
    )

    let process = Process.create(
      swiftExecutable,
      arguments: arguments,
      directory: packageDirectory
    )

    return process.runAndWait()
      .mapError { error in
        .failedToRunSwiftBuild(command: "\(swiftExecutable) \(arguments.joined(separator: " "))", error)
      }
  }

  static func createBuildArguments(
    product: String?,
    packageDirectory: URL,
    configuration: BuildConfiguration,
    architectures: [BuildArchitecture],
    platform: Platform
  ) -> [String] {
    let platformArguments: [String]
    if platform == .iOS {
      platformArguments = [
        "-sdk", "/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS15.4.sdk",
        "-target", "arm64-apple-ios14.0"
      ].flatMap { ["-Xswiftc", $0] }
    } else {
      platformArguments = []
    }

    let architectureArguments = architectures.flatMap {
      ["--arch", $0.rawValue]
    }

    let productArguments: [String]
    if let product = product {
      productArguments = ["--product", product]
    } else {
      productArguments = []
    }

    let arguments = [
      "build",
      "-c", configuration.rawValue
    ] + productArguments + architectureArguments + platformArguments

    return arguments
  }

  /// Gets the version of the current Swift installation.
  /// - Returns: The swift version, or a failure if an error occurs.
  static func getSwiftVersion() -> Result<Version, SwiftPackageManagerError> {
    let process = Process.create(
      swiftExecutable,
      arguments: ["--version"])

    return process.getOutput()
      .mapError { error in
        .failedToGetSwiftVersion(error)
      }
      .flatMap { output in
        // Sample: "swift-driver version: 1.45.2 Apple Swift version 5.6 (swiftlang-5.6.0.323.62 clang-1316.0.20.8)"
        let parser = Parse {
          Prefix { $0 != "(" }
          "(swiftlang-"
          Parse({ Version.init(major: $0, minor: $1, patch: $2) }) {
            Int.parser()
            "."
            Int.parser()
            "."
            Int.parser()
          }
          Rest()
        }.map { _, version, _ in
          version
        }

        do {
          let version = try parser.parse(output)
          return .success(version)
        } catch {
          return .failure(.invalidSwiftVersionOutput(output, error))
        }
      }
  }

  /// Gets the default products directory for the specified package and configuration.
  /// - Parameters:
  ///   - packageDirectory: The package's root directory.
  ///   - configuration: The current build configuration.
  ///   - architectures: The architectures that the build was for.
  /// - Returns: The default products directory. If `swift build --show-bin-path ... # extra args` fails, a failure is returned.
  static func getProductsDirectory(
    in packageDirectory: URL,
    configuration: BuildConfiguration,
    architectures: [BuildArchitecture],
    platform: Platform
  ) -> Result<URL, SwiftPackageManagerError> {
    let arguments = createBuildArguments(
      product: nil,
      packageDirectory: packageDirectory,
      configuration: configuration,
      architectures: architectures,
      platform: platform
    ) + ["--show-bin-path"]

    let process = Process.create(
      "/usr/bin/swift",
      arguments: arguments,
      directory: packageDirectory
    )

    return process.getOutput()
      .flatMap { output in
        let path = output.trimmingCharacters(in: .newlines)
        return .success(URL(fileURLWithPath: path))
      }
      .mapError { error in
        let command = "/usr/bin/swift " + arguments.joined(separator: " ")
        return .failedToGetProductsDirectory(command: command, error)
      }
  }
}
