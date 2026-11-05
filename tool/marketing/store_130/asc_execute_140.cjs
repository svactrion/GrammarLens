// Execute the owner-approved request manifest; secrets stay in process memory.
const fs=require('fs'),crypto=require('crypto');
const PLAN='screenshots/1.4.0/asc/dry-run-calls.json';
const RUN=process.env.ASC_RUN_DIR||'/private/tmp/grammarlens-140-asc-upload';fs.mkdirSync(RUN,{recursive:true});
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
async function preflight(){const v=requireOk(await api('GET','/v1/appStoreVersions/23d20cb5-2df3-49c4-b3c6-841cd080a576')).data;assert(v.attributes.versionString==='1.4.0'&&v.attributes.appStoreState==='PREPARE_FOR_SUBMISSION'&&v.attributes.releaseType==='MANUAL','Version guard');const b=requireOk(await api('GET','/v1/appStoreVersions/'+v.id+'/build')).data;assert(b?.attributes.version==='7'&&b.attributes.processingState==='VALID','Build guard');for(const row of JSON.parse(fs.readFileSync('screenshots/1.4.0/asc/screenshot-manifest.json'))){const h=crypto.createHash('sha256').update(fs.readFileSync(row.file)).digest('hex');assert(h===row.sha256,'Screenshot modified '+row.file);}const header=fs.readFileSync('screenshots/1.4.0/product-page/header.png');assert(header.equals(fs.readFileSync('screenshots/1.4.0/product-page/header-A-v3.png')),'Header differs');if(state.next===0){const locs=requireOk(await api('GET','/v1/appStoreVersions/'+v.id+'/appStoreVersionLocalizations')).data;assert(locs.length===1&&locs[0].id==='207797dd-54bd-480e-be43-41ef1c6bac66','Locale state changed; reconcile first');const ps=requireOk(await api('GET','/v1/appStoreVersionLocalizations/'+locs[0].id+'/placements')).data;const removals=plan.filter(c=>c.method==='DELETE'&&c.path.includes('/appAssetLibraryPlacements/'));for(const c of removals)assert(ps.some(p=>c.path.endsWith('/'+p.id)&&['IPHONE_DYNAMIC_ISLAND_LARGE_PROFILE','IPAD_13_PROFILE'].includes(p.attributes.placementGroup)),'Placement scope mismatch');}console.log('Preflight passed: 1.4.0 / build 7 / MANUAL / 112 hashes / header A');}
(async()=>{await preflight();for(let i=state.next;i<plan.length;i++){
 const c=plan[i];if(c.condition&&!state.runFallback){state.next=i+1;save();continue;}
 if(c.method==='PUT'){if(!state.pendingUpload){const reserved=state.results[i-1]?.data;assert(reserved?.id,'Missing pending reservation');state.pendingUpload=requireOk(await api('GET','/v1/'+reserved.type+'/'+reserved.id)).data?.attributes?.uploadOperations;}await upload(c.body.binaryFile,state.pendingUpload);state.next=i+1;save();continue;}
 let path=resolve(c.path),body=resolve(c.body),method=c.method;
 if(method==='POST'&&path==='/v1/appInfoLocalizations'){
  const infoId=body.data.relationships.appInfo.data.id;assert(infoId==='2222205e-4dc4-4a9e-8da1-dabb39f0ef9b','Editable appInfo scope');
  const existing=requireOk(await api('GET','/v1/appInfos/'+infoId+'/appInfoLocalizations')).data.find(x=>x.attributes.locale===body.data.attributes.locale);
  if(existing){method='PATCH';path='/v1/appInfoLocalizations/'+existing.id;body={data:{type:'appInfoLocalizations',id:existing.id,attributes:{...body.data.attributes}}};delete body.data.attributes.locale;state.adaptations||=[];state.adaptations.push({index:i,reason:'ASC created appInfo localization automatically with version localization',method,path});}
 }
 let r=await api(method,path,body);
 if(!r.ok&&r.status===404&&c.if404){const fallback=c.if404;r=await api(fallback.method,resolve(fallback.path),resolve(fallback.body));const j=requireOk(r);state.ids[c.path.split('/').at(-1)]=j.data.id;}
 if(!r.ok){const next=plan[i+1],errors=safeErrors(r.json),details=JSON.stringify(errors);const keywordLimit=next?.condition&&/keyword/i.test(details)&&/(100|length|byte|long|limit)/i.test(details);state.rejections.push({index:i,method:c.method,path,status:r.status,errors});save();if(keywordLimit){state.runFallback=true;state.next=i+1;save();console.log('Approved keyword byte-limit fallback required for '+(body.data.attributes.locale||'en-US'));continue;}requireOk(r);}
 const j=r.json;
 if(c.repeat&&c.method==='GET'){
  for(let n=0;n<600;n++){
   const a=r.json.data?.attributes||{},delivery=a.assetDeliveryState?.state,phase=a.state;
   if(/FAILED|REJECTED/.test(delivery||phase||''))throw Error('Asset processing failed '+JSON.stringify({delivery,phase,stateDetails:a.stateDetails}));
   if(path.includes('/appScreenshots/')&&delivery==='UPLOAD_COMPLETE'){
    const reservation=plan[i-3],part=plan[i-2],commit=plan[i-1],retryKey=reservation?.saveIdAs;
    const commits=fs.readFileSync(RUN+'/requests.jsonl','utf8').trim().split('\n').map(l=>JSON.parse(l)).filter(x=>x.method==='PATCH'&&x.path===path&&x.status===200);
    const since=commits[0]?Date.parse(commits[0].time):Date.now();state.retried||={};
    if(Date.now()-since>240000&&!state.retried[retryKey]){
     assert(reservation.method==='POST'&&reservation.path==='/v1/appScreenshots'&&retryKey,'Retry scope');const oldId=state.ids[retryKey];assert(path.endsWith('/'+oldId),'Retry ownership');
     state.retried[retryKey]=true;save();requireOk(await api('DELETE',path));
     const created=requireOk(await api('POST',reservation.path,resolve(reservation.body)));state.ids[retryKey]=created.data.id;state.results[i-3]=created;state.pendingUpload=created.data.attributes.uploadOperations;state.next=i-2;
     state.adaptations||=[];state.adaptations.push({index:i-3,reason:'Single retry of own screenshot after prolonged UPLOAD_COMPLETE with no errors',oldId,newId:created.data.id,file:part.body.binaryFile});save();
     await upload(part.body.binaryFile,state.pendingUpload);state.next=i-1;save();state.results[i-1]=requireOk(await api('PATCH',resolve(commit.path),resolve(commit.body)));state.next=i;save();path=resolve(c.path);r=await api('GET',path);requireOk(r);console.log('Single exact-file retry: '+part.body.binaryFile);continue;
    }
   }
   const done=path.includes('/appScreenshots/')?delivery==='COMPLETE':['PREPARE_FOR_SUBMISSION','READY_FOR_REVIEW','ACCEPTED','APPROVED','IN_REVIEW','WAITING_FOR_REVIEW'].includes(phase);
   if(done)break;
   if(n===599)throw Error('Asset processing timeout '+JSON.stringify({delivery,phase,keys:Object.keys(a)}));
   await sleep(2500);r=await api('GET',path);requireOk(r);
  }
 }
 state.results[i]=r.json;
 if(c.saveIdAs){assert(j.data?.id,'No response ID');state.ids[c.saveIdAs]=j.data.id;}
 if(c.method==='POST'&&['/v1/appScreenshots','/v1/appAssetLibraryImages'].includes(path)){state.pendingUpload=j.data?.attributes?.uploadOperations;assert(state.pendingUpload?.length,'Upload reservation has no operations');}
 if(c.condition)state.runFallback=false;
 state.next=i+1;save();
 if(c.method==='POST'&&path==='/v1/appStoreVersionLocalizations')console.log('Localization created: '+body.data.attributes.locale);
 if(c.method==='PATCH'&&path.endsWith('/relationships/appScreenshots'))console.log('Screenshot set ordered: '+body.data.length+' images ('+(i+1)+'/'+plan.length+')');
 if(c.method==='POST'&&path==='/v1/appAssetLibraryPlacements')console.log('Header placed ('+(i+1)+'/'+plan.length+')');
 }
 state.finishedAt=new Date().toISOString();save();console.log('Approved plan executed. Read-back phase required.');
})().catch(e=>{console.error(e.message);save();process.exit(1)});
