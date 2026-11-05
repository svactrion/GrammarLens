const fs=require('fs'),path=require('path'),crypto=require('crypto');
const sharp=require('/Users/ahmet/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const lang=process.argv[3];if(!lang)throw Error('Use verify.cjs --140 <language>');
const root=path.resolve('screenshots/1.4.0',lang),raw=path.resolve(process.env.CAPTURE_ROOT||'/private/tmp/grammarlens-140-captures',lang);
const assert=(v,m)=>{if(!v)throw Error(m);};const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const names=['01-results','02-hint','03-home','04-question','05-review','06-collection','07-onboarding','08-multi-blank'];
(async()=>{
 const audit=JSON.parse(fs.readFileSync(path.join(root,'composition-audit.json'))),rows=[];
 const copy=JSON.parse(fs.readFileSync(path.join(root,'copy.json')));
 const normalize=s=>s.replace(/\s+/g,' ').trim();
 const approvedOrder={iphone:['01-results','04-question','02-hint','08-multi-blank','03-home','05-review','06-collection','07-onboarding'],ipad:['01-results','04-question','02-hint','03-home','05-review','06-collection']};
 for(const [family,folder,w,h,count]of [['iphone','iphone-6.9',1320,2868,8],['ipad','ipad-13',2064,2752,6]]){
  const order=names.slice(0,count).map(n=>n+'.png');
  assert(JSON.stringify(fs.readdirSync(path.join(root,'store',folder)).sort())===JSON.stringify(order),'Frame count/order mismatch '+folder);
  const composed=audit.layout.filter(r=>r.file.startsWith(`store/${folder}/`)).sort((a,b)=>a.order-b.order);
  assert(JSON.stringify(composed.map(r=>path.basename(r.file,'.png')))===JSON.stringify(approvedOrder[family]),'Approved design sequence differs '+folder);
  const locale=JSON.parse(fs.readFileSync(path.join(raw,'raw',family,'locale-audit.json')));
  assert(locale.locale===lang.split('-')[0]&&locale.languageSetting==='system','Wrong language '+family);
  const hint=JSON.parse(fs.readFileSync(path.join(raw,'raw',family,'hint-state.json')));
  assert(hint.pointerHeld&&hint.knobAtEnd&&hint.releasedAndCardClosed,'Hint not held/released '+family);
  assert(hint.questionId==='day0_5'&&hint.correctAnswer==='saw'&&!hint.promptVerbOrAnswerInHint,'Wrong hint fixture '+family);
  assert(hint.card.y+hint.card.h<hint.screenLogicalHeight,'Hint below viewport '+family);
  for(const file of order){
   const b=fs.readFileSync(path.join(root,'store',folder,file)),m=await sharp(b).metadata();
   assert(m.width===w&&m.height===h&&!m.hasAlpha&&m.channels===3&&m.space==='srgb','Invalid final '+file);
   const original=fs.readFileSync(path.join(raw,'raw',family,file)),rm=await sharp(original).metadata();
   assert(rm.width===w&&rm.height===h,'Wrong native capture size '+family+'/'+file);
   assert(audit.layout.some(r=>r.file===`store/${folder}/${file}`&&r.sha256===hash(b)),'Composition checksum differs '+file);
   const record=composed.find(r=>r.file===`store/${folder}/${file}`),caption=copy[file.slice(3,-4)];
   if(family==='ipad'&&['01-results.png','04-question.png','02-hint.png','05-review.png'].includes(file)){
    const aligned=record.foregroundAlignment;
    assert(aligned?.length===({'01-results.png':1,'04-question.png':3,'02-hint.png':1,'05-review.png':2}[file]),'Missing foreground alignment '+file);
    for(const card of aligned)assert(Math.abs(card.cardCenterX-card.screenCenterX)<1&&card.left>=35&&card.right<=2029,'Foreground is not centered on the device screen '+file);
   }
   const rendered=record.text.map(r=>normalize(r.text));
   for(const text of [caption.tag,...caption.title,caption.subtitle])assert(rendered.includes(normalize(text)),'Caption wording differs '+lang+'/'+file+': '+text);
   rows.push({set:folder,order:record.order,file,width:w,height:h,alpha:false,sha256:hash(b),rawSha256:hash(original)});
  }
 }
 for(const family of ['iphone','ipad']){const m=await sharp(path.join(root,`overview-${family}.png`)).metadata();assert(!m.hasAlpha&&m.channels===3,'Invalid overview');}
 const result={status:'passed',language:lang,sourceCommit:'c37757a',build:'1.4.0+7',design:'approved-vivid',captionWording:'unchanged from blind-reviewed inputs',font:copy._meta,iphoneCount:8,ipadCount:6,rows};
 fs.writeFileSync(path.join(root,'verification.json'),JSON.stringify(result,null,2)+'\n');console.log(`${lang}: PASS — 8 iPhone + 6 iPad, ordered, exact dimensions, opaque RGB, checksums and hint audited`);
})().catch(e=>{console.error(e);process.exit(1)});
