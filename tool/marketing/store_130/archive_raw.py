#!/usr/bin/env python3
"""Preserve the untouched 1.4.0 native captures outside Git for redesigns."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import struct

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--source', type=Path, default=Path('/private/tmp/grammarlens-140-captures'))
parser.add_argument('--destination', type=Path, default=Path('/Users/ahmet/Pictures/GrammarLens/1.4.0-raw'))
parser.add_argument('--complete', action='store_true', help='Require all 112 native screenshots')
args = parser.parse_args()
languages = ['en', 'tr', 'de', 'es', 'pt-BR', 'ja', 'ko', 'ar']
slots = ['01-results', '02-hint', '03-home', '04-question', '05-review', '06-collection', '07-onboarding', '08-multi-blank']
rows, missing = [], []
for language in languages:
    for family, width, height, count in [('iphone', 1320, 2868, 8), ('ipad', 2064, 2752, 6)]:
        source = args.source / language / 'raw' / family
        target = args.destination / language / family
        for slot in slots[:count]:
            original = source / f'{slot}.png'
            if not original.exists():
                missing.append(f'{language}/{family}/{slot}.png')
                continue
            data = original.read_bytes()
            assert data[:8] == b'\x89PNG\r\n\x1a\n', original
            assert struct.unpack('>II', data[16:24]) == (width, height), original
            target.mkdir(parents=True, exist_ok=True)
            saved = target / original.name
            shutil.copy2(original, saved)
            digest = hashlib.sha256(data).hexdigest()
            assert hashlib.sha256(saved.read_bytes()).hexdigest() == digest, saved
            rows.append({'file': str(saved.relative_to(args.destination)), 'width': width, 'height': height, 'bytes': len(data), 'sha256': digest})
        for audit in ['locale-audit.json', 'hint-state.json']:
            if (source / audit).exists():
                target.mkdir(parents=True, exist_ok=True)
                shutil.copy2(source / audit, target / audit)
args.destination.mkdir(parents=True, exist_ok=True)
manifest = {'sourceCommit': 'c37757a', 'build': '1.4.0+7', 'captureDate': '2026-11-04', 'unmodifiedNativePngs': True, 'expectedCount': 112, 'actualCount': len(rows), 'complete': not missing, 'missing': missing, 'files': rows}
(args.destination / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
(args.destination / 'README.md').write_text('''# GrammarLens 1.4.0 — unframed native originals

Build 7 (1.4.0+7), source c37757a, captured 2026-11-04.
Retained outside Git at the owner's request for future design experiments.

Each language has separate iphone (1320 × 2868, 8 files) and ipad
(2064 × 2752, 6 files) folders. The PNGs are the original native screenshots,
without captions or device frames; they are copied byte for byte.
`manifest.json` records their dimensions, byte sizes and SHA-256 checksums,
and whether all 112 images have been captured. Locale and held-hint audits
are kept alongside the images. Learning content stays English by design.

Languages: en, tr, de, es (es-MX), pt-BR, ja, ko, ar (ar-SA).
Source rig, captions and licensed fonts: GrammarLens repository,
`tool/marketing/store_130/`. Framed checkpoint assets and blind caption
back-translations: `screenshots/1.4.0/` in that repository.
''')
print(f'Archived {len(rows)}/112 original PNGs; every copied checksum matches: {args.destination}')
if args.complete and missing:
    raise SystemExit(f'Missing {len(missing)} captures')
