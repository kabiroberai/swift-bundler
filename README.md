<p align="center">
  <img width="100%" src="banner.png">
</p>

<p align="center">
  <a href="https://swiftpackageindex.com/stackotter/swift-bundler"><img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fstackotter%2Fswift-bundler%2Fbadge%3Ftype%3Dswift-versions"></a>
  <a href="https://swiftpackageindex.com/stackotter/swift-bundler"><img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fstackotter%2Fswift-bundler%2Fbadge%3Ftype%3Dplatforms"></a>
  <a href="https://discord.gg/6mUFu3KtAn"><img src="https://img.shields.io/discord/949626773295988746?color=6A7EC2&label=discord&logo=discord&logoColor=ffffff"></a>
</p>

A Swift Package Manager wrapper that allows the creation of macOS apps with Swift packages instead of Xcode projects. My motivation is that I think Xcode projects are a lot more restrictive than Swift packages, and Swift packages are less convoluted. My end goal is to be able to create Swift apps for Windows, Linux and MacOS with a single codebase. You may also be interested in [SwiftCrossUI](https://github.com/stackotter/swift-cross-ui), a UI framework with a similar goal.

## Installation

```sh
git clone https://github.com/stackotter/swift-bundler
cd swift-bundler
sh ./install.sh
```

## Getting started

To create your first app with Swift Bundler, run the following command.

```sh
# Create a new swift package from the SwiftUI template and set it up for Swift Bundler.
swift bundler create HelloWorld --template SwiftUI
```

To learn more about package templates see [the package templates section](#package-templates).

### Run the app

```sh
# Builds and runs the app. The build configuration can
# be specified with the '-c' option (e.g. '-c debug').
swift bundler run
```

### Build a `.app` for the app

```sh
# Build and bundle the app. The default output directory is .build/bundler, but
# it can be changed using the '-o' option.
swift bundler bundle
```

### Configuration

Running `swift bundler create` creates a `Bundler.toml` file which contains all that package's configuration. Below is an example configuration;

```toml
[apps.HelloWorld]
product = "HelloWorld"
version = "0.1.0"
```

Here's an example of a configuration file containing example values for all fields:

```toml
[apps.HelloWorld]
product = "HelloWorld"
version = "0.1.0"
category = "public.app-category.education"
bundle_identifier = "com.example.HelloWorld"
minimum_macos_version = "11"

[apps.HelloWorld.extra_plist_entries]
commit = "{COMMIT}"
```

### Xcode support

If you want to use xcode as your ide, run this in the package's root directory. This command only needs to be run once unless you delete the `.swiftpm` directory.

```sh
# Creates the files necessary to get xcode to run the package as an app
swift bundler generate-xcode-support
```

To open the package in Xcode, just run `open Package.swift` or open `Package.swift` with Xcode through Finder.

### Custom build scripts

Both prebuild and postbuild scripts are supported. Just create the `prebuild.sh` and/or `postbuild.sh` files in the root directory of your project and they will automatically be run with the next build. No extra configuration required. `prebuild.sh` is run before building, and `postbuild.sh` is run after bundling (creating the `.app`).

### App Icons

There are two ways to add custom app icons to a bundler project.

1. The simplest way is to add a file called `Icon1024x1024.png` to the root directory of your package. The png file must have an alpha channel and should be 1024x1024 but this isn't checked when building.
2. If you want to have different versions of your icon for different resolutions you can add an `AppIcon.icns` iconset in the root directory of your package.

If both are present, `AppIcon.icns` is used because it is more specific.

### Info.plist customization

If you want to add extra key-value pairs to your app's Info.plist, you can specify them in an app's `extraPlistEntries` field. Here's an example where the version displayed on the app's about screen is updated to include the current commit hash:

```toml
[apps.HelloWorld.extra_plist_entries]
CFBundleShortVersionString = "{VERSION}_{COMMIT_HASH}"
```

The `{VERSION}` and `{COMMIT_HASH}` variables get replaced at build time with their respective values. See [the variable substition section](#variable-substitions) for more information.

If you provide a value for a key that is already present in the default Info.plist, the default value will be overidden with the value you provide.

### Variable substitions

Some configuration fields (currently only `extraPlistEntries`) support variable substitution. This means that anything of the form `{VARIABLE}` within the field's value will be replaced by the variable's value. Below is a list of all supported variables:

- `VERSION`: The app's configured version
- `COMMIT_HASH`: The commit hash of the git repository at the package's root directory. If there is no git repository, an error will be thrown.

### Package templates

The default package templates are located at `~/Library/Application Support/dev.stackotter.swift-bundler/templates` and are downloaded from [the swift-bundler-templates repository](https://github.com/stackotter/swift-bundler-templates) when the first command requiring the default templates is run.

To learn about creating custom templates, go to [the custom templates section](#creating-custom-templates).

#### List available templates

```
swift bundler templates list
```

#### Update available templates

```
swift bundler templates update
```

#### Get information about a template

```
swift bundler templates info [template]
```

### Help

If you want to see all available options just use the `help` command (e.g. `swift bundler help run`).

## Advanced usage

### Metal shaders

Swift Bundler supports Metal shaders, however all metal files must be siblings within a single directory and they cannot import any header files from the project. This limitation may be fixed in future versions of Swift Bundler, contributions are welcome! The folder containing the shaders must also be added to the app's target (in `Package.swift`) as resources to process, like so:

```swift
// ...
resources: [
  .process("Render/Shader/"),
]
// ...
```

### Multi-app packages

Swift Bundler makes it trivial to create multiple apps from one package. Here's an example configuration with a main app and an updater app:

```toml
[apps.Example]
product = "Example"
version = "0.1.0"

[apps.Updater]
product = "Updater"
version = "1.0.1" # The apps can specify separate versions
```

Once multiple apps are defined, certain commands such as `run` and `bundle` require an app name to be provided in order to know which app to operate on.

### Universal builds

Building a universal version of an app (x86_64 and arm64) can be performed by adding the `-u` to flag to the `run` or `bundle` command.

### Creating custom templates

1. Create a new template 'repository' (a directory that will contain a collection of templates)
2. Create a directory inside the template repository. The name of the directory is the name of your template. (`Base` and `Skeleton` are reserved names).
3. Create a `Template.toml` file with the following contents inside the template directory:
   
   ```toml
   description = "My first package template."
   platforms = ["macOS", "Linux"] # Adjust according to your needs, valid values are `macOS` and `Linux`
   ```
4. Create the template

Any files within the template directory other than `Template.toml` are copied to create packages. Any occurrence of `{{PACKAGE}}` within the file path is replaced with the package's name. Any occurrence of `{{PACKAGE}}` within files ending with `.template` is replaced with the package's name and the `.template` file extension is removed.

**All indentation must be tabs (not spaces) so that the `create` command's `--indentation` option functions correctly**.

You can also create a `Base` directory within the template repository. Whenever creating a new package, the `Base` directory is applied first and can contain files common between all templates, such as the `.gitignore` file. A template can overwrite files in the `Base` template by containing files of the same name.

See [the swift-bundler-templates repository](https://github.com/stackotter/swift-bundler-templates) for some example templates.

## Contributing

Contributions of all kinds are very welcome! Just make sure to check out [the contributing guidelines](CONTRIBUTING.md) before getting started.