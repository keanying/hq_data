export const layers=['ODS','DIM','DWD','DWS','ADS'];
export function migrate(old){
 const data={version:2,folders:[],tasks:[],flows:[]};
 old.forEach((d,i)=>{const root='domain-'+i,flowFolder=root+'-flows';data.folders.push({id:root,name:d.name,parentId:null},{id:flowFolder,name:'工作流',parentId:root});layers.forEach(l=>data.folders.push({id:root+'-'+l,name:l,parentId:root}));
 const ids=new Map(d.tasks.map(t=>[t.id,root+'-'+t.id]));
 data.tasks.push(...d.tasks.map(t=>({id:ids.get(t.id),name:t.name,table:t.table,layer:t.layer,folderId:root+'-'+(layers.includes(t.layer)?t.layer:'DIM'),code:t.code||''})));
 data.flows.push({id:root+'-flow',name:d.flow||d.name+'工作流',folderId:flowFolder,nodes:d.tasks.map(t=>({taskId:ids.get(t.id),x:Number.isFinite(t.x)?t.x:70,y:Number.isFinite(t.y)?t.y:160})),edges:d.edges.filter(e=>e.every(id=>ids.has(id))).map(e=>e.map(id=>ids.get(id))),groups:d.groups.map((g,j)=>({id:root+'-g'+j,name:g.name,ids:g.ids.filter(id=>ids.has(id)).map(id=>ids.get(id))}))});});return data;
}
export function seed(){const rows=[['景区基础信息','dim_scenic_info','DIM',70,160],['游客基础信息','dim_visitor_info','DIM',70,360],['景区客流明细','dwd_scenic_flow','DWD',345,160],['游客行为明细','dwd_visitor_behavior','DWD',345,360],['景区客流日汇总','dws_scenic_flow_day','DWS',620,160],['游客画像汇总','dws_visitor_profile','DWS',620,360],['文旅运营看板','ads_tourism_dashboard','ADS',895,160],['游客画像分析','ads_visitor_analysis','ADS',895,360]];return migrate([{name:'文旅数据',flow:'文旅数据工作流',tasks:rows.map((t,i)=>({id:'t'+i,name:t[0],table:t[1],layer:t[2],x:t[3],y:t[4],code:`-- ${t[0]}\n-- 文旅数据 / ${t[2]}\n\nINSERT OVERWRITE TABLE ${t[1]}\nPARTITION (dt = '\${bizdate}')\nSELECT\n    scenic_id,\n    scenic_name,\n    city_name\nFROM ods_scenic_source\nWHERE dt = '\${bizdate}';\n`})),edges:[['t0','t2'],['t1','t3'],['t2','t4'],['t3','t5'],['t4','t6'],['t5','t7'],['t0','t3']],groups:[{name:'景区运营分析',ids:['t2','t4','t6']},{name:'游客洞察分析',ids:['t3','t5','t7']}]},{name:'交通数据',flow:'交通数据工作流',tasks:[],edges:[],groups:[]}]);}
export function worldPoint(camera,p){return {x:(p.x-camera.x)/camera.scale,y:(p.y-camera.y)/camera.scale};}
export function zoomAt(camera,scale,point){const w=worldPoint(camera,point),s=Math.min(2.5,Math.max(.25,scale));return {x:point.x-w.x*s,y:point.y-w.y*s,scale:s};}
export function canLink(edges,from,to){if(from===to||edges.some(e=>e[0]===from&&e[1]===to))return false;const visited=new Set();function reaches(id){if(id===from)return true;if(visited.has(id))return false;visited.add(id);return edges.filter(e=>e[0]===id).some(e=>reaches(e[1]));}return !reaches(to);}
// 分组可以嵌套：子分组带 parent 字段；分组的 ids 始终包含全部后代任务（父分组 ids ⊇ 子分组 ids）
export function groupParent(flow,g){return g?.parent?flow.groups.find(x=>x.id===g.parent)||null:null}
export function groupDepth(flow,g){let d=0,seen=new Set();for(let p=groupParent(flow,g);p&&!seen.has(p.id);p=groupParent(flow,p)){seen.add(p.id);d++}return d}
export function hiddenGroup(flow,g){const seen=new Set();for(let p=groupParent(flow,g);p&&!seen.has(p.id);p=groupParent(flow,p)){seen.add(p.id);if(p.collapsed)return true}return false}
export function removeNodes(flow,ids){flow.nodes=flow.nodes.filter(n=>!ids.has(n.taskId));flow.edges=flow.edges.filter(e=>e.every(id=>!ids.has(id)));flow.groups.forEach(g=>g.ids=g.ids.filter(id=>!ids.has(id)));flow.groups=flow.groups.filter(g=>g.ids.length);fixParents(flow);}
export function fixParents(flow){const ids=new Set(flow.groups.map(g=>g.id));for(const g of flow.groups)if(g.parent&&!ids.has(g.parent))delete g.parent}
function boxOf(flow,group,seen){
 if(seen.has(group.id))return null;seen.add(group.id);
 const kids=flow.groups.filter(c=>c.parent===group.id),inKid=new Set(kids.flatMap(c=>c.ids));
 const rects=flow.nodes.filter(n=>group.ids.includes(n.taskId)&&!inKid.has(n.taskId)).map(n=>({x:n.x,y:n.y,w:192,h:96}));
 for(const c of kids){const b=boxOf(flow,c,seen);if(b)rects.push(c.collapsed?{x:b.x,y:b.y,w:240,h:82}:b)}
 if(!rects.length)return null;
 const x=Math.min(...rects.map(r=>r.x))-18,y=Math.min(...rects.map(r=>r.y))-47;
 return {x,y,w:Math.max(...rects.map(r=>r.x+r.w))+18-x,h:Math.max(...rects.map(r=>r.y+r.h))+17-y};
}
export function groupBounds(flow,group){const b=boxOf(flow,group,new Set());if(!b)return null;return group.collapsed?{x:b.x,y:b.y,w:240,h:82}:b;}
// Projection changes only what is drawn; task positions, code and dependency edges stay intact.
// 嵌套时取最外层的已收起分组作为卡片；被收起分组内部的子分组不画。
export function projectFlow(flow){const hidden=new Map(),items=[],byTask=new Map();
 const visible=flow.groups.filter(g=>g.collapsed&&!hiddenGroup(flow,g));
 for(const g of visible){const b=groupBounds(flow,g);if(!b)continue;const item={key:'group:'+g.id,groupId:g.id,ids:g.ids.filter(id=>flow.nodes.some(n=>n.taskId===id)),...b};items.push(item);for(const id of item.ids){hidden.set(id,g.id);byTask.set(id,item)}}
 for(const n of flow.nodes){if(hidden.has(n.taskId))continue;const item={key:'task:'+n.taskId,ids:[n.taskId],x:n.x,y:n.y,w:192,h:96};items.push(item);byTask.set(n.taskId,item)}
 const edges=[],seen=new Set();for(const [a,b]of flow.edges){const from=byTask.get(a),to=byTask.get(b);if(!from||!to||from.key===to.key)continue;const key=JSON.stringify([from.key,to.key]);if(seen.has(key))continue;seen.add(key);edges.push({from,to})}return {items,hidden,edges};}

export function connectionPairs(flow,fromKey,toKey){
 const items=projectFlow(flow).items,from=items.find(i=>i.key===fromKey),to=items.find(i=>i.key===toKey);
 if(!from||!to||fromKey===toKey)throw Error('请选择不同的上游和下游');
 const leaves=from.ids.filter(id=>!flow.edges.some(([a,b])=>a===id&&from.ids.includes(b)));
 const roots=to.ids.filter(id=>!flow.edges.some(([a,b])=>b===id&&to.ids.includes(a)));
 const next=[...flow.edges],pairs=[];
 for(const a of leaves)for(const b of roots){if(next.some(e=>e[0]===a&&e[1]===b))continue;if(!canLink(next,a,b))throw Error('不能形成循环依赖');pairs.push([a,b]);next.push([a,b])}
 if(!pairs.length)throw Error('这些任务已连接');return pairs;
}

export function layerFolder(data,baseId,layer){
 let root=data.folders.find(f=>f.id===baseId);const seen=new Set();
 while(root?.parentId&&!seen.has(root.id)){seen.add(root.id);root=data.folders.find(f=>f.id===root.parentId)}
 if(!root)return null;
 const matches=data.folders.filter(f=>f.name===layer&&f.parentId===root.id);return matches.length===1?matches[0].id:null;
}
export function registerTask(data,task,workflowId=null,point=null){
 if(!data.folders.some(f=>f.id===task.folderId))throw Error('目标文件夹不存在');
 if(data.tasks.some(t=>t.id===task.id||t.table===task.table))throw Error('任务标识已存在');
 const workflow=workflowId?data.flows.find(f=>f.id===workflowId):null;
 if(workflowId&&(!workflow||!point||!Number.isFinite(point.x)||!Number.isFinite(point.y)))throw Error('工作流或画布位置无效');
 data.tasks.push(task);if(workflow)workflow.nodes.push({taskId:task.id,x:point.x,y:point.y});
}

// —— 分层排布（按依赖层级） ——
// 层级：没有上游的在第 0 层，其余在“所有上游最大层级 + 1”；同层内按上游位置的平均值排序（减少交叉），并列按原顺序。
// 与 server/seed_pft.py 的同名函数一致（有测试比对）。
export function levelsOf(ids,edges){
 const idx=new Map(ids.map((id,i)=>[id,i])),succ=new Map(ids.map(id=>[id,[]])),indeg=new Map(ids.map(id=>[id,0])),seen=new Set(),preds=new Map(ids.map(id=>[id,[]]));
 for(const [a,b] of edges){if(!idx.has(a)||!idx.has(b)||a===b)continue;const k=a+'\u0000'+b;if(seen.has(k))continue;seen.add(k);succ.get(a).push(b);preds.get(b).push(a);indeg.set(b,indeg.get(b)+1)}
 const level=new Map(ids.map(id=>[id,0])),queue=ids.filter(id=>!indeg.get(id));
 for(let q=0;q<queue.length;q++){const x=queue[q];for(const y of succ.get(x)){level.set(y,Math.max(level.get(y),level.get(x)+1));indeg.set(y,indeg.get(y)-1);if(!indeg.get(y))queue.push(y)}}
 return {level,preds,idx};
}
// items:[{id,la,lc}]（沿流向长度、垂直方向宽度）→ Map id→{a,c} 相对坐标
export function layered(items,edges,gapA,gapC){
 const ids=items.map(i=>i.id),{level,preds,idx}=levelsOf(ids,edges),L=[];
 for(const id of ids){const l=level.get(id);(L[l]||(L[l]=[])).push(id)}
 const order=new Map();
 L.forEach((lv,l)=>{if(!lv)return;if(l>0){const key=new Map(lv.map((id,i)=>{const ps=preds.get(id).filter(p=>order.has(p));return [id,ps.length?ps.reduce((s,p)=>s+order.get(p),0)/ps.length:i]}));lv.sort((x,y)=>key.get(x)-key.get(y)||idx.get(x)-idx.get(y))}lv.forEach((id,i)=>order.set(id,i))});
 const out=new Map();let a=0;
 for(const lv of L){if(!lv)continue;let c=0,m=0;for(const id of lv){const it=items[idx.get(id)];out.set(id,{a,c});c+=it.lc+gapC;m=Math.max(m,it.la)}a+=m+gapA}
 return out;
}
// 展开分组时重新排布组内内容：直属任务与子分组按依赖层级排列，组的左上角位置不变
export function layoutGroupInner(flow,g,TB){
 const kids=flow.groups.filter(c=>c.parent===g.id),inKid=new Map();kids.forEach(k=>k.ids.forEach(id=>inKid.set(id,k.id)));
 for(const k of kids)if(!k.collapsed)layoutGroupInner(flow,k,TB);
 const before=groupBounds(flow,{...g,collapsed:false});if(!before)return;
 const pos=new Map(flow.nodes.map(n=>[n.taskId,n])),unit=id=>inKid.get(id)??id;
 const items=[];
 for(const id of g.ids){if(!pos.has(id))continue;const u=unit(id);if(items.some(i=>i.id===u))continue;
  if(u===id)items.push({id,la:TB?96:192,lc:TB?192:96});else{const k=kids.find(k=>k.id===u),b=groupBounds(flow,k);if(b)items.push({id:u,la:TB?b.h:b.w,lc:TB?b.w:b.h,b})}}
 const edges=flow.edges.map(([a,b])=>[unit(a),unit(b)]);
 const at=layered(items,edges,TB?50:60,TB?30:24),ox=before.x+18,oy=before.y+47;
 for(const it of items){const o=at.get(it.id),x=ox+(TB?o.c:o.a),y=oy+(TB?o.a:o.c);
  if(it.b){const dx=x-it.b.x,dy=y-it.b.y;for(const id of kids.find(k=>k.id===it.id).ids){const n=pos.get(id);if(n){n.x+=dx;n.y+=dy}}}
  else{const n=pos.get(it.id);n.x=x;n.y=y}}
}
// 普通工作流的自动布局：展开的分组先排内部，再把顶层的任务与分组按依赖层级排列
export function autoLayered(flow,TB){
 const tops=flow.groups.filter(g=>!g.parent);for(const g of tops)if(!g.collapsed)layoutGroupInner(flow,g,TB);
 const pos=new Map(flow.nodes.map(n=>[n.taskId,n])),topOf=new Map();tops.forEach(g=>g.ids.forEach(id=>topOf.set(id,g.id)));
 const unit=id=>topOf.get(id)??id,items=[];
 for(const n of flow.nodes){const u=unit(n.taskId);if(items.some(i=>i.id===u))continue;
  if(u===n.taskId)items.push({id:u,la:TB?96:192,lc:TB?192:96});else{const g=tops.find(g=>g.id===u),b=groupBounds(flow,g);if(b)items.push({id:u,la:TB?b.h:b.w,lc:TB?b.w:b.h,b,g})}}
 if(!items.length)return;
 const at=layered(items,flow.edges.map(([a,b])=>[unit(a),unit(b)]),TB?70:90,TB?40:40),x0=80,y0=120;
 for(const it of items){const o=at.get(it.id),x=x0+(TB?o.c:o.a),y=y0+(TB?o.a:o.c);
  if(it.b){const dx=x-it.b.x,dy=y-it.b.y;for(const id of it.g.ids){const n=pos.get(id);if(n){n.x+=dx;n.y+=dy}}}else{const n=pos.get(it.id);n.x=x;n.y=y}}
}

// 泳道自动排布（flow.layout 由 PFT 项目种子写入，与 server/seed_pft.py 的 relayout 同一算法）
// 网格：泳道（分层）沿流向排列，行=数据域；同一泳道里互相依赖的数据域按层级分成子列。dir=LR 从左到右、TB 从上到下。
// 分支（如 DIM）贴在锚定泳道一侧的网格外，按依赖层级排布。分组折叠/展开后重新计算，展开的分组不会与相邻分组重叠。
export function relayout(flow){
 const L=flow?.layout;if(!L||!L.lanes)return false;
 const TB=L.dir==='TB',pos=new Map(flow.nodes.map(n=>[n.taskId,n])),G=new Map(flow.groups.map(g=>[g.id,g]));
 const ext=gid=>{const g=G.get(gid),b=g&&groupBounds(flow,g);return b?{b,la:TB?b.h:b.w,lc:TB?b.w:b.h}:null};
 const put=(gid,a,c)=>{const e=ext(gid);if(!e)return;const x=TB?c:a,y=TB?a:c,dx=x-e.b.x,dy=y-e.b.y;for(const id of G.get(gid).ids){const n=pos.get(id);if(n){n.x+=dx;n.y+=dy}}};
 const laneGap=L.laneGap??150,rowGap=L.rowGap??40,subGap=L.subGap??60,A0=L.a0??380,C0=L.c0??160,base=L.rows||[],extra=[];
 for(const lane of L.lanes)for(const r of Object.keys(L.cells[lane]||{}))if(!base.includes(r)&&!extra.includes(r))extra.push(r);   // 不属于数据域的格子（如对账）排在数据域行之后
 const rows=[...base,...extra],ri=r=>Math.max(0,rows.indexOf(r));
 // 格子之间的依赖（由任务连线归并）
 const cellOf=new Map();for(const lane of L.lanes)for(const gid of Object.values(L.cells[lane]||{}))(G.get(gid)?.ids||[]).forEach(id=>cellOf.set(id,gid));
 for(const gid of L.branch?.groups||[])(G.get(gid)?.ids||[]).forEach(id=>cellOf.set(id,gid));
 const cellEdges=flow.edges.map(([a,b])=>[cellOf.get(a),cellOf.get(b)]).filter(([a,b])=>a&&b&&a!==b);
 const laneSize=L.lanes.map(()=>0),rowSize=rows.length?rows.map(()=>0):[0],subs=[];
 const LG=L.laneGroups||{},folded=lane=>!!G.get(LG[lane])?.collapsed,inLane=(lane,gid)=>!!LG[lane]&&G.get(gid)?.parent===LG[lane];
 const pad=lane=>LG[lane]&&!folded(lane)?(TB?47:18):0,padSize=lane=>LG[lane]&&!folded(lane)?(TB?64:36):0;
 L.lanes.forEach((lane,i)=>{const f=folded(lane),cells=Object.entries(L.cells[lane]||{}).filter(([,gid])=>!(f&&inLane(lane,gid))&&ext(gid));
  const lv=levelsOf(cells.map(([,g])=>g),cellEdges).level,sub=[];
  for(const [r,gid] of cells){const e=ext(gid),k=lv.get(gid);sub[k]=Math.max(sub[k]||0,e.la);rowSize[ri(r)]=Math.max(rowSize[ri(r)],e.lc)}
  const so=[];let acc=0;for(let k=0;k<sub.length;k++){so[k]=acc;if(sub[k])acc+=sub[k]+subGap}
  subs[i]={lv,so};
  let size=sub.length?acc-subGap:0;
  if(f){const e=ext(LG[lane]);if(e){size=Math.max(size,e.la);rowSize[0]=Math.max(rowSize[0],e.lc)}}else if(size)size+=padSize(lane);
  laneSize[i]=size});
 const lanePos=[];let a=A0;laneSize.forEach((s,i)=>{lanePos[i]=a;if(s)a+=s+laneGap});
 const rowPos=[];let c=C0;rowSize.forEach((s,i)=>{rowPos[i]=c;if(s)c+=s+rowGap});
 L.lanes.forEach((lane,i)=>{const f=folded(lane);if(f)put(LG[lane],lanePos[i],rowPos[0]);for(const [r,gid] of Object.entries(L.cells[lane]||{})){if(f&&inLane(lane,gid))continue;const k=subs[i].lv.get(gid)??0;put(gid,lanePos[i]+pad(lane)+(subs[i].so[k]||0),rowPos[ri(r)])}});
 const ai=L.branch?Math.max(0,L.lanes.indexOf(L.branch.anchor)):0,bc=c-rowGap+(L.branch?.gap??150);
 if(L.branch&&G.get(L.branch.group)?.collapsed)put(L.branch.group,lanePos[ai],bc);
 else if(L.branch){const items=L.branch.groups.map(gid=>{const e=ext(gid);return e&&{id:gid,la:e.la,lc:e.lc}}).filter(Boolean);
  const at=layered(items,cellEdges,90,rowGap);for(const it of items){const o=at.get(it.id);put(it.id,lanePos[ai]+o.a,bc+o.c)}}
 const node=(id,na,nc)=>{const n=pos.get(id);if(n){n.x=TB?nc:na;n.y=TB?na:nc}};
 if(L.start)node(L.start,A0-(TB?96:192)-laneGap,C0);
 if(L.end)node(L.end,a,C0);
 // 记录排布时的泳道几何：连线按它走通道，拖动单张卡片不会改变其他连线
 const NA=TB?96:192;let c0=Infinity;L.lanes.forEach(lane=>{const ids=folded(lane)||LG[lane]?[LG[lane]]:Object.values(L.cells[lane]||{});for(const gid of ids){const e=ext(gid);if(e)c0=Math.min(c0,TB?e.b.x:e.b.y)}});
 L.geo={dir:TB?'TB':'LR',lanes:lanePos.map((p,i)=>[p,p+laneSize[i]]),start:[A0-NA-laneGap,A0-laneGap],end:[a,a+NA],c0:isFinite(c0)?c0:C0};
 return true;
}
