// Turkish iPhone art direction only. Native build-7 pixels stay untouched.
// This renderer outputs review concepts outside the repository.
const fs=require('fs'),path=require('path'),crypto=require('crypto');
const deps='/Users/ahmet/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules';
const sharp=require(deps+'/sharp');
const {chromium}=require(deps+'/playwright');
const OUT=process.env.DESIGN_OUT||'/Users/ahmet/Pictures/GrammarLens/design-explorations/tr-iphone/cozy-v1';
const RAW='/Users/ahmet/Pictures/GrammarLens/1.4.0-raw/tr/iphone';
const W=1320,H=2868;
const esc=s=>String(s).replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('"','&quot;');
const uri=(buf,type='png')=>`data:image/${type};base64,${buf.toString('base64')}`;
const fileUri=f=>uri(fs.readFileSync(f),f.endsWith('.webp')?'webp':'png');
const fonts=['Fredoka','Caveat'].map(n=>`@font-face{font-family:${n};src:url(data:font/ttf;base64,${fs.readFileSync(`tool/marketing/store_130/fonts/${n}.ttf`).toString('base64')});font-weight:300 700}`).join('')+`@font-face{font-family:Nunito;src:url(data:font/ttf;base64,${fs.readFileSync('assets/fonts/NunitoSans-Variable.ttf').toString('base64')});font-weight:200 1000}`;
const copy=JSON.parse(fs.readFileSync('tool/marketing/store_130/copy.tr.json'));
const images=Object.fromEntries(['01-results','02-hint','03-home','04-question','05-review','06-collection','07-onboarding','08-multi-blank'].map(n=>[n,fileUri(`${RAW}/${n}.png`)]));
const icon=fileUri('assets/icon/app_icon.png'),fox=fileUri('assets/avatars/avatar_14.webp');
const medals=['glacier_peak_bronze','red_canyon_gold','ember_peak_silver','green_slope_bronze'].map(n=>fileUri(`assets/medals/medal_${n}.webp`));
const pages=[
 {key:'results',source:'01-results',color:'#EBA292',ink:'#4D2B32',file:'01-results'},
 {key:'question',source:'04-question',color:'#F3CB7C',ink:'#573828',file:'02-question'},
 {key:'hint',source:'02-hint',color:'#CED49F',ink:'#304B40',file:'03-hint'},
 {key:'multi-blank',source:'08-multi-blank',color:'#EFB58F',ink:'#60372C',file:'04-multi-blank'},
 {key:'home',source:'03-home',color:'#AAC9D9',ink:'#294758',file:'05-home'},
 {key:'review',source:'05-review',color:'#CAB7D1',ink:'#50364E',file:'06-review'},
 {key:'collection',source:'06-collection',color:'#E8BA79',ink:'#634027',file:'07-collection'},
 {key:'onboarding',source:'07-onboarding',color:'#BACCB0',ink:'#355144',file:'08-onboarding'}
];
const cropCache={};
async function crop(name,box){const key=name+JSON.stringify(box);return cropCache[key]||=(uri(await sharp(`${RAW}/${name}.png`).extract(box).png().toBuffer()));}
const place=(html,x,y,w,style='')=>`<div class="placed" style="left:${x}px;top:${y}px;width:${w}px;${style}">${html}</div>`;
function phone(name,x,y,w,{z=0,ry=-10,rx=5,rz=-6,opacity=1}={}){
 return place(`<div class="device"><div class="screen"><img src="${images[name]}"/><div class="island"></div><div class="glass"></div></div><i class="button b1"></i><i class="button b2"></i><i class="button b3"></i></div>`,x,y,w,`z-index:${z};opacity:${opacity};transform:perspective(2200px) rotateX(${rx}deg) rotateY(${ry}deg) rotateZ(${rz}deg);transform-origin:50% 50%;`);
}
function lifted(src,x,y,w,{z=5,rz=-5,ry=-7,r=28}={}){
 return place(`<div class="lifted" style="border-radius:${r}px"><img src="${src}"/></div>`,x,y,w,`z-index:${z};transform:perspective(2200px) rotateY(${ry}deg) rotateX(5deg) rotateZ(${rz}deg)`);
}
const txt=(s,x,y,w,size=100,{font='Fredoka',weight=550,rotate=0,cls='',line=1.02,align='left'}={})=>place(`<div class="copy ${cls}" data-text-check style="font-family:${font};font-size:${size}px;font-weight:${weight};line-height:${line};text-align:${align};transform:rotate(${rotate}deg)">${s}</div>`,x,y,w,'z-index:20');
const sub=(s,x,y,w=1100,align='left')=>txt(esc(s),x,y,w,49,{font:'Nunito',weight:650,line:1.24,align,cls:'subtitle'});
function background(index){
 const colors=pages.map((p,i)=>`<stop offset="${(i+.5)/8}" stop-color="${p.color}"/>`).join('');
 const width=W*8;
 return `<svg class="backdrop" width="${width}" height="${H}" viewBox="0 0 ${width} ${H}" style="left:${-index*W}px"><defs><linearGradient id="field">${colors}</linearGradient><filter id="grain"><feTurbulence type="fractalNoise" baseFrequency=".62" numOctaves="3" stitchTiles="stitch"/></filter></defs><rect width="${width}" height="${H}" fill="url(#field)"/><path d="M-300 2380 C500 2550 580 1720 1320 1810 S2030 2360 2640 1920 S3510 1590 3960 1990 S4610 2440 5280 2070 S5970 1840 6600 2100 S7320 2690 7920 2280 S9310 1690 10560 2310" fill="none" stroke="#F9E5BD" stroke-width="420" opacity=".57"/><path d="M-300 2380 C500 2550 580 1720 1320 1810 S2030 2360 2640 1920 S3510 1590 3960 1990 S4610 2440 5280 2070 S5970 1840 6600 2100 S7320 2690 7920 2280 S9310 1690 10560 2310" fill="none" stroke="#FFF5DA" stroke-width="7" opacity=".5"/><rect width="${width}" height="${H}" filter="url(#grain)" opacity=".055" style="mix-blend-mode:soft-light"/></svg>`;
}
const svg=(body,cls='doodle')=>`<svg class="${cls}" viewBox="0 0 1320 2868" width="1320" height="2868">${body}</svg>`;
function header(i){return `<div class="brand"><img src="${icon}"/><span>Grammar<span class="lens">Lens</span></span></div><div class="counter">${String(i+1).padStart(2,'0')}<span> / 08</span></div>`;}
async function art(i){
 const p=pages[i];let b=background(i)+header(i);
 if(i===0){
  b+=svg('<path d="M110 555 Q625 635 1160 551" stroke="#F6D37C" stroke-width="74" stroke-linecap="round" fill="none"/><path d="M1080 865 Q1210 950 1132 1090 M1132 1090 l-19 -49 M1132 1090 l46 -17" stroke="#74423E" stroke-width="8" stroke-linecap="round" fill="none"/>');
  b+=txt('Her cevap',90,230,1140,149,{weight:500})+txt('açıklanır.',86,385,1150,184,{weight:600});
  b+=sub(copy.results.subtitle,98,660,1020);
  b+=phone('01-results',260,923,760,{ry:-14,rx:6,rz:-8});
  b+=lifted(await crop('01-results',{left:108,top:984,width:1106,height:205}),195,1255,1040,{rz:-5,ry:-10,r:30});
  b+=lifted(await crop('01-results',{left:108,top:1228,width:1106,height:205}),138,1525,1040,{rz:-5,ry:-10,r:30});
  b+=lifted(await crop('01-results',{left:108,top:1474,width:1106,height:150}),175,1790,1040,{rz:-5,ry:-10,r:20});
 }
 if(i===1){
  b+=txt('Kendi cevabını',93,230,1150,115,{weight:500})+txt('yaz.',130,325,980,284,{font:'Caveat',weight:650,rotate:-7});
  b+=svg('<path d="M150 629 Q435 677 740 592" stroke="#BC5B3E" stroke-width="11" fill="none" stroke-linecap="round"/><path d="M1130 720 Q1220 745 1225 860" stroke="#BC5B3E" stroke-width="8" fill="none" stroke-linecap="round"/>');
  b+=sub(copy.question.subtitle,97,740,1040);
  b+=phone('04-question',100,1000,820,{ry:13,rx:5,rz:6,z:2});
  // This hint phone continues across the 02/03 seam at the identical global position.
  b+=phone('02-hint',1090,1410,690,{ry:-10,rx:4,rz:-9,z:1});
 }
 if(i===2){
  b+=txt('Gramer kalıbını',92,242,1140,117,{weight:500})+txt('gör.',94,373,1060,221,{font:'Caveat',weight:650,rotate:-5});
  b+=sub(copy.hint.subtitle,95,665,1090);
  // Same phone as the right edge of page 02, now entering from the left.
  b+=phone('02-hint',-230,1410,690,{ry:-10,rx:4,rz:-9,z:1});
  b+=phone('02-hint',470,1000,790,{ry:-13,rx:6,rz:7,z:2});
  b+=lifted(await crop('02-hint',{left:48,top:1150,width:1224,height:390}),95,1355,1130,{rz:-5,ry:-4,r:39});
  b+=svg('<path d="M1070 1210 Q1180 1220 1170 1330 M1170 1330 l-25 -42 M1170 1330 l32 -32" stroke="#537450" stroke-width="8" fill="none" stroke-linecap="round"/>');
 }
 if(i===3){
  b+=txt('Her boşluğa',93,235,1140,141,{weight:500})+txt('bir kutu.',90,389,1140,177,{weight:600});
  b+=sub(copy['multi-blank'].subtitle,96,660,1090);
  b+=phone('08-multi-blank',280,935,780,{ry:-12,rx:5,rz:-8,z:1});
  b+=lifted(await crop('08-multi-blank',{left:48,top:410,width:1224,height:470}),86,1120,1130,{rz:-5,ry:-7,r:50});
  b+=lifted(await crop('08-multi-blank',{left:48,top:1214,width:1224,height:154}),90,1760,1100,{rz:-5,ry:-7,r:35});
  b+=lifted(await crop('08-multi-blank',{left:48,top:1390,width:1224,height:154}),129,1980,1100,{rz:-5,ry:-7,r:35});
  b+=svg('<path d="M180 1650 Q80 1700 130 1780" stroke="#B96C3C" stroke-width="9" stroke-linecap="round" fill="none"/><path d="M1130 1690 Q1245 1820 1150 1980" stroke="#4569AA" stroke-width="9" stroke-linecap="round" fill="none"/>');
 }
 if(i===4){
  b+=txt('İlerlemenin',89,230,1140,144,{weight:500})+txt('yükselişini<br>izle.',90,392,1140,163,{weight:600,line:1.02});
  b+=sub(copy.home.subtitle,96,810,1050);
  b+=phone('03-home',400,1080,790,{ry:-12,rx:6,rz:7});
  b+=place(`<img class="fox" src="${fox}"/>`,-40,1665,580,'z-index:5;transform:rotate(-10deg)');
  b+=svg('<path d="M140 1550 C-30 1340 72 1110 298 1120 M298 1120 l-54 -17 M298 1120 l-38 43" stroke="#4E7F97" stroke-width="10" stroke-linecap="round" fill="none"/>');
 }
 if(i===5){
  b+=txt('Zayıf noktaların,',88,248,1150,109,{weight:500,rotate:-3})+txt('tek bir<br>yerde.',91,395,1140,164,{weight:600,line:1.04});
  b+=sub(copy.review.subtitle,96,805,1070);
  b+=phone('05-review',50,1085,760,{ry:12,rx:5,rz:-7,z:1});
  b+=phone('01-results',960,1250,635,{ry:-12,rx:6,rz:11,z:0,opacity:.8});
  b+=lifted(await crop('05-review',{left:48,top:1290,width:1224,height:440}),170,1610,1030,{rz:4,ry:8,r:50});
  b+=lifted(await crop('05-review',{left:48,top:1760,width:1224,height:440}),125,2085,1030,{rz:4,ry:8,r:50});
 }
 if(i===6){
  b+=txt('Dağ koleksiyonunu',88,241,1140,112,{weight:500})+txt('oluştur.',112,358,1100,244,{font:'Caveat',weight:650,rotate:-5});
  b+=sub(copy.collection.subtitle,96,730,1090);
  b+=phone('06-collection',275,1125,780,{ry:12,rx:5,rz:-7});
  const positions=[[35,940,360,-16],[445,875,400,4],[925,1000,345,18]];
  positions.forEach(([x,y,w,rz],j)=>{b+=place(`<img class="medal" src="${medals[j]}"/>`,x,y,w,`z-index:6;transform:perspective(1600px) rotateY(${j===0?-15:12}deg) rotateZ(${rz}deg)`);});
 }
 if(i===7){
  b+=txt('Öğrenme arkadaşını',90,245,1140,112,{weight:500})+txt('seç.',110,345,1100,285,{font:'Caveat',weight:650,rotate:-7});
  b+=sub(copy.onboarding.subtitle,97,745,1070);
  b+=phone('07-onboarding',460,1010,735,{ry:-13,rx:6,rz:8});
  b+=place(`<img class="fox" src="${fox}"/>`,-60,1330,760,'z-index:6;transform:rotate(-12deg)');
  b+=svg('<path d="M95 1135 Q245 1040 375 1160" stroke="#5D7B59" stroke-width="9" fill="none" stroke-linecap="round"/><path d="M365 1100 l12 62 -62 -16" stroke="#5D7B59" stroke-width="9" fill="none" stroke-linecap="round"/>');
 }
 return b;
}
const css=`${fonts}
*{box-sizing:border-box}html,body{margin:0;padding:0;background:#D8C6B1}body{-webkit-font-smoothing:antialiased} .stage{width:${W}px;height:${H}px;position:relative;overflow:hidden;isolation:isolate;color:var(--ink)}
.backdrop{position:absolute;top:0;z-index:-2}.placed{position:absolute;height:auto;transform-style:preserve-3d}.placed img{display:block;width:100%;height:auto}.copy{letter-spacing:-2.5px}.subtitle{letter-spacing:-.6px;opacity:.88}.doodle{position:absolute;inset:0;z-index:0;pointer-events:none;overflow:visible}
.brand{position:absolute;left:86px;top:79px;display:flex;align-items:center;gap:16px;padding:12px 24px 12px 12px;border:2px solid #fff7e36e;border-radius:35px;background:#fff6e54f;z-index:30;font:900 37px Nunito;letter-spacing:-1px}.brand img{width:53px;height:53px;border-radius:15px}.lens{color:#AB482D}.counter{position:absolute;top:114px;right:90px;font:800 29px Nunito;z-index:30}.counter span{opacity:.45;font-weight:650}
.device{position:relative;background:linear-gradient(105deg,#8A8077,#33312E 4%,#151A1B 50%,#8F8477 99%);border:3px solid #B2A697;border-radius:calc(1px * var(--radius,105));padding:15px;box-shadow:22px 34px 0 -13px #6A6257,37px 53px 0 -25px #ADA08B,35px 58px 70px #493A3333,5px 8px 14px #372C294D;}
.device::before{content:'';position:absolute;inset:-3px;border-radius:inherit;border:2px solid #ffffff6b;pointer-events:none}.screen{position:relative;overflow:hidden;border-radius:92px;background:#F3EFE6}.screen>img{width:100%;height:auto}.island{position:absolute;left:35.65%;top:1.1%;width:28.7%;height:3.94%;border-radius:100px;background:#050606}.island::after{content:'';position:absolute;right:16%;top:39%;height:22%;aspect-ratio:1;border:3px solid #1b242a;background:#0B1118;border-radius:50%}.glass{position:absolute;inset:0;background:linear-gradient(110deg,transparent 10%,#fff3 15%,transparent 23%,transparent 80%,#fff1);opacity:.24;pointer-events:none}.button{position:absolute;left:-8px;width:7px;background:#777269;border-radius:3px}.b1{top:14%;height:4%}.b2{top:23%;height:5.6%}.b3{top:31%;height:5.6%}
.lifted{position:relative;background:#FDF7EC;overflow:hidden;border:2px solid #FFF7E9;box-shadow:0 6px 0 #D8CFBD,0 13px 0 #BBB3A1,0 27px 0 -4px #74625533,12px 44px 48px #593B3545,3px 8px 10px #392B2826}.lifted img{width:100%;height:auto}.fox{filter:drop-shadow(12px 34px 20px #36534645)}.medal{filter:drop-shadow(9px 28px 14px #6B4C363d)}
`;
async function main(){
 const originalManifest=JSON.parse(fs.readFileSync('/Users/ahmet/Pictures/GrammarLens/1.4.0-raw/manifest.json'));
 for(const p of pages){
  const expected=originalManifest.files.find(f=>f.file===`tr/iphone/${p.source}.png`);
  const actual=crypto.createHash('sha256').update(fs.readFileSync(`${RAW}/${p.source}.png`)).digest('hex');
  if(!expected||actual!==expected.sha256)throw Error('Native source checksum mismatch: '+p.source);
 }
 fs.mkdirSync(OUT,{recursive:true});
 const browser=await chromium.launch({headless:true,executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'});
 const page=await browser.newPage({viewport:{width:W,height:H},deviceScaleFactor:1});
 const records=[];
 for(const [i,p]of pages.entries()){
  await page.setContent(`<html lang="tr"><meta charset="utf-8"><style>${css}</style><div class="stage" style="--ink:${p.ink}">${await art(i)}</div></html>`);
  await page.evaluate(async()=>{await document.fonts.ready;await Promise.all([...document.images].map(im=>im.decode()));});
  const text=await page.evaluate(()=>[...document.querySelectorAll('[data-text-check]')].map(e=>({text:e.innerText,...e.getBoundingClientRect().toJSON()})));
  const wordOverflow=await page.evaluate(()=>[...document.querySelectorAll('[data-text-check]')].filter(e=>e.scrollWidth>e.clientWidth+1).map(e=>e.innerText));
  if(wordOverflow.length)throw Error('Word overflow '+p.file+JSON.stringify(wordOverflow));
  const overflow=text.filter(t=>t.x<55||t.right>1265||t.y<0||t.bottom>H);if(overflow.length)throw Error('Text safe-area failure '+p.file+JSON.stringify(overflow));
  const png=await sharp(await page.screenshot()).removeAlpha().toColourspace('srgb').png().toBuffer();
  fs.writeFileSync(path.join(OUT,p.file+'.png'),png);
  records.push({file:p.file+'.png',source:p.source+'.png',width:W,height:H,sha256:crypto.createHash('sha256').update(png).digest('hex'),text});console.log('Rendered '+p.file);
 }
 await browser.close();
 // Review sheets: four columns for individual layouts and an unbroken panorama.
 const thumbs=await Promise.all(pages.map(p=>sharp(path.join(OUT,p.file+'.png')).resize({width:330}).png().toBuffer()));
 await sharp({create:{width:1320,height:1434,channels:3,background:'#DBC9B5'}}).composite(thumbs.map((input,i)=>({input,left:(i%4)*330,top:Math.floor(i/4)*717}))).png().toFile(path.join(OUT,'overview.png'));
 await sharp({create:{width:2640,height:717,channels:3,background:'#DBC9B5'}}).composite(thumbs.map((input,i)=>({input,left:i*330,top:0}))).png().toFile(path.join(OUT,'flow-strip.png'));
 const first=await Promise.all(pages.slice(0,4).map(p=>sharp(path.join(OUT,p.file+'.png')).resize({width:660}).png().toBuffer()));
 await sharp({create:{width:2640,height:1434,channels:3,background:'#DBC9B5'}}).composite(first.map((input,i)=>({input,left:i*660,top:0}))).png().toFile(path.join(OUT,'test-story.png'));
 fs.writeFileSync(path.join(OUT,'manifest.json'),JSON.stringify({status:'design-exploration-v1-not-approved',language:'tr',device:'iphone-6.9',sourceCommit:'c37757a',build:'1.4.0+7',rawArchive:RAW,nativeSourceChecksums:'all eight matched permanent archive manifest',copySource:'tool/marketing/store_130/copy.tr.json',type:{headlines:'Fredoka 500–600; Caveat 650',support:'Nunito 650'},order:pages.map(p=>p.source),design:'Continuous warm color field and ribbon; real screenshot crops raised into perspective layers; 02–03 share a phone across their seam.',records},null,2)+'\n');
 fs.writeFileSync(path.join(OUT,'README.md'),'# Türkçe iPhone — sıcak renkler / katmanlı cihazlar, v1\n\nYalnızca tasarım denemesi; App Store Connect’e yüklenmedi.\n\nSekiz adet 1320 × 2868 RGB PNG. `overview.png` 4 × 2 sayfa özeti; `flow-strip.png` kesintisiz sekizli akış; `test-story.png` ilişkili ilk dört sayfa. Gerçek build 7 ekranları ve birebir ekran kırpmaları kullanılır. Hiçbir uygulama ekranı yeniden çizilmedi.\n\nSıra: sonuç → soru → ipucu → çoklu boşluk → ilerleme → tekrar → koleksiyon → öğrenme arkadaşı.\n\nBaşlıklarda Fredoka ve Caveat, alt metinde Nunito Sans. Metinler mevcut Türkçe caption dosyasından; iddialar değiştirilmedi.\n');
 console.log('OUTPUT '+OUT);
}
main().catch(e=>{console.error(e);process.exit(1)});
