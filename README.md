# heka-swift-package

Swift package to integrate with Heka and get data from various fitness and health data sources.


Integrate Google Fit, Apple Healthkit and other fitness data sources in your app with just 4 lines of code.

Integrating health data from smart watches is not easy and requires understanding how various smart watches and operating systems work. On top of that, the way to get data reliability from different sources is different with data format also being different.

The Heka smartwatch integration makes it easy to integrate various watches and reliably get data on the server. With a couple of one-time setup steps, 4 lines of code and you have integrated all smart devices into your product.

## Creating an app on Heka Dashboard

Dashboard

    1. Create an account on our web app at [HekaHealth Dashboard](https://appdev.hekahealth.co).

    2. Register your application.

    3. Creating an app will provide you with an HekaHealth API Key. This you will require when integrating the HekaHealth SDK on the app side.

That’s all you need to do on the dashboard side.

## Setting up on app side

Step 1: Append the Info.plist with the following 2 entries

```xml
<key>NSHealthShareUsageDescription</key>
<string>We will sync your data with the Apple Health app to give you better insights</string>
<key>NSHealthUpdateUsageDescription</key>
<string>We will sync your data with the Apple Health app to give you better insights</string>
```

Step 2: Open your Flutter project in Xcode by right clicking on the "ios" folder and selecting "Open in Xcode". Next, enable "HealthKit" by adding a capability inside the "Signing & Capabilities" tab of the Runner target's settings. Also make sure to enable the background delivery option.

## Usage

Add this package as dependencies in your Xcode project. The following lines of code will be enough
to render the UI component with state management and syncing logic plugged in.

```swift
HekaUIView(
    uuid: "<user-uuid-goes-here>",
    apiKey: "<your-api-key-goes-here>"
)
```

## Getting the data

The collected data is unified in single format and sent to the webhook url configured while registering the app on our dashboard.
