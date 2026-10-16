// Actual screenshots + original vector layout. The app's Nunito Sans is embedded.
const fs=require('fs');
const path=require('path');
const crypto=require('crypto');
const deps='/Users/ahmet/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules';
const sharp=require(deps+'/sharp');
const {chromium}=require(deps+'/playwright');
const root=path.resolve('docs/product/marketing/2026-10-09');
const copy=JSON.parse(fs.readFileSync('tool/marketing/copy.json','utf8'));
const names=['01-home','02-daily-test','03-feedback','04-review','05-weak-spot','06-medals'];
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
const assets=[];
let browser,page;
async function write(file,w,h,body,{transparent=false,webp=true}={}){
 const full=svg(w,h,body),base=path.join(root,file);
 fs.mkdirSync(path.dirname(base),{recursive:true});fs.writeFileSync(base+'.svg',full);
 await page.setViewportSize({width:w,height:h});
 await page.setContent(`<html><head><meta charset="utf-8"/><style>html,body{margin:0;width:${w}px;height:${h}px;overflow:hidden;background:transparent}svg{display:block}</style></head><body>${full}</body></html>`);
 await page.evaluate(()=>document.fonts.ready);
 await page.evaluate(()=>Promise.all([...document.images].map(im=>im.complete?Promise.resolve():new Promise(r=>im.onload=r))));
 const bad=await page.evaluate(()=>[...document.querySelectorAll('[data-check="text"]')].map(e=>({text:e.textContent,box:e.getBoundingClientRect().toJSON()})).filter(e=>e.box.x < -0.5 || e.box.y < -0.5 || e.box.right>innerWidth+.5 || e.box.bottom>innerHeight+.5));
 if(bad.length)throw new Error('Text overflow '+file+JSON.stringify(bad));
 const shot=await page.screenshot({omitBackground:true});
 const png=transparent?await sharp(shot).png().toBuffer():await sharp(shot).flatten({background:C.paper}).removeAlpha().png().toBuffer();
 fs.writeFileSync(base+'.png',png);
 if(webp)await sharp(png).webp({quality:94,effort:6}).toFile(base+'.webp');
 const meta=await sharp(png).metadata();
 assets.push({file:file+'.png',width:meta.width,height:meta.height,alpha:meta.hasAlpha,sha256:crypto.createHash('sha256').update(png).digest('hex')});
 console.log('Exported '+file);
}
async function main(){
 browser=await chromium.launch({headless:true,executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'});
 page=await browser.newPage({deviceScaleFactor:1});
 for(const n of names)await write('framed/'+n,1552,3098,phone(n,70,55,1412,{shadow:false}),{transparent:true,webp:false});
 for(const lang of ['tr','en']){
 const c=copy[lang];
 let hero=bg(2400,1600)+brand(128,112,88,54)+t(132,352,c.eyebrow,24,C.navy,800,2.3);
 hero+=lines(122,545,c.heroTitle,lang==='tr'?122:128,143,C.ink,900,-4.7);
 hero+=rect(132,889,112,8,4,C.orange)+lines(132,995,c.heroBody,32,51,C.muted,500,0);
 hero+=pill(132,1180,lang==='tr'?216:207,c.heroPills[0])+pill(365,1180,lang==='tr'?340:315,c.heroPills[1]);
 hero+=t(132,1458,c.footer,25,C.muted,600);
 hero+=phone('03-feedback',1172,360,482)+phone('01-home',1712,210,550);
 await write('marketing/'+lang+'-01-hero',2400,1600,hero);
 let flow=bg(2400,1600)+brand(100,70,70,42)+t(2300,118,lang==='tr'?'PRATİK → GERİ BİLDİRİM → TEKRAR':'PRACTISE → UNDERSTAND → REVIEW',21,C.navy,800,1.2,'end');
 flow+=t(100,260,c.flowTitle,lang==='tr'?83:76,C.ink,900,-2.9)+t(103,327,c.flowSubtitle,30,C.muted,500);
 [1,2,3].forEach((n,i)=>{const x=112+i*775;flow+=phone(names[n],x+109,407,485);flow+=t(x,1490,'0'+(i+1),28,C.orange,900)+t(x+64,1490,c.flowSteps[i],36,C.navy,900,-.4)+t(x,1545,c.flowBodies[i],23,C.muted,500);});
 await write('marketing/'+lang+'-02-flow',2400,1600,flow);
 let card=bg(1600,1200)+brand(92,81,65,40)+t(92,285,c.eyebrow,19,C.navy,800,1.7);
 card+=lines(85,430,lang==='tr'?['Küçük adımlar.','Daha güçlü','İngilizce.']:['Small steps.','Stronger','English.'],lang==='tr'?77:90,105,C.ink,900,-2.9);
 card+=rect(92,706,90,7,3,C.orange)+lines(92,792,lang==='tr'?['Günlük pratik. Açık geri bildirim.','Görünür ilerleme.']:['Daily practice. Clear feedback.','Visible progress.'],29,47,C.muted,600,0);
 card+=pill(92,920,lang==='tr'?217:208,c.heroPills[0]);
 card+=phone('01-home',978,126,448)+rule(92,1100,1416)+t(92,1152,c.cardBody,26,C.muted,600);
 await write('marketing/'+lang+'-03-product-card',1600,1200,card);
 let social=bg(2400,1260)+brand(127,111,79,49)+t(132,323,c.eyebrow,22,C.navy,800,2.2);
 social+=lines(122,532,c.socialTitle,lang==='tr'?115:112,148,C.ink,900,-3.4)+rect(132,757,107,8,4,C.orange)+lines(132,875,c.socialBody,33,53,C.muted,500,0)+t(132,1136,c.footer,24,C.muted,700);
 social+=phone('01-home',1300,145,450)+phone('05-weak-spot',1807,210,440);
 await write('marketing/'+lang+'-04-social',2400,1260,social);
 for(let i=0;i<names.length;i++){
 let store=bg(1320,2868)+brand(90,66,61,38)+t(1230,112,String(i+1).padStart(2,'0')+' / 06',22,C.navy,800,1,'end');
 store+=t(90,230,c.storeTags[i],22,C.navy,800,1.6);
 store+=lines(84,356,c.storeTitles[i],lang==='en'&&i===3?77:82,99,C.ink,900,-2.5)+t(90,537,c.storeBodies[i],27,C.muted,600);
 store+=phone(names[i],146,626,1028);
 await write('app-store/'+lang+'/'+names[i],1320,2868,store);
 }
 let review=bg(2400,1510)+brand(83,66,61,38)+t(2310,112,lang==='tr'?'GERÇEK ÜRÜN EKRANLARI':'ACTUAL PRODUCT SCREENS',22,C.navy,800,1.3,'end');
 names.forEach((n,i)=>{const x=66+i*390;review+=t(x,235,String(i+1).padStart(2,'0'),23,C.orange,900)+t(x,289,c.screenLabels[i],25,C.ink,800)+phone(n,x+13,345,330);});
 review+=t(83,1450,'iPhone 18 Pro Max · '+(lang==='tr'?'Gerçek İngilizce arayüz · Örnek kullanıcı: Sam':'Actual English interface · Fictional learner: Sam'),23,C.muted,600);
 await write('review-'+lang,2400,1510,review,{webp:false});
 }
 fs.copyFileSync('tool/marketing/copy.json',path.join(root,'source/copy.json'));
 fs.copyFileSync('assets/fonts/NunitoSans-Variable.ttf',path.join(root,'source/NunitoSans-Variable.ttf'));
 fs.copyFileSync('assets/icon/app_icon.png',path.join(root,'source/app-icon.png'));
 fs.writeFileSync(path.join(root,'manifest.json'),JSON.stringify({status:'draft-awaiting-user-approval',capturedDevice:'GrammarLens Product Capture / iPhone 18 Pro Max / iOS 27.0 simulator',deviceId:'7EB79F5A-B0D4-4EAC-89B6-E46CEB91286D',display:[1320,2868],appVersion:'1.2.0+5',interfaceLanguage:'en',marketingLanguages:['tr','en'],database:'product_capture_2026_10_09.db (dedicated simulator only)',frame:'Original illustrative front-facing vector; not an official Apple marketing asset',frameReference:'https://www.apple.com/iphone-18-pro/specs/',storeSizeReference:'https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/',sampleContent:'Fictional learner Sam, Fox; bundled questions and seeded local practice history',exports:assets},null,2)+'\n');
 await browser.close();
}
main().catch(async e=>{console.error(e);if(browser)await browser.close();process.exit(1);});
