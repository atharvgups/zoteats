# Anteats Privacy Policy

_Last updated: September 2026_

Anteats is an unofficial student project for the UC Irvine community. The short
version: **no accounts, no ads, no tracking.** Dish ratings and short reviews
are shared so other Anteats users can read them.

## What we collect

Anonymous dish ratings and optional short written reviews.

- No accounts or sign-in. The app has no login of any kind.
- No analytics, no crash reporting SDKs, no advertising, no tracking of any kind.
- Ratings use a random on-device id, not your name, email, or Apple ID.

## What stays on your device

Your preferences — favorited dishes and campus spots, dietary filters, opening /
favorite / menu-drop alerts, appearance, and today's Plate Builder tally — are
stored locally on your device using Apple's UserDefaults (including an App Group
shared with the Anteats widgets). Deleting the app deletes them. The plate resets
each Irvine calendar day.

Your own ratings are also saved on this iPhone so they still show if the shared
feed is unreachable.

## Shared ratings

When you star a dish or write a short review, Anteats publishes that rating to
the shared community feed (`apple/community-reviews.json` on GitHub, the same
store the app already reads). Other people using Anteats can see the aggregate
and the written notes. You can clear your rating in the dish sheet.

## Network requests

The app fetches public campus data over standard HTTPS with no account
identifiers or personal data attached. Sources:

- `anteaterapi.com` — public UCI dining / menu data (Anteater API)
- `api.elevate-dxp.com` — UCI Dining Hub campus food hours and retail menus
- `waitz.io` — public live occupancy for UCI libraries (and related facilities)
- `uci.libcal.com` — official Langson + Science library building hours
- GitHub (`raw.githubusercontent.com`) — community dish ratings and reviews

Like any web request, the operators of those services may see your IP address as
part of serving the request; Anteats sends nothing else. We do not operate those
services — see their own policies for details.

## App Store Connect "App Privacy" answers

Dish ratings and short reviews are **Other User Content**. They are not linked to
your identity and are not used for tracking. Favorites, filters, and plate totals
stay on-device.

The shipping binary includes a Privacy Nutrition Label manifest
(`PrivacyInfo.xcprivacy`) declaring that user-content category, no tracking, and
Required Reason API access for UserDefaults (app + App Group for widgets).

## Changes

If the app's privacy practices ever change, this document will be updated in the
repository and the App Store listing will reflect it.

## Contact

Questions or concerns? Open an issue on GitHub:
https://github.com/atharvgups/zoteats/issues
