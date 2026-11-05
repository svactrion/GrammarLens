# Description blind back-translation — changed blocks only

Checkpoint 2 correction recheck, 2026-11-05. No upload or ASC write performed.

A fresh reviewer agent received only four changed localized blocks (ja/ko PRIVACY, ja FREE AND PREMIUM, de PRIVACY), without the English original, prior reviews, repository context or requested fixes. The English below is reproduced verbatim. The primary agent compared the returned English with en-US only after the blind pass. The two privacy locales are grouped into one row to match the owner’s three requested fixes.

| Changed block(s) | Original English | Blind back-translation into English | One-line drift note |
|---|---|---|---|
| 1 · ja / ko — PRIVACY | PRIVACY<br>There is no account and no sign-up. Your name, your progress and your practice history stay on your device. The app sends anonymous usage data, never your name.<br>To give you feedback, the answers you type are sent to our AI provider, Anthropic. The app asks your permission before this happens for the first time, and you can withdraw it at any time from the Data screen. | **ja:**<br>Privacy<br>No account or registration is required. Your name, progress, and practice history are saved on your device. The app sends anonymous usage data, but never sends your name.<br>For feedback, the answers you enter are sent to the AI provider Anthropic. The app asks for permission before sending for the first time, and you can revoke permission at any time from the ‘Data’ screen.<br><br>**ko:**<br>Personal information<br>No account or sign-up is needed. Your name, progress, and practice history are stored on your device. The app sends anonymous usage data and never sends your name.<br>To provide feedback, the answers you enter are sent to the AI provider Anthropic. The app asks for permission before sending for the first time, and you can withdraw it at any time on the ‘Data’ screen. | Matches: neither version says “only”; anonymous usage data, never sending the name, Anthropic answers and consent/withdrawal are preserved. |
| 2 · ja — FREE AND PREMIUM | FREE AND PREMIUM<br>Free includes one Daily Test and one practice session every day.<br>Premium unlocks Topic Practice across all five areas and more practice sessions each day.<br>Premium is available as a monthly or annual subscription. Both include a free trial for new subscribers. Prices are shown in the app before you subscribe. | Free version and Premium<br>With the free version, you can use one daily test and one practice session every day.<br>With Premium, you can use topic practice in all five areas and more practice sessions per day.<br>Premium is a monthly or annual subscription. Both have a free trial for new subscribers. Prices are displayed in the app before you subscribe. | Matches: both plans include a free trial explicitly for new subscribers; prices are shown before subscribing. |
| 3 · de-DE — PRIVACY | PRIVACY<br>There is no account and no sign-up. Your name, your progress and your practice history stay on your device. The app sends anonymous usage data, never your name.<br>To give you feedback, the answers you type are sent to our AI provider, Anthropic. The app asks your permission before this happens for the first time, and you can withdraw it at any time from the Data screen. | PRIVACY<br>No account, no registration. Your name, your progress, and your practice history stay on your device. The app sends anonymous usage data, never your name.<br>For feedback, the answers you enter are sent to our AI provider Anthropic. The app asks for permission before sending for the first time. You can revoke permission at any time in the ‘Data’ screen. | Matches: permission is requested before the first send, and permission can be withdrawn at any time from Data. |

All three requested fixes match. The exact localized changes in metadata.json and every corresponding dry-run request body (including conditional keyword retries) are:

- ja PRIVACY: `アプリは匿名の利用データを送信しますが、名前は決して送りません。`
- ko PRIVACY: `앱은 익명 사용 데이터를 보내고, 이름은 절대 보내지 않아요.`
- ja FREE AND PREMIUM: `どちらも新規購読者には無料体験があります。料金は購読前にアプリ内で表示されます。`
- de PRIVACY: `Die App fragt vor dem ersten Senden um Erlaubnis. Du kannst die Erlaubnis jederzeit im Bildschirm „Daten“ widerrufen.`

tr, es-MX, pt-BR and ar-SA retain the owner-approved descriptions unchanged. The initial full seven-language blind pass remains in Git commit `b2c3bb1`; this recheck supersedes its four affected blocks and drift notes.

Blind input block SHA-256 values:

- ja_PRIVACY: `32c449324e3c828394b957226ef1503cc0e63ab0cb62cbc6292e19e01f5d0c5d`
- ko_PRIVACY: `ffe830e87a1344171f03f53b4ad5f07280510b93056fccc04e883d69d1cef88a`
- ja_FREE_AND_PREMIUM: `3c49d39e32d9def91ab16cf78e180732604df5e93b45633ed9aba8b899a93a91`
- de_PRIVACY: `7586b28c41b16140fc1f3f1a5a193db32cbbea176308f8c7049c41db472c420c`

Build 7 remains attached and VALID from the latest read; no attach call is planned. Version release stays MANUAL. Promotional text stays empty. Keyword trims remain conditional on matching ASC byte-limit rejection. Upload/checkpoint 3 waits for the owner’s explicit **upload** instruction.
