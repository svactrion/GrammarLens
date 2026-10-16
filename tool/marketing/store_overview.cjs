const fs=require('fs'),path=require('path');
const sharp=require('/Users/ahmet/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root=path.resolve('docs/product/marketing/2026-10-09');
const names=['01-home','02-daily-test','03-feedback','04-review','05-weak-spot','06-medals'];
(async()=>{
 for(const lang of ['tr','en']){
  const composites=[];
  for(let i=0;i<names.length;i++){
   const input=await sharp(path.join(root,'app-store',lang,names[i]+'.png')).resize({width:376}).png().toBuffer();
   composites.push({input,left:41+i*396,top:45});
  }
  await sharp({create:{width:2400,height:905,channels:3,background:'#F3EFE6'}}).composite(composites).removeAlpha().png().toFile(path.join(root,'review-app-store-'+lang+'.png'));
 }
 console.log('Two App Store overview sheets ready');
})();
