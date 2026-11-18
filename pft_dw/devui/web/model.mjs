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

// 泳道自动排布（flow.layout 由 PFT 项目种子写入，与 server/seed_pft.py 的 relayout 同一算法）
// 网格：泳道（分层）沿流向排列，行=数据域；dir=LR 时流向从左到右、TB 时从上到下。
// 分支（如 DIM）贴在锚定泳道一侧的网格外，按 cols 列排布。分组折叠/展开后重新计算，展开的分组不会与相邻分组重叠。
export function relayout(flow){
 const L=flow?.layout;if(!L||!L.lanes)return false;
 const TB=L.dir==='TB',pos=new Map(flow.nodes.map(n=>[n.taskId,n])),G=new Map(flow.groups.map(g=>[g.id,g]));
 const ext=gid=>{const g=G.get(gid),b=g&&groupBounds(flow,g);return b?{b,la:TB?b.h:b.w,lc:TB?b.w:b.h}:null};
 const put=(gid,a,c)=>{const e=ext(gid);if(!e)return;const x=TB?c:a,y=TB?a:c,dx=x-e.b.x,dy=y-e.b.y;for(const id of G.get(gid).ids){const n=pos.get(id);if(n){n.x+=dx;n.y+=dy}}};
 const laneGap=L.laneGap??150,rowGap=L.rowGap??40,A0=L.a0??380,C0=L.c0??160,rows=L.rows||[],ri=r=>Math.max(0,rows.indexOf(r));
 const laneSize=L.lanes.map(()=>0),rowSize=rows.length?rows.map(()=>0):[0];
 const LG=L.laneGroups||{},folded=lane=>G.get(LG[lane])?.collapsed;
 L.lanes.forEach((lane,i)=>{if(folded(lane)){const e=ext(LG[lane]);if(e){laneSize[i]=e.la;rowSize[0]=Math.max(rowSize[0],e.lc)}return}for(const [r,gid] of Object.entries(L.cells[lane]||{})){const e=ext(gid);if(!e)continue;laneSize[i]=Math.max(laneSize[i],e.la+(LG[lane]?(TB?64:36):0));rowSize[ri(r)]=Math.max(rowSize[ri(r)],e.lc)}});
 const lanePos=[];let a=A0;laneSize.forEach((s,i)=>{lanePos[i]=a;if(s)a+=s+laneGap});
 const rowPos=[];let c=C0;rowSize.forEach((s,i)=>{rowPos[i]=c;if(s)c+=s+rowGap});
 const pad=lane=>LG[lane]?(TB?47:18):0;
 L.lanes.forEach((lane,i)=>{if(folded(lane)){put(LG[lane],lanePos[i],rowPos[0]);return}for(const [r,gid] of Object.entries(L.cells[lane]||{}))put(gid,lanePos[i]+pad(lane),rowPos[ri(r)])});
 if(L.branch&&G.get(L.branch.group)?.collapsed){put(L.branch.group,lanePos[Math.max(0,L.lanes.indexOf(L.branch.anchor))],c-rowGap+(L.branch.gap??150))}
 else if(L.branch){const B=L.branch,cols=B.cols||2,ai=Math.max(0,L.lanes.indexOf(B.anchor)),es=B.groups.map(ext),sub=Array(cols).fill(0),brow=[];
  es.forEach((e,i)=>{if(!e)return;sub[i%cols]=Math.max(sub[i%cols],e.la);const r=Math.floor(i/cols);brow[r]=Math.max(brow[r]||0,e.lc)});
  const subPos=[];let sa=lanePos[ai];sub.forEach((s,k)=>{subPos[k]=sa;sa+=s+90});
  const bPos=[];let bc=c-rowGap+(B.gap??150);brow.forEach((s,r)=>{bPos[r]=bc;bc+=s+rowGap});
  B.groups.forEach((gid,i)=>put(gid,subPos[i%cols],bPos[Math.floor(i/cols)]))}
 const node=(id,na,nc)=>{const n=pos.get(id);if(n){n.x=TB?nc:na;n.y=TB?na:nc}};
 if(L.start)node(L.start,A0-(TB?96:192)-laneGap,C0);
 if(L.end)node(L.end,a,C0);
 return true;
}
