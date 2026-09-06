// Injected into a temporary report only; never included in the delivered HTML.
(async () => {
 const output=document.createElement('pre');output.id='review-verification';
 const check=(condition,message)=>{if(!condition)throw new Error(message);};
 const card=id=>document.querySelector(`[data-finding="${CSS.escape(id)}"]`);
 const action=(id,value)=>card(id).querySelector(`[data-action="decision"][data-value="${value}"]`).click();
 const marker=reportKey+':verification';
 function sourceCheck(value,ranges) {
  const source=R.sourceFiles.find(f=>f.path===value.path&&f.revision===value.revision);
  if(value.kind!=='present'||!source){check(document.querySelector('.code-body .no-code'),'Missing absent/unavailable source state');return;}
  check(document.getElementById('code-title').textContent===value.path,'Wrong source path');
  check(document.getElementById('code-revision').title===value.revision,'Wrong source revision');
  const expected=[...new Set(ranges.flatMap(r=>Array.from({length:r.endLine-r.startLine+1},(_,i)=>r.startLine+i)))].sort((a,b)=>a-b);
  const actual=[...document.querySelectorAll('.code-line.highlight')].map(n=>Number(n.dataset.line));
  check(JSON.stringify(expected)===JSON.stringify(actual),'Incorrect highlighted ranges');
  const lines=source.content.split('\n');if(lines.at(-1)==='')lines.pop();
  const visible=[...document.querySelectorAll('.code-line')];
  check(visible.length===lines.length,'Full source file incomplete');
  visible.forEach((line,i)=>check(line.querySelector('code').textContent===lines[i],'Source text changed during rendering'));
 }
 try {
  check(document.getElementById('banner').textContent.includes('reviewers completed'),'Reviewer completion banner missing');
  check(document.querySelectorAll('#reviewers>.reviewer-outcome').length===R.reviewers.length,'Reviewer outcomes missing');
  for(const r of R.reviewers)if(!r.report)check(document.getElementById('banner').textContent.includes('No usable review'),'Missing explicit reviewer failure');
  check(!window.injected,'Embedded source executed as markup');
  check(!document.querySelector('.prototype-switcher'),'Prototype controls leaked into report');
  if(F.length&&!sessionStorage.getItem(marker)) {
   F.forEach((f,i)=>{
    const input=card(f.id).querySelector('textarea');input.value='Verification comment <>& '+i;input.dispatchEvent(new Event('input',{bubbles:true}));
    if(state(f)!=='open')action(f.id,'open');
    action(f.id,'done');
    check(card(f.id).closest('[data-archive="done"]'),'Done finding did not move');
   });
   sessionStorage.setItem(marker,'reload');location.reload();return;
  }
  let copied=null;
  Object.defineProperty(navigator,'clipboard',{configurable:true,value:{writeText:async text=>{copied=text;}}});
  for(const [i,f] of F.entries()) {
   check(card(f.id).querySelector('textarea').value==='Verification comment <>& '+i,'Decision note lost after reload');
   check(state(f)==='done','Decision lost after reload');
   action(f.id,'open');check(card(f.id).closest('.active-findings'),'Reopen failed');
   action(f.id,'rejected');
   check(card(f.id).closest('[data-archive="rejected"]'),'Discarded finding did not move');
   check(!card(f.id).closest('details').open,'Discarded group not collapsed');
   action(f.id,'open');jumpFlowFinding(f.id);
   check(card(f.id).classList.contains('is-current'),'Finding selection failed');
   check(card(f.id).querySelector('[data-assessment]').dataset.assessment===f.assessment.status,'Assessment missing');
   check(!card(f.id).querySelector('.repro').closest('details:not(.flow-archive)'),'Reproduction is collapsible');
   for(const view of f.codeViews) {
    document.querySelector(`[data-action="view"][data-view-id="${CSS.escape(view.id)}"]`).click();
    for(const sideName of ['before','after']) {
     document.querySelector(`[data-action="side"][data-value="${sideName}"]`).click();sourceCheck(view[sideName],view[sideName].ranges||[]);
    }
   }
   document.querySelector('[data-action="comments"]').click();
   check(!document.querySelector('.inline-review-comment'),'Comments toggle did not hide all review comments');
   document.querySelector('[data-action="comments"]').click();
   for(const e of f.evidence) {
    check(card(f.id).textContent.includes(e.label)&&card(f.id).textContent.includes(e.explanation),'Evidence missing');
    if(e.kind==='document'){const d=R.request.context.documents.find(d=>d.id===e.documentId);check(card(f.id).textContent.includes(d.content),'Document snapshot missing');}
    if(e.kind==='check')check(card(f.id).textContent.includes(e.output)&&card(f.id).textContent.includes(e.outcome),'Check outcome missing');
   }
   for(const control of card(f.id).querySelectorAll('[data-action="evidence-source"]'))control.click();
   copied=null;card(f.id).querySelector('[data-action="copy"]').click();await Promise.resolve();
   check(copied?.includes('Verification comment <>& '+i),'Copy missing decision note');
   check(copied.includes(f.assessment.reasoning)&&copied.includes('Likelihood:'),'Copy missing assessment or ratings');
   for(const view of f.codeViews) {
    check(copied.includes(view.label)&&copied.includes(view.explanation),'Copy missing code view');
    for(const side of [view.before,view.after])if(side.kind==='present') {
     check(copied.includes(side.path)&&copied.includes(side.revision),'Copy missing source identity');
     for(const range of side.ranges)check(copied.includes(range.excerpt),'Copy missing excerpt');
    }
   }
   for(const e of f.evidence)check(copied.includes(e.label),'Copy missing evidence');
  }
  for(const view of R.fileViews) {
   const select=document.getElementById('file-select');select.value=view.id;select.dispatchEvent(new Event('change',{bubbles:true}));
   for(const name of ['before','after']){document.querySelector(`[data-action="side"][data-value="${name}"]`).click();sourceCheck(view[name],[]);}
  }
  if(!F.length) {
   check(document.querySelector('.active-findings .empty'),'Empty findings state missing');
   check(document.getElementById('file-select').disabled===!R.fileViews.length,'Source browsing requires a finding');
   if(R.reviewStatus==='failed')check(document.querySelector('.active-findings').textContent.includes('No review conclusion'),'Failure presented as a clean review');
  }
  check(document.documentElement.scrollWidth<=innerWidth,'Horizontal page overflow');
  sessionStorage.removeItem(marker);localStorage.removeItem(reportKey);
  output.textContent=JSON.stringify({status:'passed',details:`Checked ${F.length} findings, all code views and revisions, full source text and highlighted ranges, ${R.fileViews.length} source-browser entries, evidence and assessments, saved decisions/notes through reload, collapsed archives, comments toggle, and complete copy content. OS clipboard transport was simulated.`});
 } catch(error) {output.textContent=JSON.stringify({status:'failed',details:String(error.message||error)});}
 document.body.append(output);
})();
