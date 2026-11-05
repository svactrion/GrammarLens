// Replace only 1.4.0 header placements with the owner-approved mobile-fit file.
const fs=require('fs'),crypto=require('crypto');
const PLAN='screenshots/1.4.0/asc/header-update-plan.json';
const RUN=process.env.ASC_RUN_DIR||'/private/tmp/grammarlens-140-asc-header-v4';fs.mkdirSync(RUN,{recursive:true});
const planBytes=fs.readFileSync(PLAN),plan=JSON.parse(planBytes),sha=crypto.createHash('sha256').update(planBytes).digest('hex');
const statePath=RUN+'/state.json';const state=fs.existsSync(statePath)?JSON.parse(fs.readFileSync(statePath)):{planSha256:sha,next:0,ids:{},results:{},rejections:[],startedAt:new Date().toISOString()};
if(state.planSha256!==sha)throw Error('Approved plan changed during execution');
const key=fs.readFileSync(process.env.ASC_KEY_PATH);let token,tokenAt=0;
const assert=(v,m)=>{if(!v)throw Error(m)};
function bearer(){const now=Math.floor(Date.now()/1000);if(now-tokenAt<600&&token)return token;const b=x=>Buffer.from(JSON.stringify(x)).toString('base64url'),h=b({alg:'ES256',kid:process.env.ASC_KEY_ID,typ:'JWT'}),p=b({iss:process.env.ASC_ISSUER_ID,iat:now,exp:now+1100,aud:'appstoreconnect-v1'}),u=h+'.'+p;token=u+'.'+crypto.sign('sha256',Buffer.from(u),{key,dsaEncoding:'ieee-p1363'}).toString('base64url');tokenAt=now;return token;}
function log(x){fs.appendFileSync(RUN+'/requests.jsonl',JSON.stringify({time:new Date().toISOString(),...x})+'\n')}
function save(){fs.writeFileSync(statePath,JSON.stringify(state,(key,value)=>['uploadOperations','pendingUpload'].includes(key)?undefined:value,2)+'\n')}
function resolve(x){if(typeof x==='string'){for(const [a,b]of Object.entries(state.ids))x=x.split(a).join(b);if(x.includes('${'))throw Error('Unresolved response ID '+x);return x;}if(Array.isArray(x))return x.map(resolve);if(x&&typeof x==='object')return Object.fromEntries(Object.entries(x).map(([k,v])=>[k,resolve(v)]));return x;}
function safeErrors(j){return j?.errors?.map(e=>({status:e.status,code:e.code,title:e.title,detail:e.detail,source:e.source}));}
async function api(method,path,body){assert(path.startsWith('/v1/'),'Non-API path');assert(!/reviewSubmissions|Submissions|releaseRequests|ageRating|appAvailabilities|price|appPrivacy/i.test(path),'Forbidden endpoint');let r;try{r=await fetch('https://api.appstoreconnect.apple.com'+path,{method,headers:{Authorization:'Bearer '+bearer(),'Content-Type':'application/json'},...(body?{body:JSON.stringify(body)}:{}),signal:AbortSignal.timeout(120000)});}catch(e){log({method,path,status:'NETWORK_ERROR'});throw e;}let j={};const text=await r.text();if(text)try{j=JSON.parse(text)}catch{throw Error('Unexpected non-JSON API response')};log({method,path,status:r.status,...(!r.ok?{errors:safeErrors(j)}:{})});return {ok:r.ok,status:r.status,json:j};}
const requireOk=r=>{if(!r.ok){console.error(JSON.stringify({status:r.status,errors:safeErrors(r.json)}));throw Error('ASC rejected request; stopped');}return r.json;};
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
async function upload(file,operations){assert(operations?.length,'No upload operations');const bytes=fs.readFileSync(file);for(const op of operations){assert(op.method==='PUT','Unexpected upload method');const url=new URL(op.url);assert(url.protocol==='https:','Upload URL must be HTTPS');const headers=Object.fromEntries((op.requestHeaders||[]).map(h=>[h.name,h.value]));assert(!Object.keys(headers).some(h=>h.toLowerCase()==='authorization'),'Unexpected authorization on upload');const body=bytes.subarray(op.offset,op.offset+op.length);assert(body.length===op.length,'Upload range mismatch');const r=await fetch(op.url,{method:'PUT',headers,body,signal:AbortSignal.timeout(120000)});log({method:'PUT',path:url.origin+'/<upload-operation-redacted>',status:r.status,file,offset:op.offset,length:op.length});assert(r.ok,'Upload PUT rejected '+r.status);}}

const entry=(type,id)=>({type,id});
function imageBody(){return {data:{type:'appAssetLibraryImages',attributes:{category:'CREATIVE_ASSETS',fileName:'header-A-mobile-fit-v4.png',fileSize:plan.fileSize,referenceName:'GrammarLens 1.4.0 header A mobile fit v4'},relationships:{assetLibrary:{data:entry('appAssetLibraries','6811477346')}}}}}
function placementBody(loc,image){return {data:{type:'appAssetLibraryPlacements',attributes:{placementType:'PRODUCT_PAGE_HEADER_ASSET',placementGroup:'DEFAULT_PROFILE'},relationships:{image:{data:entry('appAssetLibraryImages',image)},appStoreVersionLocalization:{data:entry('appStoreVersionLocalizations',loc.id)}}}}}
async function headers(loc){const data=requireOk(await api('GET','/v1/appStoreVersionLocalizations/'+loc.id+'/placements')).data;const hs=data.filter(x=>x.attributes.placementType==='PRODUCT_PAGE_HEADER_ASSET');const details=[];for(const h of hs)details.push(requireOk(await api('GET','/v1/appAssetLibraryPlacements/'+h.id+'?include=image')).data);return details;}
(async()=>{
 const bytes=fs.readFileSync(plan.file);assert(crypto.createHash('sha256').update(bytes).digest('hex')===plan.sha256,'Candidate hash changed');assert(bytes.readUInt32BE(16)===3840&&bytes.readUInt32BE(20)===1646&&bytes[25]===2,'Candidate PNG must be 3840x1646 opaque RGB');
 let version=requireOk(await api('GET','/v1/appStoreVersions/'+plan.versionId)).data;assert(version.attributes.versionString==='1.4.0'&&version.attributes.appStoreState==='PREPARE_FOR_SUBMISSION'&&version.attributes.releaseType==='MANUAL','Version guard');
 const build=requireOk(await api('GET','/v1/appStoreVersions/'+plan.versionId+'/build')).data;assert(build?.attributes.version==='7','Build guard');
 const locs=requireOk(await api('GET','/v1/appStoreVersions/'+plan.versionId+'/appStoreVersionLocalizations')).data;
 for(const loc of plan.localizations){assert(locs.some(l=>l.id===loc.id&&l.attributes.locale===loc.locale),'Locale scope changed');const hs=await headers(loc);assert(hs.length<=1,'Unexpected header count');for(const h of hs)assert([plan.oldImageId,state.imageId].includes(h.relationships?.image?.data?.id),'Existing header unexpectedly changed');}
 if(!state.imageId){const j=requireOk(await api('POST','/v1/appAssetLibraryImages',imageBody()));state.imageId=j.data.id;state.phase='reserved';save();}
 if(state.phase==='reserved'){
  const j=requireOk(await api('GET','/v1/appAssetLibraryImages/'+state.imageId));
  if(j.data.attributes.state==='AWAITING_UPLOAD'){await upload(plan.file,j.data.attributes.uploadOperations);requireOk(await api('PATCH','/v1/appAssetLibraryImages/'+state.imageId,{data:{type:'appAssetLibraryImages',id:state.imageId,attributes:{uploaded:true}}}));}
  state.phase='processing';save();
 }
 let image;
 for(let i=0;i<600;i++){
  image=requireOk(await api('GET','/v1/appAssetLibraryImages/'+state.imageId)).data;
  if(image.attributes.state==='PREPARE_FOR_SUBMISSION')break;
  assert(!['FAILED','REJECTED'].includes(image.attributes.state),'Header processing failed '+JSON.stringify(image.attributes.stateDetails));
  if(i===599)throw Error('Header processing timeout');await sleep(2500);
 }
 assert(image.attributes.imageAsset?.width===3840&&image.attributes.imageAsset?.height===1646,'Processed header dimensions');state.phase='placing';save();console.log('New mobile-fit header processed.');
 for(const loc of plan.localizations){
  let hs=await headers(loc);
  if(hs[0]?.relationships?.image?.data?.id===state.imageId){console.log(loc.locale+': already updated');continue;}
  if(hs.length){assert(hs[0].relationships?.image?.data?.id===plan.oldImageId,'Unexpected existing asset');requireOk(await api('DELETE','/v1/appAssetLibraryPlacements/'+hs[0].id));}
  const placed=await api('POST','/v1/appAssetLibraryPlacements',placementBody(loc,state.imageId));
  if(!placed.ok){await api('POST','/v1/appAssetLibraryPlacements',placementBody(loc,plan.oldImageId));requireOk(placed);}
  state.updated||=[];state.updated.push(loc.locale);save();console.log(loc.locale+': new header placed');
 }
 const results=[];for(const loc of plan.localizations){const hs=await headers(loc);assert(hs.length===1&&hs[0].relationships?.image?.data?.id===state.imageId,'Header read-back mismatch '+loc.locale);results.push({locale:loc.locale,localizationId:loc.id,placementId:hs[0].id,imageId:state.imageId,state:hs[0].attributes.state});}
 version=requireOk(await api('GET','/v1/appStoreVersions/'+plan.versionId)).data;assert(version.attributes.appStoreState==='PREPARE_FOR_SUBMISSION'&&version.attributes.releaseType==='MANUAL','Final version state');
 const result={status:'passed',readAt:new Date().toISOString(),version:{id:version.id,versionString:version.attributes.versionString,state:version.attributes.appStoreState,releaseType:version.attributes.releaseType,build:'7'},source:{file:plan.file,sha256:plan.sha256,fileSize:plan.fileSize,width:3840,height:1646},previousImageId:plan.oldImageId,image:{id:image.id,state:image.attributes.state,fileName:image.attributes.fileName,specId:image.attributes.specId},localizations:results,runLog:RUN+'/requests.jsonl',scope:'Only 1.4.0 header placements replaced; old library image retained. No screenshots/text/review/submission/release changes.'};
 fs.writeFileSync('screenshots/1.4.0/asc/header-update-read-back.json',JSON.stringify(result,null,2)+'\n');fs.copyFileSync(plan.file,'screenshots/1.4.0/product-page/header.png');state.phase='complete';state.finishedAt=new Date().toISOString();save();console.log('Eight header associations verified. Canonical header.png updated.');
})().catch(e=>{console.error(e.message);save();process.exit(1)});
