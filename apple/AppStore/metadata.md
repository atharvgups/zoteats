# Anteats — App Store listing

Source of truth for automation: `metadata.json` (this file is the human-readable twin).

| Field | Value |
|---|---|
| Name | Anteats |
| Subtitle | UCI dining, campus & study |
| Bundle ID | `com.atharvgupta.zoteats` |
| Primary category | Food & Drink |
| Secondary | Lifestyle |
| Privacy | Data Not Collected — see `privacy-policy.md` |
| Privacy URL | GitHub raw `privacy-policy.md` on `main` |
| Support | https://github.com/atharvgups/zoteats/issues |

## Shipping

1. Dogfood on Internal TestFlight (`testflight-x.y.z`).
2. When ready for the public store, push `appstore-x.y.z` (or run the **App Store** workflow).
3. CI attaches the latest VALID build, applies listing metadata / screenshots, and submits for App Review via the ASC `reviewSubmissions` API.
4. In-flight Waiting for Review submissions are canceled first when `CANCEL_IN_FLIGHT_REVIEW=true` (default on the App Store workflow). If ASC refuses, cancel once in the UI: **App Store Connect → Anteats → App Review → Cancel Submission**.

First submission may still need a one-time pass in App Store Connect for age rating, pricing (Free), and any missing screenshot size if Apple rejects the 6.7" set.

## User-only App Store Connect blockers

These cannot be automated from CI without your Apple account / ASC console:

1. **App record** — create/confirm Anteats (`com.atharvgupta.zoteats`) in App Store Connect if not already.
2. **Signing** — Distribution certificate + App Store provisioning profile (or Ascendency CI secrets already wired).
3. **Age rating / pricing** — one-time Free + age questionnaire if ASC rejects the API submit.
4. **Privacy nutrition labels** — confirm “Data Not Collected” is **Published** in ASC and matches `privacy-policy.md` + in-app `PrivacyInfo.xcprivacy`. Merge this branch to `main` before App Store submit so the privacy URL serves the Anteats policy.
5. **Screenshots** — verify 6.7" (and any required 6.5"/iPad) sets look current; CI clears and re-uploads from `metadata.json` `screenshot_files` (no Gym frames).
6. **External TestFlight** — first build of a marketing version still needs Apple Beta App Review before “Zot Eats Testers!” gets it.

## Gym

Gym / ARC busy UI is **not** in shipping builds until UCI/Occuspace confirms live ARC sensors. Code stays parked (`App/Gym/**` excluded from XcodeGen; ARC widget behind `#if ANTEATS_ENABLE_GYM`).
