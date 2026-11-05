# GrammarLens 1.4.0 — approved scope; waiting for text approval

No ASC writes performed. Search-results artwork is cancelled and excluded. Header A/vivid: `../product-page/header.png`, 3840 × 1646, one library image reused for eight 1.4.0 localizations.

## Current state and explicit decisions

- Version 1.4.0 exists in PREPARE_FOR_SUBMISSION; releaseType MANUAL. Only en-US exists.
- Re-read after owner saved in ASC (2026-11-05): build 7 is attached and VALID. Version remains PREPARE_FOR_SUBMISSION, releaseType MANUAL. The obsolete build-attachment PATCH has been removed; final read-back calls remain.
- Store text was not present as separate ready JSON files: descriptions/subtitles/keywords originated in docs/1.4.0-asc-brief.md; ja/ko privacy, ja subscription wording and de consent timing were then corrected exactly as requested by the owner; What's New verbatim from docs/1.4.0-release-steps.md §5. Full bodies are in metadata.json and dry-run-calls.json. Blind back-translation is complete: see [description-back-translation.md](description-back-translation.md) for the three requested correction rows, rechecked blind on the four changed blocks only (the initial seven-language pass is retained in Git commit b2c3bb1). The three corrected rows match. tr, es-MX, pt-BR and ar-SA were approved as-is. Stop for owner review; upload/checkpoint 3 requires the explicit “upload” instruction.
- Owner approved keeping promotional text blank in all eight locales (empty string in request).
- Seven additional store locale identifiers: tr, de-DE, es-MX, pt-BR, ja, ko, ar-SA.
- Subtitle belongs to editable appInfo localization; description, keywords, What's New, promotionalText and supportUrl belong to version localizations. Name retained; privacyPolicyUrl copied from brief, no App Privacy declarations touched.
- Existing en-US screenshots: remove only 14 placements belonging to 1.4.0 (8 large iPhone + 6 iPad), never their shared library image assets. Reuse sets if retained; if ASC removes empty sets, recreate the same display type under 1.4.0 only.
- Delete only copied en-US APP_IPHONE_61 set under 1.4.0. The live 1.3.0 is read-only and excluded from write targets.
- Review notes retain the existing notes, condense the historical 1.3.0 subscription-display paragraph, and append the seven languages + Profile → Appearance → Language + English question/feedback note. Full proposed text: review-notes.txt.
- Header may remain pending its own review. Upload and attach only; no review submission or asset publication calls. Owner handles submission.

## Calls and payloads

`dry-run-calls.json` lists every request in execution order, with complete JSON bodies, each binary file's path, exact size/checksum, all 112 screenshot reservations, each upload/commit/poll, each set order, the 6.3-inch deletion, header upload and eight associations, and final reads. `${...}` identifiers are response IDs; upload part URLs/headers/offsets are known only after reservation and are intentionally not credentials in this report. Loops/polls and conditional byte-limit retries are annotated. Read preflight GETs are recorded outside Git at `/private/tmp/grammarlens-140-asc-read.log`.

## Ordering

- iPhone: 01-results, 04-question, 02-hint, 08-multi-blank, 03-home, 05-review, 06-collection, 07-onboarding.
- iPad: 01-results, 04-question, 02-hint, 03-home, 05-review, 06-collection.
- 64 iPhone + 48 iPad = 112 exact checked files. Order follows the approved design, not filename sorting.

## Limits

See length-report.json for characters and UTF-8 bytes. Original keywords are attempted first; if ASC specifically rejects UTF-8 byte length, the exact approved fallback in keyword-fallbacks.json is retried once. The owner approved these byte-limit fallbacks, used only after a matching ASC rejection. Other rejections stop execution and are reported. Header dimensions are confirmed by GET /v1/appAssetLibraryRefData, placement PRODUCT_PAGE_HEADER_ASSET / DEFAULT_PROFILE.


| Locale | Subtitle | Description | Keywords chars / bytes | What’s New | Promotional |
|---|---:|---:|---:|---:|---:|
| en-US | 29 | 2437 | 94 / 94 | 689 | 0 |
| tr | 28 | 2351 | 82 / 85 | 708 | 0 |
| de-DE | 29 | 2567 | 85 / 88 | 801 | 0 |
| es-MX | 28 | 2542 | 86 / 90 | 746 | 0 |
| pt-BR | 29 | 2462 | 80 / 84 | 717 | 0 |
| ja | 15 | 1275 | 46 / 112 | 346 | 0 |
| ko | 16 | 1357 | 44 / 106 | 359 | 0 |
| ar-SA | 26 | 2057 | 80 / 149 | 627 | 0 |

## Scope

No search-results artwork upload; no submission/review submission creation; no release; no 1.3.0 writes; no pricing, availability, age rating or App Privacy changes. No credentials or bearer tokens in these files. Owner approved the screenshot/header/deletion/review-note/manual-release scope. Wait for explicit checkpoint 2 text approval before any upload or ASC write.

Official API sources: [App Asset Library](https://developer.apple.com/documentation/appstoreconnectapi/app-asset-library), [image uploads](https://developer.apple.com/documentation/appstoreconnectapi/uploading-and-managing-image-assets), [placement](https://developer.apple.com/documentation/appstoreconnectapi/placing-assets-on-your-app-store-surfaces).
