// Caption-weight comparison only. Temporary proof is never shipped.
const fs=require('fs'),path=require('path');
const {chromium}=require('/Users/ahmet/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
(async()=>{const browser=await chromium.launch({executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true});const page=await browser.newPage({viewport:{width:1800,height:1500},deviceScaleFactor:1});
const fonts={en:'assets/fonts/NunitoSans-Variable.ttf',ja:'tool/marketing/store_130/fonts/NotoSansJP.ttf',ko:'tool/marketing/store_130/fonts/NotoSansKR.ttf',ar:'tool/marketing/store_130/fonts/NotoSansArabic.ttf'};
let css='body{margin:30px;background:#FFFBF4;color:#1B1B1F} .row{display:grid;grid-template-columns:180px 1fr;gap:20px;margin-bottom:12px} .label{font:24px sans-serif}';let body='';
for(const [lang,file]of Object.entries(fonts)){
 css+=`@font-face{font-family:${lang};src:url(data:font/ttf;base64,${fs.readFileSync(file).toString('base64')});font-weight:100 1000}`;
 const c=JSON.parse(fs.readFileSync(`tool/marketing/store_130/copy.${lang}.json`));
 for(const weight of lang==='en'?[900]:[700,800,900])body+=`<div class="row"><span class="label">${lang} ${weight}</span><div style="font-family:${lang};font-weight:${weight};font-size:62px;direction:${lang==='ar'?'rtl':'ltr'}">${c.results.title.join(lang==='ja'?'':' ')}</div></div>`;
}
await page.setContent(`<style>${css}</style>${body}`);await page.evaluate(()=>document.fonts.ready);await page.screenshot({path:'/private/tmp/grammarlens-140-font-proof.png',fullPage:true});await browser.close();})();
