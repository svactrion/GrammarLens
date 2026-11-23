# GrammarLens 1.5.0 App Store Connect dry run

**Status:** Read-only preflight passed on 2026-11-23. Waiting for the owner’s OK. No App Store Connect changes made.

- App ID `6811477346` (`com.ahmettayfur.grammarlens`).
- Live 1.4.0 is `READY_FOR_SALE / READY_FOR_DISTRIBUTION`. No iOS 1.5.0 record exists. Build 8 is `VALID`, ID `66d41ad9-faa7-4255-8604-ddcdd33b5b48`, and is not attached to a 1.5.0 draft.
- Create 1.5.0 in `PREPARE_FOR_SUBMISSION` with `MANUAL` release and attach build 8. Update eight exact descriptions and release notes, one App Review notes field, 96 screenshots and eight placements of a single header.
- Read-only baseline totals for 1.4.0 are eight localizations, 64 iPhone screenshots, 48 iPad screenshots and eight header placements. Only newly copied placements belonging to 1.5.0 can be detached. Keep all old library assets. No other screenshot set was found on the baseline.
- The API returns null for the empty promotional-text field in all eight locales. The source and the previous approved data both use an empty string. Both represent an unset field and no write is planned. All other untouched text fields match, including app names checked against the prior approved read-back because the 1.5.0 JSON has no name field.
- Baseline review details have all four contact fields, no demo account requirement, 3,870 characters of notes and 0 reported attachment(s). The draft contact, demo setting and attachment list will be compared before and after the notes write. The new notes contain 3,977 characters.
- The older display enums in the screenshot API are the ones observed on live 1.4.0 and map to the placement groups below. The approved newer-dimension files will go in those same groups.
- No submission, release, 1.4.0 writes, non-scope asset removal, build/upload of a new binary, or changes to account or product settings. Stop on an API error except the existing-localization 409 branch specified in §3.3. If header placement is unavailable, surface the failed request and error for the owner.

## Planned final state by locale

| Locale | iPhone display type and count | iPad display type and count | Text fields | Header |
| --- | --- | --- | --- | --- |
| en-US | APP_IPHONE_67, 6 | APP_IPAD_PRO_3GEN_129, 6 | description 2843 chars; whatsNew 678 chars | Shared header.png, one placement |
| tr | APP_IPHONE_67, 6 | APP_IPAD_PRO_3GEN_129, 6 | description 2772 chars; whatsNew 703 chars | Shared header.png, one placement |
| de-DE | APP_IPHONE_67, 6 | APP_IPAD_PRO_3GEN_129, 6 | description 3033 chars; whatsNew 798 chars | Shared header.png, one placement |
| es-MX | APP_IPHONE_67, 6 | APP_IPAD_PRO_3GEN_129, 6 | description 3015 chars; whatsNew 782 chars | Shared header.png, one placement |
| pt-BR | APP_IPHONE_67, 6 | APP_IPAD_PRO_3GEN_129, 6 | description 2910 chars; whatsNew 745 chars | Shared header.png, one placement |
| ja | APP_IPHONE_67, 6 | APP_IPAD_PRO_3GEN_129, 6 | description 1549 chars; whatsNew 388 chars | Shared header.png, one placement |
| ko | APP_IPHONE_67, 6 | APP_IPAD_PRO_3GEN_129, 6 | description 1626 chars; whatsNew 406 chars | Shared header.png, one placement |
| ar-SA | APP_IPHONE_67, 6 | APP_IPAD_PRO_3GEN_129, 6 | description 2449 chars; whatsNew 655 chars | Shared header.png, one placement |

## Live baseline read back for comparison

### en-US

Localization `207797dd-54bd-480e-be43-41ef1c6bac66`. App name, subtitle, keywords, support URL and privacy policy URL matched the approved sources. Promotional text is unset.

| Display type | Existing count | Ordered file names |
| --- | ---: | --- |
| APP_IPAD_PRO_3GEN_129 | 6 | 01-results.png, 04-question.png, 02-hint.png, 03-home.png, 05-review.png, 06-collection.png |
| APP_IPHONE_67 | 8 | 01-results.png, 04-question.png, 02-hint.png, 08-multi-blank.png, 03-home.png, 05-review.png, 06-collection.png, 07-onboarding.png |

Header placement `9a000019-5fee-8562-8f04-8b6622bafce9`, image `0a800019-5fee-8562-801c-b7fb50f2373a`.

### tr

Localization `f2380dc1-9551-4863-afb3-c6dd6496e0f3`. App name, subtitle, keywords, support URL and privacy policy URL matched the approved sources. Promotional text is unset.

| Display type | Existing count | Ordered file names |
| --- | ---: | --- |
| APP_IPHONE_67 | 8 | 01-results.png, 04-question.png, 02-hint.png, 08-multi-blank.png, 03-home.png, 05-review.png, 06-collection.png, 07-onboarding.png |
| APP_IPAD_PRO_3GEN_129 | 6 | 01-results.png, 04-question.png, 02-hint.png, 03-home.png, 05-review.png, 06-collection.png |

Header placement `ebc00019-5fee-8562-8f3b-aa63f2ea6017`, image `0a800019-5fee-8562-801c-b7fb50f2373a`.

### de-DE

Localization `9c4a2cfe-bd96-4ee7-b37f-d9e778d16fa2`. App name, subtitle, keywords, support URL and privacy policy URL matched the approved sources. Promotional text is unset.

| Display type | Existing count | Ordered file names |
| --- | ---: | --- |
| APP_IPHONE_67 | 8 | 01-results.png, 04-question.png, 02-hint.png, 08-multi-blank.png, 03-home.png, 05-review.png, 06-collection.png, 07-onboarding.png |
| APP_IPAD_PRO_3GEN_129 | 6 | 01-results.png, 04-question.png, 02-hint.png, 03-home.png, 05-review.png, 06-collection.png |

Header placement `6c800019-5fee-8562-8f1d-228139bbc739`, image `0a800019-5fee-8562-801c-b7fb50f2373a`.

### es-MX

Localization `59562966-9555-4e74-a371-1f7f6c171cf7`. App name, subtitle, keywords, support URL and privacy policy URL matched the approved sources. Promotional text is unset.

| Display type | Existing count | Ordered file names |
| --- | ---: | --- |
| APP_IPHONE_67 | 8 | 01-results.png, 04-question.png, 02-hint.png, 08-multi-blank.png, 03-home.png, 05-review.png, 06-collection.png, 07-onboarding.png |
| APP_IPAD_PRO_3GEN_129 | 6 | 01-results.png, 04-question.png, 02-hint.png, 03-home.png, 05-review.png, 06-collection.png |

Header placement `c3000019-5fee-8562-8f2f-0c3e756271d4`, image `0a800019-5fee-8562-801c-b7fb50f2373a`.

### pt-BR

Localization `6d01380e-710f-48c4-80c3-1079cc96e9c0`. App name, subtitle, keywords, support URL and privacy policy URL matched the approved sources. Promotional text is unset.

| Display type | Existing count | Ordered file names |
| --- | ---: | --- |
| APP_IPAD_PRO_3GEN_129 | 6 | 01-results.png, 04-question.png, 02-hint.png, 03-home.png, 05-review.png, 06-collection.png |
| APP_IPHONE_67 | 8 | 01-results.png, 04-question.png, 02-hint.png, 08-multi-blank.png, 03-home.png, 05-review.png, 06-collection.png, 07-onboarding.png |

Header placement `6e400019-5fee-8562-8f26-831f8be07380`, image `0a800019-5fee-8562-801c-b7fb50f2373a`.

### ja

Localization `b704a413-2638-4cdf-a8a6-7e4524012aef`. App name, subtitle, keywords, support URL and privacy policy URL matched the approved sources. Promotional text is unset.

| Display type | Existing count | Ordered file names |
| --- | ---: | --- |
| APP_IPAD_PRO_3GEN_129 | 6 | 01-results.png, 04-question.png, 02-hint.png, 03-home.png, 05-review.png, 06-collection.png |
| APP_IPHONE_67 | 8 | 01-results.png, 04-question.png, 02-hint.png, 08-multi-blank.png, 03-home.png, 05-review.png, 06-collection.png, 07-onboarding.png |

Header placement `ffc00019-5fee-8562-8f3d-53797c8c0dd8`, image `0a800019-5fee-8562-801c-b7fb50f2373a`.

### ko

Localization `39426655-dc45-44a6-9cdb-c583ecdda1e7`. App name, subtitle, keywords, support URL and privacy policy URL matched the approved sources. Promotional text is unset.

| Display type | Existing count | Ordered file names |
| --- | ---: | --- |
| APP_IPAD_PRO_3GEN_129 | 6 | 01-results.png, 04-question.png, 02-hint.png, 03-home.png, 05-review.png, 06-collection.png |
| APP_IPHONE_67 | 8 | 01-results.png, 04-question.png, 02-hint.png, 08-multi-blank.png, 03-home.png, 05-review.png, 06-collection.png, 07-onboarding.png |

Header placement `f9000019-5fee-8562-8f16-aacea9002d5d`, image `0a800019-5fee-8562-801c-b7fb50f2373a`.

### ar-SA

Localization `a741abc3-8025-45b2-9c7e-8362156d87d4`. App name, subtitle, keywords, support URL and privacy policy URL matched the approved sources. Promotional text is unset.

| Display type | Existing count | Ordered file names |
| --- | ---: | --- |
| APP_IPAD_PRO_3GEN_129 | 6 | 01-results.png, 04-question.png, 02-hint.png, 03-home.png, 05-review.png, 06-collection.png |
| APP_IPHONE_67 | 8 | 01-results.png, 04-question.png, 02-hint.png, 08-multi-blank.png, 03-home.png, 05-review.png, 06-collection.png, 07-onboarding.png |

Header placement `9a400019-5fee-8562-8f3e-6db1b016e321`, image `0a800019-5fee-8562-801c-b7fb50f2373a`.

## Source manifest

Each PNG was decoded and checked for its listed dimensions and RGB color mode with no alpha or transparency. The metadata JSON contains the eight expected locales and both text fields are under the limit.

| Source | Dimensions | Bytes | SHA-256 |
| --- | --- | ---: | --- |
| `docs/1.5.0-store-metadata.json` | — | 36692 | `ac40f8e697ea22d135515b62b292b2a873859c9412e208d7b665f359884a04d4` |
| `docs/1.5.0-review-notes.txt` | — | 3997 | `bbcaa2d4bd5441dde1b5f2512fcef72f9ef5541b0a0d55074f708702bf8d9774` |
| `docs/1.5.0-store-texts.md` | — | 18133 | `f65a9a2f792d6d9efca58f33d2fe3bbac2fc86516c4df439b720919e64515124` |
| `screenshots/1.5.0/revizyon-11/en/iphone-6.9/01-feedback.png` | 1320 × 2868 | 3114076 | `3ea222923bc513ae73bfbb9d94fb15d6268896b481bb6e7297c8dabb445be5c4` |
| `screenshots/1.5.0/revizyon-11/en/iphone-6.9/02-review-ticket.png` | 1320 × 2868 | 2966010 | `79ea50d5bc94c5595e2ebc8ec92dfcad9b541e3d59f0aa924e9f35e4dd84da3e` |
| `screenshots/1.5.0/revizyon-11/en/iphone-6.9/03-hint.png` | 1320 × 2868 | 3905336 | `ab6c81f0c1c3510b56152bdc337f93843a1578de1f1fa9157d829b81275a037f` |
| `screenshots/1.5.0/revizyon-11/en/iphone-6.9/04-film.png` | 1320 × 2868 | 2854787 | `abaa676afd81ae69a31f9ecddd678fae029adbdfb947215d713ff502a792a9a4` |
| `screenshots/1.5.0/revizyon-11/en/iphone-6.9/05-first-step.png` | 1320 × 2868 | 3349915 | `2c5c9598ac5d0cfeadd04647e9856e495f34da3c70f9fee4abec20bf0ab9f3f3` |
| `screenshots/1.5.0/revizyon-11/en/iphone-6.9/06-monthly-mountains.png` | 1320 × 2868 | 4735657 | `420f6c7f1040850d1605b82dfef99d44384a5f60991ced0c89164b74517457ff` |
| `screenshots/1.5.0/revizyon-11/en/ipad-13/01-feedback.png` | 2064 × 2752 | 3411751 | `6e3e8e1c8fa36b9466bb4c8642f8fbac6ca96855b25f00e3e23b9ca62adcb9a3` |
| `screenshots/1.5.0/revizyon-11/en/ipad-13/02-review-ticket.png` | 2064 × 2752 | 3209725 | `288c5f0abd95bb373003d27f7b78f42606190e6fcd3bcee018f1f32f93222d8d` |
| `screenshots/1.5.0/revizyon-11/en/ipad-13/03-hint.png` | 2064 × 2752 | 4089484 | `3306fdcc462f32e655b4d3db3a5d68c10b7d06c89bd82599c6683d37c55ef903` |
| `screenshots/1.5.0/revizyon-11/en/ipad-13/04-film.png` | 2064 × 2752 | 2842643 | `4e09e19f72746a733f53c5ee6240461e1e5808d7a0f2da6c62b9549e86ded127` |
| `screenshots/1.5.0/revizyon-11/en/ipad-13/05-first-step.png` | 2064 × 2752 | 5874758 | `677b863f72bba92ef5bbbdb61101a87cdc8d8f8dc4259b18af4194891aed6b73` |
| `screenshots/1.5.0/revizyon-11/en/ipad-13/06-monthly-mountains.png` | 2064 × 2752 | 6872062 | `0908af5ee6f0ffaa23b883e4e4290eccdc2ccd96c298250f96c5f5a6396c9ff5` |
| `screenshots/1.5.0/revizyon-11/tr/iphone-6.9/01-geri-bildirim.png` | 1320 × 2868 | 3082589 | `2cc1659fd7aba139f9874925d09a64ee53194bc41c1171c69af0e6ec6f598306` |
| `screenshots/1.5.0/revizyon-11/tr/iphone-6.9/02-tekrar-ve-bilet.png` | 1320 × 2868 | 2938184 | `aa92d88475f701981cf0c23a2121ab922d3b2c4f26e5944fd59d38bed0737058` |
| `screenshots/1.5.0/revizyon-11/tr/iphone-6.9/03-ipucu.png` | 1320 × 2868 | 3843259 | `913a8827a9cbaa69348b3dd0526e5d1491250bfbc06317fed4f6994c32ed334b` |
| `screenshots/1.5.0/revizyon-11/tr/iphone-6.9/04-zamani-kullan.png` | 1320 × 2868 | 2787008 | `65abc61931018c0c22a7d93bd6d264f9562f0c74b24b747a80727438e530a3e7` |
| `screenshots/1.5.0/revizyon-11/tr/iphone-6.9/05-ilk-adim.png` | 1320 × 2868 | 3320517 | `98dc43730019aae1cab2ce273e3f3bcb2c1bedaad730604fd4c9943e4f681b15` |
| `screenshots/1.5.0/revizyon-11/tr/iphone-6.9/06-aylik-daglar.png` | 1320 × 2868 | 4703705 | `c938c955a1d5474284a742f290ebe1efcb294cf27613fbfef83559ad9bc4467c` |
| `screenshots/1.5.0/revizyon-11/tr/ipad-13/01-geri-bildirim.png` | 2064 × 2752 | 3416039 | `df002fe0ff0d14d93af07b8dedad39d5d02bc741a24a96a9e1e3a92b2dc1b0ec` |
| `screenshots/1.5.0/revizyon-11/tr/ipad-13/02-tekrar-ve-bilet.png` | 2064 × 2752 | 3149512 | `4c6f74534d7c376f61fb9e304bf35e009c40ecab4edb8dc0e1f6e83eb8e4903a` |
| `screenshots/1.5.0/revizyon-11/tr/ipad-13/03-ipucu.png` | 2064 × 2752 | 4068256 | `cab4eda8f5d22f8618f356efe647b221cd00ddc4895335c723c1cf34a2bf3b83` |
| `screenshots/1.5.0/revizyon-11/tr/ipad-13/04-zamani-kullan.png` | 2064 × 2752 | 2806623 | `4881ea40da68b49d32c5b9983f46f7ed2eb7e4cf2f0fc0530a55ae7339f4061e` |
| `screenshots/1.5.0/revizyon-11/tr/ipad-13/05-ilk-adim.png` | 2064 × 2752 | 5855249 | `c9aaa1a8ba9fcea65e26f9c56680fe30e141e96fff1078968e6bec6020792de4` |
| `screenshots/1.5.0/revizyon-11/tr/ipad-13/06-aylik-daglar.png` | 2064 × 2752 | 6899379 | `94ca53696e95168a0c02ef3175934a6ca9d73df68158cfaf8f557a5c5974b57c` |
| `screenshots/1.5.0/revizyon-11/de/iphone-6.9/01-feedback.png` | 1320 × 2868 | 3128267 | `c3c7719426f9c60ec6a066ab394cf335e8cb734ee9a1bf9c90389a3a314e8d75` |
| `screenshots/1.5.0/revizyon-11/de/iphone-6.9/02-review-ticket.png` | 1320 × 2868 | 2974878 | `5344e2f22d0d8f66f6637f660868bf74df04d475c6de3b4abecd2b9edb41dbf4` |
| `screenshots/1.5.0/revizyon-11/de/iphone-6.9/03-hint.png` | 1320 × 2868 | 3880959 | `c5f3824cf8ccf24299b597697814b880fdacb2777f74984159f245436ad2de09` |
| `screenshots/1.5.0/revizyon-11/de/iphone-6.9/04-film.png` | 1320 × 2868 | 2855369 | `e292154d8e3aa8ede9cdeb105c707b85ed2cfe45255d47a30acd2c1ec1545fe5` |
| `screenshots/1.5.0/revizyon-11/de/iphone-6.9/05-first-step.png` | 1320 × 2868 | 3360695 | `a87ee7f3d498effc284c43080d815b581ba95cdf205bf8524603e41a8f6ef86f` |
| `screenshots/1.5.0/revizyon-11/de/iphone-6.9/06-monthly-mountains.png` | 1320 × 2868 | 4732284 | `f45f26ce8e862e6c8ce7e6b28b53336e561aba981a51a8d98e756e41e8d14ab3` |
| `screenshots/1.5.0/revizyon-11/de/ipad-13/01-feedback.png` | 2064 × 2752 | 3423181 | `eae6bb3e2b190ac2f9c204b236f0ba23f7324895d1d486357c30fcf5f0a1c9aa` |
| `screenshots/1.5.0/revizyon-11/de/ipad-13/02-review-ticket.png` | 2064 × 2752 | 3149632 | `b9eba569a7c2e767a07793c34eff92b575be196ce052b16042f77e5291e92d94` |
| `screenshots/1.5.0/revizyon-11/de/ipad-13/03-hint.png` | 2064 × 2752 | 4066443 | `ad8fb988700fd87caf9eb961de87fc29ad495c4aa6689b99a2b8bbd4bc616dd1` |
| `screenshots/1.5.0/revizyon-11/de/ipad-13/04-film.png` | 2064 × 2752 | 2833584 | `ab0750a182bce00d42ca1b12a3f37c2c65aa6cbda60bddf004e060b38021c6a8` |
| `screenshots/1.5.0/revizyon-11/de/ipad-13/05-first-step.png` | 2064 × 2752 | 5839016 | `d8a291439c2ad4ffb1e54e24dec4f30906abd970e2792c0ccc03bd6b3a72f13b` |
| `screenshots/1.5.0/revizyon-11/de/ipad-13/06-monthly-mountains.png` | 2064 × 2752 | 6867198 | `0845e2e58687d8790466e658a80d898ed3ef656b81a8b4e25ebee965db8b7976` |
| `screenshots/1.5.0/revizyon-11/es/iphone-6.9/01-feedback.png` | 1320 × 2868 | 3130048 | `50c72735921b8cc179accf8728ee4d7a0b7882c1dd213051997455b53468e021` |
| `screenshots/1.5.0/revizyon-11/es/iphone-6.9/02-review-ticket.png` | 1320 × 2868 | 2975473 | `b0605ec3df1d403d724b350b45dc4fad23a735ee754472cf0f6db8631b9de68f` |
| `screenshots/1.5.0/revizyon-11/es/iphone-6.9/03-hint.png` | 1320 × 2868 | 3914230 | `574c3703179f93cd4c4336857b71f41c32f7e0cc01a8b7a4c11cf9fe6c5b614e` |
| `screenshots/1.5.0/revizyon-11/es/iphone-6.9/04-film.png` | 1320 × 2868 | 2860892 | `8db2effc051383561d0b71aad9bcfa1fd3d12d0337fa207fa8b4658517367381` |
| `screenshots/1.5.0/revizyon-11/es/iphone-6.9/05-first-step.png` | 1320 × 2868 | 3370211 | `4dd4706ba65ba789b742aa360fcc0967984758ba4f2996ea6910a5df40b20c4e` |
| `screenshots/1.5.0/revizyon-11/es/iphone-6.9/06-monthly-mountains.png` | 1320 × 2868 | 4754358 | `5eb73771117b7f6611405d93d20d91de04e3752f3ace657a8c16c03cf1a350d2` |
| `screenshots/1.5.0/revizyon-11/es/ipad-13/01-feedback.png` | 2064 × 2752 | 3422424 | `708ad53d831d8edea2c1acf155911508bf4802780816a30e231a5581cea2b7b6` |
| `screenshots/1.5.0/revizyon-11/es/ipad-13/02-review-ticket.png` | 2064 × 2752 | 3222145 | `485d744a3ff64ce831c1ab826f2c43b0ca88a340e3b4160494d554d00d7719ff` |
| `screenshots/1.5.0/revizyon-11/es/ipad-13/03-hint.png` | 2064 × 2752 | 4072425 | `00ac0467dcab4efde82db48e9a6fe0f3313f93c0bc02afa4bce3c3e075afb113` |
| `screenshots/1.5.0/revizyon-11/es/ipad-13/04-film.png` | 2064 × 2752 | 2845094 | `e341c6e31a5e56ba722e016c4d5a2b92266060405fced78ed45410a06d65ca05` |
| `screenshots/1.5.0/revizyon-11/es/ipad-13/05-first-step.png` | 2064 × 2752 | 5917590 | `40c797eb8a4d262cf377ffe2466c488ffe0bc2d4bcc217429a4a2627f318ccfc` |
| `screenshots/1.5.0/revizyon-11/es/ipad-13/06-monthly-mountains.png` | 2064 × 2752 | 6874442 | `bc2e239823670969ae0b7ed2d9ad08efeb2d5c2d0e226b75513b85b4245914a2` |
| `screenshots/1.5.0/revizyon-11/pt-BR/iphone-6.9/01-feedback.png` | 1320 × 2868 | 3135193 | `504afbc282c6d0466f3cd5eac265987fa74ddb45026bc821fd1748d44f31d582` |
| `screenshots/1.5.0/revizyon-11/pt-BR/iphone-6.9/02-review-ticket.png` | 1320 × 2868 | 2981621 | `2e87dbd87765b60d2985183381709c1c8721c44f19127fbec2932a385dc03aef` |
| `screenshots/1.5.0/revizyon-11/pt-BR/iphone-6.9/03-hint.png` | 1320 × 2868 | 3924497 | `1639125d0276a3c0c94953b6b6aba431a26bbc0217747c829d1887812314f9b3` |
| `screenshots/1.5.0/revizyon-11/pt-BR/iphone-6.9/04-film.png` | 1320 × 2868 | 2844772 | `137940482f009825e46325c00017f5a10edba1c570425850ab39037cf0bdc82e` |
| `screenshots/1.5.0/revizyon-11/pt-BR/iphone-6.9/05-first-step.png` | 1320 × 2868 | 3368633 | `c3f6b1cd3d3d7d16f1518c5f960e61f9b8653e7d588d1ebd7c5c1ed615cda386` |
| `screenshots/1.5.0/revizyon-11/pt-BR/iphone-6.9/06-monthly-mountains.png` | 1320 × 2868 | 4752408 | `df2fb92c9e570c35253ae018546ba37d692f4fd548510db0bb3ed3a8912f784e` |
| `screenshots/1.5.0/revizyon-11/pt-BR/ipad-13/01-feedback.png` | 2064 × 2752 | 3427886 | `99b3693befcc1ac0beb71f1c6351c10112d005410c14ba52217cf2f8f9cd1c47` |
| `screenshots/1.5.0/revizyon-11/pt-BR/ipad-13/02-review-ticket.png` | 2064 × 2752 | 3230651 | `488432d68b8e5a0f44face186834ea314ae4a1e7f10d30c67f9754d4394f2e9b` |
| `screenshots/1.5.0/revizyon-11/pt-BR/ipad-13/03-hint.png` | 2064 × 2752 | 4077731 | `172727dde5dc3354912783c2704990cd2b8396c72cf3650ed238cdb0ee4de6aa` |
| `screenshots/1.5.0/revizyon-11/pt-BR/ipad-13/04-film.png` | 2064 × 2752 | 2833113 | `3bc575c7c163cd4015fef75dce74100f5e504b01e18ea6b2f88c36920b598c6e` |
| `screenshots/1.5.0/revizyon-11/pt-BR/ipad-13/05-first-step.png` | 2064 × 2752 | 5897258 | `85f7c5c762a27e5a86dd96ad53fbf2e319445daf4ec4cba9813c86b7292551fa` |
| `screenshots/1.5.0/revizyon-11/pt-BR/ipad-13/06-monthly-mountains.png` | 2064 × 2752 | 6862558 | `44e5ad61aaf7b5420381de944eeea00cc26ac847ff031d9cdd80c53b5ef8e50a` |
| `screenshots/1.5.0/revizyon-11/ja/iphone-6.9/01-feedback.png` | 1320 × 2868 | 3138787 | `cb5de7534c932b8058b09b0e35a9e9487a0bec4b537ddf8376f78b1005b8b2d1` |
| `screenshots/1.5.0/revizyon-11/ja/iphone-6.9/02-review-ticket.png` | 1320 × 2868 | 2946029 | `0fca2d5791fd657c729cdaa5e236268edfd55ade2a120373549a200aa2253a93` |
| `screenshots/1.5.0/revizyon-11/ja/iphone-6.9/03-hint.png` | 1320 × 2868 | 3934945 | `632b83823d689702353c26e6bb0776e5ae117f8a1323b81b49fb8be0e1a4fa9f` |
| `screenshots/1.5.0/revizyon-11/ja/iphone-6.9/04-film.png` | 1320 × 2868 | 2836052 | `732edf3597b001dd72ec2a1866bf5179aba8713e139dc5f4f5c732f79a907a0c` |
| `screenshots/1.5.0/revizyon-11/ja/iphone-6.9/05-first-step.png` | 1320 × 2868 | 3405519 | `3b95bb895d5b36c80707980b1c39a822f75440712afbc389c6c98f29a6c31a7a` |
| `screenshots/1.5.0/revizyon-11/ja/iphone-6.9/06-monthly-mountains.png` | 1320 × 2868 | 4776259 | `8617365a05f70279435a6d87001941da4e188a8f91513e7f3e9b43ca530852b4` |
| `screenshots/1.5.0/revizyon-11/ja/ipad-13/01-feedback.png` | 2064 × 2752 | 3441703 | `5ea318d1718076f6e5cc3e323098117f3fd0f81ba1d2f8a1b2097e328b7e5e91` |
| `screenshots/1.5.0/revizyon-11/ja/ipad-13/02-review-ticket.png` | 2064 × 2752 | 3212437 | `29f04bc4ccac68540a09d6ede0f3ee7b22463283c6b267ee9e2661f91ea1b01e` |
| `screenshots/1.5.0/revizyon-11/ja/ipad-13/03-hint.png` | 2064 × 2752 | 4112420 | `d55f5f232577bc416bde5640f94b7c27b380e71becdcb069a8cb23ea4bbc3948` |
| `screenshots/1.5.0/revizyon-11/ja/ipad-13/04-film.png` | 2064 × 2752 | 2819698 | `a4d9c01762684f2104b0579a9e9cbe01851d0fe5c34ab31a5729ec792e7eda54` |
| `screenshots/1.5.0/revizyon-11/ja/ipad-13/05-first-step.png` | 2064 × 2752 | 5895719 | `e62c966cca10e94e46c6a31bcde0c12231f00177e105fb5e66da43442a77b4d0` |
| `screenshots/1.5.0/revizyon-11/ja/ipad-13/06-monthly-mountains.png` | 2064 × 2752 | 6910508 | `4f86056a93d153654d5e818164d8179b4e8b81a7292935b1dd151ed4cf9b9ac6` |
| `screenshots/1.5.0/revizyon-11/ko/iphone-6.9/01-feedback.png` | 1320 × 2868 | 3071260 | `c878022ea8fa73d23674028ee344f7cfcdad438d97f9033b3c7a5f08aa1ceeb8` |
| `screenshots/1.5.0/revizyon-11/ko/iphone-6.9/02-review-ticket.png` | 1320 × 2868 | 2897250 | `e1749bc7dd29fb7c0dbba624348f4cf5c2267e0effd89439f5dec81a7bf6663f` |
| `screenshots/1.5.0/revizyon-11/ko/iphone-6.9/03-hint.png` | 1320 × 2868 | 3875712 | `f1682995f749b9e3950721fd95b15d6715e8b18ab4c454ba92556f9ea622c3e6` |
| `screenshots/1.5.0/revizyon-11/ko/iphone-6.9/04-film.png` | 1320 × 2868 | 2836943 | `21a577b3ed90768afc2d22b8e0d7ff42963f4c93d4a8c31707b274ab868bdab2` |
| `screenshots/1.5.0/revizyon-11/ko/iphone-6.9/05-first-step.png` | 1320 × 2868 | 3348527 | `d47d6f10f5ba91815a235ae91427638d772179479e908051091b8d61179b3b50` |
| `screenshots/1.5.0/revizyon-11/ko/iphone-6.9/06-monthly-mountains.png` | 1320 × 2868 | 4715403 | `3a85bc920792f7e56341757a0da205f17f22cd399df27e43d370f4e47a4d33a4` |
| `screenshots/1.5.0/revizyon-11/ko/ipad-13/01-feedback.png` | 2064 × 2752 | 3386910 | `afd8854ad83f8acf3a76b579e3abf1f8df7a8cfb0aeca1210f03a902e01078e9` |
| `screenshots/1.5.0/revizyon-11/ko/ipad-13/02-review-ticket.png` | 2064 × 2752 | 3165545 | `434f9c523a8bfdbce33f5a62757c734c21d39514e2231b16a794affacd337301` |
| `screenshots/1.5.0/revizyon-11/ko/ipad-13/03-hint.png` | 2064 × 2752 | 4062263 | `ea1f07af2584f51a828105010121a1110cddadea1b927e62df2e4a654cef869e` |
| `screenshots/1.5.0/revizyon-11/ko/ipad-13/04-film.png` | 2064 × 2752 | 2822901 | `bcf2b9eedeef33304f9f3c7a06c7dee8e7ab4d16017ffdfa3572752e196fb484` |
| `screenshots/1.5.0/revizyon-11/ko/ipad-13/05-first-step.png` | 2064 × 2752 | 5880424 | `f56002c5a6c94905184e7b3d4d3086814f2e28419ba253bc65824ee532dd1a49` |
| `screenshots/1.5.0/revizyon-11/ko/ipad-13/06-monthly-mountains.png` | 2064 × 2752 | 6854328 | `1f47f36afb47457b1fbed1a59d2b034b01a704235df77afd33ffd8e2ab06cdba` |
| `screenshots/1.5.0/revizyon-11/ar/iphone-6.9/01-feedback.png` | 1320 × 2868 | 3162334 | `681b97b23fa7571482d47a716f8c616b4ca8a66f5b2dc468fa04ea29e9827914` |
| `screenshots/1.5.0/revizyon-11/ar/iphone-6.9/02-review-ticket.png` | 1320 × 2868 | 3007038 | `4fadae885f344f8caa78cce7a6aaa2b397249f0888ac24971ab96e38ef798639` |
| `screenshots/1.5.0/revizyon-11/ar/iphone-6.9/03-hint.png` | 1320 × 2868 | 3939125 | `cf596f2dcf00dd5932126482d94c43886ee31f8f8af43f7049f61278835e3bb2` |
| `screenshots/1.5.0/revizyon-11/ar/iphone-6.9/04-film.png` | 1320 × 2868 | 2881261 | `8cade4ff6f49eba429b22bc43e0cc220edda41622c07b890040c5f81adc99a3d` |
| `screenshots/1.5.0/revizyon-11/ar/iphone-6.9/05-first-step.png` | 1320 × 2868 | 3423714 | `01492a96acc557509b5cfb18d1015776260ff25c402b55a200273ed2e46918e3` |
| `screenshots/1.5.0/revizyon-11/ar/iphone-6.9/06-monthly-mountains.png` | 1320 × 2868 | 4792549 | `64992b244824c20895ed74cb879e928737272b529af8e33cf6660d35c1758120` |
| `screenshots/1.5.0/revizyon-11/ar/ipad-13/01-feedback.png` | 2064 × 2752 | 3460276 | `43c54a408231efce805a47d7ccc72c7f0a2e7915369ffc93484d4418c4928b5c` |
| `screenshots/1.5.0/revizyon-11/ar/ipad-13/02-review-ticket.png` | 2064 × 2752 | 3235239 | `82de2c81db87234376f3323ce335d55180db83133f24adfca59317c66de36d30` |
| `screenshots/1.5.0/revizyon-11/ar/ipad-13/03-hint.png` | 2064 × 2752 | 4105678 | `2b583ee045a935f34f5c1d02e3b7ca52070d0f19ac9c580a158161b29bbb34e1` |
| `screenshots/1.5.0/revizyon-11/ar/ipad-13/04-film.png` | 2064 × 2752 | 2889452 | `425045990b0c07ecf2cc0fdc4d966508e6f0461c50926bf3feb7aa0d30be04bd` |
| `screenshots/1.5.0/revizyon-11/ar/ipad-13/05-first-step.png` | 2064 × 2752 | 5937638 | `0075080abe624b1f2ba728447c7648062a54af87a2db2fbae9b2a7dffe47e638` |
| `screenshots/1.5.0/revizyon-11/ar/ipad-13/06-monthly-mountains.png` | 2064 × 2752 | 6958400 | `cee2d3426fa11a4cb795f2a107b2579d96741f79130af4409826692f7b363446` |
| `screenshots/1.5.0/revizyon-11/product-page/header.png` | 3840 × 1646 | 6433498 | `1a4001f9c0058738590561775cb82ce4db8f813826357dbb8c926020278e2331` |

## Read-only requests performed

| Order | Request | HTTP status |
| ---: | --- | ---: |
| 1 | `GET /v1/apps?filter%5BbundleId%5D=com.ahmettayfur.grammarlens&fields%5Bapps%5D=name%2CbundleId%2CprimaryLocale` | 200 |
| 2 | `GET /v1/apps/6811477346/appStoreVersions?filter%5Bplatform%5D=IOS&include=build&limit=200` | 200 |
| 3 | `GET /v1/builds?filter%5Bapp%5D=6811477346&filter%5Bversion%5D=8&include=preReleaseVersion&limit=200` | 200 |
| 4 | `GET /v1/apps/6811477346/appInfos?limit=200` | 200 |
| 5 | `GET /v1/appInfos/2222205e-4dc4-4a9e-8da1-dabb39f0ef9b/appInfoLocalizations?limit=200` | 200 |
| 6 | `GET /v1/appStoreVersions/23d20cb5-2df3-49c4-b3c6-841cd080a576/appStoreVersionLocalizations?limit=200` | 200 |
| 7 | `GET /v1/appStoreVersionLocalizations/a741abc3-8025-45b2-9c7e-8362156d87d4/appScreenshotSets?limit=200` | 200 |
| 8 | `GET /v1/appScreenshotSets/1970c4cc-5f5d-413c-818d-f84465d05f2c/appScreenshots?limit=200` | 200 |
| 9 | `GET /v1/appScreenshotSets/b9def353-5192-4da0-8484-f9166a02fee5/appScreenshots?limit=200` | 200 |
| 10 | `GET /v1/appStoreVersionLocalizations/a741abc3-8025-45b2-9c7e-8362156d87d4/placements?limit=200` | 200 |
| 11 | `GET /v1/appAssetLibraryPlacements/9a400019-5fee-8562-8f3e-6db1b016e321?include=image` | 200 |
| 12 | `GET /v1/appStoreVersionLocalizations/9c4a2cfe-bd96-4ee7-b37f-d9e778d16fa2/appScreenshotSets?limit=200` | 200 |
| 13 | `GET /v1/appScreenshotSets/c08e3bb5-28e9-4745-8d0d-a1bb32f72e21/appScreenshots?limit=200` | 200 |
| 14 | `GET /v1/appScreenshotSets/1b99cee2-faf0-470c-b1ff-e99b018fdcc8/appScreenshots?limit=200` | 200 |
| 15 | `GET /v1/appStoreVersionLocalizations/9c4a2cfe-bd96-4ee7-b37f-d9e778d16fa2/placements?limit=200` | 200 |
| 16 | `GET /v1/appAssetLibraryPlacements/6c800019-5fee-8562-8f1d-228139bbc739?include=image` | 200 |
| 17 | `GET /v1/appStoreVersionLocalizations/6d01380e-710f-48c4-80c3-1079cc96e9c0/appScreenshotSets?limit=200` | 200 |
| 18 | `GET /v1/appScreenshotSets/fc70e24c-5368-412c-b137-858cd0ea1b22/appScreenshots?limit=200` | 200 |
| 19 | `GET /v1/appScreenshotSets/9c8fae03-4f5d-4935-b8d5-4892d8f8142a/appScreenshots?limit=200` | 200 |
| 20 | `GET /v1/appStoreVersionLocalizations/6d01380e-710f-48c4-80c3-1079cc96e9c0/placements?limit=200` | 200 |
| 21 | `GET /v1/appAssetLibraryPlacements/6e400019-5fee-8562-8f26-831f8be07380?include=image` | 200 |
| 22 | `GET /v1/appStoreVersionLocalizations/39426655-dc45-44a6-9cdb-c583ecdda1e7/appScreenshotSets?limit=200` | 200 |
| 23 | `GET /v1/appScreenshotSets/2074c8b6-185d-4e7b-8230-e7ff665bad9e/appScreenshots?limit=200` | 200 |
| 24 | `GET /v1/appScreenshotSets/3d717489-d61c-41f4-8b00-359b2abc00f0/appScreenshots?limit=200` | 200 |
| 25 | `GET /v1/appStoreVersionLocalizations/39426655-dc45-44a6-9cdb-c583ecdda1e7/placements?limit=200` | 200 |
| 26 | `GET /v1/appAssetLibraryPlacements/f9000019-5fee-8562-8f16-aacea9002d5d?include=image` | 200 |
| 27 | `GET /v1/appStoreVersionLocalizations/207797dd-54bd-480e-be43-41ef1c6bac66/appScreenshotSets?limit=200` | 200 |
| 28 | `GET /v1/appScreenshotSets/b0718bd9-af23-4d9c-afa4-a99e123042c5/appScreenshots?limit=200` | 200 |
| 29 | `GET /v1/appScreenshotSets/33233b78-2a58-407c-9ff7-6bd2a5d3aa1f/appScreenshots?limit=200` | 200 |
| 30 | `GET /v1/appStoreVersionLocalizations/207797dd-54bd-480e-be43-41ef1c6bac66/placements?limit=200` | 200 |
| 31 | `GET /v1/appAssetLibraryPlacements/9a000019-5fee-8562-8f04-8b6622bafce9?include=image` | 200 |
| 32 | `GET /v1/appStoreVersionLocalizations/b704a413-2638-4cdf-a8a6-7e4524012aef/appScreenshotSets?limit=200` | 200 |
| 33 | `GET /v1/appScreenshotSets/51433d31-5093-4c11-9327-fa61a0521027/appScreenshots?limit=200` | 200 |
| 34 | `GET /v1/appScreenshotSets/1cc8dba1-c41f-4fda-9f31-aeb50f7e62e4/appScreenshots?limit=200` | 200 |
| 35 | `GET /v1/appStoreVersionLocalizations/b704a413-2638-4cdf-a8a6-7e4524012aef/placements?limit=200` | 200 |
| 36 | `GET /v1/appAssetLibraryPlacements/ffc00019-5fee-8562-8f3d-53797c8c0dd8?include=image` | 200 |
| 37 | `GET /v1/appStoreVersionLocalizations/f2380dc1-9551-4863-afb3-c6dd6496e0f3/appScreenshotSets?limit=200` | 200 |
| 38 | `GET /v1/appScreenshotSets/319baee9-6fd6-4e80-812c-097142bf5fcb/appScreenshots?limit=200` | 200 |
| 39 | `GET /v1/appScreenshotSets/eba258fc-84be-4cd5-8338-51f6a4532c64/appScreenshots?limit=200` | 200 |
| 40 | `GET /v1/appStoreVersionLocalizations/f2380dc1-9551-4863-afb3-c6dd6496e0f3/placements?limit=200` | 200 |
| 41 | `GET /v1/appAssetLibraryPlacements/ebc00019-5fee-8562-8f3b-aa63f2ea6017?include=image` | 200 |
| 42 | `GET /v1/appStoreVersionLocalizations/59562966-9555-4e74-a371-1f7f6c171cf7/appScreenshotSets?limit=200` | 200 |
| 43 | `GET /v1/appScreenshotSets/44c56bc0-bf45-481e-bc48-de6089fb7862/appScreenshots?limit=200` | 200 |
| 44 | `GET /v1/appScreenshotSets/4df75bbc-74dd-4fd1-8dc5-4b77bb80d52c/appScreenshots?limit=200` | 200 |
| 45 | `GET /v1/appStoreVersionLocalizations/59562966-9555-4e74-a371-1f7f6c171cf7/placements?limit=200` | 200 |
| 46 | `GET /v1/appAssetLibraryPlacements/c3000019-5fee-8562-8f2f-0c3e756271d4?include=image` | 200 |
| 47 | `GET /v1/appStoreVersions/23d20cb5-2df3-49c4-b3c6-841cd080a576/appStoreReviewDetail` | 200 |
| 48 | `GET /v1/appStoreReviewDetails/ef0585d5-222c-49e5-83c1-831966de5a5d/appStoreReviewAttachments?limit=200` | 200 |

## Requests after the owner’s OK

This ordered JSON lists each planned request and its body. Brace placeholders are resolved from prior responses. They never resolve to records from 1.4.0 for writes. If creation does not inherit an expected placement, its guarded DELETE is skipped. An unrecognized placement or set is never deleted. A repeated upload is one request per returned byte range; pre-signed URLs are used at runtime only. Poll counts and other conditional requests depend on the API. Authentication is omitted.

The planned legacy named display types were explicitly observed in the live API responses. The size and MD5 for each new screenshot are included in its reservation and commit requests. Full response text for unchanged metadata, review contacts and tokens is omitted here.

```json
[
  {
    "method": "POST",
    "path": "/v1/appStoreVersions",
    "purpose": "Create the manual-release iOS 1.5.0 draft",
    "body": {
      "data": {
        "type": "appStoreVersions",
        "attributes": {
          "platform": "IOS",
          "versionString": "1.5.0",
          "releaseType": "MANUAL"
        },
        "relationships": {
          "app": {
            "data": {
              "type": "apps",
              "id": "6811477346"
            }
          }
        }
      }
    },
    "saveIdAs": "{version_1.5.0}"
  },
  {
    "method": "GET",
    "path": "/v1/appStoreVersions/{version_1.5.0}",
    "purpose": "Verify the new record belongs to GrammarLens, is iOS 1.5.0, is PREPARE_FOR_SUBMISSION and uses MANUAL release."
  },
  {
    "method": "PATCH",
    "path": "/v1/appStoreVersions/{version_1.5.0}/relationships/build",
    "purpose": "Attach the validated iOS 1.5.0 build 8",
    "body": {
      "data": {
        "type": "builds",
        "id": "66d41ad9-faa7-4255-8604-ddcdd33b5b48"
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appStoreVersions/{version_1.5.0}/appStoreVersionLocalizations?limit=200",
    "purpose": "Read copied draft localizations and bind each draft locale ID. Reject all live IDs."
  },
  {
    "method": "PATCH",
    "path": "/v1/appStoreVersionLocalizations/{localization_en-US}",
    "purpose": "en-US update exactly the two approved text fields",
    "body": {
      "data": {
        "type": "appStoreVersionLocalizations",
        "id": "{localization_en-US}",
        "attributes": {
          "description": "GrammarLens turns your English mistakes into practice.\n\nEvery day you get a short grammar test. When you finish, you don't just see a score — you see why each answer was right or wrong, written in plain language.\n\nIN YOUR LANGUAGE\nThe app's menus and buttons are available in English, Japanese, Korean, Spanish, Portuguese (Brazil), Turkish, Arabic and German. The questions and the feedback stay in English, so you practice the language you are learning.\n\nWHAT YOU GET\n\nDaily Test\nA fresh set of questions every day. Fill in the blanks, correct the errors, and get an explanation for every answer.\n\nReal explanations, not just checkmarks\nInstead of \"wrong\", you get the reasoning: which rule applies, why your answer doesn't fit, and what to remember next time. The words that changed between your answer and the correction are highlighted.\n\nTopic hints\nStuck on a question? Slide to see the grammar pattern for its topic — a reminder of the rule, never the answer.\n\nYour weak spots, tracked\nThe app remembers which grammar points you keep missing and collects them in Review, so you always know what to work on.\n\nTopic Practice\nChoose from ten topics — Articles, Tense Selection, Modal Verbs, Modal Past Forms, Gerund vs. Infinitive, Conditionals, Passive Voice, Prepositions, Relative Clauses, and Comparatives & Superlatives — with sessions of 3, 5 or 10 questions.\n\nMountain of Learning\nEvery Daily Test takes your character one step up this month's mountain. Earn medals for the month and build a habit that sticks.\n\nHome Screen widgets\n\"Climb\" shows today's Daily Test and your step on this month's mountain. \"Tip\" brings a daily grammar tip from your own weak spots. Widgets show only what the app has saved on your device.\n\nDaily reminders\nOne reminder a day at most, at the time you choose. Turn it on or off in Profile → Notifications.\n\nNine study buddies\nPick the character that climbs with you.\n\nFREE AND PREMIUM\nFree includes one Daily Test and one practice session every day.\nPremium unlocks Topic Practice across all ten topics and more practice sessions each day.\nPremium is available as a monthly or annual subscription. Both include a free trial for new subscribers. Prices are shown in the app before you subscribe.\n\nPRIVACY\nThere is no account and no sign-up. Your name, your progress and your practice history stay on your device. The app sends anonymous usage data, never your name.\nTo give you feedback, the answers you type are sent to our AI provider, Anthropic. The app asks your permission before this happens for the first time, and you can withdraw it at any time from the Data screen.\n\nTerms of Use (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/\nPrivacy Policy: https://ahmettayfur.com/products/grammarlens/privacy/\nTerms of Service: https://ahmettayfur.com/products/grammarlens/terms/",
          "whatsNew": "A fresh look, widgets and five new topics.\n• A new design: every screen has been redrawn, and your study buddy reacts as you answer.\n• Home Screen widgets: \"Climb\" shows today's Daily Test and your step on this month's mountain; \"Tip\" brings a daily grammar tip from your own weak spots.\n• Daily reminders: at most one a day, at the time you choose. Change it in Profile → Notifications.\n• Topic Practice now has ten topics: Conditionals, Passive Voice, Prepositions, Relative Clauses and Comparatives & Superlatives join the original five.\n• When the day's practice is done, your buddy rests at camp until tomorrow.\n• Profile shows how close you are to this month's next medal."
        }
      }
    },
    "condition": "Draft locale exists."
  },
  {
    "method": "POST",
    "path": "/v1/appStoreVersionLocalizations",
    "purpose": "en-US create a missing localization",
    "body": {
      "data": {
        "type": "appStoreVersionLocalizations",
        "attributes": {
          "locale": "en-US",
          "description": "GrammarLens turns your English mistakes into practice.\n\nEvery day you get a short grammar test. When you finish, you don't just see a score — you see why each answer was right or wrong, written in plain language.\n\nIN YOUR LANGUAGE\nThe app's menus and buttons are available in English, Japanese, Korean, Spanish, Portuguese (Brazil), Turkish, Arabic and German. The questions and the feedback stay in English, so you practice the language you are learning.\n\nWHAT YOU GET\n\nDaily Test\nA fresh set of questions every day. Fill in the blanks, correct the errors, and get an explanation for every answer.\n\nReal explanations, not just checkmarks\nInstead of \"wrong\", you get the reasoning: which rule applies, why your answer doesn't fit, and what to remember next time. The words that changed between your answer and the correction are highlighted.\n\nTopic hints\nStuck on a question? Slide to see the grammar pattern for its topic — a reminder of the rule, never the answer.\n\nYour weak spots, tracked\nThe app remembers which grammar points you keep missing and collects them in Review, so you always know what to work on.\n\nTopic Practice\nChoose from ten topics — Articles, Tense Selection, Modal Verbs, Modal Past Forms, Gerund vs. Infinitive, Conditionals, Passive Voice, Prepositions, Relative Clauses, and Comparatives & Superlatives — with sessions of 3, 5 or 10 questions.\n\nMountain of Learning\nEvery Daily Test takes your character one step up this month's mountain. Earn medals for the month and build a habit that sticks.\n\nHome Screen widgets\n\"Climb\" shows today's Daily Test and your step on this month's mountain. \"Tip\" brings a daily grammar tip from your own weak spots. Widgets show only what the app has saved on your device.\n\nDaily reminders\nOne reminder a day at most, at the time you choose. Turn it on or off in Profile → Notifications.\n\nNine study buddies\nPick the character that climbs with you.\n\nFREE AND PREMIUM\nFree includes one Daily Test and one practice session every day.\nPremium unlocks Topic Practice across all ten topics and more practice sessions each day.\nPremium is available as a monthly or annual subscription. Both include a free trial for new subscribers. Prices are shown in the app before you subscribe.\n\nPRIVACY\nThere is no account and no sign-up. Your name, your progress and your practice history stay on your device. The app sends anonymous usage data, never your name.\nTo give you feedback, the answers you type are sent to our AI provider, Anthropic. The app asks your permission before this happens for the first time, and you can withdraw it at any time from the Data screen.\n\nTerms of Use (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/\nPrivacy Policy: https://ahmettayfur.com/products/grammarlens/privacy/\nTerms of Service: https://ahmettayfur.com/products/grammarlens/terms/",
          "keywords": "grammar,quiz,ESL,learn,tenses,articles,verbs,modal,gerund,exam,daily,practice,mistakes,writing",
          "whatsNew": "A fresh look, widgets and five new topics.\n• A new design: every screen has been redrawn, and your study buddy reacts as you answer.\n• Home Screen widgets: \"Climb\" shows today's Daily Test and your step on this month's mountain; \"Tip\" brings a daily grammar tip from your own weak spots.\n• Daily reminders: at most one a day, at the time you choose. Change it in Profile → Notifications.\n• Topic Practice now has ten topics: Conditionals, Passive Voice, Prepositions, Relative Clauses and Comparatives & Superlatives join the original five.\n• When the day's practice is done, your buddy rests at camp until tomorrow.\n• Profile shows how close you are to this month's next medal.",
          "promotionalText": "",
          "supportUrl": "https://ahmettayfur.com/products/grammarlens/support/"
        },
        "relationships": {
          "appStoreVersion": {
            "data": {
              "type": "appStoreVersions",
              "id": "{version_1.5.0}"
            }
          }
        }
      }
    },
    "condition": "Draft locale is missing.",
    "saveIdAs": "{localization_en-US}"
  },
  {
    "method": "GET",
    "path": "/v1/appStoreVersions/{version_1.5.0}/appStoreVersionLocalizations?filter%5Blocale%5D=en-US&limit=200",
    "purpose": "en-US reconcile an existing localization on a creation conflict",
    "condition": "Only the HTTP 409 existing-localization case explicitly permitted by §3.3."
  },
  {
    "method": "PATCH",
    "path": "/v1/appStoreVersionLocalizations/{localization_en-US}",
    "purpose": "en-US update the two approved fields after the specified conflict reconciliation",
    "body": {
      "data": {
        "type": "appStoreVersionLocalizations",
        "id": "{localization_en-US}",
        "attributes": {
          "description": "GrammarLens turns your English mistakes into practice.\n\nEvery day you get a short grammar test. When you finish, you don't just see a score — you see why each answer was right or wrong, written in plain language.\n\nIN YOUR LANGUAGE\nThe app's menus and buttons are available in English, Japanese, Korean, Spanish, Portuguese (Brazil), Turkish, Arabic and German. The questions and the feedback stay in English, so you practice the language you are learning.\n\nWHAT YOU GET\n\nDaily Test\nA fresh set of questions every day. Fill in the blanks, correct the errors, and get an explanation for every answer.\n\nReal explanations, not just checkmarks\nInstead of \"wrong\", you get the reasoning: which rule applies, why your answer doesn't fit, and what to remember next time. The words that changed between your answer and the correction are highlighted.\n\nTopic hints\nStuck on a question? Slide to see the grammar pattern for its topic — a reminder of the rule, never the answer.\n\nYour weak spots, tracked\nThe app remembers which grammar points you keep missing and collects them in Review, so you always know what to work on.\n\nTopic Practice\nChoose from ten topics — Articles, Tense Selection, Modal Verbs, Modal Past Forms, Gerund vs. Infinitive, Conditionals, Passive Voice, Prepositions, Relative Clauses, and Comparatives & Superlatives — with sessions of 3, 5 or 10 questions.\n\nMountain of Learning\nEvery Daily Test takes your character one step up this month's mountain. Earn medals for the month and build a habit that sticks.\n\nHome Screen widgets\n\"Climb\" shows today's Daily Test and your step on this month's mountain. \"Tip\" brings a daily grammar tip from your own weak spots. Widgets show only what the app has saved on your device.\n\nDaily reminders\nOne reminder a day at most, at the time you choose. Turn it on or off in Profile → Notifications.\n\nNine study buddies\nPick the character that climbs with you.\n\nFREE AND PREMIUM\nFree includes one Daily Test and one practice session every day.\nPremium unlocks Topic Practice across all ten topics and more practice sessions each day.\nPremium is available as a monthly or annual subscription. Both include a free trial for new subscribers. Prices are shown in the app before you subscribe.\n\nPRIVACY\nThere is no account and no sign-up. Your name, your progress and your practice history stay on your device. The app sends anonymous usage data, never your name.\nTo give you feedback, the answers you type are sent to our AI provider, Anthropic. The app asks your permission before this happens for the first time, and you can withdraw it at any time from the Data screen.\n\nTerms of Use (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/\nPrivacy Policy: https://ahmettayfur.com/products/grammarlens/privacy/\nTerms of Service: https://ahmettayfur.com/products/grammarlens/terms/",
          "whatsNew": "A fresh look, widgets and five new topics.\n• A new design: every screen has been redrawn, and your study buddy reacts as you answer.\n• Home Screen widgets: \"Climb\" shows today's Daily Test and your step on this month's mountain; \"Tip\" brings a daily grammar tip from your own weak spots.\n• Daily reminders: at most one a day, at the time you choose. Change it in Profile → Notifications.\n• Topic Practice now has ten topics: Conditionals, Passive Voice, Prepositions, Relative Clauses and Comparatives & Superlatives join the original five.\n• When the day's practice is done, your buddy rests at camp until tomorrow.\n• Profile shows how close you are to this month's next medal."
        }
      }
    },
    "condition": "§3.3 locale conflict reconciled."
  },
  {
    "method": "PATCH",
    "path": "/v1/appStoreVersionLocalizations/{localization_tr}",
    "purpose": "tr update exactly the two approved text fields",
    "body": {
      "data": {
        "type": "appStoreVersionLocalizations",
        "id": "{localization_tr}",
        "attributes": {
          "description": "GrammarLens İngilizce hatalarını pratiğe dönüştürür.\n\nHer gün kısa bir gramer testi çözersin. Bitirdiğinde yalnızca puanını görmezsin: her cevabın neden doğru ya da yanlış olduğunu sade bir dille okursun.\n\nSENİN DİLİNDE\nUygulamanın menüleri ve düğmeleri İngilizce, Japonca, Korece, İspanyolca, Portekizce (Brezilya), Türkçe, Arapça ve Almanca. Sorular ve geri bildirimler İngilizce kalır; böylece öğrendiğin dilde pratik yaparsın.\n\nNELER VAR\n\nGünlük Test\nHer gün yeni bir soru seti. Boşlukları doldur, hataları düzelt ve her cevap için bir açıklama al.\n\nSadece işaret değil, gerçek açıklama\n\"Yanlış\" yerine nedenini görürsün: hangi kural geçerli, cevabın neden uymuyor ve bir dahaki sefere neyi hatırlamalısın. Cevabınla düzeltilmiş hali arasında değişen kelimeler vurgulanır.\n\nKonu ipuçları\nBir soruda takıldın mı? Konusunun gramer kalıbını görmek için kaydır: kuralı hatırlatır, cevabı asla vermez.\n\nZayıf noktaların takipte\nUygulama sürekli kaçırdığın gramer konularını hatırlar ve Tekrar'da toplar; neye çalışman gerektiğini hep bilirsin.\n\nKonu Pratiği\nOn konudan birini seç (Articles, Tense Selection, Modal Verbs, Modal Past Forms, Gerund vs. Infinitive, Conditionals, Passive Voice, Prepositions, Relative Clauses, Comparatives & Superlatives); 3, 5 ya da 10 soruluk oturumlarla.\n\nÖğrenme Dağı\nHer Günlük Test karakterini bu ayın dağında bir adım yukarı taşır. Ayın madalyalarını kazan, kalıcı bir alışkanlık edin.\n\nAna Ekran widget'ları\n\"Climb\", bugünkü Günlük Test'i ve bu ayın dağındaki adımını gösterir. \"Tip\", kendi zayıf noktalarından her gün bir gramer ipucu getirir. Widget'lar yalnızca uygulamanın cihazına kaydettiklerini gösterir.\n\nGünlük hatırlatmalar\nGünde en fazla bir hatırlatma, seçtiğin saatte. Profil → Bildirimler'den açıp kapatabilirsin.\n\nDokuz çalışma arkadaşı\nSeninle tırmanacak karakteri seç.\n\nÜCRETSİZ VE PREMIUM\nÜcretsiz sürümde her gün bir Günlük Test ve bir pratik oturumu var.\nPremium, on konunun hepsinde Konu Pratiği'ni ve her gün daha fazla pratik oturumunu açar.\nPremium aylık ya da yıllık abonelik olarak sunulur. İkisi de yeni aboneler için ücretsiz deneme içerir. Fiyatlar abone olmadan önce uygulamada gösterilir.\n\nGİZLİLİK\nHesap yok, kayıt yok. Adın, ilerlemen ve pratik geçmişin cihazında kalır. Uygulama anonim kullanım verileri gönderir, adını asla göndermez.\nSana geri bildirim verebilmek için yazdığın cevaplar yapay zekâ sağlayıcımız Anthropic'e gönderilir. Uygulama bunu ilk kez yapmadan önce iznini ister; iznini istediğin zaman Veriler ekranından geri çekebilirsin.\n\nSon Kullanıcı Lisans Sözleşmesi (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/\nGizlilik Politikası: https://ahmettayfur.com/products/grammarlens/privacy/\nKullanım Koşulları: https://ahmettayfur.com/products/grammarlens/terms/",
          "whatsNew": "Yeni görünüm, widget'lar ve beş yeni konu.\n• Yeni tasarım: bütün ekranlar baştan çizildi; çalışma arkadaşın cevaplarına tepki veriyor.\n• Ana Ekran widget'ları: \"Climb\" bugünkü Günlük Test'i ve bu ayın dağındaki adımını gösterir; \"Tip\" kendi zayıf noktalarından her gün bir gramer ipucu getirir.\n• Günlük hatırlatmalar: günde en fazla bir tane, seçtiğin saatte. Profil → Bildirimler'den değiştirebilirsin.\n• Konu Pratiği'nde artık on konu var: Conditionals, Passive Voice, Prepositions, Relative Clauses ve Comparatives & Superlatives ilk beş konuya katıldı.\n• Günün pratiği bitince çalışma arkadaşın yarına kadar kampta dinlenir.\n• Profil, bu ayın bir sonraki madalyasına ne kadar yaklaştığını gösterir."
        }
      }
    },
    "condition": "Draft locale exists."
  },
  {
    "method": "POST",
    "path": "/v1/appStoreVersionLocalizations",
    "purpose": "tr create a missing localization",
    "body": {
      "data": {
        "type": "appStoreVersionLocalizations",
        "attributes": {
          "locale": "tr",
          "description": "GrammarLens İngilizce hatalarını pratiğe dönüştürür.\n\nHer gün kısa bir gramer testi çözersin. Bitirdiğinde yalnızca puanını görmezsin: her cevabın neden doğru ya da yanlış olduğunu sade bir dille okursun.\n\nSENİN DİLİNDE\nUygulamanın menüleri ve düğmeleri İngilizce, Japonca, Korece, İspanyolca, Portekizce (Brezilya), Türkçe, Arapça ve Almanca. Sorular ve geri bildirimler İngilizce kalır; böylece öğrendiğin dilde pratik yaparsın.\n\nNELER VAR\n\nGünlük Test\nHer gün yeni bir soru seti. Boşlukları doldur, hataları düzelt ve her cevap için bir açıklama al.\n\nSadece işaret değil, gerçek açıklama\n\"Yanlış\" yerine nedenini görürsün: hangi kural geçerli, cevabın neden uymuyor ve bir dahaki sefere neyi hatırlamalısın. Cevabınla düzeltilmiş hali arasında değişen kelimeler vurgulanır.\n\nKonu ipuçları\nBir soruda takıldın mı? Konusunun gramer kalıbını görmek için kaydır: kuralı hatırlatır, cevabı asla vermez.\n\nZayıf noktaların takipte\nUygulama sürekli kaçırdığın gramer konularını hatırlar ve Tekrar'da toplar; neye çalışman gerektiğini hep bilirsin.\n\nKonu Pratiği\nOn konudan birini seç (Articles, Tense Selection, Modal Verbs, Modal Past Forms, Gerund vs. Infinitive, Conditionals, Passive Voice, Prepositions, Relative Clauses, Comparatives & Superlatives); 3, 5 ya da 10 soruluk oturumlarla.\n\nÖğrenme Dağı\nHer Günlük Test karakterini bu ayın dağında bir adım yukarı taşır. Ayın madalyalarını kazan, kalıcı bir alışkanlık edin.\n\nAna Ekran widget'ları\n\"Climb\", bugünkü Günlük Test'i ve bu ayın dağındaki adımını gösterir. \"Tip\", kendi zayıf noktalarından her gün bir gramer ipucu getirir. Widget'lar yalnızca uygulamanın cihazına kaydettiklerini gösterir.\n\nGünlük hatırlatmalar\nGünde en fazla bir hatırlatma, seçtiğin saatte. Profil → Bildirimler'den açıp kapatabilirsin.\n\nDokuz çalışma arkadaşı\nSeninle tırmanacak karakteri seç.\n\nÜCRETSİZ VE PREMIUM\nÜcretsiz sürümde her gün bir Günlük Test ve bir pratik oturumu var.\nPremium, on konunun hepsinde Konu Pratiği'ni ve her gün daha fazla pratik oturumunu açar.\nPremium aylık ya da yıllık abonelik olarak sunulur. İkisi de yeni aboneler için ücretsiz deneme içerir. Fiyatlar abone olmadan önce uygulamada gösterilir.\n\nGİZLİLİK\nHesap yok, kayıt yok. Adın, ilerlemen ve pratik geçmişin cihazında kalır. Uygulama anonim kullanım verileri gönderir, adını asla göndermez.\nSana geri bildirim verebilmek için yazdığın cevaplar yapay zekâ sağlayıcımız Anthropic'e gönderilir. Uygulama bunu ilk kez yapmadan önce iznini ister; iznini istediğin zaman Veriler ekranından geri çekebilirsin.\n\nSon Kullanıcı Lisans Sözleşmesi (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/\nGizlilik Politikası: https://ahmettayfur.com/products/grammarlens/privacy/\nKullanım Koşulları: https://ahmettayfur.com/products/grammarlens/terms/",
          "keywords": "ingilizce,gramer,dilbilgisi,test,pratik,zamanlar,fiil,sınav,günlük,hata,yazma,ders",
          "whatsNew": "Yeni görünüm, widget'lar ve beş yeni konu.\n• Yeni tasarım: bütün ekranlar baştan çizildi; çalışma arkadaşın cevaplarına tepki veriyor.\n• Ana Ekran widget'ları: \"Climb\" bugünkü Günlük Test'i ve bu ayın dağındaki adımını gösterir; \"Tip\" kendi zayıf noktalarından her gün bir gramer ipucu getirir.\n• Günlük hatırlatmalar: günde en fazla bir tane, seçtiğin saatte. Profil → Bildirimler'den değiştirebilirsin.\n• Konu Pratiği'nde artık on konu var: Conditionals, Passive Voice, Prepositions, Relative Clauses ve Comparatives & Superlatives ilk beş konuya katıldı.\n• Günün pratiği bitince çalışma arkadaşın yarına kadar kampta dinlenir.\n• Profil, bu ayın bir sonraki madalyasına ne kadar yaklaştığını gösterir.",
          "promotionalText": "",
          "supportUrl": "https://ahmettayfur.com/products/grammarlens/support/"
        },
        "relationships": {
          "appStoreVersion": {
            "data": {
              "type": "appStoreVersions",
              "id": "{version_1.5.0}"
            }
          }
        }
      }
    },
    "condition": "Draft locale is missing.",
    "saveIdAs": "{localization_tr}"
  },
  {
    "method": "GET",
    "path": "/v1/appStoreVersions/{version_1.5.0}/appStoreVersionLocalizations?filter%5Blocale%5D=tr&limit=200",
    "purpose": "tr reconcile an existing localization on a creation conflict",
    "condition": "Only the HTTP 409 existing-localization case explicitly permitted by §3.3."
  },
  {
    "method": "PATCH",
    "path": "/v1/appStoreVersionLocalizations/{localization_tr}",
    "purpose": "tr update the two approved fields after the specified conflict reconciliation",
    "body": {
      "data": {
        "type": "appStoreVersionLocalizations",
        "id": "{localization_tr}",
        "attributes": {
          "description": "GrammarLens İngilizce hatalarını pratiğe dönüştürür.\n\nHer gün kısa bir gramer testi çözersin. Bitirdiğinde yalnızca puanını görmezsin: her cevabın neden doğru ya da yanlış olduğunu sade bir dille okursun.\n\nSENİN DİLİNDE\nUygulamanın menüleri ve düğmeleri İngilizce, Japonca, Korece, İspanyolca, Portekizce (Brezilya), Türkçe, Arapça ve Almanca. Sorular ve geri bildirimler İngilizce kalır; böylece öğrendiğin dilde pratik yaparsın.\n\nNELER VAR\n\nGünlük Test\nHer gün yeni bir soru seti. Boşlukları doldur, hataları düzelt ve her cevap için bir açıklama al.\n\nSadece işaret değil, gerçek açıklama\n\"Yanlış\" yerine nedenini görürsün: hangi kural geçerli, cevabın neden uymuyor ve bir dahaki sefere neyi hatırlamalısın. Cevabınla düzeltilmiş hali arasında değişen kelimeler vurgulanır.\n\nKonu ipuçları\nBir soruda takıldın mı? Konusunun gramer kalıbını görmek için kaydır: kuralı hatırlatır, cevabı asla vermez.\n\nZayıf noktaların takipte\nUygulama sürekli kaçırdığın gramer konularını hatırlar ve Tekrar'da toplar; neye çalışman gerektiğini hep bilirsin.\n\nKonu Pratiği\nOn konudan birini seç (Articles, Tense Selection, Modal Verbs, Modal Past Forms, Gerund vs. Infinitive, Conditionals, Passive Voice, Prepositions, Relative Clauses, Comparatives & Superlatives); 3, 5 ya da 10 soruluk oturumlarla.\n\nÖğrenme Dağı\nHer Günlük Test karakterini bu ayın dağında bir adım yukarı taşır. Ayın madalyalarını kazan, kalıcı bir alışkanlık edin.\n\nAna Ekran widget'ları\n\"Climb\", bugünkü Günlük Test'i ve bu ayın dağındaki adımını gösterir. \"Tip\", kendi zayıf noktalarından her gün bir gramer ipucu getirir. Widget'lar yalnızca uygulamanın cihazına kaydettiklerini gösterir.\n\nGünlük hatırlatmalar\nGünde en fazla bir hatırlatma, seçtiğin saatte. Profil → Bildirimler'den açıp kapatabilirsin.\n\nDokuz çalışma arkadaşı\nSeninle tırmanacak karakteri seç.\n\nÜCRETSİZ VE PREMIUM\nÜcretsiz sürümde her gün bir Günlük Test ve bir pratik oturumu var.\nPremium, on konunun hepsinde Konu Pratiği'ni ve her gün daha fazla pratik oturumunu açar.\nPremium aylık ya da yıllık abonelik olarak sunulur. İkisi de yeni aboneler için ücretsiz deneme içerir. Fiyatlar abone olmadan önce uygulamada gösterilir.\n\nGİZLİLİK\nHesap yok, kayıt yok. Adın, ilerlemen ve pratik geçmişin cihazında kalır. Uygulama anonim kullanım verileri gönderir, adını asla göndermez.\nSana geri bildirim verebilmek için yazdığın cevaplar yapay zekâ sağlayıcımız Anthropic'e gönderilir. Uygulama bunu ilk kez yapmadan önce iznini ister; iznini istediğin zaman Veriler ekranından geri çekebilirsin.\n\nSon Kullanıcı Lisans Sözleşmesi (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/\nGizlilik Politikası: https://ahmettayfur.com/products/grammarlens/privacy/\nKullanım Koşulları: https://ahmettayfur.com/products/grammarlens/terms/",
          "whatsNew": "Yeni görünüm, widget'lar ve beş yeni konu.\n• Yeni tasarım: bütün ekranlar baştan çizildi; çalışma arkadaşın cevaplarına tepki veriyor.\n• Ana Ekran widget'ları: \"Climb\" bugünkü Günlük Test'i ve bu ayın dağındaki adımını gösterir; \"Tip\" kendi zayıf noktalarından her gün bir gramer ipucu getirir.\n• Günlük hatırlatmalar: günde en fazla bir tane, seçtiğin saatte. Profil → Bildirimler'den değiştirebilirsin.\n• Konu Pratiği'nde artık on konu var: Conditionals, Passive Voice, Prepositions, Relative Clauses ve Comparatives & Superlatives ilk beş konuya katıldı.\n• Günün pratiği bitince çalışma arkadaşın yarına kadar kampta dinlenir.\n• Profil, bu ayın bir sonraki madalyasına ne kadar yaklaştığını gösterir."
        }
      }
    },
    "condition": "§3.3 locale conflict reconciled."
  },
  {
    "method": "PATCH",
    "path": "/v1/appStoreVersionLocalizations/{localization_de-DE}",
    "purpose": "de-DE update exactly the two approved text fields",
    "body": {
      "data": {
        "type": "appStoreVersionLocalizations",
        "id": "{localization_de-DE}",
        "attributes": {
          "description": "GrammarLens macht aus deinen Englischfehlern Übung.\n\nJeden Tag bekommst du einen kurzen Grammatiktest. Danach siehst du nicht nur eine Punktzahl, sondern in einfachen Worten, warum jede Antwort richtig oder falsch war.\n\nIN DEINER SPRACHE\nMenüs und Schaltflächen der App gibt es auf Englisch, Japanisch, Koreanisch, Spanisch, Portugiesisch (Brasilien), Türkisch, Arabisch und Deutsch. Fragen und Feedback bleiben auf Englisch, damit du die Sprache übst, die du lernst.\n\nDAS BEKOMMST DU\n\nTagestest\nJeden Tag neue Fragen. Fülle Lücken aus, korrigiere Fehler und bekomme zu jeder Antwort eine Erklärung.\n\nEchte Erklärungen statt Häkchen\nStatt „falsch“ bekommst du die Begründung: welche Regel gilt, warum deine Antwort nicht passt und was du dir merken solltest. Die Wörter, die sich zwischen deiner Antwort und der Korrektur unterscheiden, sind hervorgehoben.\n\nThemen-Tipps\nDu hängst bei einer Frage? Schieb, um das Grammatikmuster des Themas zu sehen – eine Erinnerung an die Regel, nie die Antwort.\n\nDeine Schwachstellen im Blick\nDie App merkt sich, welche Grammatikpunkte du immer wieder verfehlst, und sammelt sie in der Wiederholung. So weißt du immer, woran du arbeiten solltest.\n\nThemenübung\nWähle aus zehn Themen (Articles, Tense Selection, Modal Verbs, Modal Past Forms, Gerund vs. Infinitive, Conditionals, Passive Voice, Prepositions, Relative Clauses, Comparatives & Superlatives) mit Einheiten von 3, 5 oder 10 Fragen.\n\nLernberg\nJeder Tagestest bringt deine Figur einen Schritt auf den Berg dieses Monats. Verdiene Medaillen für den Monat und bau dir eine Gewohnheit auf, die bleibt.\n\nWidgets für den Home-Bildschirm\n„Climb“ zeigt den heutigen Tagestest und deinen Schritt auf dem Berg dieses Monats. „Tip“ bringt dir jeden Tag einen Grammatiktipp aus deinen eigenen Schwachstellen. Widgets zeigen nur, was die App auf deinem Gerät gespeichert hat.\n\nTägliche Erinnerungen\nHöchstens eine Erinnerung am Tag, zu der Uhrzeit, die du wählst. Ein- und ausschalten unter Profil → Mitteilungen.\n\nNeun Lernbegleiter\nWähle die Figur, die mit dir klettert.\n\nKOSTENLOS UND PREMIUM\nKostenlos: jeden Tag ein Tagestest und eine Übungseinheit.\nPremium schaltet die Themenübung in allen zehn Themen frei und mehr Übungseinheiten pro Tag.\nPremium gibt es als Monats- oder Jahresabo. Beide enthalten eine kostenlose Testphase für neue Abonnenten. Die Preise werden in der App angezeigt, bevor du abschließt.\n\nDATENSCHUTZ\nKein Konto, keine Anmeldung. Dein Name, dein Fortschritt und dein Übungsverlauf bleiben auf deinem Gerät. Die App sendet anonyme Nutzungsdaten, nie deinen Namen.\nFür das Feedback werden die Antworten, die du eingibst, an unseren KI-Anbieter Anthropic gesendet. Die App fragt vor dem ersten Senden um Erlaubnis. Du kannst die Erlaubnis jederzeit im Bildschirm „Daten“ widerrufen.\n\nLizenzvereinbarung (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/\nDatenschutzerklärung: https://ahmettayfur.com/products/grammarlens/privacy/\nNutzungsbedingungen: https://ahmettayfur.com/products/grammarlens/terms/",
          "whatsNew": "Neues Design, Widgets und fünf neue Themen.\n• Neues Design: Jeder Bildschirm wurde neu gestaltet, und dein Lernbegleiter reagiert auf deine Antworten.\n• Widgets für den Home-Bildschirm: „Climb“ zeigt den heutigen Tagestest und deinen Schritt auf dem Berg dieses Monats; „Tip“ bringt dir jeden Tag einen Grammatiktipp aus deinen eigenen Schwachstellen.\n• Tägliche Erinnerungen: höchstens eine am Tag, zu der Uhrzeit, die du wählst. Änderbar unter Profil → Mitteilungen.\n• Die Themenübung hat jetzt zehn Themen: Conditionals, Passive Voice, Prepositions, Relative Clauses und Comparatives & Superlatives kommen zu den bisherigen fünf dazu.\n• Wenn die Übungen des Tages erledigt sind, ruht dein Lernbegleiter bis morgen im Camp.\n• Im Profil siehst du, wie nah du der nächsten Medaille des Monats bist."
        }
      }
    },
    "condition": "Draft locale exists."
  },
  {
    "method": "POST",
    "path": "/v1/appStoreVersionLocalizations",
    "purpose": "de-DE create a missing localization",
    "body": {
      "data": {
        "type": "appStoreVersionLocalizations",
        "attributes": {
          "locale": "de-DE",
          "description": "GrammarLens macht aus deinen Englischfehlern Übung.\n\nJeden Tag bekommst du einen kurzen Grammatiktest. Danach siehst du nicht nur eine Punktzahl, sondern in einfachen Worten, warum jede Antwort richtig oder falsch war.\n\nIN DEINER SPRACHE\nMenüs und Schaltflächen der App gibt es auf Englisch, Japanisch, Koreanisch, Spanisch, Portugiesisch (Brasilien), Türkisch, Arabisch und Deutsch. Fragen und Feedback bleiben auf Englisch, damit du die Sprache übst, die du lernst.\n\nDAS BEKOMMST DU\n\nTagestest\nJeden Tag neue Fragen. Fülle Lücken aus, korrigiere Fehler und bekomme zu jeder Antwort eine Erklärung.\n\nEchte Erklärungen statt Häkchen\nStatt „falsch“ bekommst du die Begründung: welche Regel gilt, warum deine Antwort nicht passt und was du dir merken solltest. Die Wörter, die sich zwischen deiner Antwort und der Korrektur unterscheiden, sind hervorgehoben.\n\nThemen-Tipps\nDu hängst bei einer Frage? Schieb, um das Grammatikmuster des Themas zu sehen – eine Erinnerung an die Regel, nie die Antwort.\n\nDeine Schwachstellen im Blick\nDie App merkt sich, welche Grammatikpunkte du immer wieder verfehlst, und sammelt sie in der Wiederholung. So weißt du immer, woran du arbeiten solltest.\n\nThemenübung\nWähle aus zehn Themen (Articles, Tense Selection, Modal Verbs, Modal Past Forms, Gerund vs. Infinitive, Conditionals, Passive Voice, Prepositions, Relative Clauses, Comparatives & Superlatives) mit Einheiten von 3, 5 oder 10 Fragen.\n\nLernberg\nJeder Tagestest bringt deine Figur einen Schritt auf den Berg dieses Monats. Verdiene Medaillen für den Monat und bau dir eine Gewohnheit auf, die bleibt.\n\nWidgets für den Home-Bildschirm\n„Climb“ zeigt den heutigen Tagestest und deinen Schritt auf dem Berg dieses Monats. „Tip“ bringt dir jeden Tag einen Grammatiktipp aus deinen eigenen Schwachstellen. Widgets zeigen nur, was die App auf deinem Gerät gespeichert hat.\n\nTägliche Erinnerungen\nHöchstens eine Erinnerung am Tag, zu der Uhrzeit, die du wählst. Ein- und ausschalten unter Profil → Mitteilungen.\n\nNeun Lernbegleiter\nWähle die Figur, die mit dir klettert.\n\nKOSTENLOS UND PREMIUM\nKostenlos: jeden Tag ein Tagestest und eine Übungseinheit.\nPremium schaltet die Themenübung in allen zehn Themen frei und mehr Übungseinheiten pro Tag.\nPremium gibt es als Monats- oder Jahresabo. Beide enthalten eine kostenlose Testphase für neue Abonnenten. Die Preise werden in der App angezeigt, bevor du abschließt.\n\nDATENSCHUTZ\nKein Konto, keine Anmeldung. Dein Name, dein Fortschritt und dein Übungsverlauf bleiben auf deinem Gerät. Die App sendet anonyme Nutzungsdaten, nie deinen Namen.\nFür das Feedback werden die Antworten, die du eingibst, an unseren KI-Anbieter Anthropic gesendet. Die App fragt vor dem ersten Senden um Erlaubnis. Du kannst die Erlaubnis jederzeit im Bildschirm „Daten“ widerrufen.\n\nLizenzvereinbarung (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/\nDatenschutzerklärung: https://ahmettayfur.com/products/grammarlens/privacy/\nNutzungsbedingungen: https://ahmettayfur.com/products/grammarlens/terms/",
          "keywords": "englisch,grammatik,lernen,übung,test,zeitformen,artikel,verben,prüfung,täglich,fehler",
          "whatsNew": "Neues Design, Widgets und fünf neue Themen.\n• Neues Design: Jeder Bildschirm wurde neu gestaltet, und dein Lernbegleiter reagiert auf deine Antworten.\n• Widgets für den Home-Bildschirm: „Climb“ zeigt den heutigen Tagestest und deinen Schritt auf dem Berg dieses Monats; „Tip“ bringt dir jeden Tag einen Grammatiktipp aus deinen eigenen Schwachstellen.\n• Tägliche Erinnerungen: höchstens eine am Tag, zu der Uhrzeit, die du wählst. Änderbar unter Profil → Mitteilungen.\n• Die Themenübung hat jetzt zehn Themen: Conditionals, Passive Voice, Prepositions, Relative Clauses und Comparatives & Superlatives kommen zu den bisherigen fünf dazu.\n• Wenn die Übungen des Tages erledigt sind, ruht dein Lernbegleiter bis morgen im Camp.\n• Im Profil siehst du, wie nah du der nächsten Medaille des Monats bist.",
          "promotionalText": "",
          "supportUrl": "https://ahmettayfur.com/products/grammarlens/support/"
        },
        "relationships": {
          "appStoreVersion": {
            "data": {
              "type": "appStoreVersions",
              "id": "{version_1.5.0}"
            }
          }
        }
      }
    },
    "condition": "Draft locale is missing.",
    "saveIdAs": "{localization_de-DE}"
  },
  {
    "method": "GET",
    "path": "/v1/appStoreVersions/{version_1.5.0}/appStoreVersionLocalizations?filter%5Blocale%5D=de-DE&limit=200",
    "purpose": "de-DE reconcile an existing localization on a creation conflict",
    "condition": "Only the HTTP 409 existing-localization case explicitly permitted by §3.3."
  },
  {
    "method": "PATCH",
    "path": "/v1/appStoreVersionLocalizations/{localization_de-DE}",
    "purpose": "de-DE update the two approved fields after the specified conflict reconciliation",
    "body": {
      "data": {
        "type": "appStoreVersionLocalizations",
        "id": "{localization_de-DE}",
        "attributes": {
          "description": "GrammarLens macht aus deinen Englischfehlern Übung.\n\nJeden Tag bekommst du einen kurzen Grammatiktest. Danach siehst du nicht nur eine Punktzahl, sondern in einfachen Worten, warum jede Antwort richtig oder falsch war.\n\nIN DEINER SPRACHE\nMenüs und Schaltflächen der App gibt es auf Englisch, Japanisch, Koreanisch, Spanisch, Portugiesisch (Brasilien), Türkisch, Arabisch und Deutsch. Fragen und Feedback bleiben auf Englisch, damit du die Sprache übst, die du lernst.\n\nDAS BEKOMMST DU\n\nTagestest\nJeden Tag neue Fragen. Fülle Lücken aus, korrigiere Fehler und bekomme zu jeder Antwort eine Erklärung.\n\nEchte Erklärungen statt Häkchen\nStatt „falsch“ bekommst du die Begründung: welche Regel gilt, warum deine Antwort nicht passt und was du dir merken solltest. Die Wörter, die sich zwischen deiner Antwort und der Korrektur unterscheiden, sind hervorgehoben.\n\nThemen-Tipps\nDu hängst bei einer Frage? Schieb, um das Grammatikmuster des Themas zu sehen – eine Erinnerung an die Regel, nie die Antwort.\n\nDeine Schwachstellen im Blick\nDie App merkt sich, welche Grammatikpunkte du immer wieder verfehlst, und sammelt sie in der Wiederholung. So weißt du immer, woran du arbeiten solltest.\n\nThemenübung\nWähle aus zehn Themen (Articles, Tense Selection, Modal Verbs, Modal Past Forms, Gerund vs. Infinitive, Conditionals, Passive Voice, Prepositions, Relative Clauses, Comparatives & Superlatives) mit Einheiten von 3, 5 oder 10 Fragen.\n\nLernberg\nJeder Tagestest bringt deine Figur einen Schritt auf den Berg dieses Monats. Verdiene Medaillen für den Monat und bau dir eine Gewohnheit auf, die bleibt.\n\nWidgets für den Home-Bildschirm\n„Climb“ zeigt den heutigen Tagestest und deinen Schritt auf dem Berg dieses Monats. „Tip“ bringt dir jeden Tag einen Grammatiktipp aus deinen eigenen Schwachstellen. Widgets zeigen nur, was die App auf deinem Gerät gespeichert hat.\n\nTägliche Erinnerungen\nHöchstens eine Erinnerung am Tag, zu der Uhrzeit, die du wählst. Ein- und ausschalten unter Profil → Mitteilungen.\n\nNeun Lernbegleiter\nWähle die Figur, die mit dir klettert.\n\nKOSTENLOS UND PREMIUM\nKostenlos: jeden Tag ein Tagestest und eine Übungseinheit.\nPremium schaltet die Themenübung in allen zehn Themen frei und mehr Übungseinheiten pro Tag.\nPremium gibt es als Monats- oder Jahresabo. Beide enthalten eine kostenlose Testphase für neue Abonnenten. Die Preise werden in der App angezeigt, bevor du abschließt.\n\nDATENSCHUTZ\nKein Konto, keine Anmeldung. Dein Name, dein Fortschritt und dein Übungsverlauf bleiben auf deinem Gerät. Die App sendet anonyme Nutzungsdaten, nie deinen Namen.\nFür das Feedback werden die Antworten, die du eingibst, an unseren KI-Anbieter Anthropic gesendet. Die App fragt vor dem ersten Senden um Erlaubnis. Du kannst die Erlaubnis jederzeit im Bildschirm „Daten“ widerrufen.\n\nLizenzvereinbarung (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/\nDatenschutzerklärung: https://ahmettayfur.com/products/grammarlens/privacy/\nNutzungsbedingungen: https://ahmettayfur.com/products/grammarlens/terms/",
          "whatsNew": "Neues Design, Widgets und fünf neue Themen.\n• Neues Design: Jeder Bildschirm wurde neu gestaltet, und dein Lernbegleiter reagiert auf deine Antworten.\n• Widgets für den Home-Bildschirm: „Climb“ zeigt den heutigen Tagestest und deinen Schritt auf dem Berg dieses Monats; „Tip“ bringt dir jeden Tag einen Grammatiktipp aus deinen eigenen Schwachstellen.\n• Tägliche Erinnerungen: höchstens eine am Tag, zu der Uhrzeit, die du wählst. Änderbar unter Profil → Mitteilungen.\n• Die Themenübung hat jetzt zehn Themen: Conditionals, Passive Voice, Prepositions, Relative Clauses und Comparatives & Superlatives kommen zu den bisherigen fünf dazu.\n• Wenn die Übungen des Tages erledigt sind, ruht dein Lernbegleiter bis morgen im Camp.\n• Im Profil siehst du, wie nah du der nächsten Medaille des Monats bist."
        }
      }
    },
    "condition": "§3.3 locale conflict reconciled."
  },
  {
    "method": "PATCH",
    "path": "/v1/appStoreVersionLocalizations/{localization_es-MX}",
    "purpose": "es-MX update exactly the two approved text fields",
    "body": {
      "data": {
        "type": "appStoreVersionLocalizations",
        "id": "{localization_es-MX}",
        "attributes": {
          "description": "GrammarLens convierte tus errores de inglés en práctica.\n\nCada día haces un test corto de gramática. Al terminar, no solo ves una puntuación: ves por qué cada respuesta estuvo bien o mal, explicado con palabras sencillas.\n\nEN TU IDIOMA\nLos menús y botones de la app están en inglés, japonés, coreano, español, portugués (Brasil), turco, árabe y alemán. Las preguntas y la retroalimentación siguen en inglés, para que practiques el idioma que estás aprendiendo.\n\nLO QUE OBTIENES\n\nTest diario\nUn nuevo grupo de preguntas cada día. Completa espacios, corrige errores y recibe una explicación para cada respuesta.\n\nExplicaciones reales, no solo marcas\nEn lugar de \"incorrecto\", ves el porqué: qué regla aplica, por qué tu respuesta no encaja y qué recordar la próxima vez. Las palabras que cambian entre tu respuesta y la corrección aparecen resaltadas.\n\nPistas del tema\n¿Te atoraste en una pregunta? Desliza para ver el patrón gramatical de su tema: un recordatorio de la regla, nunca la respuesta.\n\nTus puntos débiles, bajo control\nLa app recuerda los puntos de gramática que sigues fallando y los reúne en Repaso, para que siempre sepas en qué trabajar.\n\nPráctica por temas\nElige entre diez temas (Articles, Tense Selection, Modal Verbs, Modal Past Forms, Gerund vs. Infinitive, Conditionals, Passive Voice, Prepositions, Relative Clauses, Comparatives & Superlatives) con sesiones de 3, 5 o 10 preguntas.\n\nMontaña del aprendizaje\nCada Test diario sube a tu personaje un paso en la montaña del mes. Gana las medallas del mes y crea un hábito que dure.\n\nWidgets para la pantalla de inicio\n\"Climb\" muestra el Test diario de hoy y tu paso en la montaña del mes. \"Tip\" te trae cada día un consejo de gramática a partir de tus propios puntos débiles. Los widgets solo muestran lo que la app guardó en tu dispositivo.\n\nRecordatorios diarios\nComo máximo un recordatorio al día, a la hora que elijas. Actívalos o desactívalos en Perfil → Notificaciones.\n\nNueve compañeros de estudio\nElige el personaje que sube contigo.\n\nGRATIS Y PREMIUM\nLa versión gratis incluye un Test diario y una sesión de práctica cada día.\nPremium desbloquea la Práctica por temas en los diez temas y más sesiones de práctica al día.\nPremium está disponible como suscripción mensual o anual. Ambas incluyen una prueba gratuita para nuevos suscriptores. Los precios se muestran en la app antes de suscribirte.\n\nPRIVACIDAD\nSin cuenta y sin registro. Tu nombre, tu progreso y tu historial de práctica se quedan en tu dispositivo. La app envía datos de uso anónimos, nunca tu nombre.\nPara darte retroalimentación, las respuestas que escribes se envían a nuestro proveedor de IA, Anthropic. La app te pide permiso antes de hacerlo por primera vez, y puedes retirarlo cuando quieras desde la pantalla Datos.\n\nContrato de licencia (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/\nPolítica de privacidad: https://ahmettayfur.com/products/grammarlens/privacy/\nTérminos del servicio: https://ahmettayfur.com/products/grammarlens/terms/",
          "whatsNew": "Nuevo diseño, widgets y cinco temas nuevos.\n• Nuevo diseño: todas las pantallas se rediseñaron y tu compañero de estudio reacciona a tus respuestas.\n• Widgets para la pantalla de inicio: \"Climb\" muestra el Test diario de hoy y tu paso en la montaña del mes; \"Tip\" te trae cada día un consejo de gramática a partir de tus propios puntos débiles.\n• Recordatorios diarios: como máximo uno al día, a la hora que elijas. Cámbialo en Perfil → Notificaciones.\n• La Práctica por temas ahora tiene diez temas: Conditionals, Passive Voice, Prepositions, Relative Clauses y Comparatives & Superlatives se suman a los cinco originales.\n• Cuando terminas la práctica del día, tu compañero descansa en el campamento hasta mañana.\n• En Perfil ves qué tan cerca estás de la próxima medalla del mes."
        }
      }
    },
    "condition": "Draft locale exists."
  },
  {
    "method": "POST",
    "path": "/v1/appStoreVersionLocalizations",
    "purpose": "es-MX create a missing localization",
    "body": {
      "data": {
        "type": "appStoreVersionLocalizations",
        "attributes": {
          "locale": "es-MX",
          "description": "GrammarLens convierte tus errores de inglés en práctica.\n\nCada día haces un test corto de gramática. Al terminar, no solo ves una puntuación: ves por qué cada respuesta estuvo bien o mal, explicado con palabras sencillas.\n\nEN TU IDIOMA\nLos menús y botones de la app están en inglés, japonés, coreano, español, portugués (Brasil), turco, árabe y alemán. Las preguntas y la retroalimentación siguen en inglés, para que practiques el idioma que estás aprendiendo.\n\nLO QUE OBTIENES\n\nTest diario\nUn nuevo grupo de preguntas cada día. Completa espacios, corrige errores y recibe una explicación para cada respuesta.\n\nExplicaciones reales, no solo marcas\nEn lugar de \"incorrecto\", ves el porqué: qué regla aplica, por qué tu respuesta no encaja y qué recordar la próxima vez. Las palabras que cambian entre tu respuesta y la corrección aparecen resaltadas.\n\nPistas del tema\n¿Te atoraste en una pregunta? Desliza para ver el patrón gramatical de su tema: un recordatorio de la regla, nunca la respuesta.\n\nTus puntos débiles, bajo control\nLa app recuerda los puntos de gramática que sigues fallando y los reúne en Repaso, para que siempre sepas en qué trabajar.\n\nPráctica por temas\nElige entre diez temas (Articles, Tense Selection, Modal Verbs, Modal Past Forms, Gerund vs. Infinitive, Conditionals, Passive Voice, Prepositions, Relative Clauses, Comparatives & Superlatives) con sesiones de 3, 5 o 10 preguntas.\n\nMontaña del aprendizaje\nCada Test diario sube a tu personaje un paso en la montaña del mes. Gana las medallas del mes y crea un hábito que dure.\n\nWidgets para la pantalla de inicio\n\"Climb\" muestra el Test diario de hoy y tu paso en la montaña del mes. \"Tip\" te trae cada día un consejo de gramática a partir de tus propios puntos débiles. Los widgets solo muestran lo que la app guardó en tu dispositivo.\n\nRecordatorios diarios\nComo máximo un recordatorio al día, a la hora que elijas. Actívalos o desactívalos en Perfil → Notificaciones.\n\nNueve compañeros de estudio\nElige el personaje que sube contigo.\n\nGRATIS Y PREMIUM\nLa versión gratis incluye un Test diario y una sesión de práctica cada día.\nPremium desbloquea la Práctica por temas en los diez temas y más sesiones de práctica al día.\nPremium está disponible como suscripción mensual o anual. Ambas incluyen una prueba gratuita para nuevos suscriptores. Los precios se muestran en la app antes de suscribirte.\n\nPRIVACIDAD\nSin cuenta y sin registro. Tu nombre, tu progreso y tu historial de práctica se quedan en tu dispositivo. La app envía datos de uso anónimos, nunca tu nombre.\nPara darte retroalimentación, las respuestas que escribes se envían a nuestro proveedor de IA, Anthropic. La app te pide permiso antes de hacerlo por primera vez, y puedes retirarlo cuando quieras desde la pantalla Datos.\n\nContrato de licencia (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/\nPolítica de privacidad: https://ahmettayfur.com/products/grammarlens/privacy/\nTérminos del servicio: https://ahmettayfur.com/products/grammarlens/terms/",
          "keywords": "inglés,gramática,aprender,práctica,test,tiempos,artículos,verbos,examen,diario,errores",
          "whatsNew": "Nuevo diseño, widgets y cinco temas nuevos.\n• Nuevo diseño: todas las pantallas se rediseñaron y tu compañero de estudio reacciona a tus respuestas.\n• Widgets para la pantalla de inicio: \"Climb\" muestra el Test diario de hoy y tu paso en la montaña del mes; \"Tip\" te trae cada día un consejo de gramática a partir de tus propios puntos débiles.\n• Recordatorios diarios: como máximo uno al día, a la hora que elijas. Cámbialo en Perfil → Notificaciones.\n• La Práctica por temas ahora tiene diez temas: Conditionals, Passive Voice, Prepositions, Relative Clauses y Comparatives & Superlatives se suman a los cinco originales.\n• Cuando terminas la práctica del día, tu compañero descansa en el campamento hasta mañana.\n• En Perfil ves qué tan cerca estás de la próxima medalla del mes.",
          "promotionalText": "",
          "supportUrl": "https://ahmettayfur.com/products/grammarlens/support/"
        },
        "relationships": {
          "appStoreVersion": {
            "data": {
              "type": "appStoreVersions",
              "id": "{version_1.5.0}"
            }
          }
        }
      }
    },
    "condition": "Draft locale is missing.",
    "saveIdAs": "{localization_es-MX}"
  },
  {
    "method": "GET",
    "path": "/v1/appStoreVersions/{version_1.5.0}/appStoreVersionLocalizations?filter%5Blocale%5D=es-MX&limit=200",
    "purpose": "es-MX reconcile an existing localization on a creation conflict",
    "condition": "Only the HTTP 409 existing-localization case explicitly permitted by §3.3."
  },
  {
    "method": "PATCH",
    "path": "/v1/appStoreVersionLocalizations/{localization_es-MX}",
    "purpose": "es-MX update the two approved fields after the specified conflict reconciliation",
    "body": {
      "data": {
        "type": "appStoreVersionLocalizations",
        "id": "{localization_es-MX}",
        "attributes": {
          "description": "GrammarLens convierte tus errores de inglés en práctica.\n\nCada día haces un test corto de gramática. Al terminar, no solo ves una puntuación: ves por qué cada respuesta estuvo bien o mal, explicado con palabras sencillas.\n\nEN TU IDIOMA\nLos menús y botones de la app están en inglés, japonés, coreano, español, portugués (Brasil), turco, árabe y alemán. Las preguntas y la retroalimentación siguen en inglés, para que practiques el idioma que estás aprendiendo.\n\nLO QUE OBTIENES\n\nTest diario\nUn nuevo grupo de preguntas cada día. Completa espacios, corrige errores y recibe una explicación para cada respuesta.\n\nExplicaciones reales, no solo marcas\nEn lugar de \"incorrecto\", ves el porqué: qué regla aplica, por qué tu respuesta no encaja y qué recordar la próxima vez. Las palabras que cambian entre tu respuesta y la corrección aparecen resaltadas.\n\nPistas del tema\n¿Te atoraste en una pregunta? Desliza para ver el patrón gramatical de su tema: un recordatorio de la regla, nunca la respuesta.\n\nTus puntos débiles, bajo control\nLa app recuerda los puntos de gramática que sigues fallando y los reúne en Repaso, para que siempre sepas en qué trabajar.\n\nPráctica por temas\nElige entre diez temas (Articles, Tense Selection, Modal Verbs, Modal Past Forms, Gerund vs. Infinitive, Conditionals, Passive Voice, Prepositions, Relative Clauses, Comparatives & Superlatives) con sesiones de 3, 5 o 10 preguntas.\n\nMontaña del aprendizaje\nCada Test diario sube a tu personaje un paso en la montaña del mes. Gana las medallas del mes y crea un hábito que dure.\n\nWidgets para la pantalla de inicio\n\"Climb\" muestra el Test diario de hoy y tu paso en la montaña del mes. \"Tip\" te trae cada día un consejo de gramática a partir de tus propios puntos débiles. Los widgets solo muestran lo que la app guardó en tu dispositivo.\n\nRecordatorios diarios\nComo máximo un recordatorio al día, a la hora que elijas. Actívalos o desactívalos en Perfil → Notificaciones.\n\nNueve compañeros de estudio\nElige el personaje que sube contigo.\n\nGRATIS Y PREMIUM\nLa versión gratis incluye un Test diario y una sesión de práctica cada día.\nPremium desbloquea la Práctica por temas en los diez temas y más sesiones de práctica al día.\nPremium está disponible como suscripción mensual o anual. Ambas incluyen una prueba gratuita para nuevos suscriptores. Los precios se muestran en la app antes de suscribirte.\n\nPRIVACIDAD\nSin cuenta y sin registro. Tu nombre, tu progreso y tu historial de práctica se quedan en tu dispositivo. La app envía datos de uso anónimos, nunca tu nombre.\nPara darte retroalimentación, las respuestas que escribes se envían a nuestro proveedor de IA, Anthropic. La app te pide permiso antes de hacerlo por primera vez, y puedes retirarlo cuando quieras desde la pantalla Datos.\n\nContrato de licencia (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/\nPolítica de privacidad: https://ahmettayfur.com/products/grammarlens/privacy/\nTérminos del servicio: https://ahmettayfur.com/products/grammarlens/terms/",
          "whatsNew": "Nuevo diseño, widgets y cinco temas nuevos.\n• Nuevo diseño: todas las pantallas se rediseñaron y tu compañero de estudio reacciona a tus respuestas.\n• Widgets para la pantalla de inicio: \"Climb\" muestra el Test diario de hoy y tu paso en la montaña del mes; \"Tip\" te trae cada día un consejo de gramática a partir de tus propios puntos débiles.\n• Recordatorios diarios: como máximo uno al día, a la hora que elijas. Cámbialo en Perfil → Notificaciones.\n• La Práctica por temas ahora tiene diez temas: Conditionals, Passive Voice, Prepositions, Relative Clauses y Comparatives & Superlatives se suman a los cinco originales.\n• Cuando terminas la práctica del día, tu compañero descansa en el campamento hasta mañana.\n• En Perfil ves qué tan cerca estás de la próxima medalla del mes."
        }
      }
    },
    "condition": "§3.3 locale conflict reconciled."
  },
  {
    "method": "PATCH",
    "path": "/v1/appStoreVersionLocalizations/{localization_pt-BR}",
    "purpose": "pt-BR update exactly the two approved text fields",
    "body": {
      "data": {
        "type": "appStoreVersionLocalizations",
        "id": "{localization_pt-BR}",
        "attributes": {
          "description": "O GrammarLens transforma seus erros de inglês em prática.\n\nTodo dia você faz um teste curto de gramática. Ao terminar, você não vê só uma pontuação: vê por que cada resposta estava certa ou errada, em linguagem simples.\n\nNA SUA LÍNGUA\nOs menus e botões do app estão em inglês, japonês, coreano, espanhol, português (Brasil), turco, árabe e alemão. As perguntas e o feedback continuam em inglês, para você praticar a língua que está aprendendo.\n\nO QUE VOCÊ GANHA\n\nTeste diário\nUm novo conjunto de perguntas todo dia. Complete lacunas, corrija erros e receba uma explicação para cada resposta.\n\nExplicações de verdade, não só marcações\nEm vez de \"errado\", você vê o motivo: qual regra se aplica, por que sua resposta não serve e o que lembrar da próxima vez. As palavras que mudam entre sua resposta e a correção ficam destacadas.\n\nDicas do tema\nTravou em uma pergunta? Deslize para ver o padrão gramatical do tema: um lembrete da regra, nunca a resposta.\n\nSeus pontos fracos, acompanhados\nO app lembra os pontos de gramática que você continua errando e os reúne na Revisão, para você sempre saber no que trabalhar.\n\nPrática por tema\nEscolha entre dez temas (Articles, Tense Selection, Modal Verbs, Modal Past Forms, Gerund vs. Infinitive, Conditionals, Passive Voice, Prepositions, Relative Clauses, Comparatives & Superlatives) com sessões de 3, 5 ou 10 perguntas.\n\nMontanha do aprendizado\nCada Teste diário leva seu personagem um passo acima na montanha do mês. Ganhe as medalhas do mês e crie um hábito que fica.\n\nWidgets na Tela de Início\n\"Climb\" mostra o Teste diário de hoje e o seu passo na montanha do mês. \"Tip\" traz todo dia uma dica de gramática a partir dos seus próprios pontos fracos. Os widgets mostram só o que o app salvou no seu aparelho.\n\nLembretes diários\nNo máximo um lembrete por dia, no horário que você escolher. Ative ou desative em Perfil → Notificações.\n\nNove companheiros de estudo\nEscolha o personagem que sobe com você.\n\nGRÁTIS E PREMIUM\nO plano grátis inclui um Teste diário e uma sessão de prática por dia.\nO Premium libera a Prática por tema nos dez temas e mais sessões de prática por dia.\nO Premium está disponível em assinatura mensal ou anual. As duas incluem um período grátis para novos assinantes. Os preços aparecem no app antes de você assinar.\n\nPRIVACIDADE\nSem conta e sem cadastro. Seu nome, seu progresso e seu histórico de prática ficam no seu aparelho. O app envia dados de uso anônimos, nunca o seu nome.\nPara dar feedback, as respostas que você digita são enviadas ao nosso provedor de IA, a Anthropic. O app pede sua permissão antes de fazer isso pela primeira vez, e você pode retirá-la quando quiser na tela Dados.\n\nContrato de Licença (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/\nPolítica de Privacidade: https://ahmettayfur.com/products/grammarlens/privacy/\nTermos de Serviço: https://ahmettayfur.com/products/grammarlens/terms/",
          "whatsNew": "Visual novo, widgets e cinco temas novos.\n• Novo design: todas as telas foram redesenhadas, e seu companheiro de estudo reage às suas respostas.\n• Widgets na Tela de Início: \"Climb\" mostra o Teste diário de hoje e o seu passo na montanha do mês; \"Tip\" traz todo dia uma dica de gramática a partir dos seus próprios pontos fracos.\n• Lembretes diários: no máximo um por dia, no horário que você escolher. Mude em Perfil → Notificações.\n• A Prática por tema agora tem dez temas: Conditionals, Passive Voice, Prepositions, Relative Clauses e Comparatives & Superlatives se juntam aos cinco originais.\n• Quando a prática do dia termina, seu companheiro descansa no acampamento até amanhã.\n• O Perfil mostra quanto falta para a próxima medalha do mês."
        }
      }
    },
    "condition": "Draft locale exists."
  },
  {
    "method": "POST",
    "path": "/v1/appStoreVersionLocalizations",
    "purpose": "pt-BR create a missing localization",
    "body": {
      "data": {
        "type": "appStoreVersionLocalizations",
        "attributes": {
          "locale": "pt-BR",
          "description": "O GrammarLens transforma seus erros de inglês em prática.\n\nTodo dia você faz um teste curto de gramática. Ao terminar, você não vê só uma pontuação: vê por que cada resposta estava certa ou errada, em linguagem simples.\n\nNA SUA LÍNGUA\nOs menus e botões do app estão em inglês, japonês, coreano, espanhol, português (Brasil), turco, árabe e alemão. As perguntas e o feedback continuam em inglês, para você praticar a língua que está aprendendo.\n\nO QUE VOCÊ GANHA\n\nTeste diário\nUm novo conjunto de perguntas todo dia. Complete lacunas, corrija erros e receba uma explicação para cada resposta.\n\nExplicações de verdade, não só marcações\nEm vez de \"errado\", você vê o motivo: qual regra se aplica, por que sua resposta não serve e o que lembrar da próxima vez. As palavras que mudam entre sua resposta e a correção ficam destacadas.\n\nDicas do tema\nTravou em uma pergunta? Deslize para ver o padrão gramatical do tema: um lembrete da regra, nunca a resposta.\n\nSeus pontos fracos, acompanhados\nO app lembra os pontos de gramática que você continua errando e os reúne na Revisão, para você sempre saber no que trabalhar.\n\nPrática por tema\nEscolha entre dez temas (Articles, Tense Selection, Modal Verbs, Modal Past Forms, Gerund vs. Infinitive, Conditionals, Passive Voice, Prepositions, Relative Clauses, Comparatives & Superlatives) com sessões de 3, 5 ou 10 perguntas.\n\nMontanha do aprendizado\nCada Teste diário leva seu personagem um passo acima na montanha do mês. Ganhe as medalhas do mês e crie um hábito que fica.\n\nWidgets na Tela de Início\n\"Climb\" mostra o Teste diário de hoje e o seu passo na montanha do mês. \"Tip\" traz todo dia uma dica de gramática a partir dos seus próprios pontos fracos. Os widgets mostram só o que o app salvou no seu aparelho.\n\nLembretes diários\nNo máximo um lembrete por dia, no horário que você escolher. Ative ou desative em Perfil → Notificações.\n\nNove companheiros de estudo\nEscolha o personagem que sobe com você.\n\nGRÁTIS E PREMIUM\nO plano grátis inclui um Teste diário e uma sessão de prática por dia.\nO Premium libera a Prática por tema nos dez temas e mais sessões de prática por dia.\nO Premium está disponível em assinatura mensal ou anual. As duas incluem um período grátis para novos assinantes. Os preços aparecem no app antes de você assinar.\n\nPRIVACIDADE\nSem conta e sem cadastro. Seu nome, seu progresso e seu histórico de prática ficam no seu aparelho. O app envia dados de uso anônimos, nunca o seu nome.\nPara dar feedback, as respostas que você digita são enviadas ao nosso provedor de IA, a Anthropic. O app pede sua permissão antes de fazer isso pela primeira vez, e você pode retirá-la quando quiser na tela Dados.\n\nContrato de Licença (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/\nPolítica de Privacidade: https://ahmettayfur.com/products/grammarlens/privacy/\nTermos de Serviço: https://ahmettayfur.com/products/grammarlens/terms/",
          "keywords": "inglês,gramática,aprender,prática,teste,tempos,artigos,verbos,exame,diário,erros",
          "whatsNew": "Visual novo, widgets e cinco temas novos.\n• Novo design: todas as telas foram redesenhadas, e seu companheiro de estudo reage às suas respostas.\n• Widgets na Tela de Início: \"Climb\" mostra o Teste diário de hoje e o seu passo na montanha do mês; \"Tip\" traz todo dia uma dica de gramática a partir dos seus próprios pontos fracos.\n• Lembretes diários: no máximo um por dia, no horário que você escolher. Mude em Perfil → Notificações.\n• A Prática por tema agora tem dez temas: Conditionals, Passive Voice, Prepositions, Relative Clauses e Comparatives & Superlatives se juntam aos cinco originais.\n• Quando a prática do dia termina, seu companheiro descansa no acampamento até amanhã.\n• O Perfil mostra quanto falta para a próxima medalha do mês.",
          "promotionalText": "",
          "supportUrl": "https://ahmettayfur.com/products/grammarlens/support/"
        },
        "relationships": {
          "appStoreVersion": {
            "data": {
              "type": "appStoreVersions",
              "id": "{version_1.5.0}"
            }
          }
        }
      }
    },
    "condition": "Draft locale is missing.",
    "saveIdAs": "{localization_pt-BR}"
  },
  {
    "method": "GET",
    "path": "/v1/appStoreVersions/{version_1.5.0}/appStoreVersionLocalizations?filter%5Blocale%5D=pt-BR&limit=200",
    "purpose": "pt-BR reconcile an existing localization on a creation conflict",
    "condition": "Only the HTTP 409 existing-localization case explicitly permitted by §3.3."
  },
  {
    "method": "PATCH",
    "path": "/v1/appStoreVersionLocalizations/{localization_pt-BR}",
    "purpose": "pt-BR update the two approved fields after the specified conflict reconciliation",
    "body": {
      "data": {
        "type": "appStoreVersionLocalizations",
        "id": "{localization_pt-BR}",
        "attributes": {
          "description": "O GrammarLens transforma seus erros de inglês em prática.\n\nTodo dia você faz um teste curto de gramática. Ao terminar, você não vê só uma pontuação: vê por que cada resposta estava certa ou errada, em linguagem simples.\n\nNA SUA LÍNGUA\nOs menus e botões do app estão em inglês, japonês, coreano, espanhol, português (Brasil), turco, árabe e alemão. As perguntas e o feedback continuam em inglês, para você praticar a língua que está aprendendo.\n\nO QUE VOCÊ GANHA\n\nTeste diário\nUm novo conjunto de perguntas todo dia. Complete lacunas, corrija erros e receba uma explicação para cada resposta.\n\nExplicações de verdade, não só marcações\nEm vez de \"errado\", você vê o motivo: qual regra se aplica, por que sua resposta não serve e o que lembrar da próxima vez. As palavras que mudam entre sua resposta e a correção ficam destacadas.\n\nDicas do tema\nTravou em uma pergunta? Deslize para ver o padrão gramatical do tema: um lembrete da regra, nunca a resposta.\n\nSeus pontos fracos, acompanhados\nO app lembra os pontos de gramática que você continua errando e os reúne na Revisão, para você sempre saber no que trabalhar.\n\nPrática por tema\nEscolha entre dez temas (Articles, Tense Selection, Modal Verbs, Modal Past Forms, Gerund vs. Infinitive, Conditionals, Passive Voice, Prepositions, Relative Clauses, Comparatives & Superlatives) com sessões de 3, 5 ou 10 perguntas.\n\nMontanha do aprendizado\nCada Teste diário leva seu personagem um passo acima na montanha do mês. Ganhe as medalhas do mês e crie um hábito que fica.\n\nWidgets na Tela de Início\n\"Climb\" mostra o Teste diário de hoje e o seu passo na montanha do mês. \"Tip\" traz todo dia uma dica de gramática a partir dos seus próprios pontos fracos. Os widgets mostram só o que o app salvou no seu aparelho.\n\nLembretes diários\nNo máximo um lembrete por dia, no horário que você escolher. Ative ou desative em Perfil → Notificações.\n\nNove companheiros de estudo\nEscolha o personagem que sobe com você.\n\nGRÁTIS E PREMIUM\nO plano grátis inclui um Teste diário e uma sessão de prática por dia.\nO Premium libera a Prática por tema nos dez temas e mais sessões de prática por dia.\nO Premium está disponível em assinatura mensal ou anual. As duas incluem um período grátis para novos assinantes. Os preços aparecem no app antes de você assinar.\n\nPRIVACIDADE\nSem conta e sem cadastro. Seu nome, seu progresso e seu histórico de prática ficam no seu aparelho. O app envia dados de uso anônimos, nunca o seu nome.\nPara dar feedback, as respostas que você digita são enviadas ao nosso provedor de IA, a Anthropic. O app pede sua permissão antes de fazer isso pela primeira vez, e você pode retirá-la quando quiser na tela Dados.\n\nContrato de Licença (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/\nPolítica de Privacidade: https://ahmettayfur.com/products/grammarlens/privacy/\nTermos de Serviço: https://ahmettayfur.com/products/grammarlens/terms/",
          "whatsNew": "Visual novo, widgets e cinco temas novos.\n• Novo design: todas as telas foram redesenhadas, e seu companheiro de estudo reage às suas respostas.\n• Widgets na Tela de Início: \"Climb\" mostra o Teste diário de hoje e o seu passo na montanha do mês; \"Tip\" traz todo dia uma dica de gramática a partir dos seus próprios pontos fracos.\n• Lembretes diários: no máximo um por dia, no horário que você escolher. Mude em Perfil → Notificações.\n• A Prática por tema agora tem dez temas: Conditionals, Passive Voice, Prepositions, Relative Clauses e Comparatives & Superlatives se juntam aos cinco originais.\n• Quando a prática do dia termina, seu companheiro descansa no acampamento até amanhã.\n• O Perfil mostra quanto falta para a próxima medalha do mês."
        }
      }
    },
    "condition": "§3.3 locale conflict reconciled."
  },
  {
    "method": "PATCH",
    "path": "/v1/appStoreVersionLocalizations/{localization_ja}",
    "purpose": "ja update exactly the two approved text fields",
    "body": {
      "data": {
        "type": "appStoreVersionLocalizations",
        "id": "{localization_ja}",
        "attributes": {
          "description": "GrammarLensは、英語のまちがいを練習に変えるアプリです。\n\n毎日、短い文法テストに答えます。終わるとスコアだけでなく、それぞれの答えがなぜ正しいのか、なぜまちがいなのかを、わかりやすい言葉で確認できます。\n\nあなたの言語に対応\nアプリのメニューとボタンは、英語、日本語、韓国語、スペイン語、ポルトガル語（ブラジル）、トルコ語、アラビア語、ドイツ語で表示できます。問題とフィードバックは英語のままなので、学んでいる言語で練習できます。\n\n主な機能\n\nデイリーテスト\n毎日新しい問題セット。空欄を埋め、まちがいを直し、すべての答えに解説がつきます。\n\n○×だけではない、本当の解説\n「不正解」だけでなく理由がわかります。どのルールが当てはまるのか、なぜその答えが合わないのか、次に何を覚えておけばよいのか。あなたの答えと修正後で変わった語は強調表示されます。\n\nトピックのヒント\n問題でつまずいたら、スライドしてそのトピックの文法パターンを確認できます。ルールを思い出すためのもので、答えは表示しません。\n\n弱点を記録\n何度もまちがえる文法項目をアプリが覚えて、復習にまとめます。次に取り組むべきことがいつもわかります。\n\nトピック練習\nArticles、Tense Selection、Modal Verbs、Modal Past Forms、Gerund vs. Infinitive、Conditionals、Passive Voice、Prepositions、Relative Clauses、Comparatives & Superlatives の10トピックから選び、3問・5問・10問のセッションで集中して練習できます。\n\n学びの山\nデイリーテストを1回受けるたびに、キャラクターが今月の山を一歩のぼります。月ごとにメダルを集めて、続けられる習慣をつくりましょう。\n\nホーム画面ウィジェット\n「Climb」では、今日のデイリーテストと、今月の山でのあなたの位置を確認できます。「Tip」では、あなたの苦手から毎日ひとつ文法のヒントが届きます。ウィジェットに表示されるのは、アプリがデバイスに保存した内容だけです。\n\n毎日のリマインダー\n1日1回まで、選んだ時間にお知らせします。プロフィール → 通知 でオン・オフを切り替えられます。\n\n9体の学習仲間\n一緒にのぼるキャラクターを選べます。\n\n無料版とPremium\n無料版では、毎日デイリーテスト1回と練習セッション1回を利用できます。\nPremiumでは、10トピックすべてのトピック練習と、1日あたりより多くの練習セッションが使えます。\nPremiumは月額または年額のサブスクリプションです。どちらも新規購読者には無料体験があります。料金は購読前にアプリ内で表示されます。\n\nプライバシー\nアカウントも登録も不要です。名前、進み具合、練習の履歴は端末に保存されます。アプリは匿名の利用データを送信しますが、名前は決して送りません。\nフィードバックのために、入力した答えはAIプロバイダーのAnthropicに送信されます。初めて送信する前にアプリが許可を求め、許可はいつでも「データ」画面から取り消せます。\n\n使用許諾契約（EULA）: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/\nプライバシーポリシー: https://ahmettayfur.com/products/grammarlens/privacy/\n利用規約: https://ahmettayfur.com/products/grammarlens/terms/",
          "whatsNew": "新しいデザイン、ウィジェット、5つの新トピック。\n• 新デザイン：すべての画面を描き直しました。学習仲間があなたの解答に反応します。\n• ホーム画面ウィジェット：「Climb」で今日のデイリーテストと今月の山でのあなたの位置を、「Tip」であなたの苦手から届く毎日の文法のヒントを確認できます。\n• 毎日のリマインダー：1日1回まで、選んだ時間にお知らせします。プロフィール → 通知 で変更できます。\n• トピック練習が10トピックになりました。Conditionals、Passive Voice、Prepositions、Relative Clauses、Comparatives & Superlatives が加わりました。\n• その日の練習を終えると、学習仲間は明日までキャンプで休みます。\n• プロフィールで、今月の次のメダルまであとどれくらいかを確認できます。"
        }
      }
    },
    "condition": "Draft locale exists."
  },
  {
    "method": "POST",
    "path": "/v1/appStoreVersionLocalizations",
    "purpose": "ja create a missing localization",
    "body": {
      "data": {
        "type": "appStoreVersionLocalizations",
        "attributes": {
          "locale": "ja",
          "description": "GrammarLensは、英語のまちがいを練習に変えるアプリです。\n\n毎日、短い文法テストに答えます。終わるとスコアだけでなく、それぞれの答えがなぜ正しいのか、なぜまちがいなのかを、わかりやすい言葉で確認できます。\n\nあなたの言語に対応\nアプリのメニューとボタンは、英語、日本語、韓国語、スペイン語、ポルトガル語（ブラジル）、トルコ語、アラビア語、ドイツ語で表示できます。問題とフィードバックは英語のままなので、学んでいる言語で練習できます。\n\n主な機能\n\nデイリーテスト\n毎日新しい問題セット。空欄を埋め、まちがいを直し、すべての答えに解説がつきます。\n\n○×だけではない、本当の解説\n「不正解」だけでなく理由がわかります。どのルールが当てはまるのか、なぜその答えが合わないのか、次に何を覚えておけばよいのか。あなたの答えと修正後で変わった語は強調表示されます。\n\nトピックのヒント\n問題でつまずいたら、スライドしてそのトピックの文法パターンを確認できます。ルールを思い出すためのもので、答えは表示しません。\n\n弱点を記録\n何度もまちがえる文法項目をアプリが覚えて、復習にまとめます。次に取り組むべきことがいつもわかります。\n\nトピック練習\nArticles、Tense Selection、Modal Verbs、Modal Past Forms、Gerund vs. Infinitive、Conditionals、Passive Voice、Prepositions、Relative Clauses、Comparatives & Superlatives の10トピックから選び、3問・5問・10問のセッションで集中して練習できます。\n\n学びの山\nデイリーテストを1回受けるたびに、キャラクターが今月の山を一歩のぼります。月ごとにメダルを集めて、続けられる習慣をつくりましょう。\n\nホーム画面ウィジェット\n「Climb」では、今日のデイリーテストと、今月の山でのあなたの位置を確認できます。「Tip」では、あなたの苦手から毎日ひとつ文法のヒントが届きます。ウィジェットに表示されるのは、アプリがデバイスに保存した内容だけです。\n\n毎日のリマインダー\n1日1回まで、選んだ時間にお知らせします。プロフィール → 通知 でオン・オフを切り替えられます。\n\n9体の学習仲間\n一緒にのぼるキャラクターを選べます。\n\n無料版とPremium\n無料版では、毎日デイリーテスト1回と練習セッション1回を利用できます。\nPremiumでは、10トピックすべてのトピック練習と、1日あたりより多くの練習セッションが使えます。\nPremiumは月額または年額のサブスクリプションです。どちらも新規購読者には無料体験があります。料金は購読前にアプリ内で表示されます。\n\nプライバシー\nアカウントも登録も不要です。名前、進み具合、練習の履歴は端末に保存されます。アプリは匿名の利用データを送信しますが、名前は決して送りません。\nフィードバックのために、入力した答えはAIプロバイダーのAnthropicに送信されます。初めて送信する前にアプリが許可を求め、許可はいつでも「データ」画面から取り消せます。\n\n使用許諾契約（EULA）: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/\nプライバシーポリシー: https://ahmettayfur.com/products/grammarlens/privacy/\n利用規約: https://ahmettayfur.com/products/grammarlens/terms/",
          "keywords": "英語,文法,英文法,学習,テスト,練習,時制,冠詞,動詞,助動詞,試験,毎日,間違い,英作文",
          "whatsNew": "新しいデザイン、ウィジェット、5つの新トピック。\n• 新デザイン：すべての画面を描き直しました。学習仲間があなたの解答に反応します。\n• ホーム画面ウィジェット：「Climb」で今日のデイリーテストと今月の山でのあなたの位置を、「Tip」であなたの苦手から届く毎日の文法のヒントを確認できます。\n• 毎日のリマインダー：1日1回まで、選んだ時間にお知らせします。プロフィール → 通知 で変更できます。\n• トピック練習が10トピックになりました。Conditionals、Passive Voice、Prepositions、Relative Clauses、Comparatives & Superlatives が加わりました。\n• その日の練習を終えると、学習仲間は明日までキャンプで休みます。\n• プロフィールで、今月の次のメダルまであとどれくらいかを確認できます。",
          "promotionalText": "",
          "supportUrl": "https://ahmettayfur.com/products/grammarlens/support/"
        },
        "relationships": {
          "appStoreVersion": {
            "data": {
              "type": "appStoreVersions",
              "id": "{version_1.5.0}"
            }
          }
        }
      }
    },
    "condition": "Draft locale is missing.",
    "saveIdAs": "{localization_ja}"
  },
  {
    "method": "GET",
    "path": "/v1/appStoreVersions/{version_1.5.0}/appStoreVersionLocalizations?filter%5Blocale%5D=ja&limit=200",
    "purpose": "ja reconcile an existing localization on a creation conflict",
    "condition": "Only the HTTP 409 existing-localization case explicitly permitted by §3.3."
  },
  {
    "method": "PATCH",
    "path": "/v1/appStoreVersionLocalizations/{localization_ja}",
    "purpose": "ja update the two approved fields after the specified conflict reconciliation",
    "body": {
      "data": {
        "type": "appStoreVersionLocalizations",
        "id": "{localization_ja}",
        "attributes": {
          "description": "GrammarLensは、英語のまちがいを練習に変えるアプリです。\n\n毎日、短い文法テストに答えます。終わるとスコアだけでなく、それぞれの答えがなぜ正しいのか、なぜまちがいなのかを、わかりやすい言葉で確認できます。\n\nあなたの言語に対応\nアプリのメニューとボタンは、英語、日本語、韓国語、スペイン語、ポルトガル語（ブラジル）、トルコ語、アラビア語、ドイツ語で表示できます。問題とフィードバックは英語のままなので、学んでいる言語で練習できます。\n\n主な機能\n\nデイリーテスト\n毎日新しい問題セット。空欄を埋め、まちがいを直し、すべての答えに解説がつきます。\n\n○×だけではない、本当の解説\n「不正解」だけでなく理由がわかります。どのルールが当てはまるのか、なぜその答えが合わないのか、次に何を覚えておけばよいのか。あなたの答えと修正後で変わった語は強調表示されます。\n\nトピックのヒント\n問題でつまずいたら、スライドしてそのトピックの文法パターンを確認できます。ルールを思い出すためのもので、答えは表示しません。\n\n弱点を記録\n何度もまちがえる文法項目をアプリが覚えて、復習にまとめます。次に取り組むべきことがいつもわかります。\n\nトピック練習\nArticles、Tense Selection、Modal Verbs、Modal Past Forms、Gerund vs. Infinitive、Conditionals、Passive Voice、Prepositions、Relative Clauses、Comparatives & Superlatives の10トピックから選び、3問・5問・10問のセッションで集中して練習できます。\n\n学びの山\nデイリーテストを1回受けるたびに、キャラクターが今月の山を一歩のぼります。月ごとにメダルを集めて、続けられる習慣をつくりましょう。\n\nホーム画面ウィジェット\n「Climb」では、今日のデイリーテストと、今月の山でのあなたの位置を確認できます。「Tip」では、あなたの苦手から毎日ひとつ文法のヒントが届きます。ウィジェットに表示されるのは、アプリがデバイスに保存した内容だけです。\n\n毎日のリマインダー\n1日1回まで、選んだ時間にお知らせします。プロフィール → 通知 でオン・オフを切り替えられます。\n\n9体の学習仲間\n一緒にのぼるキャラクターを選べます。\n\n無料版とPremium\n無料版では、毎日デイリーテスト1回と練習セッション1回を利用できます。\nPremiumでは、10トピックすべてのトピック練習と、1日あたりより多くの練習セッションが使えます。\nPremiumは月額または年額のサブスクリプションです。どちらも新規購読者には無料体験があります。料金は購読前にアプリ内で表示されます。\n\nプライバシー\nアカウントも登録も不要です。名前、進み具合、練習の履歴は端末に保存されます。アプリは匿名の利用データを送信しますが、名前は決して送りません。\nフィードバックのために、入力した答えはAIプロバイダーのAnthropicに送信されます。初めて送信する前にアプリが許可を求め、許可はいつでも「データ」画面から取り消せます。\n\n使用許諾契約（EULA）: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/\nプライバシーポリシー: https://ahmettayfur.com/products/grammarlens/privacy/\n利用規約: https://ahmettayfur.com/products/grammarlens/terms/",
          "whatsNew": "新しいデザイン、ウィジェット、5つの新トピック。\n• 新デザイン：すべての画面を描き直しました。学習仲間があなたの解答に反応します。\n• ホーム画面ウィジェット：「Climb」で今日のデイリーテストと今月の山でのあなたの位置を、「Tip」であなたの苦手から届く毎日の文法のヒントを確認できます。\n• 毎日のリマインダー：1日1回まで、選んだ時間にお知らせします。プロフィール → 通知 で変更できます。\n• トピック練習が10トピックになりました。Conditionals、Passive Voice、Prepositions、Relative Clauses、Comparatives & Superlatives が加わりました。\n• その日の練習を終えると、学習仲間は明日までキャンプで休みます。\n• プロフィールで、今月の次のメダルまであとどれくらいかを確認できます。"
        }
      }
    },
    "condition": "§3.3 locale conflict reconciled."
  },
  {
    "method": "PATCH",
    "path": "/v1/appStoreVersionLocalizations/{localization_ko}",
    "purpose": "ko update exactly the two approved text fields",
    "body": {
      "data": {
        "type": "appStoreVersionLocalizations",
        "id": "{localization_ko}",
        "attributes": {
          "description": "GrammarLens는 영어 실수를 연습으로 바꿔 줘요.\n\n매일 짧은 문법 테스트를 풀어요. 끝나면 점수만 보는 게 아니라, 각 답이 왜 맞았는지 또는 틀렸는지 쉬운 말로 확인할 수 있어요.\n\n내 언어로\n앱의 메뉴와 버튼을 영어, 일본어, 한국어, 스페인어, 포르투갈어(브라질), 튀르키예어, 아랍어, 독일어로 볼 수 있어요. 문제와 피드백은 영어로 유지되어, 배우고 있는 언어로 연습할 수 있어요.\n\n주요 기능\n\n데일리 테스트\n매일 새로운 문제 세트가 나와요. 빈칸을 채우고, 틀린 부분을 고치고, 모든 답에 대한 해설을 받아요.\n\n정답 표시만이 아닌 진짜 해설\n'오답' 대신 이유를 알려 줘요. 어떤 규칙이 적용되는지, 내 답이 왜 맞지 않는지, 다음에 무엇을 기억하면 좋을지요. 내 답변과 고친 답 사이에서 바뀐 단어는 강조돼요.\n\n주제 힌트\n문제가 막히면 밀어서 그 주제의 문법 패턴을 확인하세요. 규칙을 떠올리게 해 줄 뿐, 정답은 알려 주지 않아요.\n\n약점 기록\n자주 틀리는 문법 항목을 앱이 기억해서 복습에 모아 줘요. 무엇을 공부해야 할지 항상 알 수 있어요.\n\n주제별 연습\n10개 주제(Articles, Tense Selection, Modal Verbs, Modal Past Forms, Gerund vs. Infinitive, Conditionals, Passive Voice, Prepositions, Relative Clauses, Comparatives & Superlatives) 중에서 골라 3문제, 5문제, 10문제 세션으로 집중 연습해요.\n\n배움의 산\n데일리 테스트를 풀 때마다 캐릭터가 이번 달 산을 한 걸음 올라가요. 매달 메달을 모으며 꾸준한 습관을 만들어 보세요.\n\n홈 화면 위젯\n'Climb'에서는 오늘의 데일리 테스트와 이번 달 산에서의 내 위치를 볼 수 있어요. 'Tip'은 내 약점에서 고른 문법 팁을 매일 하나씩 보여 줘요. 위젯에는 앱이 기기에 저장한 내용만 표시돼요.\n\n매일 알림\n하루 최대 한 번, 내가 고른 시간에 알려 드려요. 프로필 → 알림에서 켜고 끌 수 있어요.\n\n9명의 학습 친구\n함께 오를 캐릭터를 골라요.\n\n무료와 Premium\n무료로 매일 데일리 테스트 1회와 연습 세션 1회를 이용할 수 있어요.\nPremium은 10개 주제 모두의 주제별 연습과 하루 더 많은 연습 세션을 열어 줘요.\nPremium은 월간 또는 연간 구독으로 이용할 수 있어요. 둘 다 신규 구독자에게 무료 체험이 있어요. 가격은 구독하기 전에 앱에서 보여 드려요.\n\n개인정보\n계정도 가입도 필요 없어요. 이름, 진행 상황, 연습 기록은 기기에 저장돼요. 앱은 익명 사용 데이터를 보내고, 이름은 절대 보내지 않아요.\n피드백을 드리기 위해 입력한 답은 AI 제공업체인 Anthropic으로 전송돼요. 처음 전송하기 전에 앱이 허락을 구하며, '데이터' 화면에서 언제든지 철회할 수 있어요.\n\n최종 사용자 사용권 계약(EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/\n개인정보 처리방침: https://ahmettayfur.com/products/grammarlens/privacy/\n이용약관: https://ahmettayfur.com/products/grammarlens/terms/",
          "whatsNew": "새로운 디자인, 위젯, 그리고 새 주제 5개.\n• 새 디자인: 모든 화면을 새로 그렸고, 학습 친구가 내 답에 반응해요.\n• 홈 화면 위젯: 'Climb'은 오늘의 데일리 테스트와 이번 달 산에서의 내 위치를, 'Tip'은 내 약점에서 고른 매일의 문법 팁을 보여 줘요.\n• 매일 알림: 하루 최대 한 번, 내가 고른 시간에 알려 드려요. 프로필 → 알림에서 바꿀 수 있어요.\n• 주제별 연습이 10개 주제로 늘었어요. Conditionals, Passive Voice, Prepositions, Relative Clauses, Comparatives & Superlatives가 추가됐어요.\n• 그날의 연습을 마치면 학습 친구는 내일까지 캠프에서 쉬어요.\n• 프로필에서 이번 달 다음 메달까지 얼마나 남았는지 볼 수 있어요."
        }
      }
    },
    "condition": "Draft locale exists."
  },
  {
    "method": "POST",
    "path": "/v1/appStoreVersionLocalizations",
    "purpose": "ko create a missing localization",
    "body": {
      "data": {
        "type": "appStoreVersionLocalizations",
        "attributes": {
          "locale": "ko",
          "description": "GrammarLens는 영어 실수를 연습으로 바꿔 줘요.\n\n매일 짧은 문법 테스트를 풀어요. 끝나면 점수만 보는 게 아니라, 각 답이 왜 맞았는지 또는 틀렸는지 쉬운 말로 확인할 수 있어요.\n\n내 언어로\n앱의 메뉴와 버튼을 영어, 일본어, 한국어, 스페인어, 포르투갈어(브라질), 튀르키예어, 아랍어, 독일어로 볼 수 있어요. 문제와 피드백은 영어로 유지되어, 배우고 있는 언어로 연습할 수 있어요.\n\n주요 기능\n\n데일리 테스트\n매일 새로운 문제 세트가 나와요. 빈칸을 채우고, 틀린 부분을 고치고, 모든 답에 대한 해설을 받아요.\n\n정답 표시만이 아닌 진짜 해설\n'오답' 대신 이유를 알려 줘요. 어떤 규칙이 적용되는지, 내 답이 왜 맞지 않는지, 다음에 무엇을 기억하면 좋을지요. 내 답변과 고친 답 사이에서 바뀐 단어는 강조돼요.\n\n주제 힌트\n문제가 막히면 밀어서 그 주제의 문법 패턴을 확인하세요. 규칙을 떠올리게 해 줄 뿐, 정답은 알려 주지 않아요.\n\n약점 기록\n자주 틀리는 문법 항목을 앱이 기억해서 복습에 모아 줘요. 무엇을 공부해야 할지 항상 알 수 있어요.\n\n주제별 연습\n10개 주제(Articles, Tense Selection, Modal Verbs, Modal Past Forms, Gerund vs. Infinitive, Conditionals, Passive Voice, Prepositions, Relative Clauses, Comparatives & Superlatives) 중에서 골라 3문제, 5문제, 10문제 세션으로 집중 연습해요.\n\n배움의 산\n데일리 테스트를 풀 때마다 캐릭터가 이번 달 산을 한 걸음 올라가요. 매달 메달을 모으며 꾸준한 습관을 만들어 보세요.\n\n홈 화면 위젯\n'Climb'에서는 오늘의 데일리 테스트와 이번 달 산에서의 내 위치를 볼 수 있어요. 'Tip'은 내 약점에서 고른 문법 팁을 매일 하나씩 보여 줘요. 위젯에는 앱이 기기에 저장한 내용만 표시돼요.\n\n매일 알림\n하루 최대 한 번, 내가 고른 시간에 알려 드려요. 프로필 → 알림에서 켜고 끌 수 있어요.\n\n9명의 학습 친구\n함께 오를 캐릭터를 골라요.\n\n무료와 Premium\n무료로 매일 데일리 테스트 1회와 연습 세션 1회를 이용할 수 있어요.\nPremium은 10개 주제 모두의 주제별 연습과 하루 더 많은 연습 세션을 열어 줘요.\nPremium은 월간 또는 연간 구독으로 이용할 수 있어요. 둘 다 신규 구독자에게 무료 체험이 있어요. 가격은 구독하기 전에 앱에서 보여 드려요.\n\n개인정보\n계정도 가입도 필요 없어요. 이름, 진행 상황, 연습 기록은 기기에 저장돼요. 앱은 익명 사용 데이터를 보내고, 이름은 절대 보내지 않아요.\n피드백을 드리기 위해 입력한 답은 AI 제공업체인 Anthropic으로 전송돼요. 처음 전송하기 전에 앱이 허락을 구하며, '데이터' 화면에서 언제든지 철회할 수 있어요.\n\n최종 사용자 사용권 계약(EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/\n개인정보 처리방침: https://ahmettayfur.com/products/grammarlens/privacy/\n이용약관: https://ahmettayfur.com/products/grammarlens/terms/",
          "keywords": "영어,문법,영문법,공부,테스트,연습,시제,관사,동사,조동사,시험,매일,오답,영작",
          "whatsNew": "새로운 디자인, 위젯, 그리고 새 주제 5개.\n• 새 디자인: 모든 화면을 새로 그렸고, 학습 친구가 내 답에 반응해요.\n• 홈 화면 위젯: 'Climb'은 오늘의 데일리 테스트와 이번 달 산에서의 내 위치를, 'Tip'은 내 약점에서 고른 매일의 문법 팁을 보여 줘요.\n• 매일 알림: 하루 최대 한 번, 내가 고른 시간에 알려 드려요. 프로필 → 알림에서 바꿀 수 있어요.\n• 주제별 연습이 10개 주제로 늘었어요. Conditionals, Passive Voice, Prepositions, Relative Clauses, Comparatives & Superlatives가 추가됐어요.\n• 그날의 연습을 마치면 학습 친구는 내일까지 캠프에서 쉬어요.\n• 프로필에서 이번 달 다음 메달까지 얼마나 남았는지 볼 수 있어요.",
          "promotionalText": "",
          "supportUrl": "https://ahmettayfur.com/products/grammarlens/support/"
        },
        "relationships": {
          "appStoreVersion": {
            "data": {
              "type": "appStoreVersions",
              "id": "{version_1.5.0}"
            }
          }
        }
      }
    },
    "condition": "Draft locale is missing.",
    "saveIdAs": "{localization_ko}"
  },
  {
    "method": "GET",
    "path": "/v1/appStoreVersions/{version_1.5.0}/appStoreVersionLocalizations?filter%5Blocale%5D=ko&limit=200",
    "purpose": "ko reconcile an existing localization on a creation conflict",
    "condition": "Only the HTTP 409 existing-localization case explicitly permitted by §3.3."
  },
  {
    "method": "PATCH",
    "path": "/v1/appStoreVersionLocalizations/{localization_ko}",
    "purpose": "ko update the two approved fields after the specified conflict reconciliation",
    "body": {
      "data": {
        "type": "appStoreVersionLocalizations",
        "id": "{localization_ko}",
        "attributes": {
          "description": "GrammarLens는 영어 실수를 연습으로 바꿔 줘요.\n\n매일 짧은 문법 테스트를 풀어요. 끝나면 점수만 보는 게 아니라, 각 답이 왜 맞았는지 또는 틀렸는지 쉬운 말로 확인할 수 있어요.\n\n내 언어로\n앱의 메뉴와 버튼을 영어, 일본어, 한국어, 스페인어, 포르투갈어(브라질), 튀르키예어, 아랍어, 독일어로 볼 수 있어요. 문제와 피드백은 영어로 유지되어, 배우고 있는 언어로 연습할 수 있어요.\n\n주요 기능\n\n데일리 테스트\n매일 새로운 문제 세트가 나와요. 빈칸을 채우고, 틀린 부분을 고치고, 모든 답에 대한 해설을 받아요.\n\n정답 표시만이 아닌 진짜 해설\n'오답' 대신 이유를 알려 줘요. 어떤 규칙이 적용되는지, 내 답이 왜 맞지 않는지, 다음에 무엇을 기억하면 좋을지요. 내 답변과 고친 답 사이에서 바뀐 단어는 강조돼요.\n\n주제 힌트\n문제가 막히면 밀어서 그 주제의 문법 패턴을 확인하세요. 규칙을 떠올리게 해 줄 뿐, 정답은 알려 주지 않아요.\n\n약점 기록\n자주 틀리는 문법 항목을 앱이 기억해서 복습에 모아 줘요. 무엇을 공부해야 할지 항상 알 수 있어요.\n\n주제별 연습\n10개 주제(Articles, Tense Selection, Modal Verbs, Modal Past Forms, Gerund vs. Infinitive, Conditionals, Passive Voice, Prepositions, Relative Clauses, Comparatives & Superlatives) 중에서 골라 3문제, 5문제, 10문제 세션으로 집중 연습해요.\n\n배움의 산\n데일리 테스트를 풀 때마다 캐릭터가 이번 달 산을 한 걸음 올라가요. 매달 메달을 모으며 꾸준한 습관을 만들어 보세요.\n\n홈 화면 위젯\n'Climb'에서는 오늘의 데일리 테스트와 이번 달 산에서의 내 위치를 볼 수 있어요. 'Tip'은 내 약점에서 고른 문법 팁을 매일 하나씩 보여 줘요. 위젯에는 앱이 기기에 저장한 내용만 표시돼요.\n\n매일 알림\n하루 최대 한 번, 내가 고른 시간에 알려 드려요. 프로필 → 알림에서 켜고 끌 수 있어요.\n\n9명의 학습 친구\n함께 오를 캐릭터를 골라요.\n\n무료와 Premium\n무료로 매일 데일리 테스트 1회와 연습 세션 1회를 이용할 수 있어요.\nPremium은 10개 주제 모두의 주제별 연습과 하루 더 많은 연습 세션을 열어 줘요.\nPremium은 월간 또는 연간 구독으로 이용할 수 있어요. 둘 다 신규 구독자에게 무료 체험이 있어요. 가격은 구독하기 전에 앱에서 보여 드려요.\n\n개인정보\n계정도 가입도 필요 없어요. 이름, 진행 상황, 연습 기록은 기기에 저장돼요. 앱은 익명 사용 데이터를 보내고, 이름은 절대 보내지 않아요.\n피드백을 드리기 위해 입력한 답은 AI 제공업체인 Anthropic으로 전송돼요. 처음 전송하기 전에 앱이 허락을 구하며, '데이터' 화면에서 언제든지 철회할 수 있어요.\n\n최종 사용자 사용권 계약(EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/\n개인정보 처리방침: https://ahmettayfur.com/products/grammarlens/privacy/\n이용약관: https://ahmettayfur.com/products/grammarlens/terms/",
          "whatsNew": "새로운 디자인, 위젯, 그리고 새 주제 5개.\n• 새 디자인: 모든 화면을 새로 그렸고, 학습 친구가 내 답에 반응해요.\n• 홈 화면 위젯: 'Climb'은 오늘의 데일리 테스트와 이번 달 산에서의 내 위치를, 'Tip'은 내 약점에서 고른 매일의 문법 팁을 보여 줘요.\n• 매일 알림: 하루 최대 한 번, 내가 고른 시간에 알려 드려요. 프로필 → 알림에서 바꿀 수 있어요.\n• 주제별 연습이 10개 주제로 늘었어요. Conditionals, Passive Voice, Prepositions, Relative Clauses, Comparatives & Superlatives가 추가됐어요.\n• 그날의 연습을 마치면 학습 친구는 내일까지 캠프에서 쉬어요.\n• 프로필에서 이번 달 다음 메달까지 얼마나 남았는지 볼 수 있어요."
        }
      }
    },
    "condition": "§3.3 locale conflict reconciled."
  },
  {
    "method": "PATCH",
    "path": "/v1/appStoreVersionLocalizations/{localization_ar-SA}",
    "purpose": "ar-SA update exactly the two approved text fields",
    "body": {
      "data": {
        "type": "appStoreVersionLocalizations",
        "id": "{localization_ar-SA}",
        "attributes": {
          "description": "يحوّل GrammarLens أخطاءك في الإنجليزية إلى تدريب.\n\nكل يوم تحصل على اختبار قواعد قصير. وعندما تنتهي، لا ترى الدرجة فقط، بل ترى لماذا كانت كل إجابة صحيحة أو خاطئة، بلغة بسيطة.\n\nبلغتك\nقوائم التطبيق وأزراره متاحة بالإنجليزية واليابانية والكورية والإسبانية والبرتغالية (البرازيل) والتركية والعربية والألمانية. تبقى الأسئلة والملاحظات باللغة الإنجليزية، لتتدرّب على اللغة التي تتعلّمها.\n\nما الذي تحصل عليه\n\nالاختبار اليومي\nمجموعة جديدة من الأسئلة كل يوم. املأ الفراغات، وصحّح الأخطاء، واحصل على شرح لكل إجابة.\n\nشروح حقيقية، لا مجرد علامات\nبدلًا من «خطأ» تحصل على السبب: أي قاعدة تنطبق، ولماذا لا تناسب إجابتك، وما الذي تتذكره في المرة القادمة. وتُبرَز الكلمات التي تغيّرت بين إجابتك والتصحيح.\n\nتلميحات الموضوع\nهل توقفت عند سؤال؟ اسحب لترى النمط النحوي لموضوعه: تذكير بالقاعدة، وليس الإجابة أبدًا.\n\nنقاط ضعفك تحت المتابعة\nيتذكّر التطبيق القواعد التي تخطئ فيها مرارًا ويجمعها في المراجعة، فتعرف دائمًا ما الذي تعمل عليه.\n\nتدريب الموضوعات\nاختر من بين عشرة موضوعات (Articles وTense Selection وModal Verbs وModal Past Forms وGerund vs. Infinitive وConditionals وPassive Voice وPrepositions وRelative Clauses وComparatives & Superlatives) بجلسات من 3 أو 5 أو 10 أسئلة.\n\nجبل التعلّم\nكل اختبار يومي يرفع شخصيتك خطوة على جبل هذا الشهر. اربح ميداليات الشهر وابنِ عادة تدوم.\n\nأدوات الشاشة الرئيسية\nتعرض أداة «Climb» اختبار اليوم وخطوتك على جبل هذا الشهر. وتقدّم أداة «Tip» نصيحة نحوية كل يوم من نقاط ضعفك أنت. لا تعرض الأدوات إلا ما حفظه التطبيق على جهازك.\n\nتذكيرات يومية\nتذكير واحد في اليوم على الأكثر، في الوقت الذي تختاره. يمكنك تشغيلها أو إيقافها من الملف الشخصي ← الإشعارات.\n\nتسعة رفاق للدراسة\nاختر الشخصية التي تتسلّق معك.\n\nمجاني وPremium\nتتضمن النسخة المجانية اختبارًا يوميًا واحدًا وجلسة تدريب واحدة كل يوم.\nيفتح Premium تدريب الموضوعات في الموضوعات العشرة كلها وجلسات تدريب أكثر كل يوم.\nيتوفر Premium باشتراك شهري أو سنوي، ويتضمن كلاهما فترة تجربة مجانية للمشتركين الجدد. تُعرض الأسعار في التطبيق قبل الاشتراك.\n\nالخصوصية\nلا حساب ولا تسجيل. يبقى اسمك وتقدّمك وسجل تدريبك على جهازك. يرسل التطبيق بيانات استخدام مجهولة، ولا يرسل اسمك أبدًا.\nلتقديم الملاحظات، تُرسَل الإجابات التي تكتبها إلى مزوّد الذكاء الاصطناعي لدينا، Anthropic. يطلب التطبيق إذنك قبل أن يحدث ذلك أول مرة، ويمكنك سحب الإذن في أي وقت من شاشة البيانات.\n\nاتفاقية ترخيص المستخدم النهائي (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/\nسياسة الخصوصية: https://ahmettayfur.com/products/grammarlens/privacy/\nشروط الخدمة: https://ahmettayfur.com/products/grammarlens/terms/",
          "whatsNew": "تصميم جديد وأدوات للشاشة الرئيسية وخمسة موضوعات جديدة.\n• تصميم جديد: أُعيد رسم كل الشاشات، ويتفاعل رفيقك في الدراسة مع إجاباتك.\n• أدوات الشاشة الرئيسية: تعرض «Climb» اختبار اليوم وخطوتك على جبل هذا الشهر، وتقدّم «Tip» نصيحة نحوية يومية من نقاط ضعفك أنت.\n• تذكيرات يومية: تذكير واحد في اليوم على الأكثر، في الوقت الذي تختاره. يمكنك تغييره من الملف الشخصي ← الإشعارات.\n• أصبح تدريب الموضوعات يضم عشرة موضوعات: انضمت Conditionals وPassive Voice وPrepositions وRelative Clauses وComparatives & Superlatives إلى الموضوعات الخمسة الأصلية.\n• عندما تنتهي من تدريب اليوم، يستريح رفيقك في المخيّم حتى الغد.\n• يعرض الملف الشخصي مدى قربك من ميدالية هذا الشهر التالية."
        }
      }
    },
    "condition": "Draft locale exists."
  },
  {
    "method": "POST",
    "path": "/v1/appStoreVersionLocalizations",
    "purpose": "ar-SA create a missing localization",
    "body": {
      "data": {
        "type": "appStoreVersionLocalizations",
        "attributes": {
          "locale": "ar-SA",
          "description": "يحوّل GrammarLens أخطاءك في الإنجليزية إلى تدريب.\n\nكل يوم تحصل على اختبار قواعد قصير. وعندما تنتهي، لا ترى الدرجة فقط، بل ترى لماذا كانت كل إجابة صحيحة أو خاطئة، بلغة بسيطة.\n\nبلغتك\nقوائم التطبيق وأزراره متاحة بالإنجليزية واليابانية والكورية والإسبانية والبرتغالية (البرازيل) والتركية والعربية والألمانية. تبقى الأسئلة والملاحظات باللغة الإنجليزية، لتتدرّب على اللغة التي تتعلّمها.\n\nما الذي تحصل عليه\n\nالاختبار اليومي\nمجموعة جديدة من الأسئلة كل يوم. املأ الفراغات، وصحّح الأخطاء، واحصل على شرح لكل إجابة.\n\nشروح حقيقية، لا مجرد علامات\nبدلًا من «خطأ» تحصل على السبب: أي قاعدة تنطبق، ولماذا لا تناسب إجابتك، وما الذي تتذكره في المرة القادمة. وتُبرَز الكلمات التي تغيّرت بين إجابتك والتصحيح.\n\nتلميحات الموضوع\nهل توقفت عند سؤال؟ اسحب لترى النمط النحوي لموضوعه: تذكير بالقاعدة، وليس الإجابة أبدًا.\n\nنقاط ضعفك تحت المتابعة\nيتذكّر التطبيق القواعد التي تخطئ فيها مرارًا ويجمعها في المراجعة، فتعرف دائمًا ما الذي تعمل عليه.\n\nتدريب الموضوعات\nاختر من بين عشرة موضوعات (Articles وTense Selection وModal Verbs وModal Past Forms وGerund vs. Infinitive وConditionals وPassive Voice وPrepositions وRelative Clauses وComparatives & Superlatives) بجلسات من 3 أو 5 أو 10 أسئلة.\n\nجبل التعلّم\nكل اختبار يومي يرفع شخصيتك خطوة على جبل هذا الشهر. اربح ميداليات الشهر وابنِ عادة تدوم.\n\nأدوات الشاشة الرئيسية\nتعرض أداة «Climb» اختبار اليوم وخطوتك على جبل هذا الشهر. وتقدّم أداة «Tip» نصيحة نحوية كل يوم من نقاط ضعفك أنت. لا تعرض الأدوات إلا ما حفظه التطبيق على جهازك.\n\nتذكيرات يومية\nتذكير واحد في اليوم على الأكثر، في الوقت الذي تختاره. يمكنك تشغيلها أو إيقافها من الملف الشخصي ← الإشعارات.\n\nتسعة رفاق للدراسة\nاختر الشخصية التي تتسلّق معك.\n\nمجاني وPremium\nتتضمن النسخة المجانية اختبارًا يوميًا واحدًا وجلسة تدريب واحدة كل يوم.\nيفتح Premium تدريب الموضوعات في الموضوعات العشرة كلها وجلسات تدريب أكثر كل يوم.\nيتوفر Premium باشتراك شهري أو سنوي، ويتضمن كلاهما فترة تجربة مجانية للمشتركين الجدد. تُعرض الأسعار في التطبيق قبل الاشتراك.\n\nالخصوصية\nلا حساب ولا تسجيل. يبقى اسمك وتقدّمك وسجل تدريبك على جهازك. يرسل التطبيق بيانات استخدام مجهولة، ولا يرسل اسمك أبدًا.\nلتقديم الملاحظات، تُرسَل الإجابات التي تكتبها إلى مزوّد الذكاء الاصطناعي لدينا، Anthropic. يطلب التطبيق إذنك قبل أن يحدث ذلك أول مرة، ويمكنك سحب الإذن في أي وقت من شاشة البيانات.\n\nاتفاقية ترخيص المستخدم النهائي (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/\nسياسة الخصوصية: https://ahmettayfur.com/products/grammarlens/privacy/\nشروط الخدمة: https://ahmettayfur.com/products/grammarlens/terms/",
          "keywords": "إنجليزي,قواعد,الإنجليزية,تعلم,اختبار,تدريب,الأزمنة,أفعال,امتحان,يومي,أخطاء,كتابة",
          "whatsNew": "تصميم جديد وأدوات للشاشة الرئيسية وخمسة موضوعات جديدة.\n• تصميم جديد: أُعيد رسم كل الشاشات، ويتفاعل رفيقك في الدراسة مع إجاباتك.\n• أدوات الشاشة الرئيسية: تعرض «Climb» اختبار اليوم وخطوتك على جبل هذا الشهر، وتقدّم «Tip» نصيحة نحوية يومية من نقاط ضعفك أنت.\n• تذكيرات يومية: تذكير واحد في اليوم على الأكثر، في الوقت الذي تختاره. يمكنك تغييره من الملف الشخصي ← الإشعارات.\n• أصبح تدريب الموضوعات يضم عشرة موضوعات: انضمت Conditionals وPassive Voice وPrepositions وRelative Clauses وComparatives & Superlatives إلى الموضوعات الخمسة الأصلية.\n• عندما تنتهي من تدريب اليوم، يستريح رفيقك في المخيّم حتى الغد.\n• يعرض الملف الشخصي مدى قربك من ميدالية هذا الشهر التالية.",
          "promotionalText": "",
          "supportUrl": "https://ahmettayfur.com/products/grammarlens/support/"
        },
        "relationships": {
          "appStoreVersion": {
            "data": {
              "type": "appStoreVersions",
              "id": "{version_1.5.0}"
            }
          }
        }
      }
    },
    "condition": "Draft locale is missing.",
    "saveIdAs": "{localization_ar-SA}"
  },
  {
    "method": "GET",
    "path": "/v1/appStoreVersions/{version_1.5.0}/appStoreVersionLocalizations?filter%5Blocale%5D=ar-SA&limit=200",
    "purpose": "ar-SA reconcile an existing localization on a creation conflict",
    "condition": "Only the HTTP 409 existing-localization case explicitly permitted by §3.3."
  },
  {
    "method": "PATCH",
    "path": "/v1/appStoreVersionLocalizations/{localization_ar-SA}",
    "purpose": "ar-SA update the two approved fields after the specified conflict reconciliation",
    "body": {
      "data": {
        "type": "appStoreVersionLocalizations",
        "id": "{localization_ar-SA}",
        "attributes": {
          "description": "يحوّل GrammarLens أخطاءك في الإنجليزية إلى تدريب.\n\nكل يوم تحصل على اختبار قواعد قصير. وعندما تنتهي، لا ترى الدرجة فقط، بل ترى لماذا كانت كل إجابة صحيحة أو خاطئة، بلغة بسيطة.\n\nبلغتك\nقوائم التطبيق وأزراره متاحة بالإنجليزية واليابانية والكورية والإسبانية والبرتغالية (البرازيل) والتركية والعربية والألمانية. تبقى الأسئلة والملاحظات باللغة الإنجليزية، لتتدرّب على اللغة التي تتعلّمها.\n\nما الذي تحصل عليه\n\nالاختبار اليومي\nمجموعة جديدة من الأسئلة كل يوم. املأ الفراغات، وصحّح الأخطاء، واحصل على شرح لكل إجابة.\n\nشروح حقيقية، لا مجرد علامات\nبدلًا من «خطأ» تحصل على السبب: أي قاعدة تنطبق، ولماذا لا تناسب إجابتك، وما الذي تتذكره في المرة القادمة. وتُبرَز الكلمات التي تغيّرت بين إجابتك والتصحيح.\n\nتلميحات الموضوع\nهل توقفت عند سؤال؟ اسحب لترى النمط النحوي لموضوعه: تذكير بالقاعدة، وليس الإجابة أبدًا.\n\nنقاط ضعفك تحت المتابعة\nيتذكّر التطبيق القواعد التي تخطئ فيها مرارًا ويجمعها في المراجعة، فتعرف دائمًا ما الذي تعمل عليه.\n\nتدريب الموضوعات\nاختر من بين عشرة موضوعات (Articles وTense Selection وModal Verbs وModal Past Forms وGerund vs. Infinitive وConditionals وPassive Voice وPrepositions وRelative Clauses وComparatives & Superlatives) بجلسات من 3 أو 5 أو 10 أسئلة.\n\nجبل التعلّم\nكل اختبار يومي يرفع شخصيتك خطوة على جبل هذا الشهر. اربح ميداليات الشهر وابنِ عادة تدوم.\n\nأدوات الشاشة الرئيسية\nتعرض أداة «Climb» اختبار اليوم وخطوتك على جبل هذا الشهر. وتقدّم أداة «Tip» نصيحة نحوية كل يوم من نقاط ضعفك أنت. لا تعرض الأدوات إلا ما حفظه التطبيق على جهازك.\n\nتذكيرات يومية\nتذكير واحد في اليوم على الأكثر، في الوقت الذي تختاره. يمكنك تشغيلها أو إيقافها من الملف الشخصي ← الإشعارات.\n\nتسعة رفاق للدراسة\nاختر الشخصية التي تتسلّق معك.\n\nمجاني وPremium\nتتضمن النسخة المجانية اختبارًا يوميًا واحدًا وجلسة تدريب واحدة كل يوم.\nيفتح Premium تدريب الموضوعات في الموضوعات العشرة كلها وجلسات تدريب أكثر كل يوم.\nيتوفر Premium باشتراك شهري أو سنوي، ويتضمن كلاهما فترة تجربة مجانية للمشتركين الجدد. تُعرض الأسعار في التطبيق قبل الاشتراك.\n\nالخصوصية\nلا حساب ولا تسجيل. يبقى اسمك وتقدّمك وسجل تدريبك على جهازك. يرسل التطبيق بيانات استخدام مجهولة، ولا يرسل اسمك أبدًا.\nلتقديم الملاحظات، تُرسَل الإجابات التي تكتبها إلى مزوّد الذكاء الاصطناعي لدينا، Anthropic. يطلب التطبيق إذنك قبل أن يحدث ذلك أول مرة، ويمكنك سحب الإذن في أي وقت من شاشة البيانات.\n\nاتفاقية ترخيص المستخدم النهائي (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/\nسياسة الخصوصية: https://ahmettayfur.com/products/grammarlens/privacy/\nشروط الخدمة: https://ahmettayfur.com/products/grammarlens/terms/",
          "whatsNew": "تصميم جديد وأدوات للشاشة الرئيسية وخمسة موضوعات جديدة.\n• تصميم جديد: أُعيد رسم كل الشاشات، ويتفاعل رفيقك في الدراسة مع إجاباتك.\n• أدوات الشاشة الرئيسية: تعرض «Climb» اختبار اليوم وخطوتك على جبل هذا الشهر، وتقدّم «Tip» نصيحة نحوية يومية من نقاط ضعفك أنت.\n• تذكيرات يومية: تذكير واحد في اليوم على الأكثر، في الوقت الذي تختاره. يمكنك تغييره من الملف الشخصي ← الإشعارات.\n• أصبح تدريب الموضوعات يضم عشرة موضوعات: انضمت Conditionals وPassive Voice وPrepositions وRelative Clauses وComparatives & Superlatives إلى الموضوعات الخمسة الأصلية.\n• عندما تنتهي من تدريب اليوم، يستريح رفيقك في المخيّم حتى الغد.\n• يعرض الملف الشخصي مدى قربك من ميدالية هذا الشهر التالية."
        }
      }
    },
    "condition": "§3.3 locale conflict reconciled."
  },
  {
    "method": "GET",
    "path": "/v1/appStoreVersions/{version_1.5.0}/appStoreReviewDetail",
    "purpose": "Resolve the review details ID and read contact, demo account setting and notes as the draft baseline.",
    "saveIdAs": "{review_detail_1.5.0}"
  },
  {
    "method": "GET",
    "path": "/v1/appStoreReviewDetails/{review_detail_1.5.0}/appStoreReviewAttachments?limit=200",
    "purpose": "List attachments before the notes update."
  },
  {
    "method": "PATCH",
    "path": "/v1/appStoreReviewDetails/{review_detail_1.5.0}",
    "purpose": "Replace notes only",
    "body": {
      "data": {
        "type": "appStoreReviewDetails",
        "id": "{review_detail_1.5.0}",
        "attributes": {
          "notes": "GrammarLens is an English grammar practice app. No account, no sign-up, no login. Open the app and start.\n\nFIRST LAUNCH\nOnboarding: Welcome → pick a study buddy → first name → learning goal (skippable) → this month's mountain → a 5-question Daily Test bundled with the app (no network call) → results → Welcome badge → first climb → the subscription screen, shown once → Home.\n\nAI CONSENT SCREEN\nIn practice sessions the app sends the answers a user types, with their questions, to Anthropic (Claude) to generate feedback. Before the first time this happens, a full-screen consent screen explains what is sent and asks for permission. The consent covers every practice session: the free practice with the daily ticket and Premium Topic Practice.\n\nTo reach it: answer at least one Daily Test question wrongly (type any wrong word rather than skipping) so a weak spot is created, then Review tab > \"Practice with my ticket\" on the weak spot. The consent screen appears before the practice session starts. Consent can be withdrawn at any time from Profile > Data.\n\nThe Daily Test does not send any user-written text and does not require this consent.\n\nAI requests go only through our own server (api.ahmettayfur.com); the app contains no AI API key. The server does not store question or answer text. A random anonymous device ID is used only for daily limits; the server keeps it only inside a quota counter that expires after 48 hours. It is never sent to Anthropic.\n\nFREE LIMITS\nA free user gets one Daily Test and one practice session (the daily ticket) per day. When both are used, Home shows a rest scene until the next day. Topic Practice is a Premium feature. Premium allows up to 5 practice sessions a day. Limits reset at local midnight.\n\nSUBSCRIPTIONS\nTwo auto-renewable subscriptions in one group: monthly ($5.99, 3-day free trial) and annual ($49.99, 7-day free trial). Prices and trials are loaded live through RevenueCat, never hardcoded.\n\nTo reach the subscription screen: Home > Topic practice card > \"Unlock all 10 topics\" (or any topic there), or \"Wake <buddy> up\" on the rest scene after the day's free practice. It closes with its X; Restore Purchases is in its footer.\n\nPRIVACY\nNo account system. Name, buddy, practice history and progress stay on the device. Typed answers go to Anthropic only with consent. Firebase Analytics and Crashlytics collect anonymous usage and diagnostics; the learning goal chosen in onboarding is sent with these anonymous analytics, never with the user's name. RevenueCat handles subscription status. No IDFA, no tracking.\n\nThe release build has no hidden, debug or developer features, no remote configuration and no promo or redeem codes.\n\nSUBSCRIPTION DISPLAY\nThe total annual/monthly amount is the prominent price; any monthly equivalent is secondary. Trial length, post-trial charge, renewal terms, EULA and Privacy Policy links are shown on the subscription screen.\n\nVERSION 1.5.0 (BUILD 8)\n- A new design across the app. Eight interface languages, as in 1.4.0 (Profile > Appearance > Language).\n- Home Screen widgets: \"Climb\" (small and medium) shows today's Daily Test and the user's step on this month's mountain; \"Tip\" (medium) shows a grammar tip from the user's own weak spots. Widgets show only what the app saved on the device (App Group); no network request.\n- Daily reminders: local notifications only (no push server), at most one a day at a time the user picks. Asked first by the app's own screen, then by iOS; changed in Profile > Notifications.\n- Topic Practice now has ten topics (five new: Conditionals, Passive Voice, Prepositions, Relative Clauses, Comparatives & Superlatives). Same practice request and consent as before. The Daily Test keeps its original five topics.\n- No new SDK, service or kind of data.\n\nPrivacy policy: https://ahmettayfur.com/products/grammarlens/privacy/\nTerms: https://ahmettayfur.com/products/grammarlens/terms/\nSupport: https://ahmettayfur.com/products/grammarlens/support/\n"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appStoreVersionLocalizations/{localization_en-US}/appScreenshotSets?limit=200",
    "purpose": "en-US read copied screenshot sets."
  },
  {
    "method": "GET",
    "path": "/v1/appStoreVersionLocalizations/{localization_en-US}/placements?limit=200",
    "purpose": "en-US read copied draft placements."
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshotSets/{set_en-US_iphone-6.9}/appScreenshots?limit=200",
    "purpose": "en-US compare the copied filenames and MD5 values with the live baseline for iPhone 6.9-inch.",
    "condition": "Draft set exists."
  },
  {
    "method": "GET",
    "path": "/v1/appAssetLibraryPlacements/{copied_screenshot_placement_id}?include=image,appStoreVersionLocalization",
    "purpose": "en-US verify the placement belongs to the resolved draft localization and references a copied legacy image.",
    "repeat": "Each copied iPhone 6.9-inch placement, expected 8."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_en-US_iphone-6.9_1}",
    "purpose": "en-US detach inherited iPhone 6.9-inch placement 1.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_en-US_iphone-6.9_2}",
    "purpose": "en-US detach inherited iPhone 6.9-inch placement 2.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_en-US_iphone-6.9_3}",
    "purpose": "en-US detach inherited iPhone 6.9-inch placement 3.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_en-US_iphone-6.9_4}",
    "purpose": "en-US detach inherited iPhone 6.9-inch placement 4.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_en-US_iphone-6.9_5}",
    "purpose": "en-US detach inherited iPhone 6.9-inch placement 5.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_en-US_iphone-6.9_6}",
    "purpose": "en-US detach inherited iPhone 6.9-inch placement 6.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_en-US_iphone-6.9_7}",
    "purpose": "en-US detach inherited iPhone 6.9-inch placement 7.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_en-US_iphone-6.9_8}",
    "purpose": "en-US detach inherited iPhone 6.9-inch placement 8.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "GET",
    "path": "/v1/appStoreVersionLocalizations/{localization_en-US}/appScreenshotSets?limit=200",
    "purpose": "en-US resolve the target iPhone 6.9-inch set after removal."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshotSets",
    "purpose": "en-US create the iPhone 6.9-inch set if absent",
    "body": {
      "data": {
        "type": "appScreenshotSets",
        "attributes": {
          "screenshotDisplayType": "APP_IPHONE_67"
        },
        "relationships": {
          "appStoreVersionLocalization": {
            "data": {
              "type": "appStoreVersionLocalizations",
              "id": "{localization_en-US}"
            }
          }
        }
      }
    },
    "condition": "Verified draft set is absent.",
    "saveIdAs": "{set_en-US_iphone-6.9}"
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "en-US reserve iPhone 6.9-inch screenshot 1",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "01-feedback.png",
          "fileSize": 3114076
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_en-US_iphone-6.9}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_en-US_iphone-6.9_1}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/en/iphone-6.9/01-feedback.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_en-US_iphone-6.9_1}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_en-US_iphone-6.9_1}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "2330355b99f49ff714942e9afcb88c3d"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_en-US_iphone-6.9_1}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "en-US reserve iPhone 6.9-inch screenshot 2",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "02-review-ticket.png",
          "fileSize": 2966010
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_en-US_iphone-6.9}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_en-US_iphone-6.9_2}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/en/iphone-6.9/02-review-ticket.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_en-US_iphone-6.9_2}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_en-US_iphone-6.9_2}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "f53731149b322cbc954e40b59a642b1c"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_en-US_iphone-6.9_2}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "en-US reserve iPhone 6.9-inch screenshot 3",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "03-hint.png",
          "fileSize": 3905336
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_en-US_iphone-6.9}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_en-US_iphone-6.9_3}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/en/iphone-6.9/03-hint.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_en-US_iphone-6.9_3}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_en-US_iphone-6.9_3}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "984b9bb9f206f62e942eb8d2df99829c"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_en-US_iphone-6.9_3}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "en-US reserve iPhone 6.9-inch screenshot 4",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "04-film.png",
          "fileSize": 2854787
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_en-US_iphone-6.9}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_en-US_iphone-6.9_4}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/en/iphone-6.9/04-film.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_en-US_iphone-6.9_4}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_en-US_iphone-6.9_4}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "a11e4d1cb3be41bf19f8fd40cb233be8"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_en-US_iphone-6.9_4}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "en-US reserve iPhone 6.9-inch screenshot 5",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "05-first-step.png",
          "fileSize": 3349915
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_en-US_iphone-6.9}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_en-US_iphone-6.9_5}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/en/iphone-6.9/05-first-step.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_en-US_iphone-6.9_5}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_en-US_iphone-6.9_5}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "fd9045f89dffd98c512d209323ac4d33"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_en-US_iphone-6.9_5}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "en-US reserve iPhone 6.9-inch screenshot 6",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "06-monthly-mountains.png",
          "fileSize": 4735657
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_en-US_iphone-6.9}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_en-US_iphone-6.9_6}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/en/iphone-6.9/06-monthly-mountains.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_en-US_iphone-6.9_6}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_en-US_iphone-6.9_6}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "99b63f6492645ba7d67c22fc37b3590e"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_en-US_iphone-6.9_6}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshotSets/{set_en-US_iphone-6.9}/relationships/appScreenshots",
    "purpose": "en-US set iPhone 6.9-inch order 01–06.",
    "body": {
      "data": [
        {
          "type": "appScreenshots",
          "id": "{screenshot_en-US_iphone-6.9_1}"
        },
        {
          "type": "appScreenshots",
          "id": "{screenshot_en-US_iphone-6.9_2}"
        },
        {
          "type": "appScreenshots",
          "id": "{screenshot_en-US_iphone-6.9_3}"
        },
        {
          "type": "appScreenshots",
          "id": "{screenshot_en-US_iphone-6.9_4}"
        },
        {
          "type": "appScreenshots",
          "id": "{screenshot_en-US_iphone-6.9_5}"
        },
        {
          "type": "appScreenshots",
          "id": "{screenshot_en-US_iphone-6.9_6}"
        }
      ]
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshotSets/{set_en-US_ipad-13}/appScreenshots?limit=200",
    "purpose": "en-US compare the copied filenames and MD5 values with the live baseline for iPad 13-inch.",
    "condition": "Draft set exists."
  },
  {
    "method": "GET",
    "path": "/v1/appAssetLibraryPlacements/{copied_screenshot_placement_id}?include=image,appStoreVersionLocalization",
    "purpose": "en-US verify the placement belongs to the resolved draft localization and references a copied legacy image.",
    "repeat": "Each copied iPad 13-inch placement, expected 6."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_en-US_ipad-13_1}",
    "purpose": "en-US detach inherited iPad 13-inch placement 1.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_en-US_ipad-13_2}",
    "purpose": "en-US detach inherited iPad 13-inch placement 2.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_en-US_ipad-13_3}",
    "purpose": "en-US detach inherited iPad 13-inch placement 3.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_en-US_ipad-13_4}",
    "purpose": "en-US detach inherited iPad 13-inch placement 4.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_en-US_ipad-13_5}",
    "purpose": "en-US detach inherited iPad 13-inch placement 5.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_en-US_ipad-13_6}",
    "purpose": "en-US detach inherited iPad 13-inch placement 6.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "GET",
    "path": "/v1/appStoreVersionLocalizations/{localization_en-US}/appScreenshotSets?limit=200",
    "purpose": "en-US resolve the target iPad 13-inch set after removal."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshotSets",
    "purpose": "en-US create the iPad 13-inch set if absent",
    "body": {
      "data": {
        "type": "appScreenshotSets",
        "attributes": {
          "screenshotDisplayType": "APP_IPAD_PRO_3GEN_129"
        },
        "relationships": {
          "appStoreVersionLocalization": {
            "data": {
              "type": "appStoreVersionLocalizations",
              "id": "{localization_en-US}"
            }
          }
        }
      }
    },
    "condition": "Verified draft set is absent.",
    "saveIdAs": "{set_en-US_ipad-13}"
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "en-US reserve iPad 13-inch screenshot 1",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "01-feedback.png",
          "fileSize": 3411751
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_en-US_ipad-13}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_en-US_ipad-13_1}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/en/ipad-13/01-feedback.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_en-US_ipad-13_1}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_en-US_ipad-13_1}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "90e29386484afd4dec317632eb84ff8b"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_en-US_ipad-13_1}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "en-US reserve iPad 13-inch screenshot 2",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "02-review-ticket.png",
          "fileSize": 3209725
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_en-US_ipad-13}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_en-US_ipad-13_2}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/en/ipad-13/02-review-ticket.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_en-US_ipad-13_2}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_en-US_ipad-13_2}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "89dd03b813a028616c5f33f43f7e4153"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_en-US_ipad-13_2}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "en-US reserve iPad 13-inch screenshot 3",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "03-hint.png",
          "fileSize": 4089484
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_en-US_ipad-13}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_en-US_ipad-13_3}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/en/ipad-13/03-hint.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_en-US_ipad-13_3}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_en-US_ipad-13_3}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "d791dea20251034b4428b346d1ae4e45"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_en-US_ipad-13_3}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "en-US reserve iPad 13-inch screenshot 4",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "04-film.png",
          "fileSize": 2842643
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_en-US_ipad-13}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_en-US_ipad-13_4}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/en/ipad-13/04-film.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_en-US_ipad-13_4}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_en-US_ipad-13_4}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "a25f102a43d81267328196a6de47b938"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_en-US_ipad-13_4}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "en-US reserve iPad 13-inch screenshot 5",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "05-first-step.png",
          "fileSize": 5874758
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_en-US_ipad-13}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_en-US_ipad-13_5}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/en/ipad-13/05-first-step.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_en-US_ipad-13_5}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_en-US_ipad-13_5}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "1225fa81894f19f1ab3b1d980c8f13e3"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_en-US_ipad-13_5}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "en-US reserve iPad 13-inch screenshot 6",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "06-monthly-mountains.png",
          "fileSize": 6872062
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_en-US_ipad-13}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_en-US_ipad-13_6}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/en/ipad-13/06-monthly-mountains.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_en-US_ipad-13_6}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_en-US_ipad-13_6}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "ea881517b652b239df08bfc816c29fe7"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_en-US_ipad-13_6}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshotSets/{set_en-US_ipad-13}/relationships/appScreenshots",
    "purpose": "en-US set iPad 13-inch order 01–06.",
    "body": {
      "data": [
        {
          "type": "appScreenshots",
          "id": "{screenshot_en-US_ipad-13_1}"
        },
        {
          "type": "appScreenshots",
          "id": "{screenshot_en-US_ipad-13_2}"
        },
        {
          "type": "appScreenshots",
          "id": "{screenshot_en-US_ipad-13_3}"
        },
        {
          "type": "appScreenshots",
          "id": "{screenshot_en-US_ipad-13_4}"
        },
        {
          "type": "appScreenshots",
          "id": "{screenshot_en-US_ipad-13_5}"
        },
        {
          "type": "appScreenshots",
          "id": "{screenshot_en-US_ipad-13_6}"
        }
      ]
    }
  },
  {
    "method": "GET",
    "path": "/v1/appStoreVersionLocalizations/{localization_tr}/appScreenshotSets?limit=200",
    "purpose": "tr read copied screenshot sets."
  },
  {
    "method": "GET",
    "path": "/v1/appStoreVersionLocalizations/{localization_tr}/placements?limit=200",
    "purpose": "tr read copied draft placements."
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshotSets/{set_tr_iphone-6.9}/appScreenshots?limit=200",
    "purpose": "tr compare the copied filenames and MD5 values with the live baseline for iPhone 6.9-inch.",
    "condition": "Draft set exists."
  },
  {
    "method": "GET",
    "path": "/v1/appAssetLibraryPlacements/{copied_screenshot_placement_id}?include=image,appStoreVersionLocalization",
    "purpose": "tr verify the placement belongs to the resolved draft localization and references a copied legacy image.",
    "repeat": "Each copied iPhone 6.9-inch placement, expected 8."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_tr_iphone-6.9_1}",
    "purpose": "tr detach inherited iPhone 6.9-inch placement 1.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_tr_iphone-6.9_2}",
    "purpose": "tr detach inherited iPhone 6.9-inch placement 2.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_tr_iphone-6.9_3}",
    "purpose": "tr detach inherited iPhone 6.9-inch placement 3.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_tr_iphone-6.9_4}",
    "purpose": "tr detach inherited iPhone 6.9-inch placement 4.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_tr_iphone-6.9_5}",
    "purpose": "tr detach inherited iPhone 6.9-inch placement 5.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_tr_iphone-6.9_6}",
    "purpose": "tr detach inherited iPhone 6.9-inch placement 6.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_tr_iphone-6.9_7}",
    "purpose": "tr detach inherited iPhone 6.9-inch placement 7.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_tr_iphone-6.9_8}",
    "purpose": "tr detach inherited iPhone 6.9-inch placement 8.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "GET",
    "path": "/v1/appStoreVersionLocalizations/{localization_tr}/appScreenshotSets?limit=200",
    "purpose": "tr resolve the target iPhone 6.9-inch set after removal."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshotSets",
    "purpose": "tr create the iPhone 6.9-inch set if absent",
    "body": {
      "data": {
        "type": "appScreenshotSets",
        "attributes": {
          "screenshotDisplayType": "APP_IPHONE_67"
        },
        "relationships": {
          "appStoreVersionLocalization": {
            "data": {
              "type": "appStoreVersionLocalizations",
              "id": "{localization_tr}"
            }
          }
        }
      }
    },
    "condition": "Verified draft set is absent.",
    "saveIdAs": "{set_tr_iphone-6.9}"
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "tr reserve iPhone 6.9-inch screenshot 1",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "01-geri-bildirim.png",
          "fileSize": 3082589
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_tr_iphone-6.9}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_tr_iphone-6.9_1}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/tr/iphone-6.9/01-geri-bildirim.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_tr_iphone-6.9_1}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_tr_iphone-6.9_1}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "56121eda1fdfe9deff3606f34bd530df"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_tr_iphone-6.9_1}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "tr reserve iPhone 6.9-inch screenshot 2",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "02-tekrar-ve-bilet.png",
          "fileSize": 2938184
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_tr_iphone-6.9}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_tr_iphone-6.9_2}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/tr/iphone-6.9/02-tekrar-ve-bilet.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_tr_iphone-6.9_2}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_tr_iphone-6.9_2}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "cf98d358e95cf5315a1eec8d7e2eeaa0"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_tr_iphone-6.9_2}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "tr reserve iPhone 6.9-inch screenshot 3",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "03-ipucu.png",
          "fileSize": 3843259
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_tr_iphone-6.9}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_tr_iphone-6.9_3}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/tr/iphone-6.9/03-ipucu.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_tr_iphone-6.9_3}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_tr_iphone-6.9_3}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "b3a10f24fe20d7379b514a04db21121b"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_tr_iphone-6.9_3}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "tr reserve iPhone 6.9-inch screenshot 4",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "04-zamani-kullan.png",
          "fileSize": 2787008
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_tr_iphone-6.9}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_tr_iphone-6.9_4}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/tr/iphone-6.9/04-zamani-kullan.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_tr_iphone-6.9_4}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_tr_iphone-6.9_4}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "ece3364c14afa67e7f2f3f71136b9394"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_tr_iphone-6.9_4}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "tr reserve iPhone 6.9-inch screenshot 5",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "05-ilk-adim.png",
          "fileSize": 3320517
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_tr_iphone-6.9}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_tr_iphone-6.9_5}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/tr/iphone-6.9/05-ilk-adim.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_tr_iphone-6.9_5}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_tr_iphone-6.9_5}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "273501007452bd5330ff20e65d34c002"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_tr_iphone-6.9_5}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "tr reserve iPhone 6.9-inch screenshot 6",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "06-aylik-daglar.png",
          "fileSize": 4703705
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_tr_iphone-6.9}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_tr_iphone-6.9_6}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/tr/iphone-6.9/06-aylik-daglar.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_tr_iphone-6.9_6}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_tr_iphone-6.9_6}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "39580cbeba2ee259a46779d6c415a4f8"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_tr_iphone-6.9_6}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshotSets/{set_tr_iphone-6.9}/relationships/appScreenshots",
    "purpose": "tr set iPhone 6.9-inch order 01–06.",
    "body": {
      "data": [
        {
          "type": "appScreenshots",
          "id": "{screenshot_tr_iphone-6.9_1}"
        },
        {
          "type": "appScreenshots",
          "id": "{screenshot_tr_iphone-6.9_2}"
        },
        {
          "type": "appScreenshots",
          "id": "{screenshot_tr_iphone-6.9_3}"
        },
        {
          "type": "appScreenshots",
          "id": "{screenshot_tr_iphone-6.9_4}"
        },
        {
          "type": "appScreenshots",
          "id": "{screenshot_tr_iphone-6.9_5}"
        },
        {
          "type": "appScreenshots",
          "id": "{screenshot_tr_iphone-6.9_6}"
        }
      ]
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshotSets/{set_tr_ipad-13}/appScreenshots?limit=200",
    "purpose": "tr compare the copied filenames and MD5 values with the live baseline for iPad 13-inch.",
    "condition": "Draft set exists."
  },
  {
    "method": "GET",
    "path": "/v1/appAssetLibraryPlacements/{copied_screenshot_placement_id}?include=image,appStoreVersionLocalization",
    "purpose": "tr verify the placement belongs to the resolved draft localization and references a copied legacy image.",
    "repeat": "Each copied iPad 13-inch placement, expected 6."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_tr_ipad-13_1}",
    "purpose": "tr detach inherited iPad 13-inch placement 1.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_tr_ipad-13_2}",
    "purpose": "tr detach inherited iPad 13-inch placement 2.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_tr_ipad-13_3}",
    "purpose": "tr detach inherited iPad 13-inch placement 3.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_tr_ipad-13_4}",
    "purpose": "tr detach inherited iPad 13-inch placement 4.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_tr_ipad-13_5}",
    "purpose": "tr detach inherited iPad 13-inch placement 5.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_tr_ipad-13_6}",
    "purpose": "tr detach inherited iPad 13-inch placement 6.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "GET",
    "path": "/v1/appStoreVersionLocalizations/{localization_tr}/appScreenshotSets?limit=200",
    "purpose": "tr resolve the target iPad 13-inch set after removal."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshotSets",
    "purpose": "tr create the iPad 13-inch set if absent",
    "body": {
      "data": {
        "type": "appScreenshotSets",
        "attributes": {
          "screenshotDisplayType": "APP_IPAD_PRO_3GEN_129"
        },
        "relationships": {
          "appStoreVersionLocalization": {
            "data": {
              "type": "appStoreVersionLocalizations",
              "id": "{localization_tr}"
            }
          }
        }
      }
    },
    "condition": "Verified draft set is absent.",
    "saveIdAs": "{set_tr_ipad-13}"
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "tr reserve iPad 13-inch screenshot 1",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "01-geri-bildirim.png",
          "fileSize": 3416039
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_tr_ipad-13}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_tr_ipad-13_1}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/tr/ipad-13/01-geri-bildirim.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_tr_ipad-13_1}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_tr_ipad-13_1}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "94eb3ba31adf60d5da1301b8c4e119ea"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_tr_ipad-13_1}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "tr reserve iPad 13-inch screenshot 2",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "02-tekrar-ve-bilet.png",
          "fileSize": 3149512
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_tr_ipad-13}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_tr_ipad-13_2}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/tr/ipad-13/02-tekrar-ve-bilet.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_tr_ipad-13_2}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_tr_ipad-13_2}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "9729fab510d5294b5963cd858cee822a"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_tr_ipad-13_2}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "tr reserve iPad 13-inch screenshot 3",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "03-ipucu.png",
          "fileSize": 4068256
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_tr_ipad-13}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_tr_ipad-13_3}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/tr/ipad-13/03-ipucu.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_tr_ipad-13_3}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_tr_ipad-13_3}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "01c9c334fc5d13a2aa5df8fbda252260"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_tr_ipad-13_3}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "tr reserve iPad 13-inch screenshot 4",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "04-zamani-kullan.png",
          "fileSize": 2806623
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_tr_ipad-13}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_tr_ipad-13_4}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/tr/ipad-13/04-zamani-kullan.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_tr_ipad-13_4}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_tr_ipad-13_4}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "4abebe7c584e28a3a27bfb116213a481"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_tr_ipad-13_4}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "tr reserve iPad 13-inch screenshot 5",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "05-ilk-adim.png",
          "fileSize": 5855249
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_tr_ipad-13}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_tr_ipad-13_5}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/tr/ipad-13/05-ilk-adim.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_tr_ipad-13_5}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_tr_ipad-13_5}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "52cf608b96b733edcb40cacc81bc1b6a"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_tr_ipad-13_5}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "tr reserve iPad 13-inch screenshot 6",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "06-aylik-daglar.png",
          "fileSize": 6899379
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_tr_ipad-13}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_tr_ipad-13_6}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/tr/ipad-13/06-aylik-daglar.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_tr_ipad-13_6}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_tr_ipad-13_6}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "379d279bd4df43a54060cdb62f2ecab7"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_tr_ipad-13_6}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshotSets/{set_tr_ipad-13}/relationships/appScreenshots",
    "purpose": "tr set iPad 13-inch order 01–06.",
    "body": {
      "data": [
        {
          "type": "appScreenshots",
          "id": "{screenshot_tr_ipad-13_1}"
        },
        {
          "type": "appScreenshots",
          "id": "{screenshot_tr_ipad-13_2}"
        },
        {
          "type": "appScreenshots",
          "id": "{screenshot_tr_ipad-13_3}"
        },
        {
          "type": "appScreenshots",
          "id": "{screenshot_tr_ipad-13_4}"
        },
        {
          "type": "appScreenshots",
          "id": "{screenshot_tr_ipad-13_5}"
        },
        {
          "type": "appScreenshots",
          "id": "{screenshot_tr_ipad-13_6}"
        }
      ]
    }
  },
  {
    "method": "GET",
    "path": "/v1/appStoreVersionLocalizations/{localization_de-DE}/appScreenshotSets?limit=200",
    "purpose": "de-DE read copied screenshot sets."
  },
  {
    "method": "GET",
    "path": "/v1/appStoreVersionLocalizations/{localization_de-DE}/placements?limit=200",
    "purpose": "de-DE read copied draft placements."
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshotSets/{set_de-DE_iphone-6.9}/appScreenshots?limit=200",
    "purpose": "de-DE compare the copied filenames and MD5 values with the live baseline for iPhone 6.9-inch.",
    "condition": "Draft set exists."
  },
  {
    "method": "GET",
    "path": "/v1/appAssetLibraryPlacements/{copied_screenshot_placement_id}?include=image,appStoreVersionLocalization",
    "purpose": "de-DE verify the placement belongs to the resolved draft localization and references a copied legacy image.",
    "repeat": "Each copied iPhone 6.9-inch placement, expected 8."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_de-DE_iphone-6.9_1}",
    "purpose": "de-DE detach inherited iPhone 6.9-inch placement 1.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_de-DE_iphone-6.9_2}",
    "purpose": "de-DE detach inherited iPhone 6.9-inch placement 2.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_de-DE_iphone-6.9_3}",
    "purpose": "de-DE detach inherited iPhone 6.9-inch placement 3.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_de-DE_iphone-6.9_4}",
    "purpose": "de-DE detach inherited iPhone 6.9-inch placement 4.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_de-DE_iphone-6.9_5}",
    "purpose": "de-DE detach inherited iPhone 6.9-inch placement 5.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_de-DE_iphone-6.9_6}",
    "purpose": "de-DE detach inherited iPhone 6.9-inch placement 6.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_de-DE_iphone-6.9_7}",
    "purpose": "de-DE detach inherited iPhone 6.9-inch placement 7.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_de-DE_iphone-6.9_8}",
    "purpose": "de-DE detach inherited iPhone 6.9-inch placement 8.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "GET",
    "path": "/v1/appStoreVersionLocalizations/{localization_de-DE}/appScreenshotSets?limit=200",
    "purpose": "de-DE resolve the target iPhone 6.9-inch set after removal."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshotSets",
    "purpose": "de-DE create the iPhone 6.9-inch set if absent",
    "body": {
      "data": {
        "type": "appScreenshotSets",
        "attributes": {
          "screenshotDisplayType": "APP_IPHONE_67"
        },
        "relationships": {
          "appStoreVersionLocalization": {
            "data": {
              "type": "appStoreVersionLocalizations",
              "id": "{localization_de-DE}"
            }
          }
        }
      }
    },
    "condition": "Verified draft set is absent.",
    "saveIdAs": "{set_de-DE_iphone-6.9}"
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "de-DE reserve iPhone 6.9-inch screenshot 1",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "01-feedback.png",
          "fileSize": 3128267
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_de-DE_iphone-6.9}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_de-DE_iphone-6.9_1}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/de/iphone-6.9/01-feedback.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_de-DE_iphone-6.9_1}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_de-DE_iphone-6.9_1}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "307c7bcee33ad1801761fb36db53232c"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_de-DE_iphone-6.9_1}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "de-DE reserve iPhone 6.9-inch screenshot 2",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "02-review-ticket.png",
          "fileSize": 2974878
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_de-DE_iphone-6.9}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_de-DE_iphone-6.9_2}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/de/iphone-6.9/02-review-ticket.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_de-DE_iphone-6.9_2}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_de-DE_iphone-6.9_2}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "3bd85a921964a47d7cf05b9dd000f561"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_de-DE_iphone-6.9_2}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "de-DE reserve iPhone 6.9-inch screenshot 3",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "03-hint.png",
          "fileSize": 3880959
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_de-DE_iphone-6.9}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_de-DE_iphone-6.9_3}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/de/iphone-6.9/03-hint.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_de-DE_iphone-6.9_3}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_de-DE_iphone-6.9_3}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "e25fc0129098a6114fbb21ca1184f0c0"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_de-DE_iphone-6.9_3}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "de-DE reserve iPhone 6.9-inch screenshot 4",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "04-film.png",
          "fileSize": 2855369
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_de-DE_iphone-6.9}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_de-DE_iphone-6.9_4}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/de/iphone-6.9/04-film.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_de-DE_iphone-6.9_4}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_de-DE_iphone-6.9_4}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "0ffe4cb29a87bc0d69fd2bfd9e4079cd"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_de-DE_iphone-6.9_4}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "de-DE reserve iPhone 6.9-inch screenshot 5",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "05-first-step.png",
          "fileSize": 3360695
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_de-DE_iphone-6.9}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_de-DE_iphone-6.9_5}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/de/iphone-6.9/05-first-step.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_de-DE_iphone-6.9_5}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_de-DE_iphone-6.9_5}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "e941e58af2ed728b0ca9792419664956"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_de-DE_iphone-6.9_5}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "de-DE reserve iPhone 6.9-inch screenshot 6",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "06-monthly-mountains.png",
          "fileSize": 4732284
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_de-DE_iphone-6.9}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_de-DE_iphone-6.9_6}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/de/iphone-6.9/06-monthly-mountains.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_de-DE_iphone-6.9_6}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_de-DE_iphone-6.9_6}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "95d08d48479cbf56a9128b42a0b0fa51"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_de-DE_iphone-6.9_6}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshotSets/{set_de-DE_iphone-6.9}/relationships/appScreenshots",
    "purpose": "de-DE set iPhone 6.9-inch order 01–06.",
    "body": {
      "data": [
        {
          "type": "appScreenshots",
          "id": "{screenshot_de-DE_iphone-6.9_1}"
        },
        {
          "type": "appScreenshots",
          "id": "{screenshot_de-DE_iphone-6.9_2}"
        },
        {
          "type": "appScreenshots",
          "id": "{screenshot_de-DE_iphone-6.9_3}"
        },
        {
          "type": "appScreenshots",
          "id": "{screenshot_de-DE_iphone-6.9_4}"
        },
        {
          "type": "appScreenshots",
          "id": "{screenshot_de-DE_iphone-6.9_5}"
        },
        {
          "type": "appScreenshots",
          "id": "{screenshot_de-DE_iphone-6.9_6}"
        }
      ]
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshotSets/{set_de-DE_ipad-13}/appScreenshots?limit=200",
    "purpose": "de-DE compare the copied filenames and MD5 values with the live baseline for iPad 13-inch.",
    "condition": "Draft set exists."
  },
  {
    "method": "GET",
    "path": "/v1/appAssetLibraryPlacements/{copied_screenshot_placement_id}?include=image,appStoreVersionLocalization",
    "purpose": "de-DE verify the placement belongs to the resolved draft localization and references a copied legacy image.",
    "repeat": "Each copied iPad 13-inch placement, expected 6."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_de-DE_ipad-13_1}",
    "purpose": "de-DE detach inherited iPad 13-inch placement 1.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_de-DE_ipad-13_2}",
    "purpose": "de-DE detach inherited iPad 13-inch placement 2.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_de-DE_ipad-13_3}",
    "purpose": "de-DE detach inherited iPad 13-inch placement 3.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_de-DE_ipad-13_4}",
    "purpose": "de-DE detach inherited iPad 13-inch placement 4.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_de-DE_ipad-13_5}",
    "purpose": "de-DE detach inherited iPad 13-inch placement 5.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_de-DE_ipad-13_6}",
    "purpose": "de-DE detach inherited iPad 13-inch placement 6.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "GET",
    "path": "/v1/appStoreVersionLocalizations/{localization_de-DE}/appScreenshotSets?limit=200",
    "purpose": "de-DE resolve the target iPad 13-inch set after removal."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshotSets",
    "purpose": "de-DE create the iPad 13-inch set if absent",
    "body": {
      "data": {
        "type": "appScreenshotSets",
        "attributes": {
          "screenshotDisplayType": "APP_IPAD_PRO_3GEN_129"
        },
        "relationships": {
          "appStoreVersionLocalization": {
            "data": {
              "type": "appStoreVersionLocalizations",
              "id": "{localization_de-DE}"
            }
          }
        }
      }
    },
    "condition": "Verified draft set is absent.",
    "saveIdAs": "{set_de-DE_ipad-13}"
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "de-DE reserve iPad 13-inch screenshot 1",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "01-feedback.png",
          "fileSize": 3423181
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_de-DE_ipad-13}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_de-DE_ipad-13_1}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/de/ipad-13/01-feedback.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_de-DE_ipad-13_1}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_de-DE_ipad-13_1}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "19e69160dd0be691715a20986735dda5"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_de-DE_ipad-13_1}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "de-DE reserve iPad 13-inch screenshot 2",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "02-review-ticket.png",
          "fileSize": 3149632
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_de-DE_ipad-13}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_de-DE_ipad-13_2}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/de/ipad-13/02-review-ticket.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_de-DE_ipad-13_2}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_de-DE_ipad-13_2}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "00720119b36b7a207b832befd9cb3ac4"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_de-DE_ipad-13_2}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "de-DE reserve iPad 13-inch screenshot 3",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "03-hint.png",
          "fileSize": 4066443
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_de-DE_ipad-13}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_de-DE_ipad-13_3}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/de/ipad-13/03-hint.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_de-DE_ipad-13_3}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_de-DE_ipad-13_3}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "8bf2d0ca2acc15270e8b053e3b230506"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_de-DE_ipad-13_3}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "de-DE reserve iPad 13-inch screenshot 4",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "04-film.png",
          "fileSize": 2833584
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_de-DE_ipad-13}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_de-DE_ipad-13_4}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/de/ipad-13/04-film.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_de-DE_ipad-13_4}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_de-DE_ipad-13_4}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "325bf769d1f8829e16690a7777945057"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_de-DE_ipad-13_4}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "de-DE reserve iPad 13-inch screenshot 5",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "05-first-step.png",
          "fileSize": 5839016
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_de-DE_ipad-13}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_de-DE_ipad-13_5}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/de/ipad-13/05-first-step.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_de-DE_ipad-13_5}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_de-DE_ipad-13_5}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "770b3058a4dff7961fb7ab90c7c4eecd"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_de-DE_ipad-13_5}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "de-DE reserve iPad 13-inch screenshot 6",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "06-monthly-mountains.png",
          "fileSize": 6867198
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_de-DE_ipad-13}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_de-DE_ipad-13_6}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/de/ipad-13/06-monthly-mountains.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_de-DE_ipad-13_6}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_de-DE_ipad-13_6}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "d3a997ed77045adbf6624a43e8de2da5"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_de-DE_ipad-13_6}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshotSets/{set_de-DE_ipad-13}/relationships/appScreenshots",
    "purpose": "de-DE set iPad 13-inch order 01–06.",
    "body": {
      "data": [
        {
          "type": "appScreenshots",
          "id": "{screenshot_de-DE_ipad-13_1}"
        },
        {
          "type": "appScreenshots",
          "id": "{screenshot_de-DE_ipad-13_2}"
        },
        {
          "type": "appScreenshots",
          "id": "{screenshot_de-DE_ipad-13_3}"
        },
        {
          "type": "appScreenshots",
          "id": "{screenshot_de-DE_ipad-13_4}"
        },
        {
          "type": "appScreenshots",
          "id": "{screenshot_de-DE_ipad-13_5}"
        },
        {
          "type": "appScreenshots",
          "id": "{screenshot_de-DE_ipad-13_6}"
        }
      ]
    }
  },
  {
    "method": "GET",
    "path": "/v1/appStoreVersionLocalizations/{localization_es-MX}/appScreenshotSets?limit=200",
    "purpose": "es-MX read copied screenshot sets."
  },
  {
    "method": "GET",
    "path": "/v1/appStoreVersionLocalizations/{localization_es-MX}/placements?limit=200",
    "purpose": "es-MX read copied draft placements."
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshotSets/{set_es-MX_iphone-6.9}/appScreenshots?limit=200",
    "purpose": "es-MX compare the copied filenames and MD5 values with the live baseline for iPhone 6.9-inch.",
    "condition": "Draft set exists."
  },
  {
    "method": "GET",
    "path": "/v1/appAssetLibraryPlacements/{copied_screenshot_placement_id}?include=image,appStoreVersionLocalization",
    "purpose": "es-MX verify the placement belongs to the resolved draft localization and references a copied legacy image.",
    "repeat": "Each copied iPhone 6.9-inch placement, expected 8."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_es-MX_iphone-6.9_1}",
    "purpose": "es-MX detach inherited iPhone 6.9-inch placement 1.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_es-MX_iphone-6.9_2}",
    "purpose": "es-MX detach inherited iPhone 6.9-inch placement 2.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_es-MX_iphone-6.9_3}",
    "purpose": "es-MX detach inherited iPhone 6.9-inch placement 3.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_es-MX_iphone-6.9_4}",
    "purpose": "es-MX detach inherited iPhone 6.9-inch placement 4.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_es-MX_iphone-6.9_5}",
    "purpose": "es-MX detach inherited iPhone 6.9-inch placement 5.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_es-MX_iphone-6.9_6}",
    "purpose": "es-MX detach inherited iPhone 6.9-inch placement 6.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_es-MX_iphone-6.9_7}",
    "purpose": "es-MX detach inherited iPhone 6.9-inch placement 7.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_es-MX_iphone-6.9_8}",
    "purpose": "es-MX detach inherited iPhone 6.9-inch placement 8.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "GET",
    "path": "/v1/appStoreVersionLocalizations/{localization_es-MX}/appScreenshotSets?limit=200",
    "purpose": "es-MX resolve the target iPhone 6.9-inch set after removal."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshotSets",
    "purpose": "es-MX create the iPhone 6.9-inch set if absent",
    "body": {
      "data": {
        "type": "appScreenshotSets",
        "attributes": {
          "screenshotDisplayType": "APP_IPHONE_67"
        },
        "relationships": {
          "appStoreVersionLocalization": {
            "data": {
              "type": "appStoreVersionLocalizations",
              "id": "{localization_es-MX}"
            }
          }
        }
      }
    },
    "condition": "Verified draft set is absent.",
    "saveIdAs": "{set_es-MX_iphone-6.9}"
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "es-MX reserve iPhone 6.9-inch screenshot 1",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "01-feedback.png",
          "fileSize": 3130048
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_es-MX_iphone-6.9}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_es-MX_iphone-6.9_1}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/es/iphone-6.9/01-feedback.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_es-MX_iphone-6.9_1}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_es-MX_iphone-6.9_1}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "155da452f7d4f7a50a57f50d0bf2834c"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_es-MX_iphone-6.9_1}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "es-MX reserve iPhone 6.9-inch screenshot 2",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "02-review-ticket.png",
          "fileSize": 2975473
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_es-MX_iphone-6.9}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_es-MX_iphone-6.9_2}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/es/iphone-6.9/02-review-ticket.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_es-MX_iphone-6.9_2}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_es-MX_iphone-6.9_2}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "e9af9d137b0e404fe5910b1de3aec502"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_es-MX_iphone-6.9_2}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "es-MX reserve iPhone 6.9-inch screenshot 3",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "03-hint.png",
          "fileSize": 3914230
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_es-MX_iphone-6.9}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_es-MX_iphone-6.9_3}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/es/iphone-6.9/03-hint.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_es-MX_iphone-6.9_3}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_es-MX_iphone-6.9_3}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "d0991297af7828ffc59acb06075352e8"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_es-MX_iphone-6.9_3}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "es-MX reserve iPhone 6.9-inch screenshot 4",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "04-film.png",
          "fileSize": 2860892
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_es-MX_iphone-6.9}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_es-MX_iphone-6.9_4}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/es/iphone-6.9/04-film.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_es-MX_iphone-6.9_4}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_es-MX_iphone-6.9_4}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "bfd7c692d5e160563b938ee04de537a8"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_es-MX_iphone-6.9_4}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "es-MX reserve iPhone 6.9-inch screenshot 5",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "05-first-step.png",
          "fileSize": 3370211
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_es-MX_iphone-6.9}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_es-MX_iphone-6.9_5}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/es/iphone-6.9/05-first-step.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_es-MX_iphone-6.9_5}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_es-MX_iphone-6.9_5}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "48794e51d6ec4dc5de42a7ed993c5340"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_es-MX_iphone-6.9_5}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "es-MX reserve iPhone 6.9-inch screenshot 6",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "06-monthly-mountains.png",
          "fileSize": 4754358
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_es-MX_iphone-6.9}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_es-MX_iphone-6.9_6}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/es/iphone-6.9/06-monthly-mountains.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_es-MX_iphone-6.9_6}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_es-MX_iphone-6.9_6}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "911bd13ae656ffe6b27ad075d7d3d305"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_es-MX_iphone-6.9_6}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshotSets/{set_es-MX_iphone-6.9}/relationships/appScreenshots",
    "purpose": "es-MX set iPhone 6.9-inch order 01–06.",
    "body": {
      "data": [
        {
          "type": "appScreenshots",
          "id": "{screenshot_es-MX_iphone-6.9_1}"
        },
        {
          "type": "appScreenshots",
          "id": "{screenshot_es-MX_iphone-6.9_2}"
        },
        {
          "type": "appScreenshots",
          "id": "{screenshot_es-MX_iphone-6.9_3}"
        },
        {
          "type": "appScreenshots",
          "id": "{screenshot_es-MX_iphone-6.9_4}"
        },
        {
          "type": "appScreenshots",
          "id": "{screenshot_es-MX_iphone-6.9_5}"
        },
        {
          "type": "appScreenshots",
          "id": "{screenshot_es-MX_iphone-6.9_6}"
        }
      ]
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshotSets/{set_es-MX_ipad-13}/appScreenshots?limit=200",
    "purpose": "es-MX compare the copied filenames and MD5 values with the live baseline for iPad 13-inch.",
    "condition": "Draft set exists."
  },
  {
    "method": "GET",
    "path": "/v1/appAssetLibraryPlacements/{copied_screenshot_placement_id}?include=image,appStoreVersionLocalization",
    "purpose": "es-MX verify the placement belongs to the resolved draft localization and references a copied legacy image.",
    "repeat": "Each copied iPad 13-inch placement, expected 6."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_es-MX_ipad-13_1}",
    "purpose": "es-MX detach inherited iPad 13-inch placement 1.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_es-MX_ipad-13_2}",
    "purpose": "es-MX detach inherited iPad 13-inch placement 2.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_es-MX_ipad-13_3}",
    "purpose": "es-MX detach inherited iPad 13-inch placement 3.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_es-MX_ipad-13_4}",
    "purpose": "es-MX detach inherited iPad 13-inch placement 4.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_es-MX_ipad-13_5}",
    "purpose": "es-MX detach inherited iPad 13-inch placement 5.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_es-MX_ipad-13_6}",
    "purpose": "es-MX detach inherited iPad 13-inch placement 6.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "GET",
    "path": "/v1/appStoreVersionLocalizations/{localization_es-MX}/appScreenshotSets?limit=200",
    "purpose": "es-MX resolve the target iPad 13-inch set after removal."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshotSets",
    "purpose": "es-MX create the iPad 13-inch set if absent",
    "body": {
      "data": {
        "type": "appScreenshotSets",
        "attributes": {
          "screenshotDisplayType": "APP_IPAD_PRO_3GEN_129"
        },
        "relationships": {
          "appStoreVersionLocalization": {
            "data": {
              "type": "appStoreVersionLocalizations",
              "id": "{localization_es-MX}"
            }
          }
        }
      }
    },
    "condition": "Verified draft set is absent.",
    "saveIdAs": "{set_es-MX_ipad-13}"
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "es-MX reserve iPad 13-inch screenshot 1",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "01-feedback.png",
          "fileSize": 3422424
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_es-MX_ipad-13}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_es-MX_ipad-13_1}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/es/ipad-13/01-feedback.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_es-MX_ipad-13_1}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_es-MX_ipad-13_1}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "02079052096c8ea892771d6663637c46"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_es-MX_ipad-13_1}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "es-MX reserve iPad 13-inch screenshot 2",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "02-review-ticket.png",
          "fileSize": 3222145
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_es-MX_ipad-13}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_es-MX_ipad-13_2}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/es/ipad-13/02-review-ticket.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_es-MX_ipad-13_2}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_es-MX_ipad-13_2}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "0fdb1940f0529ef6822f43f6fa9a7e46"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_es-MX_ipad-13_2}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "es-MX reserve iPad 13-inch screenshot 3",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "03-hint.png",
          "fileSize": 4072425
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_es-MX_ipad-13}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_es-MX_ipad-13_3}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/es/ipad-13/03-hint.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_es-MX_ipad-13_3}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_es-MX_ipad-13_3}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "9a31eeb5edd1093bf698ad72661e94ff"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_es-MX_ipad-13_3}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "es-MX reserve iPad 13-inch screenshot 4",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "04-film.png",
          "fileSize": 2845094
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_es-MX_ipad-13}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_es-MX_ipad-13_4}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/es/ipad-13/04-film.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_es-MX_ipad-13_4}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_es-MX_ipad-13_4}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "db48aca539da778405e14b0894793481"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_es-MX_ipad-13_4}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "es-MX reserve iPad 13-inch screenshot 5",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "05-first-step.png",
          "fileSize": 5917590
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_es-MX_ipad-13}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_es-MX_ipad-13_5}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/es/ipad-13/05-first-step.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_es-MX_ipad-13_5}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_es-MX_ipad-13_5}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "f95e508475112314fc8bcf4ed59a9c7e"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_es-MX_ipad-13_5}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "es-MX reserve iPad 13-inch screenshot 6",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "06-monthly-mountains.png",
          "fileSize": 6874442
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_es-MX_ipad-13}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_es-MX_ipad-13_6}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/es/ipad-13/06-monthly-mountains.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_es-MX_ipad-13_6}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_es-MX_ipad-13_6}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "bd68b746740a54e2ddf310d994b4ee5a"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_es-MX_ipad-13_6}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshotSets/{set_es-MX_ipad-13}/relationships/appScreenshots",
    "purpose": "es-MX set iPad 13-inch order 01–06.",
    "body": {
      "data": [
        {
          "type": "appScreenshots",
          "id": "{screenshot_es-MX_ipad-13_1}"
        },
        {
          "type": "appScreenshots",
          "id": "{screenshot_es-MX_ipad-13_2}"
        },
        {
          "type": "appScreenshots",
          "id": "{screenshot_es-MX_ipad-13_3}"
        },
        {
          "type": "appScreenshots",
          "id": "{screenshot_es-MX_ipad-13_4}"
        },
        {
          "type": "appScreenshots",
          "id": "{screenshot_es-MX_ipad-13_5}"
        },
        {
          "type": "appScreenshots",
          "id": "{screenshot_es-MX_ipad-13_6}"
        }
      ]
    }
  },
  {
    "method": "GET",
    "path": "/v1/appStoreVersionLocalizations/{localization_pt-BR}/appScreenshotSets?limit=200",
    "purpose": "pt-BR read copied screenshot sets."
  },
  {
    "method": "GET",
    "path": "/v1/appStoreVersionLocalizations/{localization_pt-BR}/placements?limit=200",
    "purpose": "pt-BR read copied draft placements."
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshotSets/{set_pt-BR_iphone-6.9}/appScreenshots?limit=200",
    "purpose": "pt-BR compare the copied filenames and MD5 values with the live baseline for iPhone 6.9-inch.",
    "condition": "Draft set exists."
  },
  {
    "method": "GET",
    "path": "/v1/appAssetLibraryPlacements/{copied_screenshot_placement_id}?include=image,appStoreVersionLocalization",
    "purpose": "pt-BR verify the placement belongs to the resolved draft localization and references a copied legacy image.",
    "repeat": "Each copied iPhone 6.9-inch placement, expected 8."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_pt-BR_iphone-6.9_1}",
    "purpose": "pt-BR detach inherited iPhone 6.9-inch placement 1.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_pt-BR_iphone-6.9_2}",
    "purpose": "pt-BR detach inherited iPhone 6.9-inch placement 2.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_pt-BR_iphone-6.9_3}",
    "purpose": "pt-BR detach inherited iPhone 6.9-inch placement 3.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_pt-BR_iphone-6.9_4}",
    "purpose": "pt-BR detach inherited iPhone 6.9-inch placement 4.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_pt-BR_iphone-6.9_5}",
    "purpose": "pt-BR detach inherited iPhone 6.9-inch placement 5.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_pt-BR_iphone-6.9_6}",
    "purpose": "pt-BR detach inherited iPhone 6.9-inch placement 6.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_pt-BR_iphone-6.9_7}",
    "purpose": "pt-BR detach inherited iPhone 6.9-inch placement 7.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_pt-BR_iphone-6.9_8}",
    "purpose": "pt-BR detach inherited iPhone 6.9-inch placement 8.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "GET",
    "path": "/v1/appStoreVersionLocalizations/{localization_pt-BR}/appScreenshotSets?limit=200",
    "purpose": "pt-BR resolve the target iPhone 6.9-inch set after removal."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshotSets",
    "purpose": "pt-BR create the iPhone 6.9-inch set if absent",
    "body": {
      "data": {
        "type": "appScreenshotSets",
        "attributes": {
          "screenshotDisplayType": "APP_IPHONE_67"
        },
        "relationships": {
          "appStoreVersionLocalization": {
            "data": {
              "type": "appStoreVersionLocalizations",
              "id": "{localization_pt-BR}"
            }
          }
        }
      }
    },
    "condition": "Verified draft set is absent.",
    "saveIdAs": "{set_pt-BR_iphone-6.9}"
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "pt-BR reserve iPhone 6.9-inch screenshot 1",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "01-feedback.png",
          "fileSize": 3135193
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_pt-BR_iphone-6.9}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_pt-BR_iphone-6.9_1}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/pt-BR/iphone-6.9/01-feedback.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_pt-BR_iphone-6.9_1}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_pt-BR_iphone-6.9_1}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "2a19be07327805565b66799dd2ffadad"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_pt-BR_iphone-6.9_1}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "pt-BR reserve iPhone 6.9-inch screenshot 2",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "02-review-ticket.png",
          "fileSize": 2981621
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_pt-BR_iphone-6.9}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_pt-BR_iphone-6.9_2}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/pt-BR/iphone-6.9/02-review-ticket.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_pt-BR_iphone-6.9_2}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_pt-BR_iphone-6.9_2}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "c62e5bc2eb1905e6674dba416ac780e2"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_pt-BR_iphone-6.9_2}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "pt-BR reserve iPhone 6.9-inch screenshot 3",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "03-hint.png",
          "fileSize": 3924497
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_pt-BR_iphone-6.9}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_pt-BR_iphone-6.9_3}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/pt-BR/iphone-6.9/03-hint.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_pt-BR_iphone-6.9_3}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_pt-BR_iphone-6.9_3}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "3b6e96b8f68e44d86389c2e689b87042"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_pt-BR_iphone-6.9_3}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "pt-BR reserve iPhone 6.9-inch screenshot 4",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "04-film.png",
          "fileSize": 2844772
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_pt-BR_iphone-6.9}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_pt-BR_iphone-6.9_4}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/pt-BR/iphone-6.9/04-film.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_pt-BR_iphone-6.9_4}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_pt-BR_iphone-6.9_4}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "a55006afefd1889d739886ba94a48b56"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_pt-BR_iphone-6.9_4}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "pt-BR reserve iPhone 6.9-inch screenshot 5",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "05-first-step.png",
          "fileSize": 3368633
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_pt-BR_iphone-6.9}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_pt-BR_iphone-6.9_5}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/pt-BR/iphone-6.9/05-first-step.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_pt-BR_iphone-6.9_5}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_pt-BR_iphone-6.9_5}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "4121706192fd1c871fd150c49a2f43e3"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_pt-BR_iphone-6.9_5}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "pt-BR reserve iPhone 6.9-inch screenshot 6",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "06-monthly-mountains.png",
          "fileSize": 4752408
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_pt-BR_iphone-6.9}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_pt-BR_iphone-6.9_6}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/pt-BR/iphone-6.9/06-monthly-mountains.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_pt-BR_iphone-6.9_6}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_pt-BR_iphone-6.9_6}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "d25e32c75cfe26680e46bd6ff36ebf5c"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_pt-BR_iphone-6.9_6}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshotSets/{set_pt-BR_iphone-6.9}/relationships/appScreenshots",
    "purpose": "pt-BR set iPhone 6.9-inch order 01–06.",
    "body": {
      "data": [
        {
          "type": "appScreenshots",
          "id": "{screenshot_pt-BR_iphone-6.9_1}"
        },
        {
          "type": "appScreenshots",
          "id": "{screenshot_pt-BR_iphone-6.9_2}"
        },
        {
          "type": "appScreenshots",
          "id": "{screenshot_pt-BR_iphone-6.9_3}"
        },
        {
          "type": "appScreenshots",
          "id": "{screenshot_pt-BR_iphone-6.9_4}"
        },
        {
          "type": "appScreenshots",
          "id": "{screenshot_pt-BR_iphone-6.9_5}"
        },
        {
          "type": "appScreenshots",
          "id": "{screenshot_pt-BR_iphone-6.9_6}"
        }
      ]
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshotSets/{set_pt-BR_ipad-13}/appScreenshots?limit=200",
    "purpose": "pt-BR compare the copied filenames and MD5 values with the live baseline for iPad 13-inch.",
    "condition": "Draft set exists."
  },
  {
    "method": "GET",
    "path": "/v1/appAssetLibraryPlacements/{copied_screenshot_placement_id}?include=image,appStoreVersionLocalization",
    "purpose": "pt-BR verify the placement belongs to the resolved draft localization and references a copied legacy image.",
    "repeat": "Each copied iPad 13-inch placement, expected 6."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_pt-BR_ipad-13_1}",
    "purpose": "pt-BR detach inherited iPad 13-inch placement 1.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_pt-BR_ipad-13_2}",
    "purpose": "pt-BR detach inherited iPad 13-inch placement 2.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_pt-BR_ipad-13_3}",
    "purpose": "pt-BR detach inherited iPad 13-inch placement 3.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_pt-BR_ipad-13_4}",
    "purpose": "pt-BR detach inherited iPad 13-inch placement 4.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_pt-BR_ipad-13_5}",
    "purpose": "pt-BR detach inherited iPad 13-inch placement 5.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_pt-BR_ipad-13_6}",
    "purpose": "pt-BR detach inherited iPad 13-inch placement 6.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "GET",
    "path": "/v1/appStoreVersionLocalizations/{localization_pt-BR}/appScreenshotSets?limit=200",
    "purpose": "pt-BR resolve the target iPad 13-inch set after removal."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshotSets",
    "purpose": "pt-BR create the iPad 13-inch set if absent",
    "body": {
      "data": {
        "type": "appScreenshotSets",
        "attributes": {
          "screenshotDisplayType": "APP_IPAD_PRO_3GEN_129"
        },
        "relationships": {
          "appStoreVersionLocalization": {
            "data": {
              "type": "appStoreVersionLocalizations",
              "id": "{localization_pt-BR}"
            }
          }
        }
      }
    },
    "condition": "Verified draft set is absent.",
    "saveIdAs": "{set_pt-BR_ipad-13}"
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "pt-BR reserve iPad 13-inch screenshot 1",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "01-feedback.png",
          "fileSize": 3427886
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_pt-BR_ipad-13}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_pt-BR_ipad-13_1}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/pt-BR/ipad-13/01-feedback.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_pt-BR_ipad-13_1}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_pt-BR_ipad-13_1}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "1732e4b38506551f0e6dc3f32a91d991"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_pt-BR_ipad-13_1}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "pt-BR reserve iPad 13-inch screenshot 2",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "02-review-ticket.png",
          "fileSize": 3230651
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_pt-BR_ipad-13}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_pt-BR_ipad-13_2}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/pt-BR/ipad-13/02-review-ticket.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_pt-BR_ipad-13_2}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_pt-BR_ipad-13_2}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "cf0d63b0fb860fbfdf45ffab4cacc6b5"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_pt-BR_ipad-13_2}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "pt-BR reserve iPad 13-inch screenshot 3",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "03-hint.png",
          "fileSize": 4077731
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_pt-BR_ipad-13}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_pt-BR_ipad-13_3}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/pt-BR/ipad-13/03-hint.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_pt-BR_ipad-13_3}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_pt-BR_ipad-13_3}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "a787e7425867bca247c61cb7c06f7842"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_pt-BR_ipad-13_3}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "pt-BR reserve iPad 13-inch screenshot 4",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "04-film.png",
          "fileSize": 2833113
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_pt-BR_ipad-13}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_pt-BR_ipad-13_4}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/pt-BR/ipad-13/04-film.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_pt-BR_ipad-13_4}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_pt-BR_ipad-13_4}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "5be5ab29b706d9e396f52cea9ca905af"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_pt-BR_ipad-13_4}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "pt-BR reserve iPad 13-inch screenshot 5",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "05-first-step.png",
          "fileSize": 5897258
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_pt-BR_ipad-13}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_pt-BR_ipad-13_5}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/pt-BR/ipad-13/05-first-step.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_pt-BR_ipad-13_5}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_pt-BR_ipad-13_5}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "072186ac6ebe938a0ced60416c236736"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_pt-BR_ipad-13_5}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "pt-BR reserve iPad 13-inch screenshot 6",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "06-monthly-mountains.png",
          "fileSize": 6862558
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_pt-BR_ipad-13}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_pt-BR_ipad-13_6}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/pt-BR/ipad-13/06-monthly-mountains.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_pt-BR_ipad-13_6}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_pt-BR_ipad-13_6}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "311111bbf8bd9a1c22d52e0b0a3a44dd"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_pt-BR_ipad-13_6}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshotSets/{set_pt-BR_ipad-13}/relationships/appScreenshots",
    "purpose": "pt-BR set iPad 13-inch order 01–06.",
    "body": {
      "data": [
        {
          "type": "appScreenshots",
          "id": "{screenshot_pt-BR_ipad-13_1}"
        },
        {
          "type": "appScreenshots",
          "id": "{screenshot_pt-BR_ipad-13_2}"
        },
        {
          "type": "appScreenshots",
          "id": "{screenshot_pt-BR_ipad-13_3}"
        },
        {
          "type": "appScreenshots",
          "id": "{screenshot_pt-BR_ipad-13_4}"
        },
        {
          "type": "appScreenshots",
          "id": "{screenshot_pt-BR_ipad-13_5}"
        },
        {
          "type": "appScreenshots",
          "id": "{screenshot_pt-BR_ipad-13_6}"
        }
      ]
    }
  },
  {
    "method": "GET",
    "path": "/v1/appStoreVersionLocalizations/{localization_ja}/appScreenshotSets?limit=200",
    "purpose": "ja read copied screenshot sets."
  },
  {
    "method": "GET",
    "path": "/v1/appStoreVersionLocalizations/{localization_ja}/placements?limit=200",
    "purpose": "ja read copied draft placements."
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshotSets/{set_ja_iphone-6.9}/appScreenshots?limit=200",
    "purpose": "ja compare the copied filenames and MD5 values with the live baseline for iPhone 6.9-inch.",
    "condition": "Draft set exists."
  },
  {
    "method": "GET",
    "path": "/v1/appAssetLibraryPlacements/{copied_screenshot_placement_id}?include=image,appStoreVersionLocalization",
    "purpose": "ja verify the placement belongs to the resolved draft localization and references a copied legacy image.",
    "repeat": "Each copied iPhone 6.9-inch placement, expected 8."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_ja_iphone-6.9_1}",
    "purpose": "ja detach inherited iPhone 6.9-inch placement 1.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_ja_iphone-6.9_2}",
    "purpose": "ja detach inherited iPhone 6.9-inch placement 2.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_ja_iphone-6.9_3}",
    "purpose": "ja detach inherited iPhone 6.9-inch placement 3.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_ja_iphone-6.9_4}",
    "purpose": "ja detach inherited iPhone 6.9-inch placement 4.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_ja_iphone-6.9_5}",
    "purpose": "ja detach inherited iPhone 6.9-inch placement 5.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_ja_iphone-6.9_6}",
    "purpose": "ja detach inherited iPhone 6.9-inch placement 6.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_ja_iphone-6.9_7}",
    "purpose": "ja detach inherited iPhone 6.9-inch placement 7.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_ja_iphone-6.9_8}",
    "purpose": "ja detach inherited iPhone 6.9-inch placement 8.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "GET",
    "path": "/v1/appStoreVersionLocalizations/{localization_ja}/appScreenshotSets?limit=200",
    "purpose": "ja resolve the target iPhone 6.9-inch set after removal."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshotSets",
    "purpose": "ja create the iPhone 6.9-inch set if absent",
    "body": {
      "data": {
        "type": "appScreenshotSets",
        "attributes": {
          "screenshotDisplayType": "APP_IPHONE_67"
        },
        "relationships": {
          "appStoreVersionLocalization": {
            "data": {
              "type": "appStoreVersionLocalizations",
              "id": "{localization_ja}"
            }
          }
        }
      }
    },
    "condition": "Verified draft set is absent.",
    "saveIdAs": "{set_ja_iphone-6.9}"
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "ja reserve iPhone 6.9-inch screenshot 1",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "01-feedback.png",
          "fileSize": 3138787
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_ja_iphone-6.9}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_ja_iphone-6.9_1}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/ja/iphone-6.9/01-feedback.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_ja_iphone-6.9_1}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_ja_iphone-6.9_1}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "50ca525438cd2f850bc3ee775b8c1ae1"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_ja_iphone-6.9_1}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "ja reserve iPhone 6.9-inch screenshot 2",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "02-review-ticket.png",
          "fileSize": 2946029
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_ja_iphone-6.9}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_ja_iphone-6.9_2}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/ja/iphone-6.9/02-review-ticket.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_ja_iphone-6.9_2}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_ja_iphone-6.9_2}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "7f4cb05cbc783c4b9886bd22c89a40e0"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_ja_iphone-6.9_2}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "ja reserve iPhone 6.9-inch screenshot 3",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "03-hint.png",
          "fileSize": 3934945
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_ja_iphone-6.9}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_ja_iphone-6.9_3}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/ja/iphone-6.9/03-hint.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_ja_iphone-6.9_3}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_ja_iphone-6.9_3}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "5a5d345ff97de523f05402b35642453c"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_ja_iphone-6.9_3}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "ja reserve iPhone 6.9-inch screenshot 4",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "04-film.png",
          "fileSize": 2836052
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_ja_iphone-6.9}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_ja_iphone-6.9_4}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/ja/iphone-6.9/04-film.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_ja_iphone-6.9_4}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_ja_iphone-6.9_4}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "c08e335942b2bc826c8f93c599bf8577"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_ja_iphone-6.9_4}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "ja reserve iPhone 6.9-inch screenshot 5",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "05-first-step.png",
          "fileSize": 3405519
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_ja_iphone-6.9}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_ja_iphone-6.9_5}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/ja/iphone-6.9/05-first-step.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_ja_iphone-6.9_5}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_ja_iphone-6.9_5}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "44be6e359d3a83f794c42866144dd108"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_ja_iphone-6.9_5}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "ja reserve iPhone 6.9-inch screenshot 6",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "06-monthly-mountains.png",
          "fileSize": 4776259
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_ja_iphone-6.9}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_ja_iphone-6.9_6}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/ja/iphone-6.9/06-monthly-mountains.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_ja_iphone-6.9_6}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_ja_iphone-6.9_6}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "c2914d93fb652c5861dee4a65c714c24"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_ja_iphone-6.9_6}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshotSets/{set_ja_iphone-6.9}/relationships/appScreenshots",
    "purpose": "ja set iPhone 6.9-inch order 01–06.",
    "body": {
      "data": [
        {
          "type": "appScreenshots",
          "id": "{screenshot_ja_iphone-6.9_1}"
        },
        {
          "type": "appScreenshots",
          "id": "{screenshot_ja_iphone-6.9_2}"
        },
        {
          "type": "appScreenshots",
          "id": "{screenshot_ja_iphone-6.9_3}"
        },
        {
          "type": "appScreenshots",
          "id": "{screenshot_ja_iphone-6.9_4}"
        },
        {
          "type": "appScreenshots",
          "id": "{screenshot_ja_iphone-6.9_5}"
        },
        {
          "type": "appScreenshots",
          "id": "{screenshot_ja_iphone-6.9_6}"
        }
      ]
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshotSets/{set_ja_ipad-13}/appScreenshots?limit=200",
    "purpose": "ja compare the copied filenames and MD5 values with the live baseline for iPad 13-inch.",
    "condition": "Draft set exists."
  },
  {
    "method": "GET",
    "path": "/v1/appAssetLibraryPlacements/{copied_screenshot_placement_id}?include=image,appStoreVersionLocalization",
    "purpose": "ja verify the placement belongs to the resolved draft localization and references a copied legacy image.",
    "repeat": "Each copied iPad 13-inch placement, expected 6."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_ja_ipad-13_1}",
    "purpose": "ja detach inherited iPad 13-inch placement 1.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_ja_ipad-13_2}",
    "purpose": "ja detach inherited iPad 13-inch placement 2.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_ja_ipad-13_3}",
    "purpose": "ja detach inherited iPad 13-inch placement 3.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_ja_ipad-13_4}",
    "purpose": "ja detach inherited iPad 13-inch placement 4.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_ja_ipad-13_5}",
    "purpose": "ja detach inherited iPad 13-inch placement 5.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_ja_ipad-13_6}",
    "purpose": "ja detach inherited iPad 13-inch placement 6.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "GET",
    "path": "/v1/appStoreVersionLocalizations/{localization_ja}/appScreenshotSets?limit=200",
    "purpose": "ja resolve the target iPad 13-inch set after removal."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshotSets",
    "purpose": "ja create the iPad 13-inch set if absent",
    "body": {
      "data": {
        "type": "appScreenshotSets",
        "attributes": {
          "screenshotDisplayType": "APP_IPAD_PRO_3GEN_129"
        },
        "relationships": {
          "appStoreVersionLocalization": {
            "data": {
              "type": "appStoreVersionLocalizations",
              "id": "{localization_ja}"
            }
          }
        }
      }
    },
    "condition": "Verified draft set is absent.",
    "saveIdAs": "{set_ja_ipad-13}"
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "ja reserve iPad 13-inch screenshot 1",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "01-feedback.png",
          "fileSize": 3441703
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_ja_ipad-13}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_ja_ipad-13_1}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/ja/ipad-13/01-feedback.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_ja_ipad-13_1}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_ja_ipad-13_1}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "41917da363dd38685746115bc46f77ca"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_ja_ipad-13_1}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "ja reserve iPad 13-inch screenshot 2",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "02-review-ticket.png",
          "fileSize": 3212437
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_ja_ipad-13}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_ja_ipad-13_2}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/ja/ipad-13/02-review-ticket.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_ja_ipad-13_2}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_ja_ipad-13_2}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "91791ae0b956624add952c95ef7205b9"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_ja_ipad-13_2}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "ja reserve iPad 13-inch screenshot 3",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "03-hint.png",
          "fileSize": 4112420
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_ja_ipad-13}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_ja_ipad-13_3}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/ja/ipad-13/03-hint.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_ja_ipad-13_3}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_ja_ipad-13_3}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "1929bdbe9cc067531744e358cb9e3f59"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_ja_ipad-13_3}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "ja reserve iPad 13-inch screenshot 4",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "04-film.png",
          "fileSize": 2819698
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_ja_ipad-13}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_ja_ipad-13_4}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/ja/ipad-13/04-film.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_ja_ipad-13_4}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_ja_ipad-13_4}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "2fe77af5da5378366510ea3ba9ea2242"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_ja_ipad-13_4}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "ja reserve iPad 13-inch screenshot 5",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "05-first-step.png",
          "fileSize": 5895719
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_ja_ipad-13}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_ja_ipad-13_5}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/ja/ipad-13/05-first-step.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_ja_ipad-13_5}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_ja_ipad-13_5}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "e8d4eb7f3b657fa20331592493316e70"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_ja_ipad-13_5}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "ja reserve iPad 13-inch screenshot 6",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "06-monthly-mountains.png",
          "fileSize": 6910508
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_ja_ipad-13}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_ja_ipad-13_6}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/ja/ipad-13/06-monthly-mountains.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_ja_ipad-13_6}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_ja_ipad-13_6}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "fdc88f59d1b8ff0d2ade7c50904008d4"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_ja_ipad-13_6}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshotSets/{set_ja_ipad-13}/relationships/appScreenshots",
    "purpose": "ja set iPad 13-inch order 01–06.",
    "body": {
      "data": [
        {
          "type": "appScreenshots",
          "id": "{screenshot_ja_ipad-13_1}"
        },
        {
          "type": "appScreenshots",
          "id": "{screenshot_ja_ipad-13_2}"
        },
        {
          "type": "appScreenshots",
          "id": "{screenshot_ja_ipad-13_3}"
        },
        {
          "type": "appScreenshots",
          "id": "{screenshot_ja_ipad-13_4}"
        },
        {
          "type": "appScreenshots",
          "id": "{screenshot_ja_ipad-13_5}"
        },
        {
          "type": "appScreenshots",
          "id": "{screenshot_ja_ipad-13_6}"
        }
      ]
    }
  },
  {
    "method": "GET",
    "path": "/v1/appStoreVersionLocalizations/{localization_ko}/appScreenshotSets?limit=200",
    "purpose": "ko read copied screenshot sets."
  },
  {
    "method": "GET",
    "path": "/v1/appStoreVersionLocalizations/{localization_ko}/placements?limit=200",
    "purpose": "ko read copied draft placements."
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshotSets/{set_ko_iphone-6.9}/appScreenshots?limit=200",
    "purpose": "ko compare the copied filenames and MD5 values with the live baseline for iPhone 6.9-inch.",
    "condition": "Draft set exists."
  },
  {
    "method": "GET",
    "path": "/v1/appAssetLibraryPlacements/{copied_screenshot_placement_id}?include=image,appStoreVersionLocalization",
    "purpose": "ko verify the placement belongs to the resolved draft localization and references a copied legacy image.",
    "repeat": "Each copied iPhone 6.9-inch placement, expected 8."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_ko_iphone-6.9_1}",
    "purpose": "ko detach inherited iPhone 6.9-inch placement 1.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_ko_iphone-6.9_2}",
    "purpose": "ko detach inherited iPhone 6.9-inch placement 2.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_ko_iphone-6.9_3}",
    "purpose": "ko detach inherited iPhone 6.9-inch placement 3.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_ko_iphone-6.9_4}",
    "purpose": "ko detach inherited iPhone 6.9-inch placement 4.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_ko_iphone-6.9_5}",
    "purpose": "ko detach inherited iPhone 6.9-inch placement 5.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_ko_iphone-6.9_6}",
    "purpose": "ko detach inherited iPhone 6.9-inch placement 6.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_ko_iphone-6.9_7}",
    "purpose": "ko detach inherited iPhone 6.9-inch placement 7.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_ko_iphone-6.9_8}",
    "purpose": "ko detach inherited iPhone 6.9-inch placement 8.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "GET",
    "path": "/v1/appStoreVersionLocalizations/{localization_ko}/appScreenshotSets?limit=200",
    "purpose": "ko resolve the target iPhone 6.9-inch set after removal."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshotSets",
    "purpose": "ko create the iPhone 6.9-inch set if absent",
    "body": {
      "data": {
        "type": "appScreenshotSets",
        "attributes": {
          "screenshotDisplayType": "APP_IPHONE_67"
        },
        "relationships": {
          "appStoreVersionLocalization": {
            "data": {
              "type": "appStoreVersionLocalizations",
              "id": "{localization_ko}"
            }
          }
        }
      }
    },
    "condition": "Verified draft set is absent.",
    "saveIdAs": "{set_ko_iphone-6.9}"
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "ko reserve iPhone 6.9-inch screenshot 1",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "01-feedback.png",
          "fileSize": 3071260
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_ko_iphone-6.9}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_ko_iphone-6.9_1}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/ko/iphone-6.9/01-feedback.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_ko_iphone-6.9_1}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_ko_iphone-6.9_1}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "44ce0a7402ffbc92f86b17f152fc2b5b"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_ko_iphone-6.9_1}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "ko reserve iPhone 6.9-inch screenshot 2",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "02-review-ticket.png",
          "fileSize": 2897250
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_ko_iphone-6.9}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_ko_iphone-6.9_2}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/ko/iphone-6.9/02-review-ticket.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_ko_iphone-6.9_2}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_ko_iphone-6.9_2}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "6ccc4d067ffaab856b3c15912193db6b"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_ko_iphone-6.9_2}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "ko reserve iPhone 6.9-inch screenshot 3",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "03-hint.png",
          "fileSize": 3875712
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_ko_iphone-6.9}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_ko_iphone-6.9_3}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/ko/iphone-6.9/03-hint.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_ko_iphone-6.9_3}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_ko_iphone-6.9_3}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "b59f643b2421799a265f890ab3810d60"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_ko_iphone-6.9_3}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "ko reserve iPhone 6.9-inch screenshot 4",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "04-film.png",
          "fileSize": 2836943
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_ko_iphone-6.9}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_ko_iphone-6.9_4}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/ko/iphone-6.9/04-film.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_ko_iphone-6.9_4}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_ko_iphone-6.9_4}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "50f3c8e41b7feb29d0229297e4d19fbb"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_ko_iphone-6.9_4}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "ko reserve iPhone 6.9-inch screenshot 5",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "05-first-step.png",
          "fileSize": 3348527
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_ko_iphone-6.9}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_ko_iphone-6.9_5}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/ko/iphone-6.9/05-first-step.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_ko_iphone-6.9_5}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_ko_iphone-6.9_5}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "87eba1fec76e2b194ae64c63c358d9eb"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_ko_iphone-6.9_5}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "ko reserve iPhone 6.9-inch screenshot 6",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "06-monthly-mountains.png",
          "fileSize": 4715403
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_ko_iphone-6.9}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_ko_iphone-6.9_6}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/ko/iphone-6.9/06-monthly-mountains.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_ko_iphone-6.9_6}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_ko_iphone-6.9_6}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "a2950f4833333fc15ffc027f7ef53127"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_ko_iphone-6.9_6}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshotSets/{set_ko_iphone-6.9}/relationships/appScreenshots",
    "purpose": "ko set iPhone 6.9-inch order 01–06.",
    "body": {
      "data": [
        {
          "type": "appScreenshots",
          "id": "{screenshot_ko_iphone-6.9_1}"
        },
        {
          "type": "appScreenshots",
          "id": "{screenshot_ko_iphone-6.9_2}"
        },
        {
          "type": "appScreenshots",
          "id": "{screenshot_ko_iphone-6.9_3}"
        },
        {
          "type": "appScreenshots",
          "id": "{screenshot_ko_iphone-6.9_4}"
        },
        {
          "type": "appScreenshots",
          "id": "{screenshot_ko_iphone-6.9_5}"
        },
        {
          "type": "appScreenshots",
          "id": "{screenshot_ko_iphone-6.9_6}"
        }
      ]
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshotSets/{set_ko_ipad-13}/appScreenshots?limit=200",
    "purpose": "ko compare the copied filenames and MD5 values with the live baseline for iPad 13-inch.",
    "condition": "Draft set exists."
  },
  {
    "method": "GET",
    "path": "/v1/appAssetLibraryPlacements/{copied_screenshot_placement_id}?include=image,appStoreVersionLocalization",
    "purpose": "ko verify the placement belongs to the resolved draft localization and references a copied legacy image.",
    "repeat": "Each copied iPad 13-inch placement, expected 6."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_ko_ipad-13_1}",
    "purpose": "ko detach inherited iPad 13-inch placement 1.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_ko_ipad-13_2}",
    "purpose": "ko detach inherited iPad 13-inch placement 2.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_ko_ipad-13_3}",
    "purpose": "ko detach inherited iPad 13-inch placement 3.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_ko_ipad-13_4}",
    "purpose": "ko detach inherited iPad 13-inch placement 4.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_ko_ipad-13_5}",
    "purpose": "ko detach inherited iPad 13-inch placement 5.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_ko_ipad-13_6}",
    "purpose": "ko detach inherited iPad 13-inch placement 6.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "GET",
    "path": "/v1/appStoreVersionLocalizations/{localization_ko}/appScreenshotSets?limit=200",
    "purpose": "ko resolve the target iPad 13-inch set after removal."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshotSets",
    "purpose": "ko create the iPad 13-inch set if absent",
    "body": {
      "data": {
        "type": "appScreenshotSets",
        "attributes": {
          "screenshotDisplayType": "APP_IPAD_PRO_3GEN_129"
        },
        "relationships": {
          "appStoreVersionLocalization": {
            "data": {
              "type": "appStoreVersionLocalizations",
              "id": "{localization_ko}"
            }
          }
        }
      }
    },
    "condition": "Verified draft set is absent.",
    "saveIdAs": "{set_ko_ipad-13}"
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "ko reserve iPad 13-inch screenshot 1",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "01-feedback.png",
          "fileSize": 3386910
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_ko_ipad-13}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_ko_ipad-13_1}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/ko/ipad-13/01-feedback.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_ko_ipad-13_1}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_ko_ipad-13_1}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "539e10db4798539b27c1ae95b716c806"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_ko_ipad-13_1}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "ko reserve iPad 13-inch screenshot 2",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "02-review-ticket.png",
          "fileSize": 3165545
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_ko_ipad-13}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_ko_ipad-13_2}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/ko/ipad-13/02-review-ticket.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_ko_ipad-13_2}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_ko_ipad-13_2}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "9498779172382156df3c1e3532f4b4b6"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_ko_ipad-13_2}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "ko reserve iPad 13-inch screenshot 3",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "03-hint.png",
          "fileSize": 4062263
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_ko_ipad-13}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_ko_ipad-13_3}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/ko/ipad-13/03-hint.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_ko_ipad-13_3}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_ko_ipad-13_3}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "13f68fb37025f741de2532e1bac59427"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_ko_ipad-13_3}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "ko reserve iPad 13-inch screenshot 4",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "04-film.png",
          "fileSize": 2822901
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_ko_ipad-13}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_ko_ipad-13_4}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/ko/ipad-13/04-film.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_ko_ipad-13_4}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_ko_ipad-13_4}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "cf056d585b516fb74c2be62eddc688f6"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_ko_ipad-13_4}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "ko reserve iPad 13-inch screenshot 5",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "05-first-step.png",
          "fileSize": 5880424
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_ko_ipad-13}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_ko_ipad-13_5}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/ko/ipad-13/05-first-step.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_ko_ipad-13_5}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_ko_ipad-13_5}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "7eddeff4885ce2088d448eac25d74901"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_ko_ipad-13_5}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "ko reserve iPad 13-inch screenshot 6",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "06-monthly-mountains.png",
          "fileSize": 6854328
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_ko_ipad-13}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_ko_ipad-13_6}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/ko/ipad-13/06-monthly-mountains.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_ko_ipad-13_6}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_ko_ipad-13_6}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "e07672c285336580963b25ec372c759a"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_ko_ipad-13_6}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshotSets/{set_ko_ipad-13}/relationships/appScreenshots",
    "purpose": "ko set iPad 13-inch order 01–06.",
    "body": {
      "data": [
        {
          "type": "appScreenshots",
          "id": "{screenshot_ko_ipad-13_1}"
        },
        {
          "type": "appScreenshots",
          "id": "{screenshot_ko_ipad-13_2}"
        },
        {
          "type": "appScreenshots",
          "id": "{screenshot_ko_ipad-13_3}"
        },
        {
          "type": "appScreenshots",
          "id": "{screenshot_ko_ipad-13_4}"
        },
        {
          "type": "appScreenshots",
          "id": "{screenshot_ko_ipad-13_5}"
        },
        {
          "type": "appScreenshots",
          "id": "{screenshot_ko_ipad-13_6}"
        }
      ]
    }
  },
  {
    "method": "GET",
    "path": "/v1/appStoreVersionLocalizations/{localization_ar-SA}/appScreenshotSets?limit=200",
    "purpose": "ar-SA read copied screenshot sets."
  },
  {
    "method": "GET",
    "path": "/v1/appStoreVersionLocalizations/{localization_ar-SA}/placements?limit=200",
    "purpose": "ar-SA read copied draft placements."
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshotSets/{set_ar-SA_iphone-6.9}/appScreenshots?limit=200",
    "purpose": "ar-SA compare the copied filenames and MD5 values with the live baseline for iPhone 6.9-inch.",
    "condition": "Draft set exists."
  },
  {
    "method": "GET",
    "path": "/v1/appAssetLibraryPlacements/{copied_screenshot_placement_id}?include=image,appStoreVersionLocalization",
    "purpose": "ar-SA verify the placement belongs to the resolved draft localization and references a copied legacy image.",
    "repeat": "Each copied iPhone 6.9-inch placement, expected 8."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_ar-SA_iphone-6.9_1}",
    "purpose": "ar-SA detach inherited iPhone 6.9-inch placement 1.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_ar-SA_iphone-6.9_2}",
    "purpose": "ar-SA detach inherited iPhone 6.9-inch placement 2.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_ar-SA_iphone-6.9_3}",
    "purpose": "ar-SA detach inherited iPhone 6.9-inch placement 3.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_ar-SA_iphone-6.9_4}",
    "purpose": "ar-SA detach inherited iPhone 6.9-inch placement 4.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_ar-SA_iphone-6.9_5}",
    "purpose": "ar-SA detach inherited iPhone 6.9-inch placement 5.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_ar-SA_iphone-6.9_6}",
    "purpose": "ar-SA detach inherited iPhone 6.9-inch placement 6.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_ar-SA_iphone-6.9_7}",
    "purpose": "ar-SA detach inherited iPhone 6.9-inch placement 7.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_ar-SA_iphone-6.9_8}",
    "purpose": "ar-SA detach inherited iPhone 6.9-inch placement 8.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "GET",
    "path": "/v1/appStoreVersionLocalizations/{localization_ar-SA}/appScreenshotSets?limit=200",
    "purpose": "ar-SA resolve the target iPhone 6.9-inch set after removal."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshotSets",
    "purpose": "ar-SA create the iPhone 6.9-inch set if absent",
    "body": {
      "data": {
        "type": "appScreenshotSets",
        "attributes": {
          "screenshotDisplayType": "APP_IPHONE_67"
        },
        "relationships": {
          "appStoreVersionLocalization": {
            "data": {
              "type": "appStoreVersionLocalizations",
              "id": "{localization_ar-SA}"
            }
          }
        }
      }
    },
    "condition": "Verified draft set is absent.",
    "saveIdAs": "{set_ar-SA_iphone-6.9}"
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "ar-SA reserve iPhone 6.9-inch screenshot 1",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "01-feedback.png",
          "fileSize": 3162334
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_ar-SA_iphone-6.9}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_ar-SA_iphone-6.9_1}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/ar/iphone-6.9/01-feedback.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_ar-SA_iphone-6.9_1}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_ar-SA_iphone-6.9_1}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "23fb492b4f2d1d06997c840586e9c9ae"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_ar-SA_iphone-6.9_1}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "ar-SA reserve iPhone 6.9-inch screenshot 2",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "02-review-ticket.png",
          "fileSize": 3007038
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_ar-SA_iphone-6.9}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_ar-SA_iphone-6.9_2}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/ar/iphone-6.9/02-review-ticket.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_ar-SA_iphone-6.9_2}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_ar-SA_iphone-6.9_2}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "372b0baec62bec9822f23e9339e6301a"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_ar-SA_iphone-6.9_2}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "ar-SA reserve iPhone 6.9-inch screenshot 3",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "03-hint.png",
          "fileSize": 3939125
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_ar-SA_iphone-6.9}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_ar-SA_iphone-6.9_3}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/ar/iphone-6.9/03-hint.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_ar-SA_iphone-6.9_3}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_ar-SA_iphone-6.9_3}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "a0a9d0452f4aa1b2592c9b3481b77005"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_ar-SA_iphone-6.9_3}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "ar-SA reserve iPhone 6.9-inch screenshot 4",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "04-film.png",
          "fileSize": 2881261
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_ar-SA_iphone-6.9}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_ar-SA_iphone-6.9_4}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/ar/iphone-6.9/04-film.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_ar-SA_iphone-6.9_4}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_ar-SA_iphone-6.9_4}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "3437308aafd10cd439460b6353a25f58"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_ar-SA_iphone-6.9_4}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "ar-SA reserve iPhone 6.9-inch screenshot 5",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "05-first-step.png",
          "fileSize": 3423714
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_ar-SA_iphone-6.9}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_ar-SA_iphone-6.9_5}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/ar/iphone-6.9/05-first-step.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_ar-SA_iphone-6.9_5}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_ar-SA_iphone-6.9_5}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "6f2ffb8b7de944305078380054900320"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_ar-SA_iphone-6.9_5}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "ar-SA reserve iPhone 6.9-inch screenshot 6",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "06-monthly-mountains.png",
          "fileSize": 4792549
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_ar-SA_iphone-6.9}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_ar-SA_iphone-6.9_6}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/ar/iphone-6.9/06-monthly-mountains.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_ar-SA_iphone-6.9_6}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_ar-SA_iphone-6.9_6}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "a130f11c05cf5460fc9556db2ab40193"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_ar-SA_iphone-6.9_6}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshotSets/{set_ar-SA_iphone-6.9}/relationships/appScreenshots",
    "purpose": "ar-SA set iPhone 6.9-inch order 01–06.",
    "body": {
      "data": [
        {
          "type": "appScreenshots",
          "id": "{screenshot_ar-SA_iphone-6.9_1}"
        },
        {
          "type": "appScreenshots",
          "id": "{screenshot_ar-SA_iphone-6.9_2}"
        },
        {
          "type": "appScreenshots",
          "id": "{screenshot_ar-SA_iphone-6.9_3}"
        },
        {
          "type": "appScreenshots",
          "id": "{screenshot_ar-SA_iphone-6.9_4}"
        },
        {
          "type": "appScreenshots",
          "id": "{screenshot_ar-SA_iphone-6.9_5}"
        },
        {
          "type": "appScreenshots",
          "id": "{screenshot_ar-SA_iphone-6.9_6}"
        }
      ]
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshotSets/{set_ar-SA_ipad-13}/appScreenshots?limit=200",
    "purpose": "ar-SA compare the copied filenames and MD5 values with the live baseline for iPad 13-inch.",
    "condition": "Draft set exists."
  },
  {
    "method": "GET",
    "path": "/v1/appAssetLibraryPlacements/{copied_screenshot_placement_id}?include=image,appStoreVersionLocalization",
    "purpose": "ar-SA verify the placement belongs to the resolved draft localization and references a copied legacy image.",
    "repeat": "Each copied iPad 13-inch placement, expected 6."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_ar-SA_ipad-13_1}",
    "purpose": "ar-SA detach inherited iPad 13-inch placement 1.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_ar-SA_ipad-13_2}",
    "purpose": "ar-SA detach inherited iPad 13-inch placement 2.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_ar-SA_ipad-13_3}",
    "purpose": "ar-SA detach inherited iPad 13-inch placement 3.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_ar-SA_ipad-13_4}",
    "purpose": "ar-SA detach inherited iPad 13-inch placement 4.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_ar-SA_ipad-13_5}",
    "purpose": "ar-SA detach inherited iPad 13-inch placement 5.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_ar-SA_ipad-13_6}",
    "purpose": "ar-SA detach inherited iPad 13-inch placement 6.",
    "condition": "Expected copied record present and verified; never delete a library image or a live placement."
  },
  {
    "method": "GET",
    "path": "/v1/appStoreVersionLocalizations/{localization_ar-SA}/appScreenshotSets?limit=200",
    "purpose": "ar-SA resolve the target iPad 13-inch set after removal."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshotSets",
    "purpose": "ar-SA create the iPad 13-inch set if absent",
    "body": {
      "data": {
        "type": "appScreenshotSets",
        "attributes": {
          "screenshotDisplayType": "APP_IPAD_PRO_3GEN_129"
        },
        "relationships": {
          "appStoreVersionLocalization": {
            "data": {
              "type": "appStoreVersionLocalizations",
              "id": "{localization_ar-SA}"
            }
          }
        }
      }
    },
    "condition": "Verified draft set is absent.",
    "saveIdAs": "{set_ar-SA_ipad-13}"
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "ar-SA reserve iPad 13-inch screenshot 1",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "01-feedback.png",
          "fileSize": 3460276
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_ar-SA_ipad-13}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_ar-SA_ipad-13_1}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/ar/ipad-13/01-feedback.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_ar-SA_ipad-13_1}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_ar-SA_ipad-13_1}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "aacc56a07570c00eb7b4641f7b893316"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_ar-SA_ipad-13_1}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "ar-SA reserve iPad 13-inch screenshot 2",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "02-review-ticket.png",
          "fileSize": 3235239
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_ar-SA_ipad-13}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_ar-SA_ipad-13_2}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/ar/ipad-13/02-review-ticket.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_ar-SA_ipad-13_2}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_ar-SA_ipad-13_2}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "8f0247d29e842b789d0d849734329b91"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_ar-SA_ipad-13_2}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "ar-SA reserve iPad 13-inch screenshot 3",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "03-hint.png",
          "fileSize": 4105678
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_ar-SA_ipad-13}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_ar-SA_ipad-13_3}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/ar/ipad-13/03-hint.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_ar-SA_ipad-13_3}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_ar-SA_ipad-13_3}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "d5b64c392d7effa6c9e7cade16a8b7d8"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_ar-SA_ipad-13_3}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "ar-SA reserve iPad 13-inch screenshot 4",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "04-film.png",
          "fileSize": 2889452
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_ar-SA_ipad-13}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_ar-SA_ipad-13_4}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/ar/ipad-13/04-film.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_ar-SA_ipad-13_4}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_ar-SA_ipad-13_4}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "afd2565fb6f1002216ecae65ca4176ea"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_ar-SA_ipad-13_4}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "ar-SA reserve iPad 13-inch screenshot 5",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "05-first-step.png",
          "fileSize": 5937638
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_ar-SA_ipad-13}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_ar-SA_ipad-13_5}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/ar/ipad-13/05-first-step.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_ar-SA_ipad-13_5}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_ar-SA_ipad-13_5}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "abf8f88d01a4592be84c32535562170e"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_ar-SA_ipad-13_5}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "POST",
    "path": "/v1/appScreenshots",
    "purpose": "ar-SA reserve iPad 13-inch screenshot 6",
    "body": {
      "data": {
        "type": "appScreenshots",
        "attributes": {
          "fileName": "06-monthly-mountains.png",
          "fileSize": 6958400
        },
        "relationships": {
          "appScreenshotSet": {
            "data": {
              "type": "appScreenshotSets",
              "id": "{set_ar-SA_ipad-13}"
            }
          }
        }
      }
    },
    "saveIdAs": "{screenshot_ar-SA_ipad-13_6}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload reservation parts in order.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/ar/ipad-13/06-monthly-mountains.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshots/{screenshot_ar-SA_ipad-13_6}",
    "purpose": "Commit the uploaded screenshot with its source MD5.",
    "body": {
      "data": {
        "type": "appScreenshots",
        "id": "{screenshot_ar-SA_ipad-13_6}",
        "attributes": {
          "uploaded": true,
          "sourceFileChecksum": "1a5721f75092f0704edec466d5909086"
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshots/{screenshot_ar-SA_ipad-13_6}",
    "purpose": "Poll until COMPLETE. Stop on FAILED.",
    "repeat": "Until terminal status."
  },
  {
    "method": "PATCH",
    "path": "/v1/appScreenshotSets/{set_ar-SA_ipad-13}/relationships/appScreenshots",
    "purpose": "ar-SA set iPad 13-inch order 01–06.",
    "body": {
      "data": [
        {
          "type": "appScreenshots",
          "id": "{screenshot_ar-SA_ipad-13_1}"
        },
        {
          "type": "appScreenshots",
          "id": "{screenshot_ar-SA_ipad-13_2}"
        },
        {
          "type": "appScreenshots",
          "id": "{screenshot_ar-SA_ipad-13_3}"
        },
        {
          "type": "appScreenshots",
          "id": "{screenshot_ar-SA_ipad-13_4}"
        },
        {
          "type": "appScreenshots",
          "id": "{screenshot_ar-SA_ipad-13_5}"
        },
        {
          "type": "appScreenshots",
          "id": "{screenshot_ar-SA_ipad-13_6}"
        }
      ]
    }
  },
  {
    "method": "POST",
    "path": "/v1/appAssetLibraryImages",
    "purpose": "Reserve one shared product page header in GrammarLens Asset Library.",
    "body": {
      "data": {
        "type": "appAssetLibraryImages",
        "attributes": {
          "category": "CREATIVE_ASSETS",
          "fileName": "header.png",
          "fileSize": 6433498,
          "referenceName": "GrammarLens 1.5.0 product page header"
        },
        "relationships": {
          "assetLibrary": {
            "data": {
              "type": "appAssetLibraries",
              "id": "6811477346"
            }
          }
        }
      }
    },
    "saveIdAs": "{header_image_1.5.0}"
  },
  {
    "method": "PUT",
    "path": "{upload_operation_URL}",
    "purpose": "Upload the shared header once.",
    "body": {
      "binaryFile": "screenshots/1.5.0/revizyon-11/product-page/header.png",
      "operationByteRange": true
    },
    "repeat": "All reservation operations."
  },
  {
    "method": "PATCH",
    "path": "/v1/appAssetLibraryImages/{header_image_1.5.0}",
    "purpose": "Commit the header upload.",
    "body": {
      "data": {
        "type": "appAssetLibraryImages",
        "id": "{header_image_1.5.0}",
        "attributes": {
          "uploaded": true
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appAssetLibraryImages/{header_image_1.5.0}",
    "purpose": "Verify the processed header and its 3840 × 1646 size.",
    "repeat": "Until processed or terminal error."
  },
  {
    "method": "GET",
    "path": "/v1/appStoreVersionLocalizations/{localization_en-US}/placements?limit=200",
    "purpose": "en-US resolve any copied draft header only."
  },
  {
    "method": "GET",
    "path": "/v1/appAssetLibraryPlacements/{copied_header_en-US}?include=image,appStoreVersionLocalization",
    "purpose": "en-US confirm the draft header and its baseline image.",
    "condition": "A copied draft header exists."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_header_en-US}",
    "purpose": "en-US detach the inherited draft header placement.",
    "condition": "Verified draft placement of the inherited header; retain the library image."
  },
  {
    "method": "POST",
    "path": "/v1/appAssetLibraryPlacements",
    "purpose": "en-US place the shared header on the 1.5.0 product page.",
    "body": {
      "data": {
        "type": "appAssetLibraryPlacements",
        "attributes": {
          "placementType": "PRODUCT_PAGE_HEADER_ASSET",
          "placementGroup": "DEFAULT_PROFILE"
        },
        "relationships": {
          "image": {
            "data": {
              "type": "appAssetLibraryImages",
              "id": "{header_image_1.5.0}"
            }
          },
          "appStoreVersionLocalization": {
            "data": {
              "type": "appStoreVersionLocalizations",
              "id": "{localization_en-US}"
            }
          }
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appStoreVersionLocalizations/{localization_tr}/placements?limit=200",
    "purpose": "tr resolve any copied draft header only."
  },
  {
    "method": "GET",
    "path": "/v1/appAssetLibraryPlacements/{copied_header_tr}?include=image,appStoreVersionLocalization",
    "purpose": "tr confirm the draft header and its baseline image.",
    "condition": "A copied draft header exists."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_header_tr}",
    "purpose": "tr detach the inherited draft header placement.",
    "condition": "Verified draft placement of the inherited header; retain the library image."
  },
  {
    "method": "POST",
    "path": "/v1/appAssetLibraryPlacements",
    "purpose": "tr place the shared header on the 1.5.0 product page.",
    "body": {
      "data": {
        "type": "appAssetLibraryPlacements",
        "attributes": {
          "placementType": "PRODUCT_PAGE_HEADER_ASSET",
          "placementGroup": "DEFAULT_PROFILE"
        },
        "relationships": {
          "image": {
            "data": {
              "type": "appAssetLibraryImages",
              "id": "{header_image_1.5.0}"
            }
          },
          "appStoreVersionLocalization": {
            "data": {
              "type": "appStoreVersionLocalizations",
              "id": "{localization_tr}"
            }
          }
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appStoreVersionLocalizations/{localization_de-DE}/placements?limit=200",
    "purpose": "de-DE resolve any copied draft header only."
  },
  {
    "method": "GET",
    "path": "/v1/appAssetLibraryPlacements/{copied_header_de-DE}?include=image,appStoreVersionLocalization",
    "purpose": "de-DE confirm the draft header and its baseline image.",
    "condition": "A copied draft header exists."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_header_de-DE}",
    "purpose": "de-DE detach the inherited draft header placement.",
    "condition": "Verified draft placement of the inherited header; retain the library image."
  },
  {
    "method": "POST",
    "path": "/v1/appAssetLibraryPlacements",
    "purpose": "de-DE place the shared header on the 1.5.0 product page.",
    "body": {
      "data": {
        "type": "appAssetLibraryPlacements",
        "attributes": {
          "placementType": "PRODUCT_PAGE_HEADER_ASSET",
          "placementGroup": "DEFAULT_PROFILE"
        },
        "relationships": {
          "image": {
            "data": {
              "type": "appAssetLibraryImages",
              "id": "{header_image_1.5.0}"
            }
          },
          "appStoreVersionLocalization": {
            "data": {
              "type": "appStoreVersionLocalizations",
              "id": "{localization_de-DE}"
            }
          }
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appStoreVersionLocalizations/{localization_es-MX}/placements?limit=200",
    "purpose": "es-MX resolve any copied draft header only."
  },
  {
    "method": "GET",
    "path": "/v1/appAssetLibraryPlacements/{copied_header_es-MX}?include=image,appStoreVersionLocalization",
    "purpose": "es-MX confirm the draft header and its baseline image.",
    "condition": "A copied draft header exists."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_header_es-MX}",
    "purpose": "es-MX detach the inherited draft header placement.",
    "condition": "Verified draft placement of the inherited header; retain the library image."
  },
  {
    "method": "POST",
    "path": "/v1/appAssetLibraryPlacements",
    "purpose": "es-MX place the shared header on the 1.5.0 product page.",
    "body": {
      "data": {
        "type": "appAssetLibraryPlacements",
        "attributes": {
          "placementType": "PRODUCT_PAGE_HEADER_ASSET",
          "placementGroup": "DEFAULT_PROFILE"
        },
        "relationships": {
          "image": {
            "data": {
              "type": "appAssetLibraryImages",
              "id": "{header_image_1.5.0}"
            }
          },
          "appStoreVersionLocalization": {
            "data": {
              "type": "appStoreVersionLocalizations",
              "id": "{localization_es-MX}"
            }
          }
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appStoreVersionLocalizations/{localization_pt-BR}/placements?limit=200",
    "purpose": "pt-BR resolve any copied draft header only."
  },
  {
    "method": "GET",
    "path": "/v1/appAssetLibraryPlacements/{copied_header_pt-BR}?include=image,appStoreVersionLocalization",
    "purpose": "pt-BR confirm the draft header and its baseline image.",
    "condition": "A copied draft header exists."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_header_pt-BR}",
    "purpose": "pt-BR detach the inherited draft header placement.",
    "condition": "Verified draft placement of the inherited header; retain the library image."
  },
  {
    "method": "POST",
    "path": "/v1/appAssetLibraryPlacements",
    "purpose": "pt-BR place the shared header on the 1.5.0 product page.",
    "body": {
      "data": {
        "type": "appAssetLibraryPlacements",
        "attributes": {
          "placementType": "PRODUCT_PAGE_HEADER_ASSET",
          "placementGroup": "DEFAULT_PROFILE"
        },
        "relationships": {
          "image": {
            "data": {
              "type": "appAssetLibraryImages",
              "id": "{header_image_1.5.0}"
            }
          },
          "appStoreVersionLocalization": {
            "data": {
              "type": "appStoreVersionLocalizations",
              "id": "{localization_pt-BR}"
            }
          }
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appStoreVersionLocalizations/{localization_ja}/placements?limit=200",
    "purpose": "ja resolve any copied draft header only."
  },
  {
    "method": "GET",
    "path": "/v1/appAssetLibraryPlacements/{copied_header_ja}?include=image,appStoreVersionLocalization",
    "purpose": "ja confirm the draft header and its baseline image.",
    "condition": "A copied draft header exists."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_header_ja}",
    "purpose": "ja detach the inherited draft header placement.",
    "condition": "Verified draft placement of the inherited header; retain the library image."
  },
  {
    "method": "POST",
    "path": "/v1/appAssetLibraryPlacements",
    "purpose": "ja place the shared header on the 1.5.0 product page.",
    "body": {
      "data": {
        "type": "appAssetLibraryPlacements",
        "attributes": {
          "placementType": "PRODUCT_PAGE_HEADER_ASSET",
          "placementGroup": "DEFAULT_PROFILE"
        },
        "relationships": {
          "image": {
            "data": {
              "type": "appAssetLibraryImages",
              "id": "{header_image_1.5.0}"
            }
          },
          "appStoreVersionLocalization": {
            "data": {
              "type": "appStoreVersionLocalizations",
              "id": "{localization_ja}"
            }
          }
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appStoreVersionLocalizations/{localization_ko}/placements?limit=200",
    "purpose": "ko resolve any copied draft header only."
  },
  {
    "method": "GET",
    "path": "/v1/appAssetLibraryPlacements/{copied_header_ko}?include=image,appStoreVersionLocalization",
    "purpose": "ko confirm the draft header and its baseline image.",
    "condition": "A copied draft header exists."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_header_ko}",
    "purpose": "ko detach the inherited draft header placement.",
    "condition": "Verified draft placement of the inherited header; retain the library image."
  },
  {
    "method": "POST",
    "path": "/v1/appAssetLibraryPlacements",
    "purpose": "ko place the shared header on the 1.5.0 product page.",
    "body": {
      "data": {
        "type": "appAssetLibraryPlacements",
        "attributes": {
          "placementType": "PRODUCT_PAGE_HEADER_ASSET",
          "placementGroup": "DEFAULT_PROFILE"
        },
        "relationships": {
          "image": {
            "data": {
              "type": "appAssetLibraryImages",
              "id": "{header_image_1.5.0}"
            }
          },
          "appStoreVersionLocalization": {
            "data": {
              "type": "appStoreVersionLocalizations",
              "id": "{localization_ko}"
            }
          }
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appStoreVersionLocalizations/{localization_ar-SA}/placements?limit=200",
    "purpose": "ar-SA resolve any copied draft header only."
  },
  {
    "method": "GET",
    "path": "/v1/appAssetLibraryPlacements/{copied_header_ar-SA}?include=image,appStoreVersionLocalization",
    "purpose": "ar-SA confirm the draft header and its baseline image.",
    "condition": "A copied draft header exists."
  },
  {
    "method": "DELETE",
    "path": "/v1/appAssetLibraryPlacements/{copied_header_ar-SA}",
    "purpose": "ar-SA detach the inherited draft header placement.",
    "condition": "Verified draft placement of the inherited header; retain the library image."
  },
  {
    "method": "POST",
    "path": "/v1/appAssetLibraryPlacements",
    "purpose": "ar-SA place the shared header on the 1.5.0 product page.",
    "body": {
      "data": {
        "type": "appAssetLibraryPlacements",
        "attributes": {
          "placementType": "PRODUCT_PAGE_HEADER_ASSET",
          "placementGroup": "DEFAULT_PROFILE"
        },
        "relationships": {
          "image": {
            "data": {
              "type": "appAssetLibraryImages",
              "id": "{header_image_1.5.0}"
            }
          },
          "appStoreVersionLocalization": {
            "data": {
              "type": "appStoreVersionLocalizations",
              "id": "{localization_ar-SA}"
            }
          }
        }
      }
    }
  },
  {
    "method": "GET",
    "path": "/v1/appStoreVersions/{version_1.5.0}",
    "purpose": "Read final version, PREPARE_FOR_SUBMISSION and MANUAL."
  },
  {
    "method": "GET",
    "path": "/v1/appStoreVersions/{version_1.5.0}/build",
    "purpose": "Read attached build and verify build 8 and VALID."
  },
  {
    "method": "GET",
    "path": "/v1/apps/6811477346/appInfos?limit=200",
    "purpose": "Resolve the applicable app information without making changes."
  },
  {
    "method": "GET",
    "path": "/v1/appInfos/{app_info_id}/appInfoLocalizations?limit=200",
    "purpose": "Read unchanged name, subtitle and privacy policy URL."
  },
  {
    "method": "GET",
    "path": "/v1/appStoreVersions/{version_1.5.0}/appStoreVersionLocalizations?limit=200",
    "purpose": "Compare exact descriptions and what’s new. Verify untouched fields against the baseline and the source."
  },
  {
    "method": "GET",
    "path": "/v1/appStoreVersionLocalizations/{localization_en-US}/appScreenshotSets?limit=200",
    "purpose": "en-US verify screenshot sets."
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshotSets/{set_en-US_iphone-6.9}/relationships/appScreenshots?limit=200",
    "purpose": "en-US verify iPhone 6.9-inch order."
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshotSets/{set_en-US_iphone-6.9}/appScreenshots?limit=200",
    "purpose": "en-US verify six source filenames, MD5 values and COMPLETE states."
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshotSets/{set_en-US_ipad-13}/relationships/appScreenshots?limit=200",
    "purpose": "en-US verify iPad 13-inch order."
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshotSets/{set_en-US_ipad-13}/appScreenshots?limit=200",
    "purpose": "en-US verify six source filenames, MD5 values and COMPLETE states."
  },
  {
    "method": "GET",
    "path": "/v1/appStoreVersionLocalizations/{localization_en-US}/placements?limit=200",
    "purpose": "en-US verify the draft header and screenshot placements."
  },
  {
    "method": "GET",
    "path": "/v1/appAssetLibraryPlacements/{header_placement_en-US}?include=image",
    "purpose": "en-US verify the associated shared header image ID."
  },
  {
    "method": "GET",
    "path": "/v1/appStoreVersionLocalizations/{localization_tr}/appScreenshotSets?limit=200",
    "purpose": "tr verify screenshot sets."
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshotSets/{set_tr_iphone-6.9}/relationships/appScreenshots?limit=200",
    "purpose": "tr verify iPhone 6.9-inch order."
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshotSets/{set_tr_iphone-6.9}/appScreenshots?limit=200",
    "purpose": "tr verify six source filenames, MD5 values and COMPLETE states."
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshotSets/{set_tr_ipad-13}/relationships/appScreenshots?limit=200",
    "purpose": "tr verify iPad 13-inch order."
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshotSets/{set_tr_ipad-13}/appScreenshots?limit=200",
    "purpose": "tr verify six source filenames, MD5 values and COMPLETE states."
  },
  {
    "method": "GET",
    "path": "/v1/appStoreVersionLocalizations/{localization_tr}/placements?limit=200",
    "purpose": "tr verify the draft header and screenshot placements."
  },
  {
    "method": "GET",
    "path": "/v1/appAssetLibraryPlacements/{header_placement_tr}?include=image",
    "purpose": "tr verify the associated shared header image ID."
  },
  {
    "method": "GET",
    "path": "/v1/appStoreVersionLocalizations/{localization_de-DE}/appScreenshotSets?limit=200",
    "purpose": "de-DE verify screenshot sets."
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshotSets/{set_de-DE_iphone-6.9}/relationships/appScreenshots?limit=200",
    "purpose": "de-DE verify iPhone 6.9-inch order."
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshotSets/{set_de-DE_iphone-6.9}/appScreenshots?limit=200",
    "purpose": "de-DE verify six source filenames, MD5 values and COMPLETE states."
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshotSets/{set_de-DE_ipad-13}/relationships/appScreenshots?limit=200",
    "purpose": "de-DE verify iPad 13-inch order."
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshotSets/{set_de-DE_ipad-13}/appScreenshots?limit=200",
    "purpose": "de-DE verify six source filenames, MD5 values and COMPLETE states."
  },
  {
    "method": "GET",
    "path": "/v1/appStoreVersionLocalizations/{localization_de-DE}/placements?limit=200",
    "purpose": "de-DE verify the draft header and screenshot placements."
  },
  {
    "method": "GET",
    "path": "/v1/appAssetLibraryPlacements/{header_placement_de-DE}?include=image",
    "purpose": "de-DE verify the associated shared header image ID."
  },
  {
    "method": "GET",
    "path": "/v1/appStoreVersionLocalizations/{localization_es-MX}/appScreenshotSets?limit=200",
    "purpose": "es-MX verify screenshot sets."
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshotSets/{set_es-MX_iphone-6.9}/relationships/appScreenshots?limit=200",
    "purpose": "es-MX verify iPhone 6.9-inch order."
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshotSets/{set_es-MX_iphone-6.9}/appScreenshots?limit=200",
    "purpose": "es-MX verify six source filenames, MD5 values and COMPLETE states."
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshotSets/{set_es-MX_ipad-13}/relationships/appScreenshots?limit=200",
    "purpose": "es-MX verify iPad 13-inch order."
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshotSets/{set_es-MX_ipad-13}/appScreenshots?limit=200",
    "purpose": "es-MX verify six source filenames, MD5 values and COMPLETE states."
  },
  {
    "method": "GET",
    "path": "/v1/appStoreVersionLocalizations/{localization_es-MX}/placements?limit=200",
    "purpose": "es-MX verify the draft header and screenshot placements."
  },
  {
    "method": "GET",
    "path": "/v1/appAssetLibraryPlacements/{header_placement_es-MX}?include=image",
    "purpose": "es-MX verify the associated shared header image ID."
  },
  {
    "method": "GET",
    "path": "/v1/appStoreVersionLocalizations/{localization_pt-BR}/appScreenshotSets?limit=200",
    "purpose": "pt-BR verify screenshot sets."
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshotSets/{set_pt-BR_iphone-6.9}/relationships/appScreenshots?limit=200",
    "purpose": "pt-BR verify iPhone 6.9-inch order."
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshotSets/{set_pt-BR_iphone-6.9}/appScreenshots?limit=200",
    "purpose": "pt-BR verify six source filenames, MD5 values and COMPLETE states."
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshotSets/{set_pt-BR_ipad-13}/relationships/appScreenshots?limit=200",
    "purpose": "pt-BR verify iPad 13-inch order."
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshotSets/{set_pt-BR_ipad-13}/appScreenshots?limit=200",
    "purpose": "pt-BR verify six source filenames, MD5 values and COMPLETE states."
  },
  {
    "method": "GET",
    "path": "/v1/appStoreVersionLocalizations/{localization_pt-BR}/placements?limit=200",
    "purpose": "pt-BR verify the draft header and screenshot placements."
  },
  {
    "method": "GET",
    "path": "/v1/appAssetLibraryPlacements/{header_placement_pt-BR}?include=image",
    "purpose": "pt-BR verify the associated shared header image ID."
  },
  {
    "method": "GET",
    "path": "/v1/appStoreVersionLocalizations/{localization_ja}/appScreenshotSets?limit=200",
    "purpose": "ja verify screenshot sets."
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshotSets/{set_ja_iphone-6.9}/relationships/appScreenshots?limit=200",
    "purpose": "ja verify iPhone 6.9-inch order."
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshotSets/{set_ja_iphone-6.9}/appScreenshots?limit=200",
    "purpose": "ja verify six source filenames, MD5 values and COMPLETE states."
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshotSets/{set_ja_ipad-13}/relationships/appScreenshots?limit=200",
    "purpose": "ja verify iPad 13-inch order."
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshotSets/{set_ja_ipad-13}/appScreenshots?limit=200",
    "purpose": "ja verify six source filenames, MD5 values and COMPLETE states."
  },
  {
    "method": "GET",
    "path": "/v1/appStoreVersionLocalizations/{localization_ja}/placements?limit=200",
    "purpose": "ja verify the draft header and screenshot placements."
  },
  {
    "method": "GET",
    "path": "/v1/appAssetLibraryPlacements/{header_placement_ja}?include=image",
    "purpose": "ja verify the associated shared header image ID."
  },
  {
    "method": "GET",
    "path": "/v1/appStoreVersionLocalizations/{localization_ko}/appScreenshotSets?limit=200",
    "purpose": "ko verify screenshot sets."
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshotSets/{set_ko_iphone-6.9}/relationships/appScreenshots?limit=200",
    "purpose": "ko verify iPhone 6.9-inch order."
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshotSets/{set_ko_iphone-6.9}/appScreenshots?limit=200",
    "purpose": "ko verify six source filenames, MD5 values and COMPLETE states."
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshotSets/{set_ko_ipad-13}/relationships/appScreenshots?limit=200",
    "purpose": "ko verify iPad 13-inch order."
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshotSets/{set_ko_ipad-13}/appScreenshots?limit=200",
    "purpose": "ko verify six source filenames, MD5 values and COMPLETE states."
  },
  {
    "method": "GET",
    "path": "/v1/appStoreVersionLocalizations/{localization_ko}/placements?limit=200",
    "purpose": "ko verify the draft header and screenshot placements."
  },
  {
    "method": "GET",
    "path": "/v1/appAssetLibraryPlacements/{header_placement_ko}?include=image",
    "purpose": "ko verify the associated shared header image ID."
  },
  {
    "method": "GET",
    "path": "/v1/appStoreVersionLocalizations/{localization_ar-SA}/appScreenshotSets?limit=200",
    "purpose": "ar-SA verify screenshot sets."
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshotSets/{set_ar-SA_iphone-6.9}/relationships/appScreenshots?limit=200",
    "purpose": "ar-SA verify iPhone 6.9-inch order."
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshotSets/{set_ar-SA_iphone-6.9}/appScreenshots?limit=200",
    "purpose": "ar-SA verify six source filenames, MD5 values and COMPLETE states."
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshotSets/{set_ar-SA_ipad-13}/relationships/appScreenshots?limit=200",
    "purpose": "ar-SA verify iPad 13-inch order."
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshotSets/{set_ar-SA_ipad-13}/appScreenshots?limit=200",
    "purpose": "ar-SA verify six source filenames, MD5 values and COMPLETE states."
  },
  {
    "method": "GET",
    "path": "/v1/appStoreVersionLocalizations/{localization_ar-SA}/placements?limit=200",
    "purpose": "ar-SA verify the draft header and screenshot placements."
  },
  {
    "method": "GET",
    "path": "/v1/appAssetLibraryPlacements/{header_placement_ar-SA}?include=image",
    "purpose": "ar-SA verify the associated shared header image ID."
  },
  {
    "method": "GET",
    "path": "/v1/appStoreVersions/{version_1.5.0}/appStoreReviewDetail",
    "purpose": "Compare notes exactly and verify review contact and demo account flag against the draft baseline."
  },
  {
    "method": "GET",
    "path": "/v1/appStoreReviewDetails/{review_detail_1.5.0}/appStoreReviewAttachments?limit=200",
    "purpose": "Confirm attachments are unchanged."
  },
  {
    "method": "GET",
    "path": "/v1/appStoreVersions/23d20cb5-2df3-49c4-b3c6-841cd080a576",
    "purpose": "Verify 1.4.0 remains live."
  },
  {
    "method": "GET",
    "path": "/v1/appStoreVersions/23d20cb5-2df3-49c4-b3c6-841cd080a576/appStoreVersionLocalizations?limit=200",
    "purpose": "Verify live localization counts."
  },
  {
    "method": "GET",
    "path": "/v1/appStoreVersionLocalizations/a741abc3-8025-45b2-9c7e-8362156d87d4/appScreenshotSets?limit=200",
    "purpose": "ar-SA verify the live set identities and counts."
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshotSets/1970c4cc-5f5d-413c-818d-f84465d05f2c/appScreenshots?limit=200",
    "purpose": "ar-SA verify the live screenshot count for APP_IPAD_PRO_3GEN_129."
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshotSets/b9def353-5192-4da0-8484-f9166a02fee5/appScreenshots?limit=200",
    "purpose": "ar-SA verify the live screenshot count for APP_IPHONE_67."
  },
  {
    "method": "GET",
    "path": "/v1/appStoreVersionLocalizations/9c4a2cfe-bd96-4ee7-b37f-d9e778d16fa2/appScreenshotSets?limit=200",
    "purpose": "de-DE verify the live set identities and counts."
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshotSets/c08e3bb5-28e9-4745-8d0d-a1bb32f72e21/appScreenshots?limit=200",
    "purpose": "de-DE verify the live screenshot count for APP_IPHONE_67."
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshotSets/1b99cee2-faf0-470c-b1ff-e99b018fdcc8/appScreenshots?limit=200",
    "purpose": "de-DE verify the live screenshot count for APP_IPAD_PRO_3GEN_129."
  },
  {
    "method": "GET",
    "path": "/v1/appStoreVersionLocalizations/6d01380e-710f-48c4-80c3-1079cc96e9c0/appScreenshotSets?limit=200",
    "purpose": "pt-BR verify the live set identities and counts."
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshotSets/fc70e24c-5368-412c-b137-858cd0ea1b22/appScreenshots?limit=200",
    "purpose": "pt-BR verify the live screenshot count for APP_IPAD_PRO_3GEN_129."
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshotSets/9c8fae03-4f5d-4935-b8d5-4892d8f8142a/appScreenshots?limit=200",
    "purpose": "pt-BR verify the live screenshot count for APP_IPHONE_67."
  },
  {
    "method": "GET",
    "path": "/v1/appStoreVersionLocalizations/39426655-dc45-44a6-9cdb-c583ecdda1e7/appScreenshotSets?limit=200",
    "purpose": "ko verify the live set identities and counts."
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshotSets/2074c8b6-185d-4e7b-8230-e7ff665bad9e/appScreenshots?limit=200",
    "purpose": "ko verify the live screenshot count for APP_IPAD_PRO_3GEN_129."
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshotSets/3d717489-d61c-41f4-8b00-359b2abc00f0/appScreenshots?limit=200",
    "purpose": "ko verify the live screenshot count for APP_IPHONE_67."
  },
  {
    "method": "GET",
    "path": "/v1/appStoreVersionLocalizations/207797dd-54bd-480e-be43-41ef1c6bac66/appScreenshotSets?limit=200",
    "purpose": "en-US verify the live set identities and counts."
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshotSets/b0718bd9-af23-4d9c-afa4-a99e123042c5/appScreenshots?limit=200",
    "purpose": "en-US verify the live screenshot count for APP_IPAD_PRO_3GEN_129."
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshotSets/33233b78-2a58-407c-9ff7-6bd2a5d3aa1f/appScreenshots?limit=200",
    "purpose": "en-US verify the live screenshot count for APP_IPHONE_67."
  },
  {
    "method": "GET",
    "path": "/v1/appStoreVersionLocalizations/b704a413-2638-4cdf-a8a6-7e4524012aef/appScreenshotSets?limit=200",
    "purpose": "ja verify the live set identities and counts."
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshotSets/51433d31-5093-4c11-9327-fa61a0521027/appScreenshots?limit=200",
    "purpose": "ja verify the live screenshot count for APP_IPAD_PRO_3GEN_129."
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshotSets/1cc8dba1-c41f-4fda-9f31-aeb50f7e62e4/appScreenshots?limit=200",
    "purpose": "ja verify the live screenshot count for APP_IPHONE_67."
  },
  {
    "method": "GET",
    "path": "/v1/appStoreVersionLocalizations/f2380dc1-9551-4863-afb3-c6dd6496e0f3/appScreenshotSets?limit=200",
    "purpose": "tr verify the live set identities and counts."
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshotSets/319baee9-6fd6-4e80-812c-097142bf5fcb/appScreenshots?limit=200",
    "purpose": "tr verify the live screenshot count for APP_IPHONE_67."
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshotSets/eba258fc-84be-4cd5-8338-51f6a4532c64/appScreenshots?limit=200",
    "purpose": "tr verify the live screenshot count for APP_IPAD_PRO_3GEN_129."
  },
  {
    "method": "GET",
    "path": "/v1/appStoreVersionLocalizations/59562966-9555-4e74-a371-1f7f6c171cf7/appScreenshotSets?limit=200",
    "purpose": "es-MX verify the live set identities and counts."
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshotSets/44c56bc0-bf45-481e-bc48-de6089fb7862/appScreenshots?limit=200",
    "purpose": "es-MX verify the live screenshot count for APP_IPHONE_67."
  },
  {
    "method": "GET",
    "path": "/v1/appScreenshotSets/4df75bbc-74dd-4fd1-8dc5-4b77bb80d52c/appScreenshots?limit=200",
    "purpose": "es-MX verify the live screenshot count for APP_IPAD_PRO_3GEN_129."
  }
]
```
