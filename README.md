# TackMath

A dead-simple tactical sailing compass for iPhone. Lay your phone flat on deck with the
top pointing at the bow, and TackMath shows your implied wind direction, the heading
you'll be on after you tack, your current heel and which tack you're on, and speed over
ground — all on a bow-up compass rose.

This is a **public source mirror** of the app. It's published for transparency and to
back the App Store privacy policy link.

## Privacy

TackMath collects no data. Your compass heading, GPS course, and motion are used on-device,
in the moment, and never stored or transmitted. Full policy: [PRIVACY.md](PRIVACY.md).

## Build

SwiftUI, iOS 17.0+. Open `TackAngle.xcodeproj` in Xcode and run. (The Xcode project and
bundle identifier use the original internal name "TackAngle"; the app ships as "TackMath".)
Compass, GPS, and motion are unavailable in the Simulator — run on a device for live data.
