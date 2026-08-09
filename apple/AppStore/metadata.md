# Anteats — App Store listing

Source of truth for automation: `metadata.json` (this file is the human-readable twin).

| Field | Value |
|---|---|
| Name | Anteats |
| Subtitle | UCI dining, gym & study |
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

First submission may still need a one-time pass in App Store Connect for age rating, pricing (Free), and any missing screenshot size if Apple rejects the 6.7" set.
