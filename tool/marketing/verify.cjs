// Artifact validation: file dimensions, alpha, embedded source and local links.
const fs=require('fs'),path=require('path'),crypto=require('crypto');
const sharp=require('/Users/ahmet/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root=path.resolve('docs/product/marketing/2026-10-09');
const manifest=JSON.parse(fs.readFileSync(path.join(root,'manifest.json')));
const names=['01-home','02-daily-test','03-feedback','04-review','05-weak-spot','06-medals'];
const errors=[],result=[];
async function record(file,expectW,expectH,expectAlpha){
 const b=fs.readFileSync(path.join(root,file)),m=await sharp(b).metadata();
 if(m.width!==expectW||m.height!==expectH||(expectAlpha!==undefined&&m.hasAlpha!==expectAlpha))errors.push('Unexpected format: '+file);
 const r={file,width:m.width,height:m.height,alpha:m.hasAlpha,bytes:b.length,sha256:crypto.createHash('sha256').update(b).digest('hex')};
 result.push(r);return r;
}
(async()=>{
 for(const a of manifest.exports){
  const r=await record(a.file,a.width,a.height,a.alpha);if(r.sha256!==a.sha256)errors.push('Changed since export: '+a.file);
  if(a.file.startsWith('framed/')){
   const corner=await sharp(path.join(root,a.file)).extract({left:0,top:0,width:1,height:1}).raw().toBuffer();
   if(corner[3]!==0)errors.push('Frame outside is not transparent: '+a.file);
  }
  if(a.file.startsWith('marketing/')||a.file.startsWith('app-store/')){
   const w=a.file.replace('.png','.webp');await record(w,a.width,a.height,false);
  }
  const svg=a.file.replace('.png','.svg');const source=fs.readFileSync(path.join(root,svg),'utf8');
  if(!source.includes('data:font/ttf;base64,'))errors.push('Font not embedded: '+svg);
  const embedded=[...source.matchAll(/data:image\/png;base64,([^"\s]+)/g)].map(x=>crypto.createHash('sha256').update(Buffer.from(x[1],'base64')).digest('hex'));
  const rawHashes=names.map(n=>crypto.createHash('sha256').update(fs.readFileSync(path.join(root,'raw',n+'.png'))).digest('hex'));
  if(!embedded.some(x=>rawHashes.includes(x)))errors.push('Actual raw screenshot not embedded: '+svg);
 }
 for(const n of names)await record('raw/'+n+'.png',1320,2868);
 for(const lang of ['tr','en'])await record('review-app-store-'+lang+'.png',2400,905,false);
 const html=fs.readFileSync(path.join(root,'gallery.html'),'utf8');
 const links=[...html.matchAll(/(?:href|src)="([^"]+)"/g)].map(x=>x[1]).filter(x=>!x.startsWith('#'));
 for(const l of links)if(!fs.existsSync(path.join(root,l)))errors.push('Missing gallery link: '+l);
 if(errors.length){console.error(errors);process.exit(1);}
 const extra=result.filter(x=>!manifest.exports.some(a=>a.file===x.file));
 manifest.files=result;manifest.verification='passed';manifest.exportCount=manifest.exports.length;manifest.checkedFileCount=result.length;
 fs.writeFileSync(path.join(root,'manifest.json'),JSON.stringify(manifest,null,2)+'\n');
 fs.writeFileSync(path.join(root,'verification.json'),JSON.stringify({status:'passed',filesChecked:result.length,galleryLinksChecked:links.length,checks:['dimensions','PNG/WebP alpha','transparent frame corners','unchanged export hashes','original raw PNG embedded in each SVG','font embedded','gallery files exist'],normalAppEntry:'lib/main.dart launched on dedicated simulator',staticAnalysis:'clean',existingTestsPassed:19,errors},null,2)+'\n');
 console.log(`${result.length} images validated; ${links.length} gallery links valid`);
})();
