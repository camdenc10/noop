# Noop

A free, private fitness and recovery tracker for iPhone. SwiftUI, Swift Charts, HealthKit, SwiftData. No account, no ads, no subscription, no network code at all.

**Important: this code was written without access to Xcode, so it has never been compiled.** Expect a few small compile errors on the first build. Copy any error from Xcode and paste it back and they are quick fixes.

## What you need
- A Mac with Xcode 15 or newer
- An iPhone on iOS 17 or newer (HealthKit does not work in the Simulator with real data, but demo mode runs there)
- A free Apple ID is enough. Free installs expire after 7 days; just rebuild.

## Install (about 5 minutes)
1. Xcode > File > New > Project > iOS > App. Product Name `Noop`, Interface SwiftUI, Storage None, Language Swift. Save it somewhere.
2. Delete the generated `ContentView.swift` and the generated `NoopApp.swift`.
3. Drag the `Noop` folder from this download (the one with App, Design, Engine, Model, Services, Views) into the Xcode project navigator. Tick "Copy items if needed", "Create groups", and your app target.
4. Select the project > target `Noop` > General > Minimum Deployments: **iOS 17.0**.
5. Signing & Capabilities > pick your Team. Click **+ Capability** > **HealthKit**.
6. Info tab > add the row **Privacy - Health Share Usage Description** with text like: `Noop reads your heart rate, HRV, sleep, steps and workouts to calculate scores on this phone.`
   Also add **Privacy - Bluetooth Always Usage Description**: `Noop connects to your Bluetooth heart rate sensor to show its battery level and live heart rate.`
7. Plug in your iPhone, choose it at the top, press Run. On the phone you may need Settings > General > VPN & Device Management > trust your developer account.

### Shortcut with XcodeGen
`brew install xcodegen`, then in this folder run `xcodegen`, open `Noop.xcodeproj`, choose your Team under Signing, and Run. `project.yml` sets up the capability and the Health description for you.

## First launch
The app opens on **demo data** (clearly marked DEMO DATA) so you can look around. Go to **Profile > Connect Apple Health**, allow the categories you want, and it switches to your real data and builds up to 118 days of history.

Set your age (and ideally your real max heart rate) in Profile. That sets your heart rate zones, which drive strain.

## What is in each tab
- **Home**: Recovery, Strain and Sleep at a glance, then metric cards.
- **Recovery**: score, HRV, resting HR, respiratory rate, score breakdown, history, insights.
- **Sleep**: stage timeline, performance, need, debt, consistency, trends.
- **Activity**: strain, zones, steps, calories, workouts, trends.
- **Profile**: data source, body settings, how scores work.

Trend charts have 7, 30 and 90 day ranges. Touch and drag on a chart to read an exact value.

## Sensor battery (top right of Home)
Tap the band icon at the top right to pair a Bluetooth heart rate sensor. When it reports its battery through the standard Bluetooth Battery service, you get the gray percentage and a green dot while connected. Noop does not use any proprietary protocol, so a device that doesn't publish the standard services (this includes Whoop bands in their normal mode) won't show a battery. With nothing paired, the icon is dimmed.

## Honest limits
- Scores are transparent estimates (see Profile > How scores work), not Whoop's or Oura's proprietary numbers, and they are not medical advice.
- Apple Watch only records heart rate in bursts outside workouts, so strain on days without workouts is rougher than with a continuous strap.
- HRV from Health is SDNN. Other devices often report RMSSD. They are not comparable.
- Anything Health can't provide shows as a dash and "Unavailable". Nothing is invented. Sleep stages need an Apple Watch or another source that writes stages.

## Code map
- `Engine/ScoringEngine.swift`: every formula, in one place
- `Engine/DemoData.swift`: deterministic sample data
- `Services/HealthService.swift`: read-only HealthKit queries
- `Services/AppStore.swift`: state, sync, demo/live switching
- `Model/Persistence.swift`: SwiftData cache of raw daily values (scores are recomputed, never stored)
- `Design/`: theme, components, charts
