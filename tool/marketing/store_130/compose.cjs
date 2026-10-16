// Actual screenshots + original vector layout. The app's Nunito Sans is embedded.
const fs=require('fs');
const path=require('path');
const crypto=require('crypto');
const deps='/Users/ahmet/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules';
const sharp=require(deps+'/sharp');
const {chromium}=require(deps+'/playwright');
const root=path.resolve('docs/product/marketing/2026-10-16-app-store');
const copy=JSON.parse(fs.readFileSync('tool/marketing/store_130/copy.json','utf8'));
// Shared brand, SVG and iPhone frame functions retained from 9 October.
const C={paper:'#F3EFE6',card:'#FFFBF4',navy:'#0D3B8F',orange:'#FF7A1A',ink:'#1B1B1F',muted:'#46464F',border:'#DED5C6'};
const data=f=>`data:image/${f.endsWith('webp')?'webp':'png'};base64,${fs.readFileSync(f).toString('base64')}`;
const icon=data('assets/icon/app_icon.png');
const font=fs.readFileSync('assets/fonts/NunitoSans-Variable.ttf').toString('base64');
const esc=s=>String(s).replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('"','&quot;');
let id=0;
const rect=(x,y,w,h,r,fill,stroke='none',sw=1)=>`<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${r}" fill="${fill}" stroke="${stroke}" stroke-width="${sw}"/>`;
const t=(x,y,s,size=32,color=C.ink,weight=600,spacing=0,anchor='start')=>`<text data-check="text" x="${x}" y="${y}" fill="${color}" font-family="NunitoSans" font-size="${size}" font-weight="${weight}" letter-spacing="${spacing}" text-anchor="${anchor}">${esc(s)}</text>`;
const lines=(x,y,ls,size,step,color=C.ink,weight=800,spacing=-2)=>ls.map((s,i)=>t(x,y+i*step,s,size,color,weight,spacing)).join('');
function im(uri,x,y,w,h,r=0){const n='clip'+id++;return `<defs><clipPath id="${n}">${rect(x,y,w,h,r,'white')}</clipPath></defs><image href="${uri}" x="${x}" y="${y}" width="${w}" height="${h}" preserveAspectRatio="xMidYMid meet" clip-path="url(#${n})"/>`;}
const defs=`<defs><style>@font-face{font-family:NunitoSans;src:url(data:font/ttf;base64,${font}) format('truetype');font-weight:200 1000;} text{font-variation-settings:'wdth' 100,'opsz' 12,'YTLC' 500;}</style>
<linearGradient id="metal"><stop stop-color="#96989e"/><stop offset=".035" stop-color="#303239"/><stop offset=".5" stop-color="#131518"/><stop offset=".965" stop-color="#2e3035"/><stop offset="1" stop-color="#86898f"/></linearGradient>
<linearGradient id="paper" x2=".65" y2="1"><stop stop-color="#FFFBF4"/><stop offset="1" stop-color="#F3EFE6"/></linearGradient>
<radialGradient id="peach"><stop stop-color="#FFD9BE" stop-opacity=".55"/><stop offset="1" stop-color="#FFD9BE" stop-opacity="0"/></radialGradient>
<filter id="shadow" x="-20%" y="-12%" width="140%" height="130%"><feDropShadow dx="0" dy="34" stdDeviation="25" flood-color="#2a2015" flood-opacity=".17"/></filter></defs>`;
const svg=(w,h,body)=>`<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}">${defs}${body}</svg>`;
const bg=(w,h)=>rect(0,0,w,h,0,'url(#paper)')+`<ellipse cx="${w*.8}" cy="${h*.54}" rx="${w*.43}" ry="${h*.69}" fill="url(#peach)"/>`;
function brand(x,y,size=78,word=46){return im(icon,x,y,size,size,size*.23)+`<text data-check="text" x="${x+size+22}" y="${y+size*.7}" font-family="NunitoSans" font-size="${word}" font-weight="900" letter-spacing="-1.4"><tspan fill="${C.ink}">Grammar</tspan><tspan fill="${C.orange}">Lens</tspan></text>`;}
function phone(name,x,y,width,{shadow=true}={}){
 const s=width/1412;
 const body=rect(0,0,1412,2958,211,'url(#metal)','#7b7e84',2.5)+rect(10,10,1392,2938,202,'#050506','#40434a',2)+im(data(path.join(root,'raw',name+'.png')),46,45,1320,2868,170)+rect(39,38,1334,2882,178,'none','#050506',6)+
 // Hardware cutout; simulator PNG does not include the island. No UI text is changed.
 rect(516.5,77,379,113,57,'#000')+`<circle cx="828" cy="133.5" r="14" fill="#111318"/><circle cx="828" cy="133.5" r="7" fill="#19232e"/>`+
 rect(-8,395,10,114,5,'#5c5e64')+rect(-8,681,10,166,5,'#45474c')+rect(-8,891,10,166,5,'#45474c')+rect(1410,707,10,228,5,'#51535a')+rect(1410,1690,9,204,4,'#3d3f45');
 return `<g data-phone="${name}" transform="translate(${x} ${y}) scale(${s})"><g ${shadow?'filter="url(#shadow)"':''}>${body}</g></g>`;
}
const pill=(x,y,w,s)=>rect(x,y,w,62,31,'#FFFBF4',C.border,1.5)+`<circle cx="${x+27}" cy="${y+31}" r="5" fill="${C.orange}"/>`+t(x+45,y+41,s,25,C.navy,800);
const rule=(x,y,w)=>`<path d="M${x} ${y}h${w}" stroke="${C.border}" stroke-width="2"/>`;

// iPad companion to the original 9 October front-facing frame. The
// native 2064 x 2752 screenshot is uniformly scaled, never stretched.
function tablet(name,x,y,width){
 const s=width/2194;
 const body=rect(0,0,2194,2870,145,'url(#metal)','#7b7e84',3)+
 rect(10,10,2174,2850,137,'#08090b','#40434a',2)+
 im(data(path.join(root,'raw','ipad',name+'.png')),65,59,2064,2752,73)+
 rect(61,55,2072,2760,77,'none','#08090b',8)+
 `<circle cx="2161" cy="1435" r="12" fill="#13171e"/><circle cx="2161" cy="1435" r="6" fill="#182c3e"/>`+
 rect(2192,330,10,142,5,'#51535a')+rect(2192,495,10,142,5,'#51535a');
 return `<g data-device="ipad" transform="translate(${x} ${y}) scale(${s})"><g filter="url(#shadow)">${body}</g></g>`;
}
const sets={
 iphone:['01-results','02-hint','03-home','04-question','05-review','06-collection','07-onboarding','08-multi-blank'],
 ipad:['01-results','02-hint','03-home','04-question','05-review','06-collection']
};
const assets=[];
let browser,page;
async function write(file,w,h,body){
 const full=svg(w,h,body),base=path.join(root,file);
 fs.mkdirSync(path.dirname(base),{recursive:true});fs.writeFileSync(base+'.svg',full);
 await page.setViewportSize({width:w,height:h});
 await page.setContent(`<html><head><meta charset="utf-8"><style>html,body{margin:0;width:${w}px;height:${h}px;overflow:hidden;background:transparent}svg{display:block}</style></head><body>${full}</body></html>`);
 await page.evaluate(()=>document.fonts.ready);
 const bad=await page.evaluate(()=>[...document.querySelectorAll('[data-check="text"]')].map(e=>({text:e.textContent,box:e.getBoundingClientRect().toJSON()})).filter(e=>e.box.x<0||e.box.y<0||e.box.right>innerWidth||e.box.bottom>innerHeight));
 if(bad.length)throw Error('Text overflow '+file+JSON.stringify(bad));
 const shot=await page.screenshot({omitBackground:true});
 const png=await sharp(shot).flatten({background:C.paper}).removeAlpha().png().toBuffer();
 fs.writeFileSync(base+'.png',png);
 if(file.startsWith('app-store/')){
  const preview=path.join(root,'preview',file.replaceAll('/','--')+'.webp');
  fs.mkdirSync(path.dirname(preview),{recursive:true});
  await sharp(png).resize({width:w===1320?528:688}).webp({quality:93}).toFile(preview);
 }
 assets.push({file:file+'.png',width:w,height:h,alpha:false,channels:3,sha256:crypto.createHash('sha256').update(png).digest('hex')});
 console.log('Exported '+file);
}
function poster(family,name,index,total){
 const c=copy[name.substring(3)],pad=family==='ipad';
 const w=pad?2064:1320,h=pad?2752:2868;
 let body=bg(w,h)+brand(pad?142:90,pad?84:66,pad?86:61,pad?55:38);
 body+=t(w-(pad?142:90),pad?145:112,`${String(index+1).padStart(2,'0')} / ${String(total).padStart(2,'0')}`,pad?28:22,C.navy,800,1,'end');
 body+=t(pad?142:90,pad?268:230,c.tag,pad?28:22,C.navy,800,1.6);
 body+=lines(pad?133:84,pad?412:356,c.title,pad?122:82,pad?140:99,C.ink,900,pad?-3.5:-2.5);
 body+=t(pad?142:90,pad?633:537,c.subtitle,pad?36:27,C.muted,600);
 body+=pad?tablet(name,287,693,1490):phone('iphone/'+name,146,626,1028);
 return {w,h,body};
}
async function overview(family){
 const names=sets[family],pad=family==='ipad',w=pad?2760:3210,h=pad?860:1110;
 const slot=pad?440:390,thumb=pad?396:350,top=185;
 let body=bg(w,h)+brand(64,52,68,42)+t(w-64,101,`1.3.0 · ${pad?'iPad 13-inch':'iPhone'} · English`,28,C.navy,800,0,'end');
 names.forEach((name,i)=>{
  const x=64+i*slot;
  body+=t(x,160,`${String(i+1).padStart(2,'0')} · ${copy[name.substring(3)].label.split(' · ')[0]}`,22,C.ink,800);
  body+=im(data(path.join(root,'app-store',family,name+'.png')),x,top,thumb,thumb*(pad?2752/2064:2868/1320));
 });
 await write('overview-'+family,w,h,body);
}
async function main(){
 browser=await chromium.launch({headless:true,executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'});
 page=await browser.newPage({deviceScaleFactor:1});
 for(const [family,names] of Object.entries(sets)){
  for(const [i,name] of names.entries()){
   const {w,h,body}=poster(family,name,i,names.length);
   await write('app-store/'+family+'/'+name,w,h,body);
  }
  await overview(family);
 }
 let first=bg(2400,1910)+brand(74,56,77,47)+t(2326,110,'THE FIRST THREE · IPHONE',25,C.navy,800,1,'end');
 sets.iphone.slice(0,3).forEach((name,i)=>{
  const x=74+i*774;
  first+=t(x,211,`${String(i+1).padStart(2,'0')} · ${copy[name.substring(3)].label.split(' · ')[0]}`,29,C.ink,800);
  first+=im(data(path.join(root,'app-store/iphone',name+'.png')),x,255,704,704*2868/1320);
 });
 await write('overview-first-three',2400,1910,first);
 await browser.close();
 fs.mkdirSync(path.join(root,'source'),{recursive:true});
 for(const [src,dest] of [['tool/marketing/store_130/copy.json','copy.json'],['assets/fonts/NunitoSans-Variable.ttf','NunitoSans-Variable.ttf'],['assets/fonts/OFL-NunitoSans.txt','OFL-NunitoSans.txt'],['assets/icon/app_icon.png','app-icon.png']])fs.copyFileSync(src,path.join(root,'source',dest));
 fs.writeFileSync(path.join(root,'manifest.json'),JSON.stringify({
  status:'owner-approved-with-requested-revisions-completed',revision:2,appVersion:'1.3.0+6',branch:'main',commit:'b7b89b8',capturedDate:'2026-10-16',interfaceLanguage:'en',storeLanguage:'English (U.S.)',
  devices:{iphone:{name:'GrammarLens 1.3 Store iPhone',udid:'40E58DFD-CBBD-44D0-8FF6-FE1961AE18AA',model:'iPhone 18 Pro Max',runtime:'iOS 27.0',size:[1320,2868]},ipad:{name:'GrammarLens 1.3 Store iPad',udid:'1DB726C6-8844-4791-B3CA-DCC2F671CCD9',model:'iPad Pro 13-inch (M5)',runtime:'iPadOS 27.0',size:[2064,2752]}},
  database:'product_capture_2026_10_16_store_r2.db',onboardingDatabase:'product_capture_2026_10_16_onboarding_r2.db',capture:{name:'Sam',avatar:'Fox',mountain:'Glacier Peak',appearance:'light',time:'9:41',signal:'full',battery:'100%',firebaseInitialized:false,revenueCatInitialized:false},
  design:'Extends the 9 October app-store layout, original iPhone frame and SVG to PNG renderer; matching original iPad frame added',
  hintCapture:'Real production slider: injected horizontal pointer gesture held down during native simctl screenshot; released and closure verified afterwards',
  questionSelection:{source:'lib/data/day_zero_daily_test.dart',id:'day0_5',question:'Yesterday I ___ a great film.',promptVerb:'see',correctAnswer:'saw',wrongAnswer:'have seen',hintTopic:'Tense Selection',sameQuestionInOpenAndClosedHint:true,resultAndReviewLinked:true},
  ipadWindowMode:'Full Screen Apps selected in the dedicated iPad simulator Settings > Multitasking & Gestures',
  multiBlank:'Eighth iPhone frame. Real production PracticeScreen and local article fixture from the existing device-test example; no AI generation or scoring claim.',
  uploadOrder:sets,copySource:'source/copy.json',exports:assets,
  references:{size:'https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/',searchOrder:'https://developer.apple.com/app-store/product-page/'}
 },null,2)+'\n');
}
main().catch(async e=>{console.error(e);if(browser)await browser.close();process.exit(1)});
