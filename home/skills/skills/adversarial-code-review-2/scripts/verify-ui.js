// Injected into a temporary copy only. Exercise every finding, view, and range.
(async () => {
  const output = document.createElement('pre');
  output.id = 'review-verification'; output.style.whiteSpace = 'pre-wrap';
  const check = (condition, message) => { if (!condition) throw new Error(message); };
  const card = id => document.querySelector('[data-finding-id="' + id + '"]');
  const marker = reportKey + ':verification';
  function selectValue(id, value) {
    document.getElementById(id).value = value;
    document.getElementById(id).dispatchEvent(new Event('change'));
  }
  function sourceCheck(value, ranges, showFull) {
    if (value.kind !== 'present') {
      check(document.querySelector('#code-block .absent'), 'Missing absent/unavailable source state');
      return;
    }
    check(document.getElementById('code-title').textContent === value.path, 'Source view switched to another file');
    check(document.getElementById('code-revision').textContent.includes(value.revision), 'Wrong source revision');
    const expected = [...new Set(ranges.flatMap(r => Array.from({length:r.endLine-r.startLine+1}, (_,i)=>r.startLine+i)))].sort((a,b)=>a-b);
    const actual = [...document.querySelectorAll('.line.target')].map(line => Number(line.dataset.line));
    check(JSON.stringify(actual) === JSON.stringify(expected), 'Incorrect highlighted ranges');
    const file = report.sourceFiles.find(f => f.revision === value.revision && f.path === value.path);
    const lines = file.content.split('\n'); if (lines.at(-1) === '') lines.pop();
    const visible = [...document.querySelectorAll('#code-block .line[data-line]')];
    if (showFull || !ranges.length) check(visible.length === lines.length, 'Full source file incomplete');
    else check(visible.length === expected.length, 'Excerpts include incorrect lines');
    for (const line of visible) {
      const copy = line.cloneNode(true); copy.querySelector('.number').remove();
      check(copy.textContent === lines[Number(line.dataset.line)-1], 'Source text changed during rendering');
    }
  }
  try {
    check(document.getElementById('banner').textContent.includes('reviewers completed'), 'Completion banner missing');
    check(document.querySelectorAll('#reviewers details').length === report.reviewers.length, 'Reviewer outcomes missing');
    check(!window.injected, 'Embedded source executed as markup');
    if (report.findings.length && !sessionStorage.getItem(marker)) {
      for (const [index, entry] of report.findings.entries()) {
        const id = entry.finding.id, comment = card(id).querySelector('textarea');
        comment.value = 'Verification comment <>& ' + index; comment.dispatchEvent(new Event('input'));
        card(id).querySelector('[data-action="done"]').click();
        check(document.getElementById('resolved-list').contains(card(id)), 'Done finding did not move');
      }
      sessionStorage.setItem(marker, 'reload'); location.reload(); return;
    }
    let copied = null;
    Object.defineProperty(navigator, 'clipboard', {configurable:true, value:{writeText:async text => {copied=text;}}});
    for (const [index, entry] of report.findings.entries()) {
      const finding = entry.finding, id = finding.id;
      check(card(id).querySelector('textarea').value === 'Verification comment <>& ' + index, 'Comment lost or leaked between findings after reload');
      check(document.getElementById('resolved-list').contains(card(id)), 'Status lost after reload');
      card(id).querySelector('[data-action="reopen"]').click();
      check(document.getElementById('open-list').contains(card(id)), 'Reopen failed');
      card(id).querySelector('[data-action="reject"]').click();
      check(document.getElementById('resolved-list').contains(card(id)), 'Reject failed');
      card(id).querySelector('[data-action="reopen"]').click();
      card(id).querySelector('[data-action="select"]').click();
      check(card(id).classList.contains('selected'), 'Finding selection failed');
      check(card(id).querySelector('[data-assessment]').dataset.assessment === finding.assessment.status, 'Assessment missing');
      for (const view of finding.codeViews) {
        document.querySelector('#code-views [data-view-id="'+view.id+'"]').click();
        for (const sideName of ['before','after']) {
          document.getElementById(sideName).click();
          const value = view[sideName];
          if (document.getElementById('full-file').getAttribute('aria-pressed') === 'true') document.getElementById('full-file').click();
          sourceCheck(value, value.ranges || [], false);
          if (value.kind !== 'present') continue;
          for (const [rangeIndex, range] of value.ranges.entries()) {
            selectValue('range-select', String(rangeIndex)); sourceCheck(value, [range], false);
          }
          selectValue('range-select', 'all'); document.getElementById('full-file').click();
          sourceCheck(value, value.ranges, true);
        }
        check(document.getElementById('view-explanation').textContent.includes(view.label), 'Revision switch lost selected code view');
      }
      for (const evidence of finding.evidence) {
        check(card(id).textContent.includes(evidence.label), 'Evidence label missing');
        if (evidence.kind === 'document') {
          const doc = report.request.context.documents.find(d=>d.id===evidence.documentId);
          check(card(id).textContent.includes(doc.content), 'Document snapshot missing');
        }
        if (evidence.kind === 'check') check(card(id).textContent.includes(evidence.output), 'Check output missing');
      }
      for (const control of card(id).querySelectorAll('[data-action="evidence-source"]')) control.click();
      copied = null; card(id).querySelector('[data-action="copy"]').click(); await Promise.resolve();
      check(copied && copied.includes('Verification comment <>& '+index), 'Copy missing current comment');
      check(copied.includes(finding.assessment.reasoning) && copied.includes('Likelihood:'), 'Copy missing assessment or ratings');
      for (const view of finding.codeViews) {
        check(copied.includes(view.label) && copied.includes(view.explanation), 'Copy missing a code view');
        for (const value of [view.before, view.after]) if (value.kind === 'present') {
          check(copied.includes(value.path) && copied.includes(value.revision), 'Copy missing source identity');
          for (const range of value.ranges) check(copied.includes(range.excerpt), 'Copy missing a source excerpt');
        }
      }
      for (const evidence of finding.evidence) check(copied.includes(evidence.label), 'Copy missing evidence');
    }
    for (const view of report.fileViews) {
      selectValue('file-select', view.id);
      for (const sideName of ['before','after']) {
        document.getElementById(sideName).click(); sourceCheck(view[sideName], [], true);
      }
    }
    if (!report.findings.length) {
      check(document.querySelector('#open-list .empty'), 'Empty findings state missing');
      check(document.getElementById('file-select').disabled === !report.fileViews.length, 'Source browsing requires a finding');
      if (report.reviewStatus === 'failed') check(document.getElementById('open-list').textContent.includes('No review conclusion'), 'Failure presented as a clean review');
    }
    check(document.documentElement.scrollWidth <= window.innerWidth, 'Horizontal page overflow');
    sessionStorage.removeItem(marker); localStorage.removeItem(reportKey);
    output.textContent = JSON.stringify({status:'passed', details:`Checked ${report.findings.length} findings, every code view and range, ${report.fileViews.length} source-browser entries, assessments and evidence, decisions/comments after reload, and full copy content. OS clipboard transport was simulated.`});
  } catch (error) {
    output.textContent = JSON.stringify({status:'failed', details:String(error.message || error)});
  }
  document.body.append(output);
})();
