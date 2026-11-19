// 工作流运行（演示）：不再弹出底部面板，运行进度直接画在工作流画布上。
// - 任务卡片：左上角状态标记（等待 / 运行中 / 成功 / 失败 / 跳过 / 已停止），边框随状态变色
// - 分组：收起时底部进度条 + "运行中 12/20"，展开时标题旁显示进度
// - 连线：流入运行中节点的连线按方向流动，已完成的连线变绿
// - 画布上方一条状态条：进度、成功/失败数、耗时，可停止或清除
// 按依赖并发调度：上游全部成功后才开始，上游失败的下游标记为跳过。仅演示，不提交到执行引擎。

export function executionPlan(flow,tasks,selected=null){
 const ids=new Set(selected?flow.nodes.filter(n=>selected.has(n.taskId)).map(n=>n.taskId):flow.nodes.map(n=>n.taskId));
 if(!ids.size)throw Error(selected?'请先选择需要运行的任务':'工作流中还没有任务');
 const remaining=new Set(ids),plan=[];
 while(remaining.size){const ready=[...remaining].filter(id=>!flow.edges.some(([a,b])=>b===id&&remaining.has(a)));if(!ready.length)throw Error('工作流存在循环依赖，请检查连线');for(const id of ready){const task=tasks.find(t=>t.id===id);if(!task)throw Error('任务不存在，请刷新后重试');plan.push({...task});remaining.delete(id)}}return plan;
}

const LABEL={waiting:'等待',running:'运行中',done:'成功',live:'已启动',failed:'失败',skipped:'跳过',stopped:'已停止'};
const CONCURRENCY=8;

export function setupWorkflowRun({snapshot,save,validateJar,currentFlowId=()=>null,toast=()=>{}}){
 const $=s=>document.querySelector(s),esc=s=>String(s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
 // run: {flowId,name,scope,groups,ups:Map,state:Map,info:Map,start,end,running}
 let run=null,timers=new Set(),raf=0;

 const bar=document.createElement('div');bar.className='workflow-run-control';bar.innerHTML='<button class="btn primary" id="workflowRun" title="运行当前任务；在工作流中运行选中任务或整个工作流">▷ 运行</button>';$('.document-bar').append(bar);
 const pill=document.createElement('div');pill.id='runStatus';pill.className='run-status hidden';pill.setAttribute('role','status');$('.shell>main').append(pill);

 const active=()=>!!run?.running;
 function updateButton(){const b=$('#workflowRun');b.textContent=active()?'■ 停止':'▷ 运行';b.title=active()?'停止当前运行':'运行当前任务；在工作流中运行选中任务或整个工作流';b.setAttribute('aria-label',active()?'停止':'运行');b.classList.toggle('is-running',active())}
 const fmt=ms=>{const s=Math.max(0,Math.round(ms/1000));return String(Math.floor(s/60)).padStart(2,'0')+':'+String(s%60).padStart(2,'0')};
 const clock=t=>new Date(t).toLocaleTimeString('zh-CN',{hour12:false});
 function counts(ids){const c={total:0,waiting:0,running:0,done:0,failed:0,skipped:0,stopped:0};for(const id of ids){const s=run.state.get(id);if(!s)continue;c.total++;c[s==='live'?'done':s]++}return c}
 function aggregate(c){if(!c.total)return null;if(c.failed)return 'failed';if(c.running)return 'running';if(c.done===c.total)return 'done';if(c.stopped)return 'stopped';if(c.done+c.skipped===c.total)return c.done?'done':'skipped';return c.done?'running':'waiting'}

 // ---- 状态条 ----
 function renderPill(){
  if(!run){pill.classList.add('hidden');return}
  const c=counts(run.state.keys()),pct=c.total?Math.round((c.done+c.failed+c.skipped)/c.total*100):0,state=run.running?'running':c.failed?'failed':c.stopped?'stopped':'done';
  const head=run.running?'运行中':state==='failed'?'运行结束（有失败）':state==='stopped'?'已停止':'运行完成';
  const elsewhere=run.flowId&&run.flowId!==currentFlowId();
  pill.dataset.state=state;pill.classList.remove('hidden');
  pill.innerHTML=`<span class="run-dot"></span><b>${head}</b><span class="run-name" title="${esc(run.name)}">${esc(run.name)} · ${run.scope==='task'?'当前任务':run.scope==='all'?'整个工作流':'选中任务'}</span><span class="run-bar"><i style="width:${pct}%"></i></span><span class="run-num">${c.done+c.failed+c.skipped}/${c.total}</span><span class="run-ok">成功 ${c.done}</span>${c.failed?`<span class="run-bad">失败 ${c.failed}</span>`:''}${c.skipped?`<span class="run-skip">跳过 ${c.skipped}</span>`:''}<span class="run-time">${fmt((run.end||Date.now())-run.start)}</span>${elsewhere?`<button data-act="goto" title="切换到正在运行的工作流">查看</button>`:''}${run.running?'<button data-act="stop">停止</button>':'<button data-act="clear" title="清除画布上的运行状态" aria-label="清除运行状态">×</button>'}<span class="run-demo" title="仅演示编排顺序与状态变化，不提交 SQL、脚本或 JAR 到执行引擎。选中任务模式不补跑未选中的上游依赖。">演示</span>`;
 }
 pill.addEventListener('click',e=>{const a=e.target.closest('[data-act]')?.dataset.act;if(a==='stop')cancel();else if(a==='clear')clear();else if(a==='goto')document.querySelector(`[data-flow="${CSS.escape(run.flowId)}"]`)?.click()});

 // ---- 画布装饰 ----
 function decorate(){
  raf=0;
  document.querySelectorAll('.run-badge,.run-group').forEach(el=>el.remove());
  document.querySelectorAll('[data-run]').forEach(el=>el.removeAttribute('data-run'));
  document.querySelectorAll('#edges .edge-run,#edges .edge-ok').forEach(el=>el.classList.remove('edge-run','edge-ok'));
  renderPill();
  if(!run||!run.flowId||run.flowId!==currentFlowId())return;
  const itemState=new Map();
  document.querySelectorAll('#nodes .node[data-id]').forEach(el=>{const id=el.dataset.id,s=run.state.get(id);if(!s)return;itemState.set('task:'+id,s);el.dataset.run=s;const info=run.info.get(id)||{};
   const tip=LABEL[s]+(info.start?` · 开始 ${clock(info.start)}`:'')+(info.end?` · 耗时 ${((info.end-info.start)/1000).toFixed(1)}s`:'')+(info.reason?` · ${info.reason}`:'');
   el.insertAdjacentHTML('beforeend',`<span class="run-badge" data-run="${s}" title="${esc(tip)}"><i></i>${LABEL[s]}</span>`)});
  document.querySelectorAll('#groups [data-group-box]').forEach(el=>{const g=run.groups.get(el.dataset.groupBox);if(!g)return;const c=counts(g),s=aggregate(c);if(!s)return;itemState.set('group:'+el.dataset.groupBox,s);el.dataset.run=s;const fin=c.done+c.failed+c.skipped,pct=Math.round(fin/c.total*100);
   const text=(s==='running'?'运行中':LABEL[s])+` ${fin}/${c.total}`+(c.failed?` · 失败 ${c.failed}`:'');
   if(el.classList.contains('collapsed')){const sum=el.querySelector('.group-summary');sum?.lastElementChild&&(sum.lastElementChild.dataset.run=s,sum.lastElementChild.textContent=text);el.insertAdjacentHTML('beforeend',`<span class="run-group run-group-bar"><i style="width:${pct}%"></i></span>`)}
   else el.querySelector('.group-heading')?.insertAdjacentHTML('beforeend',`<span class="run-group run-group-chip" data-run="${s}">${esc(text)}</span>`)});
  document.querySelectorAll('#edges [data-edge]').forEach(g=>{const t=itemState.get(g.dataset.to),f=itemState.get(g.dataset.from);if(t==='running'&&(!f||f==='done'||f==='running'||f==='live'))g.classList.add('edge-run');else if((t==='done'||t==='live')&&f)g.classList.add('edge-ok')});
 }
 const schedule=()=>{if(!raf)raf=requestAnimationFrame(decorate)};
 const obs=new MutationObserver(schedule);['#nodes','#groups','#edges'].forEach(s=>{const el=$(s);if(el)obs.observe(el,{childList:true})});
 window.addEventListener('dataflow:open-task',schedule);document.addEventListener('click',e=>{if(e.target.closest('[data-flow],.document-tab,.development-task-tab'))setTimeout(schedule,50)},true);

 // ---- 调度 ----
 function finish(){run.running=false;run.end=Date.now();timers.forEach(clearTimeout);timers.clear();updateButton();clearInterval(run.tick);schedule();
  const c=counts(run.state.keys());toast(c.failed?`运行结束：成功 ${c.done}，失败 ${c.failed}，跳过 ${c.skipped}`:`运行完成：${c.done} 个任务（演示）`)}
 function pump(){
  if(!run?.running)return;
  let busy=[...run.state.values()].filter(s=>s==='running').length;
  for(const [id,s] of run.state){
   if(busy>=CONCURRENCY)break;if(s!=='waiting')continue;
   const ups=run.ups.get(id)||[];
   if(ups.some(u=>['failed','skipped','stopped'].includes(run.state.get(u)))){run.state.set(id,'skipped');run.info.set(id,{reason:'上游未成功'});continue}
   if(!ups.every(u=>['done','live'].includes(run.state.get(u))))continue;
   const t=run.tasks.get(id),error=t.type?.endsWith('_jar')?validateJar(t.jar):!t.code?.trim()?'代码为空':null,start=Date.now();
   run.state.set(id,'running');run.info.set(id,{start});busy++;
   const timer=setTimeout(()=>{timers.delete(timer);if(!run?.running)return;run.state.set(id,error?'failed':t.mode==='streaming'?'live':'done');run.info.set(id,{start,end:Date.now(),reason:error?'校验未通过：'+error:''});schedule();pump()},error?300:250+Math.random()*650);timers.add(timer);
  }
  // 跳过可能让后续任务也满足条件，或全部结束
  if([...run.state.values()].some(s=>s==='skipped')&&[...run.state].some(([id,s])=>s==='waiting'&&(run.ups.get(id)||[]).some(u=>run.state.get(u)==='skipped'))){schedule();return pump()}
  schedule();
  if(![...run.state.values()].some(s=>s==='waiting'||s==='running'))finish();
 }
 function start(){
  save(false);const st=snapshot(),scope=st.singleTask?'task':st.selection.size?'selected':'all';let plan;
  try{plan=executionPlan(st.flow,st.tasks,scope==='selected'?st.selection:null)}catch(e){toast(e.message);return}
  const ids=new Set(plan.map(t=>t.id)),ups=new Map(plan.map(t=>[t.id,[]]));st.flow.edges.forEach(([a,b])=>{if(ids.has(a)&&ids.has(b))ups.get(b).push(a)});
  timers.forEach(clearTimeout);timers.clear();if(run)clearInterval(run.tick);
  run={flowId:st.singleTask?null:st.flow.id,name:st.flow.name,scope,ups,tasks:new Map(plan.map(t=>[t.id,t])),groups:new Map((st.flow.groups||[]).map(g=>[g.id,g.ids])),state:new Map(plan.map(t=>[t.id,'waiting'])),info:new Map(),start:Date.now(),end:0,running:true};
  run.tick=setInterval(renderPill,1000);updateButton();schedule();pump();
 }
 function cancel(){if(!active())return;for(const [id,s] of run.state)if(s==='waiting'||s==='running')run.state.set(id,'stopped');finish()}
 function clear(){if(active())return;run=null;schedule()}
 $('#workflowRun').onclick=()=>active()?cancel():start();
 updateButton();
 return {cancel,clear,refresh:schedule};
}
