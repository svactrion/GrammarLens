const fs=require('fs'),path=require('path');
const deps='/Users/ahmet/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules';
const {chromium}=require(deps+'/playwright'),sharp=require(deps+'/sharp');
const out=path.resolve('screenshots/1.4.0/product-page'),W=3840,H=1646;
const font=fs.readFileSync('assets/fonts/NunitoSans-Variable.ttf').toString('base64');
const face=`@font-face{font-family:Brand;src:url(data:font/ttf;base64,${font});font-weight:200 1000;font-style:normal}`;
const navy='#0D3B8F',orange='#FF7A1A',ivory='#F3EFE6';
const fadeBackground=`<defs><linearGradient id="vivid-field"><stop offset="0" stop-color="#FF8F9E"/><stop offset=".16" stop-color="#FFC36C"/><stop offset=".32" stop-color="#D7EE87"/><stop offset=".47" stop-color="#7EDDD2"/><stop offset=".62" stop-color="#9EC0FF"/><stop offset=".77" stop-color="#C6A0ED"/><stop offset=".9" stop-color="#FFADBB"/><stop offset="1" stop-color="#FFD284"/></linearGradient><linearGradient id="vivid-depth" x1="0" y1="0" x2=".15" y2="1"><stop stop-color="#FFFFFF" stop-opacity=".23"/><stop offset=".48" stop-color="#FFFFFF" stop-opacity="0"/><stop offset="1" stop-color="#B54891" stop-opacity=".19"/></linearGradient><radialGradient id="warm-glow"><stop stop-color="#FFEAD0" stop-opacity=".62"/><stop offset="1" stop-color="#FFEAD0" stop-opacity="0"/></radialGradient><radialGradient id="type-clear"><stop stop-color="#FFF8ED" stop-opacity=".3"/><stop offset="1" stop-color="#FFF8ED" stop-opacity="0"/></radialGradient></defs><rect width="3840" height="1646" fill="url(#vivid-field)"/><rect width="3840" height="1646" fill="url(#vivid-depth)"/><ellipse cx="850" cy="330" rx="1700" ry="1400" fill="url(#warm-glow)"/><ellipse cx="3050" cy="1150" rx="1700" ry="1400" fill="url(#warm-glow)"/><ellipse cx="1920" cy="823" rx="2300" ry="800" fill="url(#type-clear)"/>`;
const wordmark=`<text id="wordmark" x="0" y="0" font-size="500"><tspan fill="${navy}">Grammar</tspan><tspan id="lens" fill="${orange}">Lens</tspan></text>`;
const card=`<g transform="translate(2390 490) scale(.75) rotate(-5 640 480)"><rect x="0" y="0" width="1280" height="960" rx="88" fill="#FFF8ED" stroke="#9BCBF0" stroke-width="12"/><g id="correction-underlays"></g><text id="wrong-line" x="90" y="275" font-size="106" fill="${navy}">She <tspan id="wrong">write</tspan> every day.</text><text id="right-line" x="90" y="590" font-size="106" fill="${navy}">She <tspan id="correct">writes</tspan> every day.</text><g id="correction-marks"></g><path d="M645 825 C770 735 827 883 979 831" fill="none" stroke="${navy}" stroke-width="11" stroke-linecap="round"/><g transform="translate(1110 700) rotate(45)"><path d="M-34 38 L34 38 L55 108 L0 185 L-55 108 Z" fill="${orange}"/><path d="M0 180 V103" stroke="#FFF8ED" stroke-width="7" stroke-linecap="round"/><circle cy="96" r="11" fill="#FFF8ED"/><rect x="-40" y="-55" width="80" height="104" rx="17" fill="${navy}"/><path d="M-36 25 H36" stroke="#2356A0" stroke-width="8" stroke-linecap="round"/></g></g>`;
const icons=`
<g transform="translate(400 170) rotate(-8 190 135)"><path d="M72 225 L35 286 L118 253 C238 271 326 205 326 123 C326 46 253 0 167 0 C70 0 0 51 0 126 C0 170 25 204 72 225Z" fill="none" stroke="${navy}" stroke-width="27" stroke-linejoin="round"/><path d="M268 112 C184 112 133 164 133 221 C133 289 210 332 285 315 L342 349 L333 293 C375 269 397 237 397 204 C397 146 344 112 268 112Z" fill="#FFD4AD" stroke="${ivory}" stroke-width="13" stroke-linejoin="round"/><g fill="${orange}"><circle cx="213" cy="218" r="17"/><circle cx="268" cy="218" r="17"/><circle cx="323" cy="218" r="17"/></g></g>
<g transform="translate(2990 146) rotate(10 200 160)"><rect x="-28" y="70" width="302" height="234" rx="46" fill="#FFF8ED" transform="rotate(-18 123 187)"/><text x="71" y="222" font-size="154" fill="${navy}">Aa</text><circle cx="169" cy="166" r="147" fill="none" stroke="${orange}" stroke-width="29"/><path d="M280 277 L394 365" stroke="${orange}" stroke-width="62" stroke-linecap="round"/></g>
<g transform="translate(346 1190) rotate(-10 185 122)" stroke="${navy}" stroke-width="25" stroke-linejoin="round"><path d="M185 29 C122 -9 55 -5 0 24 V249 C61 224 123 231 185 266Z" fill="#FFF8ED"/><path d="M185 29 C250 -8 314 -7 370 22 V249 C307 228 246 229 185 266Z" fill="${orange}"/><path d="M185 29 V266" fill="none"/></g>
<g transform="translate(3028 1165) rotate(8 215 135)"><rect width="430" height="270" rx="58" fill="#C7DEF8"/><path d="M73 89 H221 M73 151 H185" stroke="${navy}" stroke-width="26" stroke-linecap="round"/><path d="M285 144 L320 184 L380 105" stroke="${orange}" stroke-width="28" stroke-linecap="round" stroke-linejoin="round" fill="none"/></g>`;
(async()=>{const browser=await chromium.launch({headless:true,executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'});
try{const page=await browser.newPage({viewport:{width:W,height:H},deviceScaleFactor:1});const metrics=[];
for(const variant of ['A']){
 await page.setContent(`<html><meta charset="utf-8"><style>${face}html,body{margin:0;background:${ivory}}svg{display:block}text{font-family:Brand;font-weight:800;font-kerning:normal;letter-spacing:0}</style><body><svg width="3840" height="1646" viewBox="0 0 3840 1646">${fadeBackground}${variant==='A'?card:icons}${wordmark}<g id="brand-accent"></g></svg></body></html>`);
 await page.evaluate(()=>document.fonts.ready);
 metrics.push(await page.evaluate(({variant,navy,orange})=>{
  if(!document.fonts.check('800 500px Brand'))throw Error('Font missing');
  const svgNS='http://www.w3.org/2000/svg';
  function add(parent,tag,attrs){const e=document.createElementNS(svgNS,tag);for(const [k,v] of Object.entries(attrs))e.setAttribute(k,v);document.getElementById(parent).append(e);return e;}
  const t=document.getElementById('wordmark'),target=1850;
  t.setAttribute('font-size',500*target/t.getBBox().width);const box=t.getBBox(),left=450;
  const tx=left-box.x,ty=(1700-box.height)/2-box.y;t.setAttribute('transform',`translate(${tx},${ty})`);
  if(variant==='B'){
   const l=document.getElementById('lens').getBBox(),x=l.x+tx,w=l.width,y=1038;
   add('brand-accent','path',{d:`M${x+20} ${y} Q${x+w*.5} ${y-74} ${x+w-25} ${y-18}`,fill:'none',stroke:orange,'stroke-width':25,'stroke-linecap':'round'});
  }else{
   const wrong=document.getElementById('wrong-line'),right=document.getElementById('right-line');let sz=106;
   while(Math.max(wrong.getBBox().width,right.getBBox().width)>1100){sz-=.5;wrong.setAttribute('font-size',sz);right.setAttribute('font-size',sz);}
   const a=document.getElementById('wrong').getBBox(),b=document.getElementById('correct').getBBox();
   add('correction-underlays','rect',{x:b.x-19,y:b.y+9,width:b.width+38,height:b.height-13,rx:27,fill:'#FFD4AD'});
   add('correction-marks','path',{d:`M${a.x-10} ${a.y+a.height*.57} L${a.x+a.width+12} ${a.y+a.height*.5}`,stroke:orange,'stroke-width':14,'stroke-linecap':'round',fill:'none'});
   const cx=a.x+a.width/2,cy=a.y+a.height+35,endX=b.x+b.width*.55,endY=b.y-32;
   add('correction-marks','path',{d:`M${cx+4} ${cy} C${cx-74} ${cy+65} ${endX-75} ${endY-50} ${endX} ${endY}`,stroke:orange,'stroke-width':13,'stroke-linecap':'round',fill:'none'});
   add('correction-marks','path',{d:`M${endX-41} ${endY-2} L${endX+3} ${endY+4} L${endX+5} ${endY-41}`,stroke:orange,'stroke-width':13,'stroke-linecap':'round','stroke-linejoin':'round',fill:'none'});
   add('correction-marks','path',{d:`M${b.x-3} ${b.y+b.height+13} Q${b.x+b.width*.5} ${b.y+b.height+23} ${b.x+b.width+3} ${b.y+b.height+12}`,stroke:orange,'stroke-width':12,'stroke-linecap':'round',fill:'none'});
  }
  const r=t.getBoundingClientRect(),paper=document.querySelector('svg>g>rect').getBoundingClientRect();if(r.left<400||r.right>2340||paper.left<2320||paper.right>3440||paper.top<420||paper.bottom>1290)throw Error('Shared crop bounds');for(const el of document.querySelectorAll('text')){const q=el.getBoundingClientRect();if(q.left<0||q.top<0||q.right>3840||q.bottom>1646)throw Error('Text out of bounds');}
  return {variant,font:'Nunito Sans ExtraBold 800',wordmarkWidth:r.width,wordmarkLeft:r.left};
 },{variant,navy,orange}));
 await sharp(await page.screenshot()).removeAlpha().toColourspace('srgb').png().toFile(path.join(out,`header-${variant}-balanced-v5.png`));
}
console.log('Balanced v5 exported; current uploaded header retained.');
}finally{await browser.close();}})().catch(e=>{console.error(e);process.exit(1)});
