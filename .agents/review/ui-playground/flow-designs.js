/* THROWAWAY: Feed with GitHub and AI Hero visual variants, with a viewport-following source pane. */
const flowVariants = [11,17,15,16];
let flowUndo = null, flowScrollFrame = 0;
const archiveOpen = {done:false,rejected:false};
const isFlow = () => flowVariants.includes(variant);
const openFindings = () => F.filter(f=>state(f)==='open');
const flowNumber = f => numbers(F.indexOf(f));
function flowActions(f) {
 return `<div class="decision-actions">${state(f)==='open'?b('✓ Mark done','decision','primary',`data-id="${f.id}" data-value="done"`)+b('Discard','decision','secondary',`data-id="${f.id}" data-value="rejected"`):b('↶ Reopen finding','decision','secondary',`data-id="${f.id}" data-value="open"`)}</div>`;
}
function flowCounts() {
 return `<div class="flow-counts"><span><strong>${openFindings().length}</strong> open</span><span><strong>${F.filter(f=>state(f)==='done').length}</strong> done</span><span><strong>${F.filter(f=>state(f)==='rejected').length}</strong> discarded</span></div>`;
}
function flowScope() {
 return `<div class="flow-scope"><span>project-refactor</span><code>${esc(R.request.scope.baseSha)} → ${esc(R.request.scope.headSha)}</code></div>`;
}
function flowCoverage() {
 return `<div class="flow-coverage"><span>${agentLogo('claude-opus')} <strong>Claude failed to start.</strong> Two reviewers completed; Claude supplied no review.</span><small>Synthetic example · no runtime checks executed.</small></div>`;
}
function flowContext() {
 return `<details class="flow-context"><summary>Review scope & limits <span>+</span></summary><p>${esc(R.request.context.intent)}</p>${R.request.context.acceptedExceptions.map(s=>`<p>${esc(s)}</p>`).join('')}${R.limits.map(s=>`<p>${esc(s)}</p>`).join('')}</details>`;
}
function changeList() { return `<ul class="change-list">${R.whatChanged.map((x,i)=>`<li><span class="change-number">${numbers(i)}</span><span>${esc(x)}</span></li>`).join('')}</ul>`; }
function feedOverview() {
 return `<header class="flow-overview" id="review-overview"><div class="flow-topline"><div class="feed-identity">${appIdentity()}<span class="eyebrow">project-refactor</span></div>${sample()}</div><h1>What changed</h1><p class="overview-deck">The behavior behind this change, before the findings.</p>${flowScope()}${changeList()}${flowCoverage()}${flowContext()}<div class="overview-tail">${flowCounts()}${b('Start reading ↓','flow-start','primary')}</div></header>`;
}
function flowFindingHeader(f) {
 return `<header class="flow-finding-header"><div class="finding-chapter"><span>Finding ${flowNumber(f)}</span><span>${f.codeViews.length} source files</span></div><h2 data-track-title="${f.id}">${esc(f.title)}</h2>${tags(f)}</header>`;
}
function flowDecision(f) { return `<footer class="flow-decision">${note(f)}${flowActions(f)}</footer>`; }
function feedFinding(f) {
 return `<article class="flow-finding" data-finding="${f.id}">${flowFindingHeader(f)}<section class="finding-consequence"><h3>What goes wrong</h3><p>${esc(f.whatGoesWrong)}</p></section><section class="finding-mechanism"><h3>Why it happens</h3><p>${esc(f.whyItHappens)}</p>${origin(f)}</section>${uncertainty(f)}${reproduction(f)}${evidence(f)}${flowDecision(f)}</article>`;
}
function currentFindingRenderer() { return ({11:feedFinding,17:feedFinding,15:githubFinding,16:aiheroFinding})[variant]; }
function flowArchives() {
 return `<section class="flow-archives" id="review-archives"><div class="eyebrow">Reviewed findings</div>${[['done','Done','✓'],['rejected','Discarded','−']].map(([value,label,mark])=>{const items=F.filter(f=>state(f)===value);return `<details class="flow-archive" data-archive="${value}" ${archiveOpen[value]?'open':''}><summary><span class="archive-mark">${mark}</span><strong>${label}</strong><span class="archive-count">${items.length}</span><span class="archive-chevron">⌄</span></summary><div class="archive-content">${items.length?items.map(currentFindingRenderer()).join(''):`<p class="archive-empty">No ${label.toLowerCase()} findings.</p>`}</div></details>`;}).join('')}<p class="flow-endnote">End of review · decisions and notes stay in this page until it is refreshed.</p></section>`;
}
function flowFindingsHeading() {
 const items=openFindings();return `<div class="findings-start"><h2>${items.length?'Findings':'No open findings'}</h2><span>${items.length?items.length+' open · sorted by relevance':'Everything has been triaged'}</span></div>`;
}
function flowFindings(showHeading=true) {
 return `${showHeading?flowFindingsHeading():''}<div class="active-findings">${openFindings().map(currentFindingRenderer()).join('')}</div>${flowArchives()}`;
}
function flowCode() {
 const f=F[selected];
 const hasVisible=state(f)==='open'||archiveOpen[state(f)];
 if(!hasVisible&&!openFindings().length)return `<div class="flow-code-empty"><span>✓</span><h2>No open findings</h2><p>Expand Done or Discarded to revisit a finding and its source.</p>${flowCounts()}</div>`;
 return `<div class="flow-code-heading"><span class="flow-code-index">${flowNumber(f)}</span><div><small>${state(f)==='open'?'Following this finding':state(f)==='done'?'Done finding':'Discarded finding'}</small><strong>${esc(shortTitles[selected])}</strong></div><span class="follow-indicator"><i></i> Auto-follow</span></div>${source(f)}`;
}
function flowToast() {return flowUndo?`<div class="flow-toast" role="status"><span>Finding ${flowNumber(F.find(f=>f.id===flowUndo.id))} ${flowUndo.value==='done'?'marked done':flowUndo.value==='rejected'?'discarded':'reopened'}</span>${b('Undo','flow-undo')}</div>`:'';}
function renderYellowFeed() { return renderFeed().replace('class="flow feed"','class="flow feed feed-yellow"'); }
function renderFeed() {return `<div class="flow feed">${feedOverview()}${flowFindingsHeading()}<div class="flow-layout"><main class="flow-reading">${flowFindings(false)}</main><aside class="flow-code" aria-label="Source code follows the current finding">${flowCode()}</aside></div>${flowToast()}</div>`;}
function updateFlowCode(keepScroll=false) {
 const pane=document.querySelector('.flow-code');if(!pane)return;
 const oldScroll=pane.querySelector('.code-body')?.scrollTop||0;
 pane.innerHTML=flowCode();
 const code=pane.querySelector('.code-body');
 if(code&&keepScroll)code.scrollTop=oldScroll;
 document.querySelectorAll('.flow-finding').forEach(n=>n.classList.toggle('is-current',n.dataset.finding===F[selected].id));
 document.querySelectorAll('.flow-rail [data-action="flow-jump"],.ledger-jumpbar [data-action="flow-jump"]').forEach(n=>{const active=n.dataset.id===F[selected].id;n.classList.toggle('active',active);if(active)n.setAttribute('aria-current','location');else n.removeAttribute('aria-current');});
 const label=document.querySelector('.switcher-label small');if(label)label.textContent=`Throwaway · ${selected+1}/4 selected · ${state(F[selected])}`;
}
function syncFlowToScroll() {
 if(!isFlow())return;
 const titles=[...document.querySelectorAll('[data-track-title]')].filter(n=>!n.closest('details:not([open])')&&n.getClientRects().length);
 if(!titles.length){updateFlowCode();return;}
 const midpoint=innerHeight/2;
 const passed=titles.filter(n=>{const r=n.getBoundingClientRect();return r.top+r.height/2<=midpoint+1;});
 const active=passed.at(-1)||titles[0];
 const index=F.findIndex(f=>f.id===active.dataset.trackTitle);
 if(index!==selected){selected=index;updateFlowCode();}
}
function scheduleFlowSync(){if(!isFlow()||flowScrollFrame)return;flowScrollFrame=requestAnimationFrame(()=>{flowScrollFrame=0;syncFlowToScroll();});}
function jumpFlowFinding(id) {
 const f=F.find(f=>f.id===id);if(!f)return;
 if(state(f)!=='open') {archiveOpen[state(f)]=true;const group=document.querySelector(`[data-archive="${state(f)}"]`);if(group)group.open=true;}
 const title=document.querySelector(`[data-track-title="${id}"]`);if(!title)return;
 selected=F.indexOf(f);updateFlowCode();
 const r=title.getBoundingClientRect();window.scrollTo({top:Math.max(0,scrollY+r.top+r.height/2-innerHeight/2+2),behavior:'instant'});
}
function handleFlowDecision(f,value) {
 const was=state(f), before=openFindings(), next=before[before.indexOf(f)+1]||before[before.indexOf(f)-1];
 decisions[f.id]=value;flowUndo={id:f.id,was,value};
 if(value!=='open')archiveOpen[value]=false;
 const target=value==='open'?f:(next&&state(next)==='open'?next:openFindings()[0]);
 if(target)selected=F.indexOf(target);
 render();
 if(target)jumpFlowFinding(target.id);else document.getElementById('review-archives').scrollIntoView({block:'start'});
}
function handleFlowClick(a,control,f) {
 if(a==='flow-overview'){window.scrollTo({top:0,behavior:'instant'});return true;}
 if(a==='flow-start'){if(openFindings()[0])jumpFlowFinding(openFindings()[0].id);return true;}
 if(a==='flow-jump'){jumpFlowFinding(control.dataset.id);return true;}
 if(a==='flow-archives'){document.getElementById('review-archives').scrollIntoView({block:'start'});return true;}
 if(a==='flow-undo') {if(flowUndo){const prev=flowUndo;decisions[prev.id]=prev.was;flowUndo=null;selected=F.findIndex(f=>f.id===prev.id);render();jumpFlowFinding(prev.id);}return true;}
 if(a==='decision'){handleFlowDecision(f,control.dataset.value);return true;}
 if(a==='view'){viewerState(f).view=Number(control.dataset.index);updateFlowCode();return true;}
 if(a==='side'){viewerState(f).side=control.dataset.value;updateFlowCode();return true;}
 if(a==='comments'){showComments=control.dataset.value==='all';updateFlowCode(true);return true;}
 return false;
}
window.addEventListener('scroll',scheduleFlowSync,{passive:true});
window.addEventListener('resize',scheduleFlowSync);
document.addEventListener('toggle',e=>{if(e.target.isConnected&&e.target.matches('.flow-archive')){archiveOpen[e.target.dataset.archive]=e.target.open;scheduleFlowSync();}},true);

// Brand-inspired treatments preserve Feed's recap-first layout and all interactions.
function githubOverview() {
 return `<header class="flow-overview gh-overview" id="review-overview"><div class="gh-repo-bar"><img class="review-logo" src="${appLogo}" alt="Review"><span>project-refactor <b>/ Code review</b></span><span class="gh-private">Local</span>${sample()}</div><div class="gh-review-title"><h1>What changed <span>#024</span></h1><div class="gh-review-subtitle"><span class="gh-state">◉ Review</span><code>${esc(R.request.scope.baseSha)} → ${esc(R.request.scope.headSha)}</code><span>${R.request.scope.changedPaths.length} changed files</span></div></div><div class="gh-recap-grid"><section class="gh-description"><div class="gh-box-heading"><strong>Change summary</strong><span>Behavior before → after</span></div><div class="gh-description-body">${changeList()}${flowContext()}</div></section><aside class="gh-review-meta"><h3>Review coverage</h3>${flowCoverage()}<h3>Findings</h3>${flowCounts()}${b('Start review ↓','flow-start','primary')}</aside></div></header>`;
}
function githubFinding(f) {
 const meta=`<div class="gh-thread-meta"><span>◉</span><strong>Finding ${flowNumber(f)}</strong><span>· ${f.codeViews.length} files</span><span class="gh-thread-state">${state(f)==='rejected'?'Discarded':state(f)==='done'?'Done':'Open'}</span></div>`;
 return feedFinding(f).replace(flowFindingHeader(f),meta+flowFindingHeader(f));
}
function aiheroOverview() {
 return `<header class="flow-overview ai-overview" id="review-overview"><div class="ai-topbar">${appIdentity()}<span class="ai-ref">project-refactor</span>${sample()}</div><div class="ai-recap-grid"><div class="ai-hero-copy"><span class="ai-kicker">CODE REVIEW · ${esc(R.request.scope.baseSha)} → ${esc(R.request.scope.headSha)}</span><h1>What<br>changed<span class="ai-period">.</span></h1><p>Understand the change.<br>Inspect the consequences.</p><div class="ai-stats"><div><strong>${openFindings().length}</strong><span>OPEN FINDINGS</span></div><div><strong>2 / 3</strong><span>REVIEWERS COMPLETED</span></div></div>${b('Explore the findings →','flow-start','primary')}</div><div class="ai-change-sheet"><div class="ai-sheet-heading"><span>THE CHANGESET</span><span>01—04</span></div>${changeList()}${flowContext()}</div></div>${flowCoverage()}</header>`;
}
function aiheroFinding(f) {
 const header=`<header class="flow-finding-header ai-finding-header"><div class="ai-finding-kicker"><span class="ai-finding-number">${flowNumber(f)}</span><span>THE FINDING / ${f.codeViews.length} SOURCE FILES</span></div><h2 data-track-title="${f.id}">${esc(f.title)}</h2>${tags(f)}</header>`;
 return feedFinding(f).replace(flowFindingHeader(f),header);
}
function renderGitHub(){return `<div class="flow github">${githubOverview()}${flowFindingsHeading()}<div class="flow-layout"><main class="flow-reading">${flowFindings(false)}</main><aside class="flow-code" aria-label="Source code follows the current finding">${flowCode()}</aside></div>${flowToast()}</div>`;}
function renderAIHero(){return `<div class="flow aihero">${aiheroOverview()}${flowFindingsHeading()}<div class="flow-layout"><main class="flow-reading">${flowFindings(false)}</main><aside class="flow-code" aria-label="Source code follows the current finding">${flowCode()}</aside></div>${flowToast()}</div>`;}
