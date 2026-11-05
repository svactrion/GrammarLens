// Approved vivid composition for eight locales and iPhone/iPad.
// Native build-7 pixels stay untouched; final deliverables go to screenshots/1.4.0/.
const fs=require('fs'),path=require('path'),crypto=require('crypto');
const deps='/Users/ahmet/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules';
const sharp=require(deps+'/sharp');
const {chromium}=require(deps+'/playwright');
const language=process.argv[2],family=process.argv[3]||'iphone';
if(!['en','tr','de','es','pt-BR','ja','ko','ar'].includes(language)||!['iphone','ipad'].includes(family))throw Error('Expected locale and device family');
const pad=family==='ipad',rtl=language==='ar',latin=!['ja','ko','ar'].includes(language);
const THEME='vivid',theme={name:'Canlı fade',colors:['#FF8F9E','#FFC36C','#D7EE87','#7EDDD2','#9EC0FF','#C6A0ED','#FFADBB','#FFD284'],glow:'#FFEAD0',ribbon:'#FFF0CF'};
const OUT=path.resolve('screenshots/1.4.0',language),folder=pad?'ipad-13':'iphone-6.9';
const RAW=`/Users/ahmet/Pictures/GrammarLens/1.4.0-raw/${language}/${family}`;
let displayIndex=0;
const W=pad?2064:1320,H=pad?2752:2868;
const esc=s=>String(s).replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('"','&quot;');
const uri=(buf,type='png')=>`data:image/${type};base64,${buf.toString('base64')}`;
const fileUri=f=>uri(fs.readFileSync(f),f.endsWith('.webp')?'webp':'png');
const fonts=['Fredoka','Caveat'].map(n=>`@font-face{font-family:${n};src:url(data:font/ttf;base64,${fs.readFileSync(`tool/marketing/store_130/fonts/${n}.ttf`).toString('base64')});font-weight:300 700}`).join('')+`@font-face{font-family:Nunito;src:url(data:font/ttf;base64,${fs.readFileSync('assets/fonts/NunitoSans-Variable.ttf').toString('base64')});font-weight:200 1000}`;
const localeFont=latin?'':`@font-face{font-family:Local;src:url(data:font/ttf;base64,${fs.readFileSync('tool/marketing/store_130/fonts/'+({ja:'NotoSansJP.ttf',ko:'NotoSansKR.ttf',ar:'NotoSansArabic.ttf'}[language])).toString('base64')});font-weight:100 1000}`;
const copy=JSON.parse(fs.readFileSync(`tool/marketing/store_130/copy.${language}.json`));
const images=Object.fromEntries(['01-results','02-hint','03-home','04-question','05-review','06-collection','07-onboarding','08-multi-blank'].filter(n=>fs.existsSync(`${RAW}/${n}.png`)).map(n=>[n,fileUri(`${RAW}/${n}.png`)]));
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
async function crop(name,box){box=resolveBox(name,box);const key=name+JSON.stringify(box);return cropCache[key]||=(uri(await sharp(`${RAW}/${name}.png`).extract(box).png().toBuffer()));}
const place=(html,x,y,w,style='')=>`<div class="placed" style="left:${x}px;top:${y}px;width:${w}px;${style}">${html}</div>`;
function phone(name,x,y,w,{z=0,ry=-10,rx=5,rz=-6,opacity=1}={}){
 return place(`<div class="device"><div class="screen"><img src="${images[name]}"/><div class="island"></div><div class="glass"></div></div><i class="button b1"></i><i class="button b2"></i><i class="button b3"></i></div>`,x,y,w,`z-index:${z};opacity:${opacity};transform:perspective(2200px) rotateX(${rx}deg) rotateY(${ry}deg) rotateZ(${rz}deg);transform-origin:50% 50%;`);
}
function lifted(src,x,y,w,{z=5,rz=-5,ry=-7,r=28}={}){
 return place(`<div class="lifted" style="border-radius:${r}px"><img src="${src}"/></div>`,x,y,w,`z-index:${z};transform:perspective(2200px) rotateY(${ry}deg) rotateX(5deg) rotateZ(${rz}deg)`);
}
const txt=(s,x,y,w,size=100,{font='Fredoka',weight=550,rotate=0,cls='',line=1.02,align='left'}={})=>place(`<div class="copy ${cls}" data-text-check data-copy="${esc(s.replaceAll('<br>','\n'))}" style="font-family:${latin?font:'Local'};direction:${rtl?'rtl':'ltr'};font-size:${size}px;font-weight:${weight};line-height:${line};text-align:${rtl?'right':align};transform:rotate(${rotate}deg)">${cls.includes('cedilla-fix')?centeredCedilla(s):s}</div>`,x,y,w,'z-index:20');
const sub=(s,x,y,w=1100,align='left')=>txt(esc(s),x,y,w,49,{font:'Nunito',weight:650,line:1.24,align,cls:'subtitle'});
function background(index){
 index=displayIndex;
 const width=10560;
 const stops=theme.colors.map((c,i)=>`<stop offset="${(i+.5)/8}" stop-color="${c}"/>`).join('');
 const ribbon='M-300 2380 C500 2550 580 1720 1320 1810 S2030 2360 2640 1920 S3510 1590 3960 1990 S4610 2440 5280 2070 S5970 1840 6600 2100 S7320 2690 7920 2280 S9310 1690 10560 2310';
 return `<svg class="backdrop" width="${W*8}" height="${H}" viewBox="0 0 10560 2868" preserveAspectRatio="none" style="left:${-index*W}px"><defs>
 <linearGradient id="field">${stops}</linearGradient>
 <linearGradient id="vertical" x1="0" y1="0" x2=".15" y2="1"><stop stop-color="#fff" stop-opacity=".23"/><stop offset=".48" stop-color="#fff" stop-opacity="0"/><stop offset="1" stop-color="${THEME==='vivid'?'#B54891':'#7F9DC4'}" stop-opacity="${THEME==='vivid'?'.19':'.17'}"/></linearGradient>
 <radialGradient id="glow"><stop stop-color="${theme.glow}" stop-opacity=".62"/><stop offset="1" stop-color="${theme.glow}" stop-opacity="0"/></radialGradient>
 <filter id="grain"><feTurbulence type="fractalNoise" baseFrequency=".62" numOctaves="3" stitchTiles="stitch"/></filter></defs>
 <rect width="${width}" height="2868" fill="url(#field)"/><rect width="${width}" height="2868" fill="url(#vertical)"/>
 ${[0,1,2,3,4,5,6,7].map(i=>`<ellipse cx="${660+i*1320}" cy="${i%2?1750:900}" rx="1100" ry="1400" fill="url(#glow)"/>`).join('')}
 <path d="${ribbon}" fill="none" stroke="${theme.ribbon}" stroke-width="420" opacity=".48"/><path d="${ribbon}" fill="none" stroke="#FFFDF4" stroke-width="7" opacity=".6"/>
 <rect width="${width}" height="2868" filter="url(#grain)" opacity=".035" style="mix-blend-mode:soft-light"/></svg>`;
}

const svg=(body,cls='doodle')=>`<svg class="${cls}" viewBox="0 0 1320 2868" width="1320" height="2868">${body}</svg>`;
function header(i){return `<div class="brand"><img src="${icon}"/><span>Grammar<span class="lens">Lens</span></span></div><div class="counter">${String(displayIndex+1).padStart(2,'0')}<span> / ${pad?'06':'08'}</span></div>`;}
async function component(name,box,x,y,w,{z=5,rz=-2,ry=-3,r=40,pad=30,rx=2,stroke='#FFF6E9'}={}){
 box=resolveBox(name,box);const bytes=await sharp(`${RAW}/${name}.png`).extract(box).png().toBuffer();
 const pixel=await sharp(bytes).extract({left:0,top:0,width:1,height:1}).removeAlpha().raw().toBuffer();
 const color=`rgb(${pixel[0]},${pixel[1]},${pixel[2]})`;
 return place(`<div class="tile" style="--tile-color:${color};--tile-stroke:${stroke};padding:${pad}px;border-radius:${r}px"><img src="${uri(bytes)}"/></div>`,x,y,w,`z-index:${z};transform:perspective(2400px) rotateY(${ry}deg) rotateX(${rx}deg) rotateZ(${rz}deg)`);
}
async function fieldRow(textBox,controlBox,x,y,w,options={}){
 const box=textBox.top<1400?{left:48,top:1214,width:1224,height:154}:{left:48,top:1390,width:1224,height:154};
 return lifted(await crop('08-multi-blank',box),x,y,w,{rz:options.rz||2,ry:options.ry||3,r:38});
}
// Keep the rounded type, but center the Turkish cedilla below s rather than
// letting Fredoka's rightward hook appear below the following i/ı.
function centeredCedilla(s){
 return s.replaceAll('ş','<span class="tr-sh">s<svg class="cedilla" viewBox="0 0 24 24" aria-hidden="true"><path d="M13 3 C17 8 15 15 8 16"/></svg></span>');
}
async function wholeErrorCard(){
 const src=await crop('01-results',geometry.error);
 return place(`<div class="whole-error"><img src="${src}"/></div>`,92,1260,1135,'z-index:5;transform:perspective(2400px) rotateY(-3deg) rotateX(2deg) rotateZ(-2deg)');
}
async function hintControl(x,y,w){
 const image=await crop('04-question',geometry.slider);
 return place(`<div class="slider-float"><img src="${image}"/></div>`,x,y,w,'z-index:6;transform:perspective(2400px) rotateY(-3deg) rotateX(2deg) rotateZ(-2deg)');
}


function atmosphere(i){
 // Local light is inset so the original global gradient and ribbon still
 // join exactly at every page boundary.
 return `<div class="spotlight" style="left:${i===4||i===7?290:95}px"></div>`;
}
function featureTag(i){
 const y=[842,883,835,872,924,924,838,860][i]-(rtl?35:0);
 const align=rtl?'right:96px':i===2?'left:50%;transform:translateX(-50%)':i===3?'right:96px':'left:96px';
 return `<div class="feature-tag" data-text-check data-copy="${esc(copy[pages[i].key].tag)}" style="top:${y}px;${align}"><span class="tag-dot"></span>${esc(copy[pages[i].key].tag)}</div>`;
}
function accentBadge(i){
 const icons=[
  '<path d="M26 52 l17 17 34 -39"/><path d="M80 17 v12 M74 23 h12" stroke-width="3"/>',
  '<path d="M28 70 l5 -19 34 -34 16 16 -34 34 -21 3 M33 51 l16 16 M58 26 l16 16"/><path d="M25 83 h55" stroke-width="3"/>',
  '<path d="M38 66 C35 53 24 51 27 35 C30 12 67 12 73 35 C77 51 65 55 62 66 Z M39 78 h22 M44 88 h12 M50 6 v-7 M14 25 l-9 -5 M85 25 l9 -5"/>',
  '<path d="M35 25 H20 V77 H35 M65 25 H80 V77 H65"/><circle cx="50" cy="51" r="6" fill="currentColor" stroke="none"/>',
  '<path d="M14 77 L43 27 L59 53 L70 37 L91 77 Z M34 43 L43 49 L51 41"/><path d="M43 27 V9 h21 l-7 8 7 8 H43" stroke-width="3"/>',
  '<rect x="19" y="28" width="60" height="55" rx="9"/><path d="M30 28 V17 h60 v54 H79 M32 44 h33 M32 57 h25 M32 70 h18" stroke-width="4"/>',
  '<path d="M50 12 L61 38 L89 41 L68 60 L74 88 L50 74 L26 88 L32 60 L11 41 L39 38 Z"/>',
  '<path d="M50 79 C40 70 16 53 16 34 C16 12 42 10 50 29 C59 10 84 12 84 34 C84 53 60 70 50 79 Z"/>'
 ];
 const pos=[[1040,365,155,12],[1030,418,158,13],[1080,451,125,9],[125,410,165,-12],[1030,465,160,9],[1030,535,160,-10],[1070,461,145,11],[1045,475,155,12]][i];
 let [x,y,w,r]=pos; if(rtl)x=95; if(pad){x*=1.55;w*=1.15;}
 return place(`<div class="accent-badge"><svg viewBox="0 0 100 100" aria-hidden="true">${icons[i]}</svg></div>`,x,y,w,`z-index:1;transform:rotate(${r}deg);color:${pages[i].ink}`);
}

async function art(i){
 const p=pages[i];let b=background(i)+atmosphere(i)+header(i)+featureTag(i)+accentBadge(i);
 if(i===0){
  b+=txt(esc(copy['results'].title[0]),92,240,1140,141,{weight:500,rotate:-2})+txt(esc(copy['results'].title[1]),86,395,1150,184,{weight:600});
  b+=svg('<path d="M125 590 Q610 630 1115 570" stroke="#F6D37C" stroke-width="50" stroke-linecap="round" fill="none"/>');
  b+=sub(copy.results.subtitle,98,660,1020);
  b+=phone('01-results',280,1020,760,{ry:-3,rx:2,rz:-2});
  b+=await wholeErrorCard();
 }
 if(i===1){
  b+=txt(esc(copy['question'].title[0]),93,235,1150,111,{font:'Nunito',weight:800})+txt(esc(copy['question'].title[1]),125,327,1000,300,{font:'Caveat',weight:700,rotate:-6});
  b+=svg('<path d="M155 655 Q415 700 730 618" stroke="#BC5B3E" stroke-width="13" fill="none" stroke-linecap="round"/>');
  b+=sub(copy.question.subtitle,97,755,1040);
  b+=phone('04-question',267,1060,780,{ry:3,rx:2,rz:2});
  b+=await component('04-question',{left:90,top:450,width:1140,height:480},92,1260,1135,{rz:2,ry:3,r:44,pad:32});
  b+=lifted(await crop('04-question',geometry.input),118,2005,1095,{rz:2,ry:3,r:38});
 }
 if(i===2){
  b+=txt(esc(copy['hint'].title[0]),92,242,1140,117,{weight:500,align:'center'})+txt(esc(copy['hint'].title[1]),90,370,1140,230,{font:'Nunito',weight:950,align:'center',rotate:3});
  b+=svg('<path d="M415 606 Q665 632 915 607" stroke="#E9CA75" stroke-width="37" fill="none" stroke-linecap="round"/>');
  b+=sub(copy.hint.subtitle,95,665,1090);
  b+=phone('02-hint',298,1050,750,{ry:-3,rx:2,rz:-2});
  b+=await hintControl(93,1740,1135);
  b+=await component('02-hint',{left:80,top:1150,width:1150,height:385},93,1940,1135,{rz:-2,ry:-3,r:44,pad:32});
 }
 if(i===3){
  b+=txt(esc(copy['multi-blank'].title[0]),93,235,1140,136,{font:'Nunito',weight:800,rotate:-2,align:'right'})+txt(esc(copy['multi-blank'].title[1]),90,395,1140,177,{weight:600,align:'right'});
  b+=svg('<path d="M505 600 Q605 625 695 602" stroke="#C97D4E" stroke-width="18" fill="none" stroke-linecap="round"/><path d="M770 606 Q970 630 1180 594" stroke="#718AB7" stroke-width="18" fill="none" stroke-linecap="round"/>');
  b+=sub(copy['multi-blank'].subtitle,96,660,1090);
  b+=phone('08-multi-blank',265,1040,780,{ry:3,rx:2,rz:2});
  b+=await component('08-multi-blank',{left:90,top:450,width:1140,height:400},90,1230,1135,{rz:2,ry:3,r:44,pad:32});
  b+=await fieldRow({left:100,top:1260,width:900,height:80},{left:1135,top:1227,width:120,height:126},100,1840,1110,{color:'#F8E7D8',stroke:'#BB6A34'});
  b+=await fieldRow({left:100,top:1440,width:900,height:80},{left:1140,top:1425,width:110,height:90},100,2080,1110,{color:'#FFFBF4',stroke:'#4268BA'});
 }
 if(i===4){
  b+=txt(esc(copy['home'].title[0]),89,230,1140,144,{weight:500})+txt(esc(copy['home'].title[1]),90,392,1140,163,{weight:600,line:1.02,cls:'cedilla-fix'});
  b+=sub(copy.home.subtitle,96,810,1050);
  b+=phone('03-home',400,1080,790,{ry:-12,rx:6,rz:7});
  b+=place(`<img class="fox" src="${fox}"/>`,-40,1665,580,'z-index:5;transform:rotate(-10deg)');
  b+=svg('<path d="M140 1550 C-30 1340 72 1110 298 1120 M298 1120 l-54 -17 M298 1120 l-38 43" stroke="#4E7F97" stroke-width="10" stroke-linecap="round" fill="none"/>');
 }
 if(i===6){
  b+=txt(esc(copy['collection'].title[0]),88,241,1140,112,{weight:500})+txt(esc(copy['collection'].title[1]),112,358,1100,244,{font:'Caveat',weight:650,rotate:-5});
  b+=sub(copy.collection.subtitle,96,730,1090);
  b+=phone('06-collection',275,1125,780,{ry:12,rx:5,rz:-7});
  const positions=[[35,940,360,-16],[445,875,400,4],[925,1000,345,18]];
  positions.forEach(([x,y,w,rz],j)=>{b+=place(`<img class="medal" src="${medals[j]}"/>`,x,y,w,`z-index:6;transform:perspective(1600px) rotateY(${j===0?-15:12}deg) rotateZ(${rz}deg)`);});
 }
 if(i===7){
  b+=txt(esc(copy['onboarding'].title[0]),90,245,1140,112,{weight:500,cls:'cedilla-fix'})+txt(esc(copy['onboarding'].title[1]),110,345,1100,285,{font:'Caveat',weight:650,rotate:-7});
  b+=sub(copy.onboarding.subtitle,97,745,1070);
  b+=phone('07-onboarding',460,1010,735,{ry:-13,rx:6,rz:8});
  b+=place(`<img class="fox" src="${fox}"/>`,-60,1330,760,'z-index:6;transform:rotate(-12deg)');
  b+=svg('<path d="M95 1135 Q245 1040 375 1160" stroke="#5D7B59" stroke-width="9" fill="none" stroke-linecap="round"/><path d="M365 1100 l12 62 -62 -16" stroke="#5D7B59" stroke-width="9" fill="none" stroke-linecap="round"/>');
 }
 if(i===5){
  b+=txt(esc(copy['review'].title[0]),88,248,1150,109,{weight:500,rotate:-3})+txt(esc(copy['review'].title[1]),91,395,1140,164,{weight:600,line:1.04});
  b+=sub(copy.review.subtitle,96,805,1070);
  b+=phone('05-review',50,1085,760,{ry:12,rx:5,rz:-7,z:1});
  b+=phone('01-results',960,1250,635,{ry:-12,rx:6,rz:11,z:0,opacity:.8});
  b+=await component('05-review',{left:110,top:1340,width:1100,height:340},170,1610,1030,{rz:4,ry:8,rx:5,r:48,pad:32,stroke:'#D7C9B4'});
  b+=await component('05-review',{left:110,top:1810,width:1100,height:340},125,2085,1030,{rz:4,ry:8,rx:5,r:48,pad:32,stroke:'#D7C9B4'});
 }
 return b;
}

const css=`${fonts}
*{box-sizing:border-box}html,body{margin:0;padding:0;background:#D8C6B1}body{-webkit-font-smoothing:antialiased} .stage{width:${W}px;height:${H}px;position:relative;overflow:hidden;isolation:isolate;color:var(--ink)}
.tr-sh{position:relative;display:inline-block}.tr-sh .cedilla{position:absolute;width:.17em;height:.17em;left:48%;top:.88em;transform:translateX(-50%);overflow:visible}.cedilla path{fill:none;stroke:currentColor;stroke-width:5.5;stroke-linecap:round}.whole-error{overflow:hidden;border-radius:74px;background:#F8E1DF;box-shadow:0 5px 0 #EDD9CE,0 12px 0 #BFAE9B,14px 38px 48px #5F403342}.whole-error img{display:block;width:100%;height:auto}.backdrop{position:absolute;top:0;z-index:-2}.placed{position:absolute;height:auto;transform-style:preserve-3d}.placed img{display:block;width:100%;height:auto}.copy{letter-spacing:-2.5px}.subtitle{letter-spacing:-.6px;opacity:.88}.doodle{position:absolute;inset:0;z-index:0;pointer-events:none;overflow:visible}
.brand{position:absolute;left:86px;top:79px;display:flex;align-items:center;gap:16px;padding:12px 24px 12px 12px;border:2px solid #fff7e36e;border-radius:35px;background:#fff6e54f;z-index:30;font:900 37px Nunito;letter-spacing:-1px}.brand img{width:53px;height:53px;border-radius:15px}.lens{color:#AB482D}.counter{position:absolute;top:114px;right:90px;font:800 29px Nunito;z-index:30}.counter span{opacity:.45;font-weight:650}
.device{position:relative;background:linear-gradient(105deg,#8A8077,#33312E 4%,#151A1B 50%,#8F8477 99%);border:3px solid #B2A697;border-radius:calc(1px * var(--radius,105));padding:15px;box-shadow:22px 34px 0 -13px #6A6257,37px 53px 0 -25px #ADA08B,35px 58px 70px #493A3333,5px 8px 14px #372C294D;}
.device::before{content:'';position:absolute;inset:-3px;border-radius:inherit;border:2px solid #ffffff6b;pointer-events:none}.screen{position:relative;overflow:hidden;border-radius:92px;background:#F3EFE6}.screen>img{width:100%;height:auto}.island{position:absolute;left:35.65%;top:1.1%;width:28.7%;height:3.94%;border-radius:100px;background:#050606}.island::after{content:'';position:absolute;right:16%;top:39%;height:22%;aspect-ratio:1;border:3px solid #1b242a;background:#0B1118;border-radius:50%}.glass{position:absolute;inset:0;background:linear-gradient(110deg,transparent 10%,#fff3 15%,transparent 23%,transparent 80%,#fff1);opacity:.24;pointer-events:none}.button{position:absolute;left:-8px;width:7px;background:#777269;border-radius:3px}.b1{top:14%;height:4%}.b2{top:23%;height:5.6%}.b3{top:31%;height:5.6%}
.lifted{position:relative;background:#FDF7EC;overflow:hidden;border:2px solid #FFF7E9;box-shadow:0 6px 0 #D8CFBD,0 13px 0 #BBB3A1,0 27px 0 -4px #74625533,12px 44px 48px #593B3545,3px 8px 10px #392B2826}.lifted img{width:100%;height:auto}.fox{filter:drop-shadow(12px 34px 20px #36534645)}.medal{filter:drop-shadow(9px 28px 14px #6B4C363d)}
`;

const polishCss=`
.spotlight{position:absolute;top:960px;width:1130px;height:1720px;border-radius:50%;background:radial-gradient(ellipse closest-side at 50% 45%,#fff8dc90 0%,#fff6de45 54%,transparent 100%);z-index:-1;pointer-events:none}
.feature-tag{position:absolute;display:flex;align-items:center;gap:16px;padding:15px 25px;border-radius:100px;background:var(--ink);color:#FFF5DD;font:800 28px Nunito;letter-spacing:1.1px;white-space:nowrap;z-index:20;box-shadow:0 4px 0 #fff4d73d,0 9px 18px #4d332614}
.tag-dot{width:9px;height:9px;border-radius:50%;background:#F5CC76;box-shadow:0 0 0 5px #f5cc7626}
.accent-badge{padding:23px;border-radius:36%;background:linear-gradient(135deg,#FFF7D5e6,#F9DF9Bbd);border:2px solid #fff7decc;box-shadow:0 5px 0 #c39c6b55,6px 15px 25px #61442d20}
.accent-badge svg{display:block;width:100%;fill:none;stroke:currentColor;stroke-width:5.5;stroke-linecap:round;stroke-linejoin:round}
.brand{background:#fff5de80;border-color:#fff8e5b3;box-shadow:0 5px 14px #5c3a2810}
.counter{border:1.5px solid #fff5df80;background:#fff6e533;border-radius:100px;padding:11px 19px;top:99px}
.tile,.field-tile,.slider-float{box-shadow:0 4px 0 #F1E3D0,0 10px 0 #C6B49D,5px 22px 24px #54362225,14px 42px 60px #54362230}
.whole-error{box-shadow:0 5px 0 #F4DCD1,0 12px 0 #C7A996,5px 22px 24px #64362225,14px 42px 60px #64362230}
`;
const tileCss=`
.slider-float{overflow:hidden;border-radius:999px;border:2.5px solid #FFF6E9;background:#FFE5CC;box-shadow:0 4px 0 #EFE5D4,0 10px 0 #CBBBA4,12px 34px 40px #5F40333D,2px 5px 8px #4C392522}.slider-float img{display:block;width:100%;height:auto}

.tile,.field-tile{position:relative;background:var(--tile-color);border:2.5px solid var(--tile-stroke);box-shadow:0 4px 0 #EFE5D4,0 10px 0 #CBBBA4,12px 34px 40px #5F40333D,2px 5px 8px #4C392522;overflow:hidden}.tile img{width:100%;height:auto;display:block}.field-tile{padding:22px 27px;display:flex;align-items:center;gap:24px;border-radius:43px;border-width:3px;min-height:156px}.field-tile .field-text{width:calc(100% - 130px);height:auto;flex:1;min-width:0}.field-control{display:block;flex:0 0 104px;width:104px;height:104px;border-radius:50%;overflow:hidden}.field-control img{width:100%;height:100%;object-fit:cover}
`;

let geometry={};
const inset=(b,n)=>({left:b.left+n,top:b.top+n,width:b.width-2*n,height:b.height-2*n});
function resolveBox(name,box){
 if(name==='04-question'&&box.top===450)return inset(geometry.question,pad?16:24);
 if(name==='02-hint'&&box.top===1150)return inset(geometry.hint,pad?12:16);
 if(name==='05-review'&&box.top===1340)return inset(geometry.review[0],pad?22:32);
 if(name==='05-review'&&box.top===1810)return inset(geometry.review[1],pad?22:32);
 return box;
}
async function bands(name,color,start=0,end=H,minFraction=.2){
 const {data,info}=await sharp(`${RAW}/${name}.png`).removeAlpha().raw().toBuffer({resolveWithObject:true});
 const matches=(x,y)=>{const p=(y*info.width+x)*3;return color.every((c,k)=>Math.abs(data[p+k]-c)<=1)};
 const rows=[];for(let y=start;y<Math.min(end,info.height);y++){let n=0;for(let x=0;x<info.width;x+=4)if(matches(x,y))n++;rows.push({y,on:n>info.width/4*minFraction});}
 let runs=[],a=null,last=null;for(const row of rows){if(row.on){if(a===null)a=row.y;last=row.y;}else if(a!==null&&row.y-last>8){if(last-a>35)runs.push([a,last]);a=null;}}if(a!==null&&last-a>35)runs.push([a,last]);
 return runs.map(([top,bottom])=>{let left=info.width,right=0;for(let y=top;y<=bottom;y+=3)for(let x=0;x<info.width;x++)if(matches(x,y)){left=Math.min(left,x);right=Math.max(right,x);}return {left:Math.max(0,left-3),top:Math.max(0,top-3),width:Math.min(info.width,right+4)-Math.max(0,left-3),height:bottom-top+7};});
}
async function loadGeometry(){
 const red=await bands('01-results',[248,225,224],pad?200:400,H,.025);
 const whites=await bands('04-question',[255,251,244],pad?170:380,pad?1200:1800,.25);
 const slider=await bands('04-question',[255,229,204],pad?250:600,pad?1000:1500,.2);
 const review=await bands('05-review',[255,251,244],pad?650:1100,pad?1550:2450,.25);
 const hint=JSON.parse(fs.readFileSync(`${RAW}/hint-state.json`)).card,scale=pad?2:3;
 const knob=await bands('04-question',[255,122,26],whites[0].top+whites[0].height,Math.round(hint.y*scale),.015);
 if(!knob[0])throw Error('Slider knob missing');
 geometry={error:red[0],question:whites[0],input:whites[1],slider:{left:Math.round(hint.x*scale),top:whites[0].top+whites[0].height+(pad?11:18),width:Math.round(hint.w*scale),height:pad?112:168},review:review.slice(0,2),hint:{left:Math.round(hint.x*scale),top:Math.round(hint.y*scale),width:Math.round(hint.w*scale),height:Math.round(hint.h*scale)}};
 if(!geometry.error||!geometry.question||!geometry.input||!geometry.slider||geometry.review.length!==2)throw Error('Missing native geometry '+JSON.stringify(geometry));
}
function tablet(name,x,y,w,rz=-3,z=0){return place(`<div class="device tablet"><div class="screen"><img src="${images[name]}"/></div><i class="tablet-camera"></i></div>`,x,y,w,`z-index:${z};transform:perspective(3600px) rotateY(-4deg) rotateX(2deg) rotateZ(${rz}deg)`);}
async function tabletArt(i){
 const p=pages[i],c=copy[p.key];
 let b=background(i)+header(i)+accentBadge(i);
 const font=[1,6,7].includes(i)?'Caveat':i===2?'Nunito':'Fredoka';
 b+=txt(esc(c.title[0]),140,230,1760,166,{weight:500,align:'left'});
 b+=txt(esc(c.title[1]),140,415,1760,font==='Caveat'?280:211,{font,weight:font==='Caveat'?700:600,rotate:font==='Caveat'?-1:0,cls:'cedilla-fix'});
 b+=sub(c.subtitle,145,[1,6].includes(i)?780:720,1760);
 b+=`<div class="feature-tag" data-text-check data-copy="${esc(c.tag)}" style="top:${rtl?815:855}px;${rtl?'right':'left'}:145px">${esc(c.tag)}</div>`;
 b+=`<svg class="doodle" width="2064" height="2752" viewBox="0 0 2064 2752"><path d="M170 ${[1,6].includes(i)?725:655} Q680 ${[1,6].includes(i)?760:690} 1260 ${[1,6].includes(i)?715:645}" stroke="${i===1?'#BC5B3E':'#F6D37C'}" stroke-width="${i===1?13:35}" fill="none" stroke-linecap="round"/></svg>`;
 if(i===0){b+=tablet(p.source,660,960,1270);b+=place(`<div class="whole-error"><img src="${await crop(p.source,geometry.error)}"/></div>`,277,1330,1510,'z-index:5;transform:rotate(-2deg)');}
 if(i===1){b+=tablet(p.source,620,960,1300,2);b+=await component(p.source,inset(geometry.question,16),257,1270,1550,{rz:2,ry:3,pad:36,r:48});b+=lifted(await crop(p.source,geometry.input),307,1940,1450,{rz:2,ry:3,r:40});}
 if(i===2){b+=tablet(p.source,580,955,1310,-2);b+=await hintControl(267,1585,1530);b+=await component(p.source,inset(geometry.hint,12),267,1810,1530,{rz:-2,ry:-3,pad:36,r:48});}
 if(i===4){b+=tablet(p.source,665,950,1300,5);b+=place(`<img class="fox" src="${fox}"/>`,-50,1630,880,'z-index:5;transform:rotate(-10deg)');}
 if(i===5){b+=tablet(p.source,190,970,1270,-5,1);b+=tablet('01-results',1540,1220,1080,9,0);b+=await component(p.source,inset(geometry.review[0],22),175,1560,1550,{rz:3,ry:4,pad:36,r:48});b+=await component(p.source,inset(geometry.review[1],22),120,2050,1550,{rz:3,ry:4,pad:36,r:48});}
 if(i===6){b+=tablet(p.source,630,1040,1260,-4);[[372,1050,420,-8],[822,1050,420,0],[1272,1050,420,8]].forEach(([x,y,w,r],j)=>b+=place(`<img class="medal" src="${medals[j]}"/>`,x,y,w,`z-index:6;transform:rotate(${r}deg)`));}
 return b;
}
const localeCss=`${localeFont}
${!latin?`.copy,.feature-tag{font-family:Local!important;letter-spacing:0!important}.copy{line-height:${rtl?1.4:1.18}!important}.feature-tag{font-weight:700}`:''}
${rtl?'.copy,.feature-tag{direction:rtl}.copy{text-align:right!important}':''}
${pad?'.brand{left:140px;transform:scale(1.25);transform-origin:top left}.counter{right:140px;font-size:35px}.feature-tag{font-size:34px}.tablet{padding:30px;border-radius:70px}.tablet .screen{border-radius:42px}.tablet-camera{position:absolute;right:10px;top:49%;height:10px;width:10px;border-radius:50%;background:#151b21}.spotlight{width:1700px;height:1700px}':''}
`;
async function fitCopy(page){
 return await page.evaluate(({pad,rtl,latin,language})=>{
 const adjusted=[];
 for(const el of document.querySelectorAll('[data-text-check]')){
  if(!latin&&!el.classList.contains('subtitle')&&!el.classList.contains('feature-tag'))el.style.fontWeight=parseFloat(getComputedStyle(el).fontWeight)>=600?'800':'600';
  const c=getComputedStyle(el);let size=parseFloat(c.fontSize);const original=size;
  if(el.classList.contains('feature-tag')){
   el.style.maxWidth=(pad?1750:1120)+'px';
   while(el.scrollWidth>el.clientWidth+1&&size>20)el.style.fontSize=(--size)+'px';
  }else{
   const wrap=el.parentElement,top=parseFloat(wrap.style.top),sub=el.classList.contains('subtitle');
   if(!sub){
    const second=top>310;
    if(second&&!pad)wrap.style.top='410px';
    if(rtl)el.style.transform='none';
    if(second){wrap.style.width=(pad?1440:930)+'px';if(rtl||(!pad&&document.body.dataset.slot==='multi-blank')){wrap.style.left=(pad?480:300)+'px';}}
    const maxHeight=sub?125:(second?(pad?(['question','collection'].includes(document.body.dataset.slot)?330:260):(top>=390&&['home','review'].includes(document.body.dataset.slot)?300:220)):(pad?170:165));
    el.style.whiteSpace='normal';el.style.overflowWrap=latin||language==='ko'?'normal':'anywhere';if(language==='ko')el.style.wordBreak='keep-all';
    while((el.scrollWidth>el.clientWidth+1||el.getBoundingClientRect().height>maxHeight)&&size>(pad?90:72))el.style.fontSize=(--size)+'px';
   }else{
    while((el.scrollWidth>el.clientWidth+1||el.getBoundingClientRect().height>(pad?120:125))&&size>40)el.style.fontSize=(--size)+'px';
   }
  }
  if(!latin&&!el.classList.contains('subtitle')&&!el.classList.contains('feature-tag'))el.style.fontWeight=parseFloat(c.fontWeight)>=600?'800':'600';
  const r=el.getBoundingClientRect(),style=getComputedStyle(el);
  if(el.scrollWidth>el.clientWidth+1||r.x<45||r.right>(pad?2020:1275)||r.bottom>(el.classList.contains('feature-tag')?(pad?1000:1030):(pad?960:980)))throw Error('Caption bounds: '+el.dataset.copy+' '+JSON.stringify(r));
  adjusted.push({text:el.dataset.copy,fontFamily:style.fontFamily,fontWeight:style.fontWeight,fontSize:parseFloat(style.fontSize),direction:style.direction,x:r.x,y:r.y,width:r.width,height:r.height});
 }
 const subtitle=document.querySelector('.subtitle'),tag=document.querySelector('.feature-tag');
 const titles=[...document.querySelectorAll('.copy:not(.subtitle)')];
 if(titles.length===2){const first=titles[0],second=titles[1],wrap=second.parentElement;let a=first.getBoundingClientRect(),b=second.getBoundingClientRect();
 if(b.top<a.bottom+16)wrap.style.top=(parseFloat(wrap.style.top)+a.bottom+16-b.top)+'px';
 let size=parseFloat(getComputedStyle(second).fontSize);while(subtitle&&second.getBoundingClientRect().bottom>subtitle.getBoundingClientRect().top-18&&size>72)second.style.fontSize=(--size)+'px';}

 if(subtitle&&tag){tag.style.top=Math.max(parseFloat(tag.style.top),subtitle.getBoundingClientRect().bottom+24)+'px';
 if(!pad&&document.body.dataset.slot==='collection'){const shift=Math.max(0,tag.getBoundingClientRect().bottom+25-875);for(const medal of document.querySelectorAll('.medal'))medal.parentElement.style.top=(parseFloat(medal.parentElement.style.top)+shift)+'px';}}
 const texts=[...document.querySelectorAll('[data-text-check]')];
 for(let a=0;a<texts.length;a++)for(let b=a+1;b<texts.length;b++){const x=texts[a].getBoundingClientRect(),y=texts[b].getBoundingClientRect();if(Math.min(x.right,y.right)-Math.max(x.left,y.left)>5&&Math.min(x.bottom,y.bottom)-Math.max(x.top,y.top)>5)throw Error('Caption collision '+texts[a].dataset.copy+' / '+texts[b].dataset.copy);}
 return texts.map(e=>{const r=e.getBoundingClientRect(),c=getComputedStyle(e);return {text:e.dataset.copy,fontFamily:c.fontFamily,fontWeight:c.fontWeight,fontSize:parseFloat(c.fontSize),direction:c.direction,x:r.x,y:r.y,width:r.width,height:r.height};});
 },{pad,rtl,latin,language});
}
async function main(){
 const active=pad?[0,1,2,4,5,6]:[0,1,2,3,4,5,6,7];
 const archive=JSON.parse(fs.readFileSync('/Users/ahmet/Pictures/GrammarLens/1.4.0-raw/manifest.json'));
 for(const i of active){const p=pages[i],expect=archive.files.find(x=>x.file===`${language}/${family}/${p.source}.png`);if(!expect||crypto.createHash('sha256').update(fs.readFileSync(`${RAW}/${p.source}.png`)).digest('hex')!==expect.sha256)throw Error('Native source mismatch');}
 await loadGeometry();console.log('Native geometry '+language+'/'+family+' '+JSON.stringify(geometry));
 fs.mkdirSync(path.join(OUT,'store',folder),{recursive:true});
 const browser=await chromium.launch({headless:true,executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'});
 const page=await browser.newPage({viewport:{width:W,height:H},deviceScaleFactor:1});const records=[];
 try{for(const [order,i]of active.entries()){displayIndex=order;const p=pages[i];let png,text;
 if(language==='tr'&&!pad){const base='/Users/ahmet/Pictures/GrammarLens/design-explorations/tr-iphone/fade-vivid';png=fs.readFileSync(path.join(base,p.file+'.png'));text=JSON.parse(fs.readFileSync(path.join(base,'manifest.json'))).records.find(x=>x.file===p.file+'.png').text;}
 else{await page.setContent(`<html lang="${language}"><meta charset="utf-8"><style>${css}${tileCss}${polishCss}${localeCss}</style><body data-slot="${p.key}"><div class="stage" style="--ink:${p.ink}">${pad?await tabletArt(i):await art(i)}</div></body></html>`);await page.evaluate(async()=>{await document.fonts.ready;await Promise.all([...document.images].map(x=>x.decode()));});text=await fitCopy(page);png=await sharp(await page.screenshot()).removeAlpha().toColourspace('srgb').png().toBuffer();}
 const file=`store/${folder}/${p.source}.png`;fs.writeFileSync(path.join(OUT,file),png);records.push({file,order:order+1,slot:p.key,width:W,height:H,sha256:crypto.createHash('sha256').update(png).digest('hex'),text});console.log('Rendered '+language+'/'+family+'/'+p.source);
 }
 const thumbs=await Promise.all(records.map(r=>sharp(path.join(OUT,r.file)).resize({width:pad?516:330}).png().toBuffer()));const columns=pad?3:4,tw=pad?516:330,th=pad?688:717;
 await sharp({create:{width:columns*tw,height:th*2,channels:3,background:'#fff'}}).composite(thumbs.map((input,i)=>({input,left:i%columns*tw,top:Math.floor(i/columns)*th}))).removeAlpha().png().toFile(path.join(OUT,`overview-${family}.png`));
 const auditPath=path.join(OUT,'composition-audit.json'),audit=fs.existsSync(auditPath)?JSON.parse(fs.readFileSync(auditPath)):{language,sourceCommit:'c37757a',build:'1.4.0+7',design:'approved-vivid',layout:[],nativeGeometry:{}};
 audit.layout=audit.layout.filter(r=>!r.file.startsWith(`store/${folder}/`)).concat(records);audit.nativeGeometry[family]=geometry;fs.writeFileSync(auditPath,JSON.stringify(audit,null,2)+'\n');
 copy._meta.fontFamily=latin?'Fredoka / Caveat / Nunito Sans':{ja:'Noto Sans JP',ko:'Noto Sans KR',ar:'Noto Sans Arabic'}[language];copy._meta.fontWeights=latin?{tag:800,title:600,subtitle:650}:{tag:700,title:800,subtitle:650};copy._meta.design='approved vivid fade';copy._meta.fontWeightReview='See composition-audit.json for each caption’s actual font, weight and fitted size; caption wording unchanged.';
 fs.writeFileSync(path.join(OUT,'copy.json'),JSON.stringify(copy,null,2)+'\n');fs.writeFileSync(path.join(OUT,`copy.${language}.json`),JSON.stringify(copy,null,2)+'\n');
 }finally{await browser.close();}
}
main().catch(e=>{console.error(e);process.exit(1)});
