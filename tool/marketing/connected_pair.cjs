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

// One panoramic master, exported as two adjacent portrait tiles.
// Real screenshots remain whole; shared geometry continues through the seam.
const out=path.join(root,'experiments/connected-pair-v1');
const W=2640,H=2868,PW=1320;
const messages={
 tr:{tags:['01 · GÜNLÜK PRATİK','02 · AÇIKLAMALI SONUÇLAR'],titles:[['Önce','kendin yaz.'],['Sonra','nedenini öğren.']],body:[['İngilizce gramerini','kısa sorularla çalış.'],['Doğru cevabı gör.','Bir sonraki adımı daha bilinçli at.']]},
 en:{tags:['01 · DAILY PRACTICE','02 · CLEAR EXPLANATIONS'],titles:[['Write your','answer.'],['Understand','why.']],body:[['Build your grammar','one written answer at a time.'],['See the correction.','Take your next step with confidence.']]}
};
const backdrop=rect(0,0,W,H,0,C.paper)+`<defs>
 <linearGradient id="panorama" x1="0" y1="0" x2="1" y2=".8"><stop stop-color="#FFFBF4"/><stop offset=".46" stop-color="#F3EFE6"/><stop offset="1" stop-color="#FCE3D1"/></linearGradient>
 <radialGradient id="halo"><stop stop-color="#D7E1FA" stop-opacity=".78"/><stop offset="1" stop-color="#D7E1FA" stop-opacity="0"/></radialGradient></defs>`+rect(0,0,W,H,0,'url(#panorama)')+
 `<ellipse cx="1320" cy="1950" rx="1420" ry="1220" fill="url(#halo)"/>
 <circle cx="1320" cy="2000" r="1150" fill="none" stroke="#0D3B8F" stroke-width="4" opacity=".07"/>
 <circle cx="1320" cy="2000" r="850" fill="none" stroke="#0D3B8F" stroke-width="4" opacity=".07"/>
 <path d="M-150 2470 C430 2870 1080 2680 1150 2180 C1210 1750 1420 1510 1850 1530 S2400 1540 2820 1060" fill="none" stroke="#FFFBF4" stroke-width="125" stroke-linecap="round"/>
 <path d="M-150 2470 C430 2870 1080 2680 1150 2180 C1210 1750 1420 1510 1850 1530 S2400 1540 2820 1060" fill="none" stroke="#FF7A1A" stroke-width="88" stroke-linecap="round"/>
 <path d="M-150 2470 C430 2870 1080 2680 1150 2180 C1210 1750 1420 1510 1850 1530 S2400 1540 2820 1060" fill="none" stroke="#FFFBF4" stroke-width="4" stroke-dasharray="5 27" stroke-linecap="round"/>
 <path d="M1190 1900 L1255 1848 L1252 1932" fill="none" stroke="#0D3B8F" stroke-width="12" stroke-linecap="round" stroke-linejoin="round"/>`;
function artwork(lang){
 const c=messages[lang];let body=backdrop;
 [0,1].forEach(i=>{
  const x=100+i*PW;
  body+=brand(x,67,74,46)+t(x,240,c.tags[i],24,C.navy,800,2.2);
  body+=lines(x-7,391,c.titles[i],lang==='tr'?(i===0?119:105):116,137,C.ink,900,-3.8);
  body+=lines(x,620,c.body[i],31,50,C.muted,600,0);
 });
 body+=phone('02-daily-test',180,777,960)+phone('03-feedback',1500,777,960);
 return body;
}
const manifest={status:'experiment-awaiting-user-review',concept:'Two adjacent portrait tiles from one continuous panorama',master:[W,H],tile:[PW,H],interfaceLanguage:'en',languages:['tr','en'],rawScreens:['02-daily-test','03-feedback'],exports:[]};
function mark(file,b,w,h){manifest.exports.push({file,width:w,height:h,alpha:false,sha256:crypto.createHash('sha256').update(b).digest('hex')});}
async function main(){
 const browser=await chromium.launch({headless:true,executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'});
 const page=await browser.newPage({viewport:{width:W,height:H},deviceScaleFactor:1});
 try{
  for(const lang of ['tr','en']){
   const body=artwork(lang),full=svg(W,H,body);
   fs.writeFileSync(path.join(out,lang+'-panorama.svg'),full);
   await page.setContent(`<html><head><meta charset="utf-8"><style>html,body{margin:0;background:transparent;width:${W}px;height:${H}px;overflow:hidden}svg{display:block}</style></head><body>${full}</body></html>`);
   await page.evaluate(()=>document.fonts.ready);
   const overflow=await page.evaluate(()=>[...document.querySelectorAll('[data-check="text"]')].map(e=>({text:e.textContent,b:e.getBoundingClientRect().toJSON()})).filter(e=>{const left=e.b.x>=1320?1320:0;return e.b.x<left||e.b.right>left+1320-80||e.b.top<0||e.b.bottom>2868;}));
   if(overflow.length)throw Error('Text overflows panel: '+JSON.stringify(overflow));
   const shot=await page.screenshot({omitBackground:true});
   const master=await sharp(shot).flatten({background:C.paper}).removeAlpha().png().toBuffer();
   fs.writeFileSync(path.join(out,lang+'-panorama.png'),master);mark(lang+'-panorama.png',master,W,H);
   await sharp(master).webp({quality:95,effort:6}).toFile(path.join(out,lang+'-panorama.webp'));
   const slices=[];
   for(let i=0;i<2;i++){
    const file=lang+'-0'+(i+1)+(i===0?'-write':'-understand');
    const png=await sharp(master).extract({left:i*PW,top:0,width:PW,height:H}).png().toBuffer();slices.push(png);
    fs.writeFileSync(path.join(out,file+'.png'),png);mark(file+'.png',png,PW,H);
    await sharp(png).webp({quality:95,effort:6}).toFile(path.join(out,file+'.webp'));
    fs.writeFileSync(path.join(out,file+'.svg'),`<svg xmlns="http://www.w3.org/2000/svg" width="${PW}" height="${H}" viewBox="${i*PW} 0 ${PW} ${H}">${defs}${body}</svg>`);
   }
   const merged=await sharp({create:{width:W,height:H,channels:3,background:C.paper}}).composite([{input:slices[0],left:0,top:0},{input:slices[1],left:PW,top:0}]).removeAlpha().raw().toBuffer();
   const source=await sharp(master).removeAlpha().raw().toBuffer();
   if(!merged.equals(source))throw Error('Seam mismatch');
   await sharp(master).resize({width:1320}).webp({quality:92}).toFile(path.join(out,lang+'-preview.webp'));
   for(let i=0;i<2;i++)await sharp(slices[i]).resize({width:660}).webp({quality:92}).toFile(path.join(out,lang+'-preview-0'+(i+1)+'.webp'));
   console.log('Rendered '+lang+': master + two tiles; recombination pixel-identical');
  }
 }finally{await browser.close();}
 fs.writeFileSync(path.join(out,'source/copy.json'),JSON.stringify(messages,null,2)+'\n');
 fs.copyFileSync('assets/fonts/NunitoSans-Variable.ttf',path.join(out,'source/NunitoSans-Variable.ttf'));
 fs.copyFileSync('assets/fonts/OFL-NunitoSans.txt',path.join(out,'source/OFL-NunitoSans.txt'));
 fs.copyFileSync('assets/icon/app_icon.png',path.join(out,'source/app-icon.png'));
 fs.writeFileSync(path.join(out,'manifest.json'),JSON.stringify({...manifest,seamVerification:'Both PNG tiles reassembled are pixel-identical to the master',sourceMethod:'Original captured app PNGs embedded in editable SVG; shared vectors rendered once then split'},null,2)+'\n');
}
main().catch(e=>{console.error(e);process.exit(1)});
