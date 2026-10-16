"""Package only the 1.3.0 store delivery; never include its own archive."""
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile
import json

root = Path("docs/product/marketing/2026-10-16-app-store")
output = root / "grammarlens-1.3.0-app-store.zip"
# Explicit delivery roots prevent a previously opened ZIP from nesting an old
# screenshot set inside the next package.
files = [root / name for name in [
    "ASSET_NOTES.md", "gallery.html", "manifest.json", "verification.json",
    "overview-first-three.png", "overview-first-three.svg",
    "overview-iphone.png", "overview-iphone.svg",
    "overview-ipad.png", "overview-ipad.svg",
]]
for folder in ["raw", "app-store", "preview", "source"]:
    files.extend(p for p in (root / folder).rglob("*") if p.is_file())
files = sorted(files)
order = json.loads((root / "manifest.json").read_text())["uploadOrder"]
expected = sorted(f"app-store/{family}/{name}.png"
                  for family, names in order.items() for name in names)
assert len(expected) == 14
with ZipFile(output, "w", ZIP_DEFLATED, compresslevel=6) as archive:
    for file in files:
        archive.write(file, Path("grammarlens-1.3.0-app-store") / file.relative_to(root))
with ZipFile(output) as archive:
    assert archive.testzip() is None
    assert len(archive.namelist()) == len(files)
    actual = sorted(str(Path(name).relative_to("grammarlens-1.3.0-app-store"))
                    for name in archive.namelist()
                    if "/app-store/" in name and name.endswith(".png"))
    assert actual == expected
    assert not any("06-weak-spot" in name for name in archive.namelist())
print(f"Packaged {len(files)} files, {output.stat().st_size / 1024 / 1024:.1f} MB; archive CRC verified.")
