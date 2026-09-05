// Injected only into a temporary verification copy, never the delivered report.
(async () => {
  const output = document.createElement('pre');
  output.id = 'review-verification';
  function check(condition, message) { if (!condition) throw new Error(message); }
  try {
    check(document.getElementById('banner').textContent.includes('reviewers completed'), 'Completion banner missing');
    check(document.querySelectorAll('#reviewers details').length === report.reviewers.length, 'Reviewer outcomes missing');
    check(document.documentElement.scrollWidth <= window.innerWidth, 'Horizontal page overflow');
    if (report.findings.length) {
      const entry = report.findings[0], id = entry.finding.id;
      const card = () => document.querySelector('[data-finding-id="' + id + '"]');
      const marker = reportKey + ':verification';
      if (!sessionStorage.getItem(marker)) {
        card().querySelector('textarea').value = 'Verification comment <>&';
        card().querySelector('textarea').dispatchEvent(new Event('input'));
        card().querySelector('[data-action="done"]').click();
        check(document.getElementById('resolved-list').contains(card()), 'Done finding did not move');
        sessionStorage.setItem(marker, 'reload');
        location.reload();
        return;
      }
      check(card().querySelector('textarea').value === 'Verification comment <>&', 'Comment lost after reload');
      check(document.getElementById('resolved-list').contains(card()), 'Status lost after reload');
      card().querySelector('[data-action="reopen"]').click();
      check(document.getElementById('open-list').contains(card()), 'Reopen did not restore finding');
      card().querySelector('[data-action="reject"]').click();
      check(document.getElementById('resolved-list').contains(card()), 'Reject did not move finding');
      card().querySelector('[data-action="reopen"]').click();
      card().querySelector('[data-action="select"]').click();
      for (const name of ['before', 'after']) {
        document.getElementById(name).click();
        const value = entry.finding[name];
        if (value.kind === 'absent') {
          check(document.getElementById('code-block').textContent.includes('no ' + name), 'Absent source side mislabeled');
        } else {
          check(document.getElementById('code-revision').textContent.includes(value.location.revision), 'Wrong source revision');
          check(document.querySelectorAll('.line.target').length === value.location.endLine - value.location.startLine + 1, 'Wrong highlighted range');
          document.getElementById('full-file').click();
          const source = report.sourceFiles.find(f => f.revision === value.location.revision && f.path === value.location.path);
          const expected = source.content.split('\n').length - (source.content.endsWith('\n') ? 1 : 0);
          check(document.querySelectorAll('.line').length === expected, 'Full source file missing');
          document.getElementById('full-file').click();
        }
      }
      let copied = null;
      Object.defineProperty(navigator, 'clipboard', {configurable: true, value: {writeText: async text => {copied = text;}}});
      card().querySelector('[data-action="copy"]').click();
      await Promise.resolve();
      check(copied === findingText(entry), 'Copy action does not export complete finding');
      check(copied.includes('Verification comment <>&') && copied.includes('Likelihood:') && copied.includes('Before') && copied.includes('Predicted actual:') === (entry.finding.reproduction.basis === 'predicted'), 'Copy omits required fields');
      sessionStorage.removeItem(marker);
      localStorage.removeItem(reportKey);
    } else {
      check(document.querySelector('#open-list .empty'), 'Empty findings state missing');
      check(document.getElementById('before').disabled, 'Source controls enabled without findings');
      if (report.reviewStatus === 'failed') check(document.getElementById('open-list').textContent.includes('No review conclusion'), 'Failure presented as clean review');
    }
    output.textContent = JSON.stringify({status:'passed', details:report.findings.length ? 'Selection, source revisions and ranges, full files, status transitions, comments after reload, and copy content passed. OS clipboard integration was simulated.' : 'Reviewer status, empty findings, and disabled source controls passed; no finding interactions applied.'});
  } catch (error) {
    output.textContent = JSON.stringify({status:'failed', details:String(error.message || error)});
  }
  document.body.append(output);
})();
