# Balanced header v5 — current read-back

Status: **passed**. Read at 2026-11-05T16:57:53.687Z.

Version **1.4.0**, build **7**, **PREPARE_FOR_SUBMISSION**, **MANUAL**. No submission or release.

The owner reported that v4 was too small on iPhone and clipped at the bottom on iPad. v5 uses separate measurements from both supplied ASC previews: iPhone image scale ≈0.194 with a 94 px top offset, iPad scale ≈0.492 with a −80 px vertical offset. The phone screenshot’s visible header is 626 × 414; iPad is 1893 × 568.

Wordmark width is 1850 source pixels (approximately 44% larger than v4), and the correction card scale is 0.75 (approximately 21% larger). The card is moved up to stay above the measured iPad bottom crop. [Comparison with the actual supplied previews](../product-page/header-device-comparison-v5.png) labels its new renders as calibrated simulations; final visual confirmation remains in ASC.

Source: `screenshots/1.4.0/product-page/header-A-balanced-v5.png`, 3840 × 1646 opaque RGB. SHA-256: `4292acd44747a5323c6ecdfc84eadace21843a560c3b5e102982a9683c73f109`. Canonical `product-page/header.png` has identical bytes.

New shared image ID: `0a800019-5fee-8562-801c-b7fb50f2373a`. Asset state: **PREPARE_FOR_SUBMISSION**.

| Locale | Placement ID | Verified image ID | State |
|---|---|---|---|
| en-US | `9a000019-5fee-8562-8f04-8b6622bafce9` | `0a800019-5fee-8562-801c-b7fb50f2373a` | ACTIVE |
| tr | `ebc00019-5fee-8562-8f3b-aa63f2ea6017` | `0a800019-5fee-8562-801c-b7fb50f2373a` | ACTIVE |
| de-DE | `6c800019-5fee-8562-8f1d-228139bbc739` | `0a800019-5fee-8562-801c-b7fb50f2373a` | ACTIVE |
| es-MX | `c3000019-5fee-8562-8f2f-0c3e756271d4` | `0a800019-5fee-8562-801c-b7fb50f2373a` | ACTIVE |
| pt-BR | `6e400019-5fee-8562-8f26-831f8be07380` | `0a800019-5fee-8562-801c-b7fb50f2373a` | ACTIVE |
| ja | `ffc00019-5fee-8562-8f3d-53797c8c0dd8` | `0a800019-5fee-8562-801c-b7fb50f2373a` | ACTIVE |
| ko | `f9000019-5fee-8562-8f16-aacea9002d5d` | `0a800019-5fee-8562-801c-b7fb50f2373a` | ACTIVE |
| ar-SA | `9a400019-5fee-8562-8f3e-6db1b016e321` | `0a800019-5fee-8562-801c-b7fb50f2373a` | ACTIVE |

Only the eight 1.4.0 header placements were replaced. The previous library image was retained. All 112 screenshots, localization texts, review notes, version/build and release settings were preserved. No pricing, availability, age rating, App Privacy or 1.3.0 changes.

API rejections: **0**. Processing retries: **0**. Run log: `/Users/ahmet/Pictures/GrammarLens/1.4.0-asc/2026-11-05/header-balanced-v5-requests.jsonl`.
