# heka-swift-package

Swift package to integrate with Heka and get data from various fitness and health data sources.

Integrate Apple Healthkit, Fitbit and other fitness data sources in your app with just 4 lines of code.

Integrating health data from smart watches is not easy and requires understanding how various smart watches and operating systems work. On top of that, the way to get data reliability from different sources is different with data format also being different.

The Heka smartwatch integration makes it easy to integrate various watches and reliably get data on the server. With a couple of one-time setup steps, 4 lines of code and you have integrated all smart devices into your product.

## Creating an app on Heka Dashboard

1. Create an account on our web app at [HekaHealth Dashboard](https://appdev.hekahealth.co).
2. Register your application.
3. Creating an app will provide you with an HekaHealth API Key. This you will require when integrating the HekaHealth SDK on the app side.

That’s all you need to do on the dashboard side.

## Setting the app

1) Append the `Info.plist` with the following 2 entries

```xml
<key>NSHealthShareUsageDescription</key>
<string>We will sync your data with the Apple Health app to give you better insights</string>
<key>NSHealthUpdateUsageDescription</key>
<string>We will sync your data with the Apple Health app to give you better insights</string>
```

2) Open your Flutter project in Xcode by right-clicking on the `ios` folder and selecting `Open in Xcode`. Next, enable `HealthKit` by adding a capability inside the `Signing & Capabilities` tab of the Runner target's settings. Also, make sure to enable the background delivery option.

3) Add this package under `Project` -> `Package dependencies` in your Xcode project.

## Usage

The following lines of code will be enough to render the UI component with state management and syncing logic plugged in.

```swift
HekaUIView(
    uuid: "<user-uuid-goes-here>",
    apiKey: "<your-api-key-goes-here>"
)
```

## Getting the data

The data is unified in a single format and sent to the webhook URL configured while registering the app on our dashboard.

## Sample app

A sample app that uses the `HekaUIView` can be found at [heka-ios-sample](https://github.com/HekaHealth/heka-ios-sample).

## FAQs

**Q.** If the user denies Apple Healthkit permission, it doesn't show any error and connects. Shouldn't it prevent connecting and show an error message about permission not being granted?

**Ans.** Unfortunately, Apple Healthkit provides no way to detect if a user has granted permission or not due to privacy reasons. The queries that get data from Healthkit don't return an error and rather return an empty list if permissions are not granted.
We think the best way to handle this is to ask users to make sure permissions are granted from the health app if data is not getting synced.
