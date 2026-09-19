# App Store listing draft: ZotEats

Draft copy for the App Store Connect listing. Fields map 1:1 to App Store Connect;
character limits are noted where they apply.

## App name (30 chars max)

ZotEats: UCI Dining & Gym

## Subtitle (30 chars max)

Menus, gym hours & busyness

## Promotional text (170 chars max)

See what's on the menu at The Anteatery and Brandywine, check ARC hours, and find a
quiet library. All live, all in one place. Made by a UCI student, for UCI students.

## Description

ZotEats puts UC Irvine campus life in your pocket:

DINING
- Daily menus for The Anteatery and Brandywine, organized by meal period and station.
- Nutrition info (calories, serving size) for each dish.
- Allergen flags and dietary tags (Vegan, Vegetarian, and more) so you can filter to
  what you can actually eat.
- Save favorites and set a dietary filter. Preferences stay on your device.

GYM
- Anteater Recreation Center (ARC) hours at a glance, for today and the whole week.
- Live busyness for the ARC when occupancy data is available, so you can skip the
  peak-hour crowd.

BUSYNESS
- Live occupancy for campus libraries (Langson, Science, and more) and other tracked
  facilities, powered by public community data.
- Find the least busy spot to study before you walk across Ring Road.

ZotEats is an unofficial, independent student project. It is not affiliated with,
endorsed by, or sponsored by UC Irvine, UCI Dining, or UCI Campus Recreation. All data
comes from public community data sources and may occasionally be incomplete or out of
date. Always check official UCI channels for authoritative hours and menus.

No account. No ads. No tracking. Just campus data.

Have feedback? Use the form at
https://docs.google.com/forms/d/e/1FAIpQLSesZHPTDKKyD0lZ2EXUPtfCdAhWvdi6eT8RgchWjtDqWFXzMw/viewform

## Keywords (100 chars max)

UCI,UC Irvine,dining,menu,anteatery,brandywine,ARC,gym,campus,college,food,busyness

## Category

- Primary: Food & Drink
- Secondary: Lifestyle

## Age rating notes

- No objectionable content: no user-generated content, no gambling,
  no violence, no medical content. Settings can open the public feedback form
  in Safari.
- Expected rating: 4+.

## URLs

- Support URL: https://docs.google.com/forms/d/e/1FAIpQLSesZHPTDKKyD0lZ2EXUPtfCdAhWvdi6eT8RgchWjtDqWFXzMw/viewform
- Marketing URL: none
- Privacy Policy URL: host `apple/AppStore/privacy-policy.md` (e.g. via the GitHub repo
  or GitHub Pages) and paste that link into App Store Connect.

## App Review notes

For the App Review team:

- ZotEats requires no account, login, or demo credentials. All features are available
  immediately on first launch.
- The app only reads public, unauthenticated community data sources:
  - `anteaterapi.com` (Anteater API): public REST API for UCI dining menus, dishes,
    nutrition, and allergen data. No API key or authentication is required.
  - `waitz.io`: public live occupancy feed for UCI facilities (libraries, ARC).
    No API key or authentication is required.
- The app makes no writes to campus data services; it is read-only against those
  feeds. Settings includes a Feedback row that opens the public Anteats Google Form
  in Safari. Submitting that form is optional.
- ZotEats is an unofficial student project and clearly discloses this in the app
  description. It uses no UCI trademarks in its branding beyond factual references to
  campus locations.
- No data is collected from users (see privacy policy: "Data Not Collected").
