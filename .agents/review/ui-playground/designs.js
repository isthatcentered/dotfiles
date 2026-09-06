/* THROWAWAY: Feed and two visual alternatives for the same review, with in-memory triage. */
const R = JSON.parse(document.getElementById('report-data').textContent);
const relevanceRank = {low:1, medium:2, high:3};
const relevance = f => (relevanceRank[f.severity.value] || 0) * (relevanceRank[f.likelihood.value] || 0);
// Unknown likelihood stays explicitly unknown and follows rated findings.
R.findings.sort((a,b)=>relevance(b.finding)-relevance(a.finding) || relevanceRank[b.finding.severity.value]-relevanceRank[a.finding.severity.value]);
const F = R.findings.map(e => e.finding);
const variantIds = [11, 17, 15, 16];
const names = {11:'Feed',17:'Feed · Yellow',15:'GitHub',16:'AI Hero'};
const descriptions = {11:'Original Feed',17:'Feed with AI Hero yellow',15:'GitHub-inspired review',16:'AI Hero-inspired review'};
const initial = Number(new URL(location.href).searchParams.get('variant') || 11);
let variant = variantIds.includes(initial) ? initial : 11;
let selected = 0, showComments = true;
const decisions = {}, comments = {}, viewers = {};
const esc = v => String(v ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const b = (text, action, cls = '', attrs = '') => `<button type="button" class="${cls}" data-action="${action}" ${attrs}>${text}</button>`;
const state = f => decisions[f.id] || 'open';
const shortTitles = F.map(f=>({'cache-leak':'Cross-tenant cache leak','hidden-timeout':'Timeout recovery disappears','broken-export':'Public export breaks','invite-retention':'Cleanup replacement unverified'})[f.id] || f.title);
const numbers = n => String(n + 1).padStart(2, '0');
const icon = (name) => ({arrow:'↗', next:'→', prev:'←', check:'✓', source:'⌘', dot:'●'})[name];
function badge(text, cls='') { return `<span class="badge ${cls}">${esc(text)}</span>`; }
function agentLogo(id) {
 const provider=id.includes('claude')?'claude':'openai';
 return `<img class="agent-logo ${provider}" src="${agentIcons[provider]}" alt="${provider==='claude'?'Claude':'ChatGPT'}">`;
}
function reviewerBadges(f) {
 const ids=[...new Set(R.findings[F.indexOf(f)].sources.map(s=>s.reviewer))];
 const labels={'codex-astra':'Codex Astra','codex-sol':'Codex Sol','claude-opus':'Claude Opus'};
 return `<span class="reviewer-attribution"><span class="reviewer-avatars">${ids.map(id=>`<span class="reviewer-avatar" title="${esc(labels[id]||id)}" aria-label="${esc(labels[id]||id)}">${agentLogo(id)}</span>`).join('')}</span><span>${ids.length} reviewer${ids.length===1?'':'s'}</span></span>`;
}
function tags(f) {
 return `<div class="tags">${badge(f.severity.value + ' impact', f.severity.value)}${badge(f.likelihood.value + ' likelihood','likelihood')}${badge(f.assessment.status === 'needs-verification' ? 'Needs verification' : 'Source supported', f.assessment.status === 'needs-verification' ? 'uncertain' : 'supported')}${state(f) !== 'open' ? badge(isFlow()&&state(f)==='rejected'?'discarded':state(f),'decided') : ''}${reviewerBadges(f)}</div>`;
}
function metrics(f) { return `<div class="metrics"><div><span>Likelihood</span><strong>${esc(f.likelihood.value)}</strong></div><div><span>Evidence</span><strong>${f.codeViews.length} files · ${f.codeViews.reduce((n,v)=>n+(v.after.ranges || v.before.ranges || []).length,0)} ranges</strong></div><div><span>Reported by</span><strong>${new Set(R.findings[F.indexOf(f)].sources.map(s=>s.reviewer)).size} reviewers</strong></div></div>`; }
function runInfo(compact=false) { return `<details class="run-info"><summary><span class="status-dot"></span> Partial review <span class="muted">2 of 3 completed</span> <span>⌄</span></summary><div class="run-detail"><strong>Claude did not start</strong><p>Two startup attempts timed out. It supplied no review and contributed no findings.</p><div class="reviewer-row"><span class="reviewer-name">${agentLogo("codex-astra")} Codex Astra</span><span>✓ completed</span></div><div class="reviewer-row"><span class="reviewer-name">${agentLogo("codex-sol")} Codex Sol</span><span>✓ completed</span></div><div class="reviewer-row"><span class="reviewer-name">${agentLogo("claude-opus")} Claude Opus</span><span>× failed</span></div><small>Simulated outcomes for this design playground.</small></div></details>`; }
function appIdentity() { return `<div class="review-identity"><img class="review-logo" src="${appLogo}" alt=""><span>Review</span></div>`; }
function brand(label) { return `<div class="brand"><span class="brand-symbol">r/</span>${label}</div>`; }
function sample() { return `<span class="sample">SYNTHETIC EXAMPLE</span>`; }
function actions(f) { return `<div class="decision-actions">${b('✓ Mark done','decision','primary',`data-id="${f.id}" data-value="done"`)}${b('Reject','decision','secondary',`data-id="${f.id}" data-value="rejected"`)}${state(f)!=='open'?b('Reopen','decision','secondary',`data-id="${f.id}" data-value="open"`):''}</div>`; }
function note(f) { return `<label class="note-label">Your decision note <span>kept while this page is open</span><textarea data-comment="${f.id}" placeholder="What should we change, check, or accept?">${esc(comments[f.id] || '')}</textarea></label>`; }
function reproduction(f) { return `<div class="repro"><h3>How to reproduce</h3><ol>${f.reproduction.steps.map(s=>`<li>${esc(s)}</li>`).join('')}</ol><div class="expected"><span>Expected</span>${esc(f.reproduction.expected)}</div><div class="actual"><span>Predicted outcome</span>${esc(f.reproduction.actual)}</div><small>Source-based prediction. No runtime check was executed.</small></div>`; }
function evidence(f) { return `<div class="evidence">${f.evidence.filter(e=>e.kind!=='source').map(e=>{
 if(e.kind==='document'){const d=R.request.context.documents.find(d=>d.id===e.documentId);return `<details><summary>↗ ${esc(d.title)}</summary><pre>${esc(d.content)}</pre><small>Snapshot · ${esc(d.sha256.slice(0,14))}</small></details>`;}
 if(e.kind==='check')return `<details><summary>⌘ Suggested check <span class="muted">not run</span></summary><pre>${esc(e.command)}</pre><p>${esc(e.output)}</p></details>`;
 return '';
}).join('')}${R.findings[F.indexOf(f)].disagreements.map(d=>`<details><summary>⇄ Reviewer disagreement</summary><p>${esc(d.explanation)}</p></details>`).join('')}<section class="confidence-limits"><h3>Confidence & limits</h3><p>${esc(f.assessment.reasoning)}</p><p>${esc(f.limits.join(' '))}</p><p><strong>Severity:</strong> ${esc(f.severity.reasoning)}</p><p><strong>Likelihood:</strong> ${esc(f.likelihood.reasoning)}</p></section></div>`; }
function uncertainty(f) { return f.assessment.status!=='needs-verification'?'':`<div class="uncertainty"><strong>Verify before treating this as a regression</strong><p>${esc(f.assessment.assumptions[0])}</p><ul>${f.assessment.verificationSteps.map(s=>`<li>${esc(s)}</li>`).join('')}</ul></div>`; }
function origin(f) { const l=f.problematicLocation.location; return `<span class="origin">${esc(l.path)} <b>L${l.startLine}–${l.endLine}</b></span>`; }
function viewerState(f) { return viewers[f.id] ||= {view:0, side:f.problematicLocation.kind==='deletion'?'before':'after', range:'all', full:false}; }
const highlightedSourceCache = new Map();
function highlightedLines(content, path) {
 const key=path+'\0'+content;
 if(highlightedSourceCache.has(key)) return highlightedSourceCache.get(key);
 const language=({ts:'typescript',tsx:'typescript',js:'javascript',jsx:'javascript',py:'python',json:'json',css:'css',html:'xml',sh:'bash'})[path.split('.').at(-1)];
 if(!language || !hljs.getLanguage(language)) return content.split('\n').map(esc);
 // Highlight the complete file, then preserve token classes across line breaks.
 const parsed=document.createElement('template');
 parsed.innerHTML=hljs.highlight(content,{language,ignoreIllegals:true}).value;
 const lines=[''];
 function walk(node, classes=[]) {
  if(node.nodeType===Node.TEXT_NODE) {
   node.textContent.split('\n').forEach((piece,i)=>{
    if(i) lines.push('');
    lines[lines.length-1]+=classes.length?`<span class="${esc(classes.join(' '))}">${esc(piece)}</span>`:esc(piece);
   });
  } else {
   const next=node.classList?[...classes,...node.classList]:classes;
   node.childNodes.forEach(child=>walk(child,next));
  }
 }
 walk(parsed.content);
 highlightedSourceCache.set(key,lines);
 return lines;
}
function commentToggle() {
 const label=showComments?'Hide all review comments':'Show all review comments';
 const svg=`<svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M20 11.5v4a2 2 0 0 1-2 2H9l-5 4v-17a2 2 0 0 1 2-2h12a2 2 0 0 1 2 2v3"/><path d="M8 7h8M8 11h6"/>${showComments?'':'<path d="M2 2l20 20"/>'}</svg>`;
 return b(svg,'comments','comment-icon '+(showComments?'active':''),`data-value="${showComments?'none':'all'}" aria-pressed="${showComments}" aria-label="${label}" title="${label}"`);
}
function source(f) {
 const s=viewerState(f), vi=s.view, v=f.codeViews[vi], side=v[s.side];
 const ranges=side.ranges || [];
 let body='';
 if(side.kind==='absent') body=`<div class="no-code"><strong>${side.reason==='deleted'?'This file was deleted':'This file is new'}</strong><p>Switch to ${side.reason==='deleted'?'Before':'After'} to inspect the source.</p></div>`;
 else {
  const content=R.sourceFiles.find(x=>x.path===side.path&&x.revision===side.revision)?.content || '';
  const syntax=highlightedLines(content,side.path);
  const lines=content.split('\n'); if(lines.at(-1)==='') lines.pop();
  const chosen=ranges;
  const show=lines.map((_,i)=>i);
  let previous=-1;
  body=show.map(i=>{
   const gap=previous>=0&&i>previous+1?'<div class="code-gap">···</div>':'';
   previous=i;
   const line=`<div class="code-line ${chosen.some(r=>i+1>=r.startLine&&i+1<=r.endLine)?'highlight':''}"><span class="line-number">${i+1}</span><code>${syntax[i]}</code></div>`;
   let annotations='';
   if(showComments) {
    if(i+1===ranges[0]?.endLine) annotations+=`<div class="inline-review-comment"><div class="inline-comment-heading"><span class="comment-mark">↳</span><strong>Review note</strong><span>${esc(v.label)}</span></div><p>${esc(v.explanation)}</p></div>`;
   }
   return gap+line+annotations;
  }).join('');
 }
 return `<section class="source-panel editor-panel" data-source="${f.id}">
 <div class="editor-toolbar"><div class="file-tabs">${f.codeViews.map((v,i)=>b(`<span>${i===0?'◎':'↳'}</span> ${esc(v.label)}`,'view',i===vi?'active':'',`data-index="${i}" data-id="${f.id}" title="${esc(v.label)}"`)).join('')}</div>
 <div class="source-controls">${commentToggle()}<div class="segmented">${['before','after'].map(x=>b(x==='before'?'Before':'After','side',s.side===x?'active':'',`data-value="${x}" data-id="${f.id}"`)).join('')}</div></div></div>
 <div class="code-body">${body}</div><div class="source-path source-status"><span>${esc(side.path || v.before.path || v.after.path)}</span><small>${s.side==='after'?'HEAD':'BASE'}</small></div></section>`;
}
function switcher() {
 return `<nav class="prototype-switcher" aria-label="Prototype design switcher"><div class="switcher-label"><strong>DESIGN LAB</strong><small>Throwaway · ${selected+1}/4 selected · ${state(F[selected])}</small></div>${b('←','prev-variant','switch-arrow','aria-label="Previous design"')}<div class="design-options">${variantIds.map(id=>b(`<span>${id}</span>${names[id]}`,'variant',variant===id?'active':'',`data-index="${id}" title="${descriptions[id]}"`)).join('')}</div>${b('→','next-variant','switch-arrow','aria-label="Next design"')}<div class="switcher-description">${descriptions[variant]}<small>Use ← → to switch</small></div></nav>`;
}
function render() {
 document.body.dataset.variant=variant;
 document.title=`${names[variant]} · Review design playground`;
 document.getElementById('app').innerHTML=({11:renderFeed,17:renderYellowFeed,15:renderGitHub,16:renderAIHero})[variant]()+switcher();
 if(isFlow()){updateFlowCode();scheduleFlowSync();}
}
function setVariant(n) {
 variant=variantIds.includes(n)?n:11;
 const url=new URL(location.href);url.searchParams.set('variant',variant);history.replaceState(null,'',url);
 render();window.scrollTo(0,0);
}
function cycleVariant(direction) { setVariant(variantIds[(variantIds.indexOf(variant)+direction+variantIds.length)%variantIds.length]); }
function choose(i) { selected=(i+F.length)%F.length;render(); }

document.addEventListener('click',e=>{
 const control=e.target.closest('[data-action]');if(!control)return;
 const a=control.dataset.action, index=Number(control.dataset.index), f=F.find(f=>f.id===control.dataset.id)||F[selected];
 if(a==='variant')return setVariant(index);
 if(a==='prev-variant')return cycleVariant(-1);
 if(a==='next-variant')return cycleVariant(1);
 if(isFlow()&&handleFlowClick(a,control,f))return;
 if(a==='select')return choose(index);
 if(a==='previous-finding')return choose(selected-1);
 if(a==='next-finding')return choose(selected+1);
 if(a==='view'){viewerState(f).view=index;viewerState(f).range='all';}
 if(a==='side'){viewerState(f).side=control.dataset.value;viewerState(f).range='all';}
 if(a==='full')viewerState(f).full=!viewerState(f).full;
 if(a==='comments')showComments=control.dataset.value==='all';
 if(a==='decision')decisions[f.id]=control.dataset.value;
 const y=window.scrollY, paneScrolls=[...document.querySelectorAll('.inbox-nav,.trace-explanation,.lab-details,.lab-sidebar,.code-body')].map(n=>[n.className,n.scrollTop]);
 render();window.scrollTo(0,y);for(const [c,y]of paneScrolls){const n=document.querySelector('.'+c.split(' ')[0]);if(n)n.scrollTop=y;}
});
document.addEventListener('input',e=>{if(e.target.dataset.comment)comments[e.target.dataset.comment]=e.target.value;});
document.addEventListener('change',e=>{if(e.target.dataset.range){const f=F.find(f=>f.id===e.target.dataset.range);viewerState(f).range=e.target.value;const y=scrollY;render();scrollTo(0,y);}});
document.addEventListener('keydown',e=>{
 if(e.target.closest('input,textarea,select,[contenteditable]'))return;
 if(e.key==='ArrowLeft'||e.key==='ArrowRight'){e.preventDefault();cycleVariant(e.key==='ArrowLeft'?-1:1);}
});
