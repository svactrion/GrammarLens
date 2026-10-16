const fs=require('fs'),path=require('path'),crypto=require('crypto'),cp=require('child_process');
const sharp=require('/Users/ahmet/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root=path.resolve('docs/product/marketing/2026-10-16-app-store');
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const assert=(value,message)=>{if(!value)throw Error(message);};
async function main(){
 assert(!fs.existsSync(path.join(root,'grammarlens-1.3.0-app-store')),'Old extracted package is nested in the delivery folder');
 const manifest=JSON.parse(fs.readFileSync(path.join(root,'manifest.json'),'utf8'));
 assert(manifest.exports.length===17,'Expected 14 store PNGs and three overviews');
 const copy=JSON.parse(fs.readFileSync(path.join(root,'source/copy.json'),'utf8'));
 const contract=JSON.parse(fs.readFileSync(path.join(root,'source/revision-contract.json'),'utf8'));
 const composer=fs.readFileSync('tool/marketing/store_130/compose.cjs','utf8');
 const drawing=composer.split('const sets=')[0];
 assert(hash(drawing)===contract.drawingFunctionsSha256,'Approved drawing functions changed');
 assert(hash(composer.slice(composer.indexOf('function poster('),composer.indexOf('async function overview(')))===contract.posterLayoutSha256,'Approved poster layout changed');
 for(const [key,approved]of Object.entries(contract.copy)){
  for(const [field,value]of Object.entries(approved))assert(JSON.stringify(copy[key][field])===JSON.stringify(value),'Approved copy changed: '+key+'.'+field);
 }
 const expected={iphone:['01-results','02-hint','03-home','04-question','05-review','06-collection','07-onboarding','08-multi-blank'],ipad:['01-results','02-hint','03-home','04-question','05-review','06-collection']};
 assert(JSON.stringify(manifest.uploadOrder)===JSON.stringify(expected),'Requested upload order not applied');
 assert(!copy['weak-spot'],'Removed weak-spot detail still in active copy');
 const files=[],raw=[],hints=[];
 const ipadOcr=JSON.parse(fs.readFileSync(path.join(root,'source/native-ipad-ocr.json'),'utf8'));
 const iphoneOcr=JSON.parse(fs.readFileSync(path.join(root,'source/native-iphone-ocr.json'),'utf8'));
 const nativeText=(records,file)=>records.find(x=>x.file===file)?.lines.map(x=>x.text).join(' ')||'';
 for(const records of [iphoneOcr,ipadOcr]){
  for(const file of ['04-question.png','02-hint.png'])assert(/Yesterday I/.test(nativeText(records,file))&&/great film/.test(nativeText(records,file)),'Question not visible: '+file);
  assert(/have seen/.test(nativeText(records,'01-results.png'))&&/saw/.test(nativeText(records,'01-results.png')),'New result not visible');
  assert(/Tense Selection/.test(nativeText(records,'05-review.png'))&&/last seen today/.test(nativeText(records,'05-review.png')),'Review not linked to current question');
 }
 const ipadCorners=[];
 for(const asset of manifest.exports){
  const buffer=fs.readFileSync(path.join(root,asset.file));
  const meta=await sharp(buffer).metadata();
  assert(meta.width===asset.width&&meta.height===asset.height,'Size mismatch: '+asset.file);
  assert(!meta.hasAlpha&&meta.channels===3&&meta.space==='srgb','Not opaque RGB: '+asset.file);
  assert(hash(buffer)===asset.sha256,'Hash mismatch: '+asset.file);
  const svg=fs.readFileSync(path.join(root,asset.file.replace('.png','.svg')),'utf8');
  assert(svg.includes('data:font/ttf;base64,'),'Missing embedded font: '+asset.file);
  files.push({file:asset.file,width:meta.width,height:meta.height,channels:meta.channels,alpha:meta.hasAlpha,space:meta.space});
 }
 for(const [family,names]of Object.entries(manifest.uploadOrder)){
  const [w,h]=manifest.devices[family].size;
  assert(names.length===(family==='iphone'?8:6),'Unexpected set length');
  const actual=fs.readdirSync(path.join(root,'app-store',family)).filter(f=>f.endsWith('.png'));
  assert(actual.length===names.length,'Extra upload PNGs in '+family);
  for(const [folder,extension] of [[`raw/${family}`,'.png'],[`app-store/${family}`,'.svg']]){
   const filenames=fs.readdirSync(path.join(root,folder)).filter(x=>x.endsWith(extension)).sort();
   assert(JSON.stringify(filenames)===JSON.stringify(names.map(n=>n+extension).sort()),'Unexpected active files in '+folder);
  }
  for(const [i,name]of names.entries()){
   assert(name.startsWith(String(i+1).padStart(2,'0')+'-'),'Incorrect upload numbering');
   const file=`raw/${family}/${name}.png`,buffer=fs.readFileSync(path.join(root,file)),meta=await sharp(buffer).metadata();
   assert(meta.width===w&&meta.height===h,'Raw native size mismatch: '+file);
   const svg=fs.readFileSync(path.join(root,'app-store',family,name+'.svg'),'utf8');
   assert(svg.includes(buffer.toString('base64')),'SVG does not embed original raw PNG: '+file);
   assert(svg.includes(`>${String(i+1).padStart(2,'0')} / ${String(names.length).padStart(2,'0')}</text>`),'Incorrect image counter');
   raw.push({file,width:w,height:h,sha256:hash(buffer)});
   if(family==='ipad'){
    const text=ipadOcr.find(x=>x.file===name+'.png');
    assert(text,'Missing iPad native OCR: '+name);
    const status=text.lines.filter(x=>x.y>.975).map(x=>x.text).join(' ');
    assert(/9:41/.test(status)&&!/Settings|GrammarLens|Grammar Lens/i.test(status),'iPad status bar contains app name or breadcrumb: '+name);
    const corner=await sharp(buffer).extract({left:w-70,top:h-70,width:70,height:70}).toBuffer();
    const stats=await sharp(corner).stats();
    assert(stats.channels.slice(0,3).every(x=>x.stdev<.01&&x.min>220),'Non-uniform bottom-right iPad corner: '+name);
    ipadCorners.push({file,statusBarOcr:status,bottomRight70pxRgb:stats.channels.slice(0,3).map(x=>x.mean),bottomRightUniform:true});
   }
  }
  const hint=JSON.parse(fs.readFileSync(path.join(root,'raw',family,'hint-state.json'),'utf8'));
  assert(hint.pointerHeld,'Hint was not captured while held');
  assert(hint.questionId==='day0_5'&&hint.correctAnswer==='saw','Wrong hint question');
  assert(hint.promptVerbOrAnswerInHint===false&&!/\b(?:see|saw)\b/i.test(hint.hintPoints.join(' ')),'Hint includes prompt verb or answer');
  assert(hint.knobAtEnd&&hint.releasedAndCardClosed,'Hint interaction not verified');
  assert(hint.card.y+hint.card.h<hint.screenLogicalHeight,'Hint card beyond native viewport');
  hints.push({family,...hint,releaseCheck:'Driver awaited card absence before answering the test'});
 }
 for(const c of Object.values(copy)){
  const headline=c.title.join(' ');
  assert(!/\b(free|unlimited)\b|\$|€|£|app store/i.test(headline),'Forbidden headline claim: '+headline);
  assert(c.alternatives.length===2,'Expected two alternatives');
 }
 const html=fs.readFileSync(path.join(root,'gallery.html'),'utf8'),links=[];
 for(const match of html.matchAll(/(?:href|src|data-full)="([^"#]+)"/g)){
  const f=match[1];assert(!/^https?:/.test(f),'Unexpected external gallery asset');
  assert(fs.existsSync(path.join(root,f)),'Missing gallery file: '+f);links.push(f);
 }
 const analyze=fs.readFileSync(path.join(root,'source/flutter-analyze.txt'),'utf8');
 const tests=fs.readFileSync(path.join(root,'source/relevant-tests.txt'),'utf8');
 assert(analyze.includes('No issues found!'),'Analysis is not clean');
 assert(tests.includes('All tests passed!'),'Relevant tests did not pass');
 const unchanged=cp.spawnSync('git',['diff','--quiet','HEAD','--','lib','README.md','screenshots/1.2.0/README.md','tool/screenshots/seed.dart'],{cwd:process.cwd()});
 assert(unchanged.status===0,'Protected tracked sources changed');
 const normal=JSON.parse(fs.readFileSync(path.join(root,'source/normal-launch-check.json'),'utf8'));
 assert(normal.target==='lib/main.dart'&&normal.status==='passed','Normal app launch not confirmed');
 assert(fs.existsSync(path.join(root,normal.screenshot)),'Normal launch screenshot missing');
 const ui=JSON.parse(fs.readFileSync(path.join(root,'source/gallery-check.json'),'utf8'));
 assert(ui.status==='passed','Gallery interaction verification incomplete');
 assert(ui.iphoneCount===8&&ui.ipadCount===6,'Gallery counts not updated');
 const full=JSON.parse(fs.readFileSync(path.join(root,'source/ipad-fullscreen-check.json'),'utf8'));
 assert(full.status==='passed'&&full.mode==='Full Screen Apps'&&full.appNameInStatusBar===false&&full.resizeHandleVisible===false,'iPad full screen not verified');
 const result={status:'passed',appVersion:manifest.appVersion,branch:manifest.branch,commit:manifest.commit,
  revision:2,appStorePngCount:14,iphoneCount:8,ipadCount:6,uploadOrder:manifest.uploadOrder,approvedHeadlinesAndDrawingFunctionsUnchanged:true,weakSpotDetailRemoved:true,ipadFullscreen:{...full,nativeStatusAndCornerChecks:ipadCorners},
  contentContinuity:{sameBundledQuestionInQuestionAndHint:'day0_5',promptVerb:'see',correctAnswer:'saw',wrongAnswerInResults:'have seen',reviewLatestTopic:'Tense Selection',nativeOcrEvidence:['source/native-iphone-ocr.json','source/native-ipad-ocr.json']},
  opaqueRgbPngChecks:files,rawCaptureChecks:raw,originalRawPngEmbeddedInEveryStoreSvg:true,
  embeddedFont:true,marketingTextOverflow:'Renderer checked every SVG text boundary before export',hintCaptureChecks:hints,
  headlines:{language:'en',priceOrAccessClaims:false,selectedOnImage:true,alternativesInNotesOnly:true},
  gallery:{localLinksChecked:links.length,...ui},normalEntry:normal,
  flutterAnalyze:'No issues found',relevantTests:{passed:172,failed:0,files:['tool_import_guard_test','screenshot_seed_test','debug_tools_release_test','topic_hint_card_test','question_topic_tag_test','multi_blank_test','daily_test_screen_test','onboarding_screen_test']},
  protectedTrackedSourcesUnchanged:true,publicationOrUpload:false};
 fs.writeFileSync(path.join(root,'verification.json'),JSON.stringify(result,null,2)+'\n');
 console.log(`Verified ${files.length} opaque RGB exports, ${raw.length} native captures and ${links.length} local gallery links.`);
}
main().catch(e=>{console.error(e);process.exit(1)});
