<div align="center">

# AniniTools

### Your phone's hidden superpowers, in one app.

**Flashlight · Concert Flash · Strobe · Sound Meter · Spirit Level · Compass · Metal Detector — and a full lab of real-time sensors.**

Stop downloading ten single-purpose apps. AniniTools turns the sensors already inside your phone into a pocket toolkit you'll actually use — at a concert, on a job site, on a hike, or just finding a stud in the wall.

<br/>

<a href="https://apps.apple.com/us/app/sound-meter-level-tools/id6755042830">
  <img src="https://developer.apple.com/assets/elements/badges/download-on-the-app-store.svg" alt="Download on the App Store" height="56"/>
</a>
&nbsp;&nbsp;
<a href="https://play.google.com/store/apps/details?id=anini.aninitools">
  <img src="https://play.google.com/intl/en_us/badges/static/images/badges/en_badge_web_generic.png" alt="Get it on Google Play" height="56"/>
</a>

<br/><br/>

![Platform](https://img.shields.io/badge/iOS%20%7C%20Android-black?style=flat-square)
![Price](https://img.shields.io/badge/Price-Free-brightgreen?style=flat-square)
![No Ads Tracking](https://img.shields.io/badge/Privacy-No%20data%20collected-blue?style=flat-square)

</div>

---

## Why people keep AniniTools on their home screen

🔦 **The brightest, fastest flashlight** — one tap to torch. Plus a full-screen color light when you need a glow, not a beam.

🎶 **Own the concert** — scrolling custom text in any color, beat-synced strobe, and flash patterns that turn your phone into the loudest fan in the crowd.

🔊 **Pro-grade Sound Meter** — measure real decibel levels with OSHA noise warnings. Know when it's actually too loud.

📐 **Spirit Level & Compass** — hang the shelf straight, find true north. The tools you wish you had exactly when you need them.

🧲 **Metal Detector** — find studs, nails, and hidden metal using your phone's magnetometer.

📊 **A real sensor lab** — live, graphed readouts for accelerometer, gyroscope, magnetometer, GPS, barometer, proximity, light, and battery. Great for makers, students, and the endlessly curious.

⛰️ **Altitude & Vibration analysis** — elevation from barometer + GPS, and FFT vibration diagnostics for the tinkerers.

> **One app. A dozen tools. Zero clutter.**

---

## Everything inside

| Lights & Show | Measure & Build | Sensor Lab |
|---|---|---|
| Instant flashlight | Sound / decibel meter | Accelerometer |
| Full-screen color light | Spirit level (2D bubble) | Gyroscope |
| Concert scrolling text | Compass + coordinates | Magnetometer |
| Beat-synced strobe | Metal detector | GPS / location |
| Custom flash patterns | Altitude calculator | Barometer (pressure) |
| | Vibration analyzer (FFT) | Proximity · Light · Battery |

---

## Built for trust

- **Free to download.**
- **No account, no sign-up.** Open the app and go.
- **Your data stays on your device.** Sensor readings are processed locally — not harvested. See the [Privacy Policy](docs/privacy.html).

---

<div align="center">

### Ready to unlock your phone?

<a href="https://apps.apple.com/us/app/sound-meter-level-tools/id6755042830">
  <img src="https://developer.apple.com/assets/elements/badges/download-on-the-app-store.svg" alt="Download on the App Store" height="50"/>
</a>
&nbsp;&nbsp;
<a href="https://play.google.com/store/apps/details?id=anini.aninitools">
  <img src="https://play.google.com/intl/en_us/badges/static/images/badges/en_badge_web_generic.png" alt="Get it on Google Play" height="50"/>
</a>

</div>

---

<details>
<summary><h2>For developers</h2></summary>

AniniTools is a cross-platform **Flutter** app (Android + iOS) using an MVVM architecture with `provider` for state management. Sensor access is built on `sensors_plus`, `geolocator`, `battery_plus`, `torch_light`, and `record` + `fftea` for audio/FFT analysis, with `fl_chart` for live graphs.

### Run locally

```bash
flutter pub get
flutter run            # Android or iOS device/simulator
```

### Build releases

```bash
flutter build apk --release       # Android
flutter build appbundle --release # Android (Play Store)
flutter build ios --release       # iOS
```

### Project layout

```
lib/
├── models/        # data models + SharedPreferences wrapper
├── viewmodels/    # ChangeNotifier business logic
├── views/         # UI screens (flashlight, sensors, tools, compass)
├── services/      # sensor + audio abstractions
└── widgets/       # reusable components (graphs, renderers, cards)
```

**Requirements:** Flutter SDK 3.32+, Dart 3.8+. Android minSdk 21 / target 35 · iOS 12+.

> Note: Firebase config (`firebase_options.dart`, `google-services.json`, `GoogleService-Info.plist`) and signing keys are intentionally not committed. Provide your own via `flutterfire configure` to build the Firebase-backed features.

</details>

## License

MIT — see [LICENSE](LICENSE).
