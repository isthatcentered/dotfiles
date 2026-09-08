'use strict';
const R = JSON.parse(document.getElementById('report-data').textContent);
const relevanceRank = {low:1, medium:2, high:3};
const relevance = f => (relevanceRank[f.severity.value] || 0) * (relevanceRank[f.likelihood.value] || 0);
R.findings.sort((a,b)=>relevance(b.finding)-relevance(a.finding) || relevanceRank[b.finding.severity.value]-relevanceRank[a.finding.severity.value]);
const F = R.findings.map(e=>e.finding);
const reportKey = 'adversarial-review-2:' + R.runId;
const decisions = Object.create(null), comments = Object.create(null), viewers = Object.create(null);
let selected = 0, showComments = true, fileId = null, fileSide = 'after';
const esc = v => String(v ?? '').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const b = (text,action,cls='',attrs='') => `<button type="button" class="${cls}" data-action="${action}" ${attrs}>${text}</button>`;
const state = f => f ? decisions[f.id] || 'open' : 'open';
const numbers = n => String(n+1).padStart(2,'0');
const shortTitles = F.map(f=>f.title);
const labels = {'codex-astra':'Codex Astra','codex-sol':'Codex Sol','claude-opus':'Claude Opus'};
const list = items => `<ul>${items.map(x=>`<li>${esc(x)}</li>`).join('')}</ul>`;
function notice(text) { document.getElementById('feedback').textContent=text; }
try {
 const saved=JSON.parse(localStorage.getItem(reportKey)||'{}');
 for(const f of F) {
  const value=saved?.[f.id];
  if(['open','done','rejected'].includes(value?.status))decisions[f.id]=value.status;
  if(typeof value?.comment==='string')comments[f.id]=value.comment;
 }
} catch { notice('Browser storage is unavailable; decisions and notes will last only while this page is open.'); }
function persist() {
 const saved=Object.fromEntries(F.map(f=>[f.id,{status:state(f),comment:comments[f.id]||''}]));
 try { localStorage.setItem(reportKey,JSON.stringify(saved)); }
 catch { notice('Could not save in this browser. Copy your finding and note before closing.'); }
}
function badge(text,cls='') { return `<span class="badge ${esc(cls)}">${esc(text)}</span>`; }
function agentLogo(id) {
 const provider=id.includes('claude')?'claude':'openai';
 return `<img class="agent-logo ${provider}" src="${agentIcons[provider]}" alt="${provider==='claude'?'Claude':'ChatGPT'}">`;
}
function reviewerBadges(f) {
 const ids=[...new Set(R.findings[F.indexOf(f)].sources.map(s=>s.reviewer))];
 return `<span class="reviewer-attribution"><span class="reviewer-avatars">${ids.map(id=>`<span class="reviewer-avatar" title="${esc(labels[id]||id)}" aria-label="${esc(labels[id]||id)}">${agentLogo(id)}</span>`).join('')}</span><span>${ids.length} reviewer${ids.length===1?'':'s'}</span></span>`;
}
function tags(f) {
 return `<div class="tags">${badge(f.severity.value+' impact',f.severity.value)}${badge(f.likelihood.value+' likelihood','likelihood')}${badge(f.assessment.status==='needs-verification'?'Needs verification':'Source supported',f.assessment.status==='needs-verification'?'uncertain':'supported')}${state(f)!=='open'?badge(state(f)==='rejected'?'discarded':state(f),'decided'):''}${reviewerBadges(f)}</div>`;
}
function appIdentity() { return `<div class="review-identity"><img class="review-logo" src="${appLogo}" alt=""><span>Review</span></div>`; }
function note(f) { return `<label class="note-label">Your decision note <span>Saved in this browser</span><textarea data-comment="${esc(f.id)}" placeholder="What should we change, check, or accept?">${esc(comments[f.id]||'')}</textarea></label>`; }
function reproduction(f) {
 const r=f.reproduction;
 return `<div class="repro"><h3>How to reproduce</h3>${r.prerequisites.length?`<p><strong>Prerequisites</strong></p>${list(r.prerequisites)}`:''}<ol>${r.steps.map(s=>`<li>${esc(s)}</li>`).join('')}</ol><div class="expected"><span>Expected</span>${esc(r.expected)}</div><div class="actual"><span>${r.basis==='observed'?'Observed outcome':'Predicted outcome'}</span>${esc(r.actual)}</div><small>${r.basis==='observed'?'Reported as observed; see the recorded checks and evidence.':'Source-based prediction; this reproduction is not recorded as observed.'}</small></div>`;
}
function documentPanel(d) {
 return d?`<details class="context-document"><summary>${esc(d.title)}</summary><p>${esc(d.path)}</p><pre>${esc(d.content)}</pre><small>Snapshot SHA256: ${esc(d.sha256)}</small></details>`:'<p>Document snapshot unavailable.</p>';
}
function externalLink(url) {
 try { const u=new URL(url);if(['http:','https:'].includes(u.protocol)&&!u.username&&!u.password)return `<a href="${esc(u.href)}" target="_blank" rel="noopener noreferrer">${esc(url)}</a>`; } catch {}
 return `<span>${esc(url)}</span>`;
}
function evidence(f) {
 return `<div class="evidence">${f.evidence.map(e=>{
  let detail='';
  if(e.kind==='source')detail=b('View source','evidence-source','secondary',`data-id="${esc(f.id)}" data-view-id="${esc(e.codeViewId)}"`);
  if(e.kind==='document')detail=documentPanel(R.request.context.documents.find(d=>d.id===e.documentId));
  if(e.kind==='external')detail=externalLink(e.url)+(e.quote?`<blockquote>${esc(e.quote)}</blockquote>`:'');
  if(e.kind==='check')detail=`<p>Check: ${esc(e.outcome)}</p><pre>${esc(e.command)}</pre><pre>${esc(e.output)}</pre>`;
  return `<details data-evidence-kind="${esc(e.kind)}"><summary>${esc(e.label)}</summary><p>${esc(e.explanation)}</p>${detail}</details>`;
 }).join('')}${R.findings[F.indexOf(f)].disagreements.map(d=>`<details><summary>Reviewer disagreement · ${esc(labels[d.reviewer]||d.reviewer)}</summary><p>${esc(d.explanation)}</p></details>`).join('')}<section class="confidence-limits" data-assessment="${esc(f.assessment.status)}"><h3>Confidence & limits</h3><p>${esc(f.assessment.reasoning)}</p>${list(f.limits)}<p><strong>Severity:</strong> ${esc(f.severity.reasoning)}</p><p><strong>Likelihood:</strong> ${esc(f.likelihood.reasoning)}</p></section></div>`;
}
function uncertainty(f) {
 const a=f.assessment;
 if(a.status!=='needs-verification'&&!a.assumptions.length&&!a.verificationSteps.length)return '';
 return `<div class="uncertainty"><strong>${a.status==='needs-verification'?'Verify before treating this as a regression':'Assumptions & verification'}</strong>${list(a.assumptions)}${list(a.verificationSteps)}</div>`;
}
function origin(f) { const l=f.problematicLocation.location;return b(`${f.problematicLocation.kind==='deletion'?'Deleted · ':''}${esc(l.path)} <b>L${l.startLine}–${l.endLine}</b>`,'origin','origin',`data-id="${esc(f.id)}" title="${esc(l.revision)}"`); }
function originIndex(f) {
 const l=f.problematicLocation.location;
 const index=f.codeViews.findIndex(v=>[v.before,v.after].some(s=>s.kind==='present'&&s.path===l.path&&s.revision===l.revision&&(s.ranges||[]).some(r=>r.startLine<=l.startLine&&r.endLine>=l.endLine)));
 return Math.max(0,index);
}
function viewerState(f) { return viewers[f.id] ||= {view:originIndex(f),side:f.problematicLocation.kind==='deletion'?'before':'after'}; }
function locationText(value) { return `${value.path} @ ${value.revision} · lines ${value.startLine}–${value.endLine}`; }
function sideText(value) {
  if (value.kind === 'absent') return value.reason === 'added' ? 'New code — no before location or excerpt' : 'Deleted — no after location or excerpt';
  if (value.kind === 'unavailable') return 'Source unavailable: ' + value.reason;
  return value.path + ' @ ' + value.revision + '\n' + value.ranges.map(range =>
    `${range.label} · lines ${range.startLine}–${range.endLine}\n${range.excerpt}`).join('\n\n');
}
function contextDocument(id) { return R.request.context.documents.find(d => d.id === id); }
function evidenceText(evidence) {
  const lines = [evidence.label, evidence.explanation];
  if (evidence.kind === 'source') lines.push('Code view: ' + evidence.codeViewId);
  if (evidence.kind === 'external') lines.push(evidence.url, evidence.quote);
  if (evidence.kind === 'check') lines.push(evidence.command, evidence.outcome, evidence.output);
  if (evidence.kind === 'document') {
    const doc = contextDocument(evidence.documentId);
    if (doc) lines.push(doc.title, doc.path, 'Snapshot SHA256: ' + doc.sha256, doc.content);
  }
  return lines.join('\n');
}
function findingText(entry) {
  const f = entry.finding, r = f.reproduction, a = f.assessment;
  return [f.title, `Severity: ${f.severity.value} — ${f.severity.reasoning}`,
    `Likelihood: ${f.likelihood.value} — ${f.likelihood.reasoning}`,
    'Assessment: ' + a.status + ' — ' + a.reasoning,
    'Assumptions\n' + a.assumptions.join('\n'), 'Verification needed\n' + a.verificationSteps.join('\n'),
    'Problematic location' + (f.problematicLocation.kind === 'deletion' ? ' (deletion)' : '') + ': ' + locationText(f.problematicLocation.location),
    'What goes wrong\n' + f.whatGoesWrong,
    ...f.codeViews.map(view => `${view.label}\n${view.explanation}\nBefore\n${sideText(view.before)}\nAfter\n${sideText(view.after)}`),
    'Why it happens\n' + f.whyItHappens, 'Prerequisites\n' + (r.prerequisites.join('\n') || 'None'),
    'How to reproduce\n' + r.steps.map((step, i) => `${i + 1}. ${step}`).join('\n'), 'Expected: ' + r.expected,
    (r.basis === 'observed' ? 'Actual: ' : 'Predicted actual: ') + r.actual,
    'Evidence\n' + f.evidence.map(evidenceText).join('\n\n'), 'Limits\n' + f.limits.join('\n'),
    'Reported by ' + new Set(entry.sources.map(s => s.reviewer)).size + ' distinct reviewers: ' + entry.sources.map(s => s.reviewer + ' / ' + s.findingId).join(', '),
    'Disagreements\n' + entry.disagreements.map(d => d.reviewer + ': ' + d.explanation).join('\n'),
    'Comment: ' + (comments[f.id] || '')].join('\n\n');
}
async function copyFinding(entry) {
  const text = findingText(entry);
  try { await navigator.clipboard.writeText(text); notice('Complete finding copied.'); }
  catch {
    const area = document.createElement('textarea'); area.value = text; document.body.append(area); area.select();
    let copied = false; try { copied = document.execCommand('copy'); } catch {}
    area.remove(); notice(copied ? 'Complete finding copied.' : 'Copy unavailable. Select the finding text and copy manually.');
  }
}
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
 const s=fileId?{side:fileSide}:viewerState(f);
 const views=fileId?[R.fileViews.find(v=>v.id===fileId)]:f.codeViews;
 const vi=fileId?0:s.view,v=views[vi],side=v[s.side],ranges=side.ranges||[];
 const captured=side.kind==='present'?R.sourceFiles.find(x=>x.path===side.path&&x.revision===side.revision):null;
 let body='';
 if(side.kind==='absent')body=`<div class="no-code"><strong>${side.reason==='deleted'?'This file was deleted':'This file is new'}</strong><p>Switch to ${side.reason==='deleted'?'Before':'After'} to inspect the source.</p></div>`;
 else if(side.kind==='unavailable'||!captured)body=`<div class="no-code"><strong>Source unavailable</strong><p>${esc(side.reason||'This revision was not captured in the report.')}</p></div>`;
 else {
  const content=captured.content,syntax=highlightedLines(content,side.path),lines=content.split('\n');
  if(lines.at(-1)==='')lines.pop();
  const annotation=showComments&&v.explanation?`<div class="inline-review-comment"><div class="inline-comment-heading"><span class="comment-mark">↳</span><strong>Review note</strong><span>${esc(v.label)}</span></div><p>${esc(v.explanation)}</p></div>`:'';
  body=lines.map((line,i)=>`<div class="code-line ${ranges.some(r=>i+1>=r.startLine&&i+1<=r.endLine)?'highlight':''}" data-line="${i+1}"><span class="line-number" aria-hidden="true">${i+1}</span><code>${syntax[i]}</code></div>${i+1===ranges[0]?.endLine?annotation:''}`).join('');
  if(!ranges.length)body+=annotation;
 }
 const attrs=f?`data-id="${esc(f.id)}"`:'';
 return `<section class="source-panel editor-panel" data-source="${esc(fileId||f?.id)}"><div class="editor-toolbar"><div class="file-tabs" aria-label="Source files">${views.map((view,i)=>fileId?`<span class="browser-file-label">${esc(view.label)}</span>`:b(`<span>${i===originIndex(f)?'◎':'↳'}</span> ${esc(view.label)}`,'view',i===vi?'active':'',`data-index="${i}" ${attrs} data-view-id="${esc(view.id)}" aria-pressed="${i===vi}" title="${esc(view.label)}"`)).join('')}</div><div class="source-controls">${commentToggle()}<div class="segmented" aria-label="Source revision">${['before','after'].map(x=>b(x==='before'?'Before':'After','side',s.side===x?'active':'',`data-value="${x}" ${attrs} aria-pressed="${s.side===x}"`)).join('')}</div></div></div><div class="code-body" tabindex="0" aria-label="Captured source code">${body}</div><div class="source-path source-status"><span id="code-title">${esc(side.path||v.before.path||v.after.path||'No file')}</span><small id="code-revision" title="${esc(side.revision)}">${s.side==='after'?'HEAD':'BASE'}${side.revision?' · '+esc(side.revision.slice(0,9)):''}</small></div></section>`;
}
function render() {
 document.title='Code review · '+R.request.scope.headSha.slice(0,9);
 document.getElementById('app').innerHTML=renderFeed();
 updateFlowCode();scheduleFlowSync();
}
document.addEventListener('click',e=>{
 const control=e.target.closest('[data-action]');if(!control)return;
 const f=F.find(f=>f.id===control.dataset.id)||F[selected];
 handleFlowClick(control.dataset.action,control,f);
});
document.addEventListener('input',e=>{if(e.target.dataset.comment){comments[e.target.dataset.comment]=e.target.value;persist();}});
document.addEventListener('change',e=>{if(e.target.id==='file-select'){fileId=e.target.value||null;updateFlowCode();}});

let flowUndo = null, flowScrollFrame = 0;
const archiveOpen = {done:false,rejected:false};
const openFindings = () => F.filter(f=>state(f)==='open');
const flowNumber = f => numbers(F.indexOf(f));
function flowActions(f) {
 return `<div class="decision-actions">${state(f)==='open'?b('✓ Mark done','decision','primary',`data-id="${esc(f.id)}" data-value="done"`)+b('Discard','decision','secondary',`data-id="${esc(f.id)}" data-value="rejected"`):b('↶ Reopen finding','decision','secondary',`data-id="${esc(f.id)}" data-value="open"`)}${b('Copy finding','copy','secondary',`data-id="${esc(f.id)}"`)}</div>`;
}
function flowCounts() {
 return `<div class="flow-counts"><span><strong>${openFindings().length}</strong> open</span><span><strong>${F.filter(f=>state(f)==='done').length}</strong> done</span><span><strong>${F.filter(f=>state(f)==='rejected').length}</strong> discarded</span></div>`;
}
function flowScope() {
 const s=R.request.scope;
 return `<div class="flow-scope"><span>${esc(s.requested)} · ${s.changedPaths.length} changed files</span><code title="${esc(s.baseSha+' → '+s.headSha)}">${esc(s.baseSha.slice(0,12))} → ${esc(s.headSha.slice(0,12))}</code></div>`;
}
function flowCoverage() {
 const completed=R.reviewers.filter(r=>r.status==='completed').length;
 const label=R.reviewStatus==='complete'?'Review complete':R.reviewStatus==='partial'?'Partial review':'Review failed';
 return `<div class="flow-coverage" id="banner" data-status="${esc(R.reviewStatus)}"><span><strong>${label}</strong> · ${completed} of ${R.reviewers.length} reviewers completed.</span>${R.reviewers.filter(r=>r.status!=='completed').map(r=>`<span>${agentLogo(r.reviewer)} <strong>${esc(labels[r.reviewer]||r.reviewer)}: ${esc(r.status)}.</strong> ${r.report?'Only a partial report was supplied.':'No usable review was supplied; this reviewer contributed no findings.'} ${esc(r.failure?.message||'')}</span>`).join('')}${R.reviewStatus==='failed'?'<span>No review conclusion is available.</span>':''}${R.consolidationStatus!=='completed'?`<span>Consolidation: ${esc(R.consolidationStatus)}. ${R.findings.length?'Findings below are unconsolidated.':''}</span>`:''}${R.warnings.map(w=>`<small>${esc(w)}</small>`).join('')}</div>`;
}
function flowContext() {
 const c=R.request.context,s=R.request.scope;
 return `<details class="flow-context"><summary>Review scope & limits <span>+</span></summary><p><strong>Run:</strong> ${esc(R.runId)}</p><p>Pinned commits only; local changes are excluded.${s.hadLocalChanges?' Local changes were present at review time.':''}</p>${c.intent?`<h3>Intent</h3><p>${esc(c.intent)}</p>`:''}${c.acceptedExceptions.length?`<h3>Accepted exceptions</h3>${list(c.acceptedExceptions)}`:''}${c.documents.map(documentPanel).join('')}${R.limits.length?`<h3>Limits</h3>${list(R.limits)}`:''}<h3>Reviewer outcomes</h3><div id="reviewers">${R.reviewers.map(r=>`<details class="reviewer-outcome"><summary><span class="reviewer-name">${agentLogo(r.reviewer)} ${esc(labels[r.reviewer]||r.reviewer)}</span><span>${esc(r.status)} · ${esc(r.requestedModel)} / ${esc(r.effort)}</span></summary>${r.failure?`<p>${esc(r.failure.message)}</p>`:''}${r.report?`<p>${r.report.findings.length} raw findings</p>${list(r.report.coverage.inspected)}${r.report.coverage.checks.map(c=>`<p>${esc(c.outcome)}: ${esc(c.description)} — ${esc(c.details)}</p>`).join('')}${list(r.report.coverage.limits)}`:''}${(r.attempts||[]).map(a=>`<details><summary>Attempt ${a.number} · ${esc(a.failure?.kind||'completed')}</summary><p>${esc(a.startedAt)} → ${esc(a.finishedAt)}</p>${a.failure?`<pre>${esc(a.failure.message)}</pre>`:''}${a.environment?`<pre>${esc(JSON.stringify(a.environment,null,2))}</pre>`:''}<p>Events: ${esc(a.eventsPath||'not started')}</p><p>Stderr: ${esc(a.stderrPath||'not started')}</p></details>`).join('')}</details>`).join('')}</div>${R.excluded.length?`<h3>Excluded by consolidation</h3>${R.excluded.map(x=>`<p>${esc(x.source.reviewer)} / ${esc(x.source.findingId)}: ${esc(x.reason)}</p>`).join('')}`:''}<p>Browser verification: ${R.verification?esc(R.verification.status)+'. '+esc(R.verification.details):'pending'}</p></details>`;
}
function changeList() { return R.whatChanged.length?`<ul class="change-list">${R.whatChanged.map((x,i)=>`<li><span class="change-number">${numbers(i)}</span><span>${esc(x)}</span></li>`).join('')}</ul>`:'<p class="empty">No change summary was supplied by the available reviews.</p>'; }
function feedOverview() {
 return `<header class="flow-overview" id="review-overview"><div class="flow-topline"><div class="feed-identity">${appIdentity()}<span class="eyebrow">${esc(R.request.scope.requested)}</span></div><span class="run-id">${esc(R.runId)}</span></div><h1>What changed</h1><p class="overview-deck">The behavior behind this change, before the findings.</p>${flowScope()}${changeList()}${flowCoverage()}${flowContext()}<div class="overview-tail">${flowCounts()}${openFindings().length?b('Start reading ↓','flow-start','primary'):''}</div></header>`;
}
function flowFindingHeader(f) {
 return `<header class="flow-finding-header"><div class="finding-chapter"><span>Finding ${flowNumber(f)}</span><span>${f.codeViews.length} source files</span></div><h2 data-track-title="${esc(f.id)}">${esc(f.title)}</h2>${tags(f)}</header>`;
}
function flowDecision(f) { return `<footer class="flow-decision">${note(f)}${flowActions(f)}</footer>`; }
function feedFinding(f) {
 return `<article class="flow-finding" data-finding="${esc(f.id)}">${flowFindingHeader(f)}<section class="finding-consequence"><h3>What goes wrong</h3><p>${esc(f.whatGoesWrong)}</p></section><section class="finding-mechanism"><h3>Why it happens</h3><p>${esc(f.whyItHappens)}</p>${origin(f)}</section>${uncertainty(f)}${reproduction(f)}${evidence(f)}${flowDecision(f)}</article>`;
}
function currentFindingRenderer() { return feedFinding; }
function flowArchives() {
 return `<section class="flow-archives" id="review-archives"><div class="eyebrow">Reviewed findings</div>${[['done','Done','✓'],['rejected','Discarded','−']].map(([value,label,mark])=>{const items=F.filter(f=>state(f)===value);return `<details class="flow-archive" data-archive="${value}" ${archiveOpen[value]?'open':''}><summary><span class="archive-mark">${mark}</span><strong>${label}</strong><span class="archive-count">${items.length}</span><span class="archive-chevron">⌄</span></summary><div class="archive-content">${items.length?items.map(currentFindingRenderer()).join(''):`<p class="archive-empty">No ${label.toLowerCase()} findings.</p>`}</div></details>`;}).join('')}<p class="flow-endnote">End of review · decisions and notes are saved in this browser.</p></section>`;
}
function flowFindingsHeading() {
 const count=openFindings().length;
 return `<div class="findings-start"><h2>${F.length?'Findings':'Review outcome'}</h2><span>${count?count+' open · sorted by relevance':F.length?'Everything has been triaged':'No findings available'}${R.consolidationStatus!=='completed'&&F.length?' · unconsolidated':''}</span></div>`;
}
function flowFindings(showHeading=true) {
 return `${showHeading?flowFindingsHeading():''}<div class="active-findings">${openFindings().map(feedFinding).join('')||`<p class="empty">${F.length?'All findings have been triaged.':R.reviewStatus==='failed'?'No review conclusion is available.':R.consolidationStatus==='failed'?'No findings in the available reports. Consolidation failed.':R.reviewStatus==='partial'?'No findings identified in the available reviews; coverage is incomplete.':'No findings identified in the completed reviews.'}</p>`}</div>${F.length?flowArchives():''}`;
}
function flowCode() {
 const f=F[selected],visible=f&&(state(f)==='open'||archiveOpen[state(f)]);
 if(!F.length&&!fileId)fileId=R.fileViews[0]?.id||null;
 const heading=`<div class="flow-code-heading">${f&&!fileId?`<span class="flow-code-index">${flowNumber(f)}</span><div><small>${state(f)==='open'?'Following this finding':state(f)==='done'?'Done finding':'Discarded finding'}</small><strong>${esc(f.title)}</strong></div><span class="follow-indicator"><i></i> Auto-follow</span>`:'<strong>Captured source files</strong>'}<label class="file-browser"><span class="sr-only">Browse reviewed or changed files</span><select id="file-select" aria-label="Browse reviewed or changed files" ${R.fileViews.length?'':'disabled'}><option value="">${f?'Finding source':'Choose a file'}</option>${R.fileViews.map(v=>`<option value="${esc(v.id)}" ${fileId===v.id?'selected':''}>${esc(v.label)}</option>`).join('')}</select></label></div>`;
 if(fileId||visible)return heading+source(f);
 return heading+`<div class="flow-code-empty"><h2>${F.length?'No open findings':'No source files available'}</h2><p>${F.length?'Expand Done or Discarded to revisit a finding, or browse a captured file.':'The report contains no captured source to browse.'}</p></div>`;
}
function flowToast() {return flowUndo?`<div class="flow-toast" role="status"><span>Finding ${flowNumber(F.find(f=>f.id===flowUndo.id))} ${flowUndo.value==='done'?'marked done':flowUndo.value==='rejected'?'discarded':'reopened'}</span>${b('Undo','flow-undo')}</div>`:'';}

function renderFeed() {return `<div class="flow feed">${feedOverview()}${flowFindingsHeading()}<div class="flow-layout"><main class="flow-reading">${flowFindings(false)}</main><aside class="flow-code" aria-label="Source code follows the current finding">${flowCode()}</aside></div>${flowToast()}</div>`;}
function updateFlowCode(keepScroll=false) {
 const pane=document.querySelector('.flow-code');if(!pane)return;
 const oldScroll=pane.querySelector('.code-body')?.scrollTop||0;
 pane.innerHTML=flowCode();
 const code=pane.querySelector('.code-body');
 if(code&&keepScroll)code.scrollTop=oldScroll;
 else if(code){const target=code.querySelector('.highlight');if(target)code.scrollTop+=target.getBoundingClientRect().top-code.getBoundingClientRect().top-40;}
 document.querySelectorAll('.flow-finding').forEach(n=>n.classList.toggle('is-current',n.dataset.finding===F[selected]?.id));
}
function syncFlowToScroll() {

 const titles=[...document.querySelectorAll('[data-track-title]')].filter(n=>!n.closest('details:not([open])')&&n.getClientRects().length);
 if(!titles.length){updateFlowCode();return;}
 const midpoint=innerHeight/2;
 const passed=titles.filter(n=>{const r=n.getBoundingClientRect();return r.top+r.height/2<=midpoint+1;});
 const active=passed.at(-1)||titles[0];
 const index=F.findIndex(f=>f.id===active.dataset.trackTitle);
 if(index!==selected){selected=index;fileId=null;updateFlowCode();}
}
function scheduleFlowSync(){if(flowScrollFrame)return;flowScrollFrame=requestAnimationFrame(()=>{flowScrollFrame=0;syncFlowToScroll();});}
function jumpFlowFinding(id) {
 const f=F.find(f=>f.id===id);if(!f)return;
 if(state(f)!=='open') {archiveOpen[state(f)]=true;const group=document.querySelector(`[data-archive="${state(f)}"]`);if(group)group.open=true;}
 const title=document.querySelector(`[data-track-title="${CSS.escape(id)}"]`);if(!title)return;
 selected=F.indexOf(f);fileId=null;updateFlowCode();
 const r=title.getBoundingClientRect();window.scrollTo({top:Math.max(0,scrollY+r.top+r.height/2-innerHeight/2+2),behavior:'instant'});
}
function handleFlowDecision(f,value) {
 const was=state(f), before=openFindings(), next=before[before.indexOf(f)+1]||before[before.indexOf(f)-1];
 decisions[f.id]=value;persist();fileId=null;flowUndo={id:f.id,was,value};
 if(value!=='open')archiveOpen[value]=false;
 const target=value==='open'?f:(next&&state(next)==='open'?next:openFindings()[0]);
 if(target)selected=F.indexOf(target);
 render();
 if(target)jumpFlowFinding(target.id);else document.getElementById('review-archives').scrollIntoView({block:'start'});
}
function handleFlowClick(a,control,f) {
 if(a==='flow-start'){if(openFindings()[0])jumpFlowFinding(openFindings()[0].id);return;}
 if(a==='flow-undo') {if(flowUndo){const prev=flowUndo;decisions[prev.id]=prev.was;persist();flowUndo=null;selected=F.findIndex(f=>f.id===prev.id);fileId=null;render();jumpFlowFinding(prev.id);}return;}
 if(a==='comments'){showComments=control.dataset.value==='all';updateFlowCode(true);return;}
 if(a==='side'){if(fileId)fileSide=control.dataset.value;else if(f)viewerState(f).side=control.dataset.value;updateFlowCode();return;}
 if(!f)return;
 if(a==='decision'){handleFlowDecision(f,control.dataset.value);return;}
 if(a==='copy'){copyFinding(R.findings[F.indexOf(f)]);return;}
 if(a==='origin'||a==='evidence-source'){
  const s=viewerState(f);s.view=a==='origin'?originIndex(f):Math.max(0,f.codeViews.findIndex(v=>v.id===control.dataset.viewId));
  if(a==='origin')s.side=f.problematicLocation.kind==='deletion'?'before':'after';
  jumpFlowFinding(f.id);return;
 }
 if(a==='view'){viewerState(f).view=Number(control.dataset.index);fileId=null;updateFlowCode();}
}
window.addEventListener('scroll',scheduleFlowSync,{passive:true});
window.addEventListener('resize',scheduleFlowSync);
document.addEventListener('toggle',e=>{if(e.target.isConnected&&e.target.matches('.flow-archive')){archiveOpen[e.target.dataset.archive]=e.target.open;scheduleFlowSync();}},true);


render();
