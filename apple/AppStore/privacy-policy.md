# Anteats Privacy Policy

_Last updated: August 2026_

Anteats is an unofficial student project for the UC Irvine community. The short
version: **the app collects no personal data at all.**

## What we collect

Nothing.

- No accounts or sign-in. The app has no login of any kind.
- No analytics, no crash reporting SDKs, no advertising, no tracking of any kind.
- No personal information is collected, stored, or transmitted by us.

## What stays on your device

Your preferences — favorited dishes and campus spots, dietary filters, opening /
favorite / menu-drop alerts, appearance, and today's Plate Builder tally — are
stored locally on your device using Apple's UserDefaults (including an App Group
shared with the Anteats widgets). They never leave your device, and we have no
way to see them. Deleting the app deletes them. The plate resets each Irvine
calendar day.

## Network requests

The app fetches public campus data over standard, read-only HTTPS with no account
identifiers or personal data attached. Sources:

- `anteaterapi.com` — public UCI dining / menu data (Anteater API)
- `api.elevate-dxp.com` — UCI Dining Hub campus food hours and retail menus
- `waitz.io` — public live occupancy for UCI libraries (and related facilities)
- `uci.libcal.com` — official Langson + Science library building hours

Like any web request, the operators of those services may see your IP address as
part of serving the request; Anteats sends nothing else. We do not operate those
services — see their own policies for details.

## App Store Connect "App Privacy" answers

For the App Privacy section in App Store Connect, Anteats qualifies for
**"Data Not Collected"**: the app does not collect any data from this app, for any
purpose, in any category (no contact info, identifiers, usage data, diagnostics,
location, or anything else). Preferences and plate totals stay on-device only.

The shipping binary includes a Privacy Nutrition Label manifest
(`PrivacyInfo.xcprivacy`) declaring no collected data types, no tracking, and
Required Reason API access for UserDefaults (app + App Group for widgets).

## Changes

If the app's privacy practices ever change, this document will be updated in the
repository and the App Store listing will reflect it.

## Contact

Questions or concerns? Open an issue on GitHub:
https://github.com/atharvgups/zoteats/issues
