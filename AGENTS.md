# papaWeather development

Use the container for Swift syntax checks. Build from standard input to avoid sending the workspace or local API keys as build context.

```sh
docker build -t papaweather-swift-checks - < Dockerfile
docker run --rm --network none -v "$PWD:/workspace:ro" papaweather-swift-checks
```

The iOS app and App Intents extension require Apple's SDKs. Build and run the `papaWeather` scheme in Xcode 27.1 or later for SwiftUI's arrangement and reserved-region APIs. The project targets iOS 27.0. To build without a specific simulator or signing credentials, run:

```sh
xcodebuild -project papaWeather/papaWeather.xcodeproj \
  -scheme papaWeather -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

When Docker is unavailable, use Xcode's Swift frontend for the syntax check.

```sh
find papaWeather/papaWeather papaWeatherIntents papaWeatherWidgets -name '*.swift' -print0 \
  | xargs -0 xcrun swiftc -frontend -parse
```
