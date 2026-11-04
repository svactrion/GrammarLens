// Actual screenshots + original vector layout. The app's Nunito Sans is embedded.
const fs=require('fs');
const path=require('path');
const crypto=require('crypto');
const deps='/Users/ahmet/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules';
const sharp=require(deps+'/sharp');
const {chromium}=require(deps+'/playwright');
const language=process.argv[2];
if(!['en','tr','de','es','pt-BR','ja','ko','ar'].includes(language))throw Error('Expected language');
const root=path.resolve(process.env.CAPTURE_ROOT||'/private/tmp/grammarlens-140-captures',language);
const delivery=path.resolve('screenshots/1.4.0',language);
const copy=JSON.parse(fs.readFileSync(`tool/marketing/store_130/copy.${language}.json`,'utf8'));
const fontFile={ja:'NotoSansJP.ttf',ko:'NotoSansKR.ttf',ar:'NotoSansArabic.ttf'}[language];
const captionFont=fs.readFileSync(fontFile?`tool/marketing/store_130/fonts/${fontFile}`:'assets/fonts/NunitoSans-Variable.ttf').toString('base64');
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
const defs=`<defs><style>@font-face{font-family:NunitoSans;src:url(data:font/ttf;base64,${font}) format('truetype');font-weight:200 1000;} @font-face{font-family:Caption;src:url(data:font/ttf;base64,${captionFont}) format('truetype');font-weight:100 1000;} text{font-variation-settings:'wdth' 100,'opsz' 12,'YTLC' 500;}</style>
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
const sets={iphone:['01-results','02-hint','03-home','04-question','05-review','06-collection','07-onboarding','08-multi-blank'],ipad:['01-results','02-hint','03-home','04-question','05-review','06-collection']};
let browser,page;
const layout=[];
const rtl=language==='ar', latin=['en','tr','de','es','pt-BR'].includes(language);
function caption(x,y,text,size,weight,color,spacing=0){
 return `<text data-check="caption" x="${x}" y="${y}" fill="${color}" font-family="Caption" font-size="${size}" font-weight="${weight}" letter-spacing="${spacing}" direction="${rtl?'rtl':'ltr'}" text-anchor="start" style="unicode-bidi:plaintext">${esc(text)}</text>`;
}
async function fit(text,size,min,maxWidth,maxLines,weight,spacing=0){
 for(;size>=min;size--){
  const result=await page.evaluate(async ({text,size,maxWidth,weight,spacing,language})=>{
   await document.fonts.load(`${weight} ${size}px Caption`);
   const c=document.createElement('canvas').getContext('2d');c.font=`${weight} ${size}px Caption`;
   const measure=s=>c.measureText(s).width+Math.max(0,[...s].length-1)*spacing;
   const tokens=[...new Intl.Segmenter(language,{granularity:'word'}).segment(text)].map(x=>x.segment);
   const lines=[];let line='';
   for(const token of tokens){
    if(line&&measure((line+token).trim())>maxWidth){lines.push(line.trim());line=token.trimStart();}else line+=token;
   }
   if(line.trim())lines.push(line.trim());
   return {lines,widths:lines.map(measure)};
  },{text,size,maxWidth,weight,spacing,language});
  if(result.lines.length<=maxLines&&result.widths.every(w=>w<=maxWidth))return {...result,size};
 }
 throw Error('Caption does not fit: '+text);
}
async function write(file,w,h,body,captionFloor=null){
 const full=svg(w,h,body);
 await page.setViewportSize({width:w,height:h});
 await page.setContent(`<html><head><meta charset="utf-8"><style>html,body{margin:0;width:${w}px;height:${h}px;overflow:hidden}svg{display:block}</style></head><body>${full}</body></html>`);
 await page.evaluate(()=>document.fonts.ready);
 const boxes=await page.evaluate(()=>[...document.querySelectorAll('[data-check]')].map(e=>({kind:e.dataset.check,text:e.textContent,...e.getBoundingClientRect().toJSON()})));
 const bad=boxes.filter(b=>b.x<0||b.y<0||b.right>w||b.bottom>h||(captionFloor&&b.kind==='caption'&&b.bottom>captionFloor));
 if(bad.length)throw Error('Text overflow/overlap '+file+' '+JSON.stringify(bad));
 const png=await sharp(await page.screenshot()).removeAlpha().toColourspace('srgb').png().toBuffer();
 const dest=path.join(delivery,file);fs.mkdirSync(path.dirname(dest),{recursive:true});fs.writeFileSync(dest,png);
 layout.push({file,width:w,height:h,sha256:crypto.createHash('sha256').update(png).digest('hex'),text:boxes});
 console.log('Exported '+language+'/'+file);
}
async function poster(family,name,index){
 const c=copy[name.substring(3)],pad=family==='ipad',w=pad?2064:1320,h=pad?2752:2868;
 const weights=copy._meta.fontWeights, margin=pad?142:90, x=rtl?w-margin:margin, maxWidth=w-2*margin;
 let body=bg(w,h)+brand(margin,pad?84:66,pad?86:61,pad?55:38);
 body+=t(w-margin,pad?145:112,`${String(index+1).padStart(2,'0')} / ${String(sets[family].length).padStart(2,'0')}`,pad?28:22,C.navy,800,1,'end');
 const tag=await fit(c.tag,pad?28:22,pad?28:22,maxWidth,1,weights.tag,latin?1.6:0);
 body+=caption(x,pad?268:230,c.tag,tag.size,weights.tag,C.navy,latin?1.6:0);
 // Keep approved English line breaks and sizes; fit localized text in up to 3 lines.
 const preferred=await Promise.all(c.title.map(line=>fit(line,pad?122:82,pad?36:27,maxWidth,1,weights.title,latin?(pad?-3.5:-2.5):0)));
 let title={lines:c.title,size:Math.min(...preferred.map(line=>line.size))};
 let step=title.lines.length===3?(pad?102:78):(pad?140:99);
 if(title.lines.length===3&&title.size>step*.9)title=await fit(c.title.join(language==='ja'?'':' '),Math.floor(step*.9),pad?36:27,maxWidth,3,weights.title,latin?(pad?-3.5:-2.5):0);
 const start=title.lines.length===3?(pad?380:328):(pad?412:356);
 title.lines.forEach((line,i)=>{body+=caption(x,start+i*step,line,title.size,weights.title,C.ink,latin?(pad?-3.5:-2.5):0);});
 const sub=await fit(c.subtitle,pad?36:27,pad?36:27,maxWidth,2,weights.subtitle);
 sub.lines.forEach((line,i)=>{body+=caption(x,(pad?633:537)+i*(pad?44:34),line,sub.size,weights.subtitle,C.muted);});
 body+=pad?tablet(name,287,693,1490):phone('iphone/'+name,146,626,1028);
 await write(`store/${pad?'ipad-13':'iphone-6.9'}/${name}.png`,w,h,body,pad?693:626);
}
async function overview(family){
 const pad=family==='ipad',names=sets[family],w=pad?2760:3210,h=pad?860:1110,slot=pad?440:390,thumb=pad?396:350;
 let body=bg(w,h)+brand(64,52,68,42)+t(w-64,101,`1.4.0 · ${pad?'iPad 13-inch':'iPhone 6.9-inch'} · ${language}`,28,C.navy,800,0,'end');
 names.forEach((name,i)=>{const x=64+i*slot;body+=t(x,160,`${String(i+1).padStart(2,'0')} · ${name.substring(3)}`,22,C.ink,800);body+=im(data(path.join(delivery,'store',pad?'ipad-13':'iphone-6.9',name+'.png')),x,185,thumb,thumb*(pad?2752/2064:2868/1320));});
 await write(`overview-${family}.png`,w,h,body);
}
async function main(){
 browser=await chromium.launch({headless:true,executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'});page=await browser.newPage({deviceScaleFactor:1});
 await page.setContent(`<svg>${defs}<text font-family="Caption">${esc(copy.results.title.join(' '))}</text></svg>`);await page.evaluate(()=>document.fonts.ready);
 for(const [family,names]of Object.entries(sets).filter(([family])=>!process.argv[3]||process.argv[3]===family)){for(const [i,name]of names.entries())await poster(family,name,i);await overview(family);}
 fs.copyFileSync(`tool/marketing/store_130/copy.${language}.json`,path.join(delivery,'copy.json'));
 fs.copyFileSync(`tool/marketing/store_130/copy.${language}.json`,path.join(delivery,`copy.${language}.json`));
 fs.writeFileSync(path.join(root,'composition-audit.json'),JSON.stringify({language,sourceCommit:'c37757a',weights:copy._meta.fontWeights,layout},null,2));
 await browser.close();
}
main().catch(async e=>{console.error(e);if(browser)await browser.close();process.exit(1)});
