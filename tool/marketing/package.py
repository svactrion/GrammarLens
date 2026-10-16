"""Package the local visual set without including the archive itself."""
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
root=Path(__file__).resolve().parents[2]/'docs/product/marketing/2026-10-09'
output=root/'grammarlens-visual-set-2026-10-09.zip'
with ZipFile(output, 'w', ZIP_DEFLATED, compresslevel=6) as z:
 for p in sorted(root.rglob('*')):
  if p.is_file() and p != output and p.name != '.DS_Store':
   z.write(p,Path('GrammarLens-visual-set')/p.relative_to(root))
print(f'ZIP ready: {output.stat().st_size/1024/1024:.1f} MB')
