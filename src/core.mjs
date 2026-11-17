export function esc(v){return String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));}
export function norm(v){return String(v??'').toLowerCase().replaceAll('đ','d').normalize('NFD').replace(/[\u0300-\u036f]/g,'');}
export function today(now=new Date()){const p=Object.fromEntries(new Intl.DateTimeFormat('en-CA',{timeZone:'Europe/Belgrade',year:'numeric',month:'2-digit',day:'2-digit'}).formatToParts(now).map(p=>[p.type,p.value]));return `${p.year}-${p.month}-${p.day}`;}
export function opt(d,k,c){return d.options.find(x=>x.kind===k&&x.code===c);}
export function lbl(d,k,c){return opt(d,k,c)?.label??c??'—';}
export function closed(d,k,c){return opt(d,k,c)?.flags?.closed===true;}
export function shares(d,id){const rows=d.ownerships.filter(x=>x.asset_id===id);const valid=rows.length>0&&rows.every(x=>d.owners.some(o=>o.id===x.owner_id)&&Number.isInteger(+x.numerator)&&Number.isInteger(+x.denominator)&&+x.numerator>0&&+x.denominator>=+x.numerator);const total=valid?rows.reduce((s,x)=>s+x.numerator/x.denominator,0):null;return {rows,total,complete:total!==null&&Math.abs(total-1)<1e-6,group:valid?rows.reduce((s,x)=>s+(d.owners.find(o=>o.id===x.owner_id)?.within_group?x.numerator/x.denominator:0),0):null};}
export function steps(d,id){return d.actions.filter(x=>x.asset_id===id).sort((a,b)=>a.position-b.position);}
export function openSteps(d,id){return steps(d,id).filter(x=>!closed(d,'action_status',x.status));}
export function late(d,x,key,kind,day=today()){return !!x[key]&&x[key]<day&&(!kind||!closed(d,kind,x.status));}
export function inProgress(d,a){return opt(d,'proceedings_status',a.proceedings_status)?.flags?.in_progress===true||a.occupancy_permit==='pending'||a.construction_permit==='pending'||d.cases.some(c=>c.asset_id===a.id&&!closed(d,'case_status',c.status));}
export function filterAssets(d,f={}){const q=norm(f.q), owned=f.owner?new Set(d.ownerships.filter(x=>x.owner_id===f.owner).map(x=>x.asset_id)):null;return d.assets.filter(a=>{
 if(owned&&!owned.has(a.id))return false;
 for(const k of ['city','country','asset_type','portfolio_status','usage_status','occupancy_permit','priority'])if(f[k]&&a[k]!==f[k])return false;
 if(f.mode==='progress'&&!inProgress(d,a))return false;
 if(f.mode==='no_permit'&&a.occupancy_permit!=='no')return false;
 if(f.mode==='unknown_permit'&&a.occupancy_permit!=='unknown')return false;
 if(f.mode==='overdue'&&!openSteps(d,a.id).some(x=>late(d,x,'due_date','action_status')))return false;
 if(f.mode==='shares'&&shares(d,a.id).complete)return false;
 if(f.mode==='portfolio'&&!opt(d,'portfolio_status',a.portfolio_status)?.flags?.portfolio)return false;
 const owners=d.ownerships.filter(x=>x.asset_id===a.id).map(x=>d.owners.find(o=>o.id===x.owner_id)?.full_name).join(' ');
 const cases=d.cases.filter(x=>x.asset_id===a.id).map(x=>x.case_number+' '+x.external_status).join(' ');
 return !q||norm([a.code,a.name,a.city,a.address,a.cadastral_municipality,a.parcel_number,a.notes,owners,cases].join(' ')).includes(q);
 });}
export function totals(d,assets){return ['EUR','RSD'].map(currency=>{const rows=assets.filter(a=>a.currency===currency);const sum=k=>rows.reduce((s,a)=>s+(a[k]==null?0:+a[k]),0);let group=0,missingShares=0;for(const a of rows){const o=shares(d,a.id);if(a.market_value!=null&&o.complete)group+=a.market_value*o.group;else if(a.market_value!=null)missingShares++;}return {currency,count:rows.length,market:sum('market_value'),group,rent:sum('monthly_rent'),tax:sum('annual_tax'),maintenance:sum('monthly_maintenance'),missingShares,missingMarket:rows.filter(a=>a.market_value==null).length};});}
export function safeUrl(s){try{const u=new URL(s);return u.protocol==='https:'?u.href:null;}catch{return null;}}
export function csv(rows){return '\uFEFF'+rows.map(row=>row.map(v=>{if(v==null)return '""';let s=String(v);if(typeof v!=='number'&&/^[\s]*[=+@\-\t\r]/.test(s))s="'"+s;return '"'+s.replaceAll('"','""')+'"';}).join(';')).join('\r\n');}
export function validate(table,r,d,id){const fail=m=>{throw new Error(m);};for(const [k,v]of Object.entries(r)){if(typeof v==='string'&&v.length>20000)fail('Najviše 20.000 znakova po polju.');if(typeof v==='number'&&(!Number.isFinite(v)||v<0||v>1e12))fail('Proverite brojeve: dozvoljeno je od 0 do 1.000.000.000.000.');if(['url','source_url','documents_url'].includes(k)&&v&&!safeUrl(v))fail('Link mora počinjati sa https://.');}
 if(r.code&&d[table].some(x=>x.id!==id&&norm(x.code)===norm(r.code)))fail('Ovaj ID već postoji.');
 if(table==='ownerships'){if(!Number.isInteger(r.numerator)||!Number.isInteger(r.denominator)||r.numerator<1||r.denominator<r.numerator||r.denominator>1e9)fail('Unesite pozitivan razlomak do 1/1 sa celim brojevima.');if(d.ownerships.some(x=>x.id!==id&&x.asset_id===r.asset_id&&x.owner_id===r.owner_id))fail('Vlasnik je već evidentiran za ovu nepokretnost.');}
 if(table==='actions'&&(r.position<1||r.position>5||d.actions.some(x=>x.id!==id&&x.asset_id===r.asset_id&&x.position===r.position)))fail('Izaberite slobodan redni broj koraka od 1 do 5.');
 if(table==='cases'&&d.cases.some(x=>x.id!==id&&x.asset_id===r.asset_id&&x.system===r.system&&norm(x.case_number)===norm(r.case_number)))fail('Predmet sa ovim brojem već postoji za nepokretnost.');
 const money=table==='assets'?['purchase_value','market_value','annual_tax','monthly_rent','monthly_maintenance']:table==='utilities'?['monthly_cost']:[];if(money.some(k=>r[k]!=null)&&!r.currency)fail('Izaberite valutu za novčane iznose.');
}
export function validateConfig(url,key){let u;try{u=new URL(url);}catch{throw new Error('Unesite ispravan Supabase Project URL.');}if(u.protocol!=='https:'||!u.hostname.endsWith('.supabase.co')||u.pathname!=='/'||u.username||u.password||u.search||u.hash)throw new Error('Koristite HTTPS Project URL na supabase.co.');if(key.startsWith('sb_secret_'))throw new Error('Secret/service_role ključ nije dozvoljen u HTML aplikaciji.');if(!key.startsWith('sb_publishable_')){try{const p=JSON.parse(atob(key.split('.')[1].replaceAll('-','+').replaceAll('_','/')));if(p.role!=='anon')throw new Error();}catch{throw new Error('Koristite publishable ili legacy anon ključ.');}}if(key.length<24)throw new Error('Ključ nije potpun.');return {url:u.origin,key};}
