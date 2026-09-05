'use strict';
const report = JSON.parse(document.getElementById('report-data').textContent);
const reportKey = 'adversarial-review-2:' + report.runId;
const $ = id => document.getElementById(id);
function el(tag, text, className) {
  const node = document.createElement(tag);
  if (text !== undefined) node.textContent = text;
  if (className) node.className = className;
  return node;
}
function list(parent, items) { for (const item of items) parent.append(el('li', item)); }
function notice(text) { $('feedback').textContent = text; }
function button(text, action, name) {
  const node = el('button', text); node.type = 'button';
  if (name) node.dataset.action = name;
  node.onclick = action; return node;
}
function paragraph(parent, title, text) { parent.append(el('h4', title), el('p', text)); }
function option(value, text) { const node = el('option', text); node.value = value; return node; }
let state = {};
try {
  const saved = JSON.parse(localStorage.getItem(reportKey) || '{}');
  if (saved && typeof saved === 'object' && !Array.isArray(saved)) state = saved;
} catch { notice('Browser storage is unavailable; comments and decisions may not persist.'); }
function stateFor(id) {
  const saved = state[id];
  return {status: ['open', 'done', 'rejected'].includes(saved?.status) ? saved.status : 'open',
    comment: typeof saved?.comment === 'string' ? saved.comment : ''};
}
function persist() {
  try { localStorage.setItem(reportKey, JSON.stringify(state)); }
  catch { notice('Could not save in this browser. Copy your finding and comment before closing.'); }
}
function setStatus(id, status) { state[id] = {...stateFor(id), status}; persist(); renderFindings(); }
function locationText(value) { return `${value.path} @ ${value.revision} · lines ${value.startLine}–${value.endLine}`; }
function sideText(value) {
  if (value.kind === 'absent') return value.reason === 'added' ? 'New code — no before location or excerpt' : 'Deleted — no after location or excerpt';
  if (value.kind === 'unavailable') return 'Source unavailable: ' + value.reason;
  return value.path + ' @ ' + value.revision + '\n' + value.ranges.map(range =>
    `${range.label} · lines ${range.startLine}–${range.endLine}\n${range.excerpt}`).join('\n\n');
}
function contextDocument(id) { return report.request.context.documents.find(d => d.id === id); }
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
    'Comment: ' + stateFor(f.id).comment].join('\n\n');
}
async function copyFinding(entry) {
  const text = findingText(entry);
  try { await navigator.clipboard.writeText(text); notice('Complete finding copied.'); }
  catch {
    const area = el('textarea'); area.value = text; document.body.append(area); area.select();
    let copied = false; try { copied = document.execCommand('copy'); } catch {}
    area.remove(); notice(copied ? 'Complete finding copied.' : 'Copy unavailable. Select the finding text and copy manually.');
  }
}
let selected = report.findings[0]?.finding.id || null;
let viewId = null, fileId = selected ? null : report.fileViews[0]?.id || null;
let side = 'after', full = !selected, rangeFocus = 'all';
function selectedEntry() { return report.findings.find(entry => entry.finding.id === selected); }
function originView(finding) {
  const origin = finding.problematicLocation.location;
  return finding.codeViews.find(view => [view.before, view.after].some(value => value.kind === 'present' &&
    value.path === origin.path && value.revision === origin.revision && value.ranges.some(range =>
      range.startLine <= origin.startLine && range.endLine >= origin.endLine))) || finding.codeViews[0];
}
function currentView() {
  if (fileId) return report.fileViews.find(view => view.id === fileId);
  const entry = selectedEntry();
  return entry?.finding.codeViews.find(view => view.id === viewId) || (entry && originView(entry.finding));
}
function chooseView(id) { viewId = id; fileId = null; rangeFocus = 'all'; $('file-select').value = ''; renderCode(); }
function chooseFinding(id) {
  selected = id; viewId = originView(selectedEntry().finding).id; fileId = null; rangeFocus = 'all';
  side = selectedEntry().finding.problematicLocation.kind === 'deletion' ? 'before' : 'after';
  $('file-select').value = ''; renderFindings(); renderCode();
}
function documentPanel(doc) {
  const details = el('details', undefined, 'context-document');
  details.append(el('summary', doc.title), el('p', doc.path), el('p', 'Snapshot SHA256: ' + doc.sha256), el('pre', doc.content));
  return details;
}
function renderEvidence(evidence) {
  const node = el('div', undefined, 'evidence-item');
  node.dataset.evidenceKind = evidence.kind;
  node.append(el('strong', evidence.label), el('p', evidence.explanation));
  if (evidence.kind === 'source') node.append(button('View source', () => chooseView(evidence.codeViewId), 'evidence-source'));
  if (evidence.kind === 'document') {
    const doc = contextDocument(evidence.documentId);
    node.append(doc ? documentPanel(doc) : el('p', 'Document snapshot unavailable.'));
  }
  if (evidence.kind === 'external') {
    try {
      const url = new URL(evidence.url);
      if (['http:', 'https:'].includes(url.protocol) && !url.username && !url.password) {
        const link = el('a', evidence.url); link.href = url.href; link.target = '_blank'; link.rel = 'noopener noreferrer'; node.append(link);
      }
    } catch {}
    if (evidence.quote) node.append(el('blockquote', evidence.quote));
  }
  if (evidence.kind === 'check') node.append(el('p', 'Check: ' + evidence.outcome), el('pre', evidence.command), el('pre', evidence.output));
  return node;
}
function findingCard(entry) {
  const f = entry.finding, current = stateFor(f.id), active = selected === f.id;
  const article = el('article', undefined, 'finding' + (active ? ' selected' : '') + (current.status !== 'open' ? ' resolved' : ''));
  article.dataset.findingId = f.id;
  article.append(el('div', current.status.toUpperCase(), 'label'), el('h3', f.title));
  const meta = el('div', undefined, 'meta');
  for (const text of ['severity · ' + f.severity.value, 'likelihood · ' + f.likelihood.value, 'reported by ' + new Set(entry.sources.map(s => s.reviewer)).size + ' reviewers']) meta.append(el('span', text));
  article.append(meta);
  const assessment = el('p', (f.assessment.status === 'needs-verification' ? 'Needs verification — ' : 'Supported — ') + f.assessment.reasoning, 'assessment');
  assessment.dataset.assessment = f.assessment.status; article.append(assessment);
  const where = button((f.problematicLocation.kind === 'deletion' ? 'Deletion · ' : '') + locationText(f.problematicLocation.location), () => chooseFinding(f.id), 'select');
  where.className = 'where'; where.setAttribute('aria-expanded', String(active)); article.append(where, el('p', f.whatGoesWrong));
  if (active) {
    const details = el('div', undefined, 'explanation');
    paragraph(details, 'Severity', f.severity.reasoning); paragraph(details, 'Likelihood', f.likelihood.reasoning);
    if (f.assessment.assumptions.length) paragraph(details, 'Assumptions to verify', f.assessment.assumptions.join('\n'));
    if (f.assessment.verificationSteps.length) paragraph(details, 'How to resolve the uncertainty', f.assessment.verificationSteps.join('\n'));
    paragraph(details, 'Why it happens', f.whyItHappens);
    const views = el('div', undefined, 'actions');
    for (const view of f.codeViews) views.append(button(view.label, () => chooseView(view.id), 'view-source'));
    details.append(views); paragraph(details, 'Prerequisites', f.reproduction.prerequisites.join('\n') || 'None');
    details.append(el('h4', 'How to reproduce')); const steps = el('ol'); list(steps, f.reproduction.steps); details.append(steps);
    paragraph(details, 'Expected', f.reproduction.expected); paragraph(details, f.reproduction.basis === 'observed' ? 'Actual' : 'Predicted actual', f.reproduction.actual);
    details.append(el('h4', 'Evidence')); for (const evidence of f.evidence) details.append(renderEvidence(evidence));
    paragraph(details, 'Limits', f.limits.join('\n') || 'None reported');
    for (const disagreement of entry.disagreements) paragraph(details, 'Disagreement · ' + disagreement.reviewer, disagreement.explanation);
    article.append(details);
  }
  const label = el('label', 'Your comment · saved in this browser', 'label comment'); label.htmlFor = 'comment-' + f.id;
  const comment = el('textarea'); comment.id = label.htmlFor; comment.value = current.comment;
  comment.oninput = () => { state[f.id] = {...stateFor(f.id), comment: comment.value}; persist(); }; article.append(label, comment);
  const actions = el('div', undefined, 'actions');
  if (current.status !== 'done') actions.append(button('Mark done', () => setStatus(f.id, 'done'), 'done'));
  if (current.status !== 'rejected') actions.append(button('Reject', () => setStatus(f.id, 'rejected'), 'reject'));
  if (current.status !== 'open') actions.append(button('Reopen', () => setStatus(f.id, 'open'), 'reopen'));
  actions.append(button('Copy finding', () => copyFinding(entry), 'copy')); article.append(actions); return article;
}
function renderFindings() {
  $('open-list').replaceChildren(); $('resolved-list').replaceChildren();
  for (const entry of report.findings) $(stateFor(entry.finding.id).status === 'open' ? 'open-list' : 'resolved-list').append(findingCard(entry));
  if (!$('open-list').children.length) {
    let text = 'All findings have been triaged.';
    if (!report.findings.length) text = report.reviewStatus === 'failed' ? 'No review conclusion is available.' :
      report.consolidationStatus === 'failed' ? 'No findings in the available reports. Consolidation failed.' :
      'No supported findings identified' + (report.reviewStatus === 'partial' ? ' in the available reviews.' : '.');
    $('open-list').append(el('p', text, 'empty'));
  }
  if (!$('resolved-list').children.length) $('resolved-list').append(el('p', 'Done and rejected findings appear here.', 'empty'));
}
function highlight(text) {
  const fragment = document.createDocumentFragment();
  const tokens = /(\/\/.*$|#.*$|'(?:\\.|[^'\\])*'|"(?:\\.|[^"\\])*"|`(?:\\.|[^`\\])*`|\b(?:import|export|from|type|interface|const|let|return|yield|function|readonly|never|void|new|as|async|await|if|else|class|def|raise|for|while|try|except|true|false|null|None|True|False)\b)/g;
  let cursor = 0;
  for (const match of text.matchAll(tokens)) {
    fragment.append(document.createTextNode(text.slice(cursor, match.index))); const token = match[0];
    fragment.append(el('span', token, token.startsWith('//') || token.startsWith('#') ? 'tok-comment' : /^["'`]/.test(token) ? 'tok-string' : 'tok-keyword'));
    cursor = match.index + token.length;
  }
  fragment.append(document.createTextNode(text.slice(cursor))); return fragment;
}
function renderCode() {
  const view = currentView(), entry = selectedEntry();
  $('code-block').replaceChildren(); $('code-views').replaceChildren(); $('range-select').replaceChildren();
  for (const name of ['before', 'after', 'full-file']) $(name).disabled = !view;
  if (entry) for (const item of entry.finding.codeViews) {
    const control = button(item.label, () => chooseView(item.id)); control.dataset.viewId = item.id;
    control.setAttribute('aria-pressed', String(!fileId && view?.id === item.id)); $('code-views').append(control);
  }
  $('range-select').disabled = true; $('range-select').append(option('all', 'All highlighted ranges'));
  if (!view) { $('code-block').append(el('p', 'No source files available.', 'absent')); return; }
  $('before').setAttribute('aria-pressed', String(side === 'before')); $('after').setAttribute('aria-pressed', String(side === 'after'));
  $('full-file').setAttribute('aria-pressed', String(full)); $('view-explanation').textContent = view.label + ' — ' + view.explanation;
  const value = view[side]; $('code-revision').textContent = side === 'before' ? 'Before · base' : 'After · HEAD';
  if (value.kind !== 'present') {
    $('code-title').textContent = value.path || (side === 'before' ? 'New code' : 'Deleted code');
    $('code-block').append(el('p', sideText(value), 'absent')); $('code-foot').textContent = 'This side has no captured source range.'; return;
  }
  $('code-title').textContent = value.path; $('code-revision').textContent += ' @ ' + value.revision;
  const source = report.sourceFiles.find(file => file.revision === value.revision && file.path === value.path);
  if (!source) { $('code-block').append(el('p', 'Source unavailable; see report limits.', 'absent')); return; }
  value.ranges.forEach((range, index) => $('range-select').append(option(String(index), `${range.label} · ${range.startLine}–${range.endLine}`)));
  if (rangeFocus !== 'all' && !value.ranges[Number(rangeFocus)]) rangeFocus = 'all';
  $('range-select').value = rangeFocus; $('range-select').disabled = !value.ranges.length;
  const ranges = rangeFocus === 'all' ? value.ranges : [value.ranges[Number(rangeFocus)]];
  const lines = source.content.split('\n'); if (lines.at(-1) === '') lines.pop();
  const numbers = full || !ranges.length ? lines.map((_, i) => i + 1) : [...new Set(ranges.flatMap(range => Array.from({length: range.endLine - range.startLine + 1}, (_, i) => range.startLine + i)))].sort((a, b) => a - b);
  const pre = el('pre'), code = el('code'); pre.append(code); let previous = null;
  for (const n of numbers) {
    if (previous !== null && n !== previous + 1) code.append(el('span', '…', 'line source-gap'));
    const target = ranges.some(range => n >= range.startLine && n <= range.endLine);
    const line = el('span', undefined, 'line' + (target ? ' target' : '')); line.dataset.line = String(n);
    const number = el('span', String(n), 'number'); number.setAttribute('aria-hidden', 'true');
    line.append(number, highlight(lines[n - 1])); code.append(line); previous = n;
  }
  $('code-block').append(pre);
  $('code-foot').textContent = ranges.length ? ranges.map(range => range.label + ': ' + range.startLine + '–' + range.endLine).join(' · ') : 'Full file captured at review time.';
  const target = code.querySelector('.target');
  if (target) $('code-block').scrollTop += target.getBoundingClientRect().top - $('code-block').getBoundingClientRect().top - 40;
}

document.title = 'Adversarial review · ' + report.request.scope.headSha.slice(0, 9);
$('edition').textContent = report.runId;
$('scope').textContent = report.request.scope.requested + ' · Base ' + report.request.scope.baseSha + ' → HEAD ' + report.request.scope.headSha;
const completed = report.reviewers.filter(r => r.status === 'completed').length;
$('banner').dataset.status = report.reviewStatus;
$('banner').append(el('strong', (report.reviewStatus === 'complete' ? 'Review complete' : report.reviewStatus === 'partial' ? 'Review incomplete' : 'Review failed') + ' — ' + completed + ' of ' + report.reviewers.length + ' reviewers completed.'));
$('banner').append(el('p', report.reviewStatus === 'failed' ? 'No reviewer supplied a usable report. No review conclusion is available.' : report.findings.length + ' ' + (report.consolidationStatus === 'completed' ? 'consolidated' : 'unconsolidated') + ' findings.'));
for (const warning of report.warnings) $('warnings').append(el('p', warning, 'notice'));
for (const reviewer of report.reviewers) {
  const details = el('details', undefined, 'reviewer');
  details.append(el('summary', reviewer.reviewer + ' · ' + reviewer.status.toUpperCase() + ' · ' + reviewer.requestedModel + ' / ' + reviewer.effort));
  if (reviewer.failure) details.append(el('p', reviewer.failure.message, 'notice'));
  if (reviewer.report) {
    details.append(el('p', reviewer.report.findings.length + ' raw findings')); const inspected = el('ul'); list(inspected, reviewer.report.coverage.inspected); details.append(inspected);
    for (const check of reviewer.report.coverage.checks) details.append(el('p', check.outcome + ': ' + check.description + ' — ' + check.details));
    for (const limit of reviewer.report.coverage.limits) details.append(el('p', 'Limit: ' + limit));
  }
  for (const attempt of reviewer.attempts) {
    details.append(el('p', 'Attempt ' + attempt.number + ' · ' + (attempt.failure ? attempt.failure.kind : 'completed') + ' · ' + attempt.startedAt + ' → ' + attempt.finishedAt));
    if (attempt.failure) details.append(el('pre', attempt.failure.message));
    if (attempt.environment) details.append(el('pre', JSON.stringify(attempt.environment, null, 2)));
    details.append(el('p', 'Events: ' + (attempt.eventsPath || 'not started') + '\nStderr: ' + (attempt.stderrPath || 'not started')));
  }
  $('reviewers').append(details);
}
const context = report.request.context;
if (context.intent) paragraph($('context'), 'Intent', context.intent);
if (context.acceptedExceptions.length) { $('context').append(el('h3', 'Accepted exceptions')); const exceptions = el('ul'); list(exceptions, context.acceptedExceptions); $('context').append(exceptions); }
for (const doc of context.documents) $('context').append(documentPanel(doc));
$('context-section').hidden = !context.intent && !context.acceptedExceptions.length && !context.documents.length;
$('file-select').append(option('', 'Choose a reviewed or changed file'));
for (const view of report.fileViews) $('file-select').append(option(view.id, view.label));
$('file-select').value = fileId || ''; $('file-select').disabled = !report.fileViews.length;
$('file-select').onchange = () => { fileId = $('file-select').value || null; rangeFocus = 'all'; full = true; renderCode(); };
list($('changes'), report.whatChanged); $('changes-section').hidden = !report.whatChanged.length;
list($('limits'), report.limits); $('limits-section').hidden = !report.limits.length;
for (const excluded of report.excluded) $('excluded').append(el('p', excluded.source.reviewer + ' / ' + excluded.source.findingId + ': ' + excluded.reason));
$('excluded-section').hidden = !report.excluded.length;
$('findings-title').textContent = report.consolidationStatus === 'failed' ? 'Open findings · unconsolidated' : 'Open findings';
$('footer').textContent = 'Pinned commits only · local changes excluded. Decisions and comments are stored in this browser. ' + (report.verification ? 'Browser verification: ' + report.verification.status + '. ' + report.verification.details : 'Browser verification pending.');
$('before').onclick = () => { side = 'before'; rangeFocus = 'all'; renderCode(); };
$('after').onclick = () => { side = 'after'; rangeFocus = 'all'; renderCode(); };
$('full-file').onclick = () => { full = !full; renderCode(); };
$('range-select').onchange = () => { rangeFocus = $('range-select').value; renderCode(); };
renderFindings(); renderCode();
