"""Illustrative review data for iterating on the bundled UI. No agents are run."""
import json
from pathlib import Path
import sys
import textwrap

ROOT = Path(__file__).resolve().parent
SKILL = ROOT.parents[2] / 'home/skills/skills/adversarial-code-review-2'
sys.path.insert(0, str(SKILL / 'scripts'))
from render import render_report

BASE, HEAD = 'demo-base', 'demo-head'
sources = {}
pairs = []


def file(path, before, after=None, new_path=None):
    if before is not None:
        sources[BASE, path] = textwrap.dedent(before).strip() + '\n'
    target = new_path or path
    if after is not None:
        sources[HEAD, target] = textwrap.dedent(after).strip() + '\n'
    pairs.append((path if before is not None else None, target if after is not None else None))


cache_before = '''
    import { loadProject } from './project-store';
    import type { Project } from './types';

    const cache = new Map<string, Project>();

    export async function getProject(tenantId: string, slug: string) {
      const key = `${tenantId}:${slug}`;
      const cached = cache.get(key);
      if (cached) return cached;

      const project = await loadProject(tenantId, slug);
      cache.set(key, project);
      return project;
    }

    export function evictProject(tenantId: string, slug: string) {
      cache.delete(`${tenantId}:${slug}`);
    }
'''
cache_after = cache_before.replace('const key = `${tenantId}:${slug}`;', 'const key = slug;').replace('cache.delete(`${tenantId}:${slug}`);', 'cache.delete(slug);')
file('src/server/project-cache.ts', cache_before, cache_after)
route = '''
    import { getProject } from './project-cache';

    export async function projectRoute(request: RequestContext) {
      const session = await request.requireSession();
      const slug = request.params.slug;
      const project = await getProject(session.tenantId, slug);
      return { status: 200, body: project };
    }
'''
file('src/server/project-route.ts', route, route)
store = '''
    export async function loadProject(tenantId: string, slug: string) {
      return db.project.findUniqueOrThrow({
        where: { tenantId_slug: { tenantId, slug } },
      });
    }
'''
file('src/server/project-store.ts', store, store)
classifier_before = '''
    export function isExpectedCancellation(error: unknown): boolean {
      return error instanceof Error && error.name === 'AbortError';
    }
'''
classifier_after = classifier_before.replace("error.name === 'AbortError'", "/abort|timeout/i.test(error.message)")
file('src/client/errors.ts', classifier_before, classifier_after)
hooks = '''
    import { isExpectedCancellation } from './errors';

    export function onQueryError(error: unknown) {
      if (isExpectedCancellation(error)) return;
      showErrorToast(error);
      markQueryFailed(error);
    }

    export function onQuerySuccess(data: unknown) {
      updateResults(data);
      clearPendingState();
    }

    export function onStreamError(error: unknown) {
      if (isExpectedCancellation(error)) return;
      markStreamFailed(error);
      showReconnectAction();
    }

    export function onStreamMessage(message: unknown) {
      appendResult(message);
    }
'''
file('src/client/result-hooks.ts', hooks, hooks)
session = '''
    export function createSession(userId: string) {
      return { userId, createdAt: Date.now() };
    }

    export function expireSession(session: Session) {
      return { ...session, expired: true };
    }
'''
file('packages/auth/src/session.ts', session, session, 'packages/auth/src/session-store.ts')
barrel = '''
    export { createSession, expireSession } from './session';
    export type { Session } from './types';
'''
file('packages/auth/src/index.ts', barrel, barrel)
job = '''
    export async function expirePendingInvites(now: Date) {
      return db.invite.deleteMany({
        where: { acceptedAt: null, expiresAt: { lt: now } },
      });
    }

    registerDailyJob('expire-pending-invites', expirePendingInvites);
'''
file('src/jobs/expire-pending-invites.ts', job)
invite_before = '''
    export async function createInvite(email: string) {
      return db.invite.create({
        data: { email, expiresAt: addDays(new Date(), 7) },
      });
    }
'''
invite_after = invite_before.replace('      });', '      });')
file('src/server/invites.ts', invite_before, invite_after)
file('src/client/empty-state.ts', None, '''
    export const emptyState = {
      title: 'No results yet',
      description: 'Run a query to see your projects.',
    };
''')


def side(revision, path, spans):
    if path is None:
        return {'kind': 'absent', 'reason': 'added' if revision == BASE else 'deleted'}
    lines = sources[revision, path].splitlines(keepends=True)
    return {'kind': 'present', 'revision': revision, 'path': path, 'ranges': [
        {'label': label, 'startLine': start, 'endLine': end, 'excerpt': ''.join(lines[start-1:end])}
        for label, start, end in spans]}


def view(id, label, explanation, path, spans, after_path=True):
    return {'id': id, 'label': label, 'explanation': explanation,
            'before': side(BASE, path, spans),
            'after': side(HEAD, path if after_path is True else after_path, spans)}


def finding(id, title, severity, likelihood, views, what, why, steps, expected, actual, uncertain=False):
    origin = views[0]['before' if uncertain else 'after']
    first = origin['ranges'][0]
    return {'id': id, 'title': title,
            'severity': {'value': severity, 'reasoning': {
                'cache-leak': 'A response can expose one tenant’s project data to another tenant.',
                'hidden-timeout': 'An interrupted query or stream can remain pending without a visible recovery action.',
                'broken-export': 'Consumers of the public auth entry point cannot resolve the renamed module.',
                'invite-retention': 'Expired invitation data could accumulate beyond the intended retention window.'}[id]},
            'likelihood': {'value': likelihood, 'reasoning': {
                'cache-leak': 'Two tenants using a common slug such as onboarding is a routine scenario when they share a server process.',
                'hidden-timeout': 'Requires a non-cancellation error whose message includes timeout or abort.',
                'broken-export': 'Every build that resolves the package entry point encounters the stale relative path.',
                'invite-retention': 'Depends on whether an external cleanup job has already replaced this registration.'}[id]},
            'problematicLocation': {'kind': 'deletion' if uncertain else 'head', 'location': {
                'revision': origin['revision'], 'path': origin['path'], 'startLine': first['startLine'], 'endLine': first['endLine']}},
            'whatGoesWrong': what, 'whyItHappens': why, 'codeViews': views,
            'assessment': {'status': 'needs-verification' if uncertain else 'supported',
                'reasoning': 'The repository shows the deletion; the deployed replacement schedule is not captured.' if uncertain else 'The illustrated source establishes this failure path. It has not been executed.',
                'assumptions': ['No independently deployed service deletes expired invitations.'] if uncertain else [],
                'verificationSteps': ['Inspect the deployed scheduler and identify the replacement job.', 'Confirm that its retention window satisfies the documented 24-hour cleanup requirement.'] if uncertain else []},
            'reproduction': {'prerequisites': ['Illustrative fixture only; these snippets are not a runnable application.'],
                'steps': steps, 'expected': expected, 'actual': actual, 'basis': 'predicted'},
            'evidence': [{'kind': 'source', 'label': v['label'], 'explanation': v['explanation'], 'codeViewId': v['id']} for v in views],
            'limits': ['Synthetic example. No model review or runtime reproduction was performed.']}


f1 = finding('cache-leak', 'A shared project slug returns another tenant’s cached data', 'high', 'high', [
    view('cache', 'Cache origin', 'The read and write share a slug-only key. Eviction also omits the tenant.', 'src/server/project-cache.ts', [('Lookup and early return', 6, 9), ('Database result cached', 11, 13), ('Eviction key', 16, 18)]),
    view('route', 'Request boundary', 'The route has an authenticated tenant, but returns the cached object without a second ownership check.', 'src/server/project-route.ts', [('Authenticated lookup and response', 3, 7)]),
    view('store', 'Database isolation', 'The database lookup is tenant-scoped; a cache hit bypasses this protection.', 'src/server/project-store.ts', [('Composite tenant key', 1, 5)])],
    'Tenant B requesting onboarding can receive the project cached by tenant A in the same server process.',
    'The refactor removes tenantId from the cache key. The route supplies a tenant, but a cache hit returns before the tenant-scoped database lookup. The invalidation path repeats the same key collision.',
    ['Create onboarding projects for tenants A and B.', 'Request A’s project to warm the process-local cache.', 'Request B’s project on that same process.'],
    'Each response contains only the requesting tenant’s project.', 'B receives A’s cached project.')

f2 = finding('hidden-timeout', 'Timeout errors silently bypass both recovery handlers', 'medium', 'medium', [
    view('classifier', 'Error classifier', 'The changed predicate accepts message substrings, including a server-side timeout.', 'src/client/errors.ts', [('Classification rule', 1, 3)]),
    view('handlers', 'Query + stream handlers', 'These separated early returns suppress different recovery paths in the same file.', 'src/client/result-hooks.ts', [('Query failure path', 3, 7), ('Stream failure path', 14, 18)])],
    'A query or stream reporting “upstream timeout” is treated as intentional cancellation, hiding the error and recovery controls.',
    'The classifier matches text instead of the cancellation error name. Both consumers return before recording failure, and the stream handler also skips its reconnect action.',
    ['Deliver Error("upstream timeout") to onQueryError.', 'Deliver the same error to onStreamError.', 'Inspect the pending state and reconnect controls.'],
    'The operation becomes failed and exposes recovery controls.', 'Both handlers return immediately; the failure actions do not run.')
f2['evidence'].append({'kind': 'check', 'label': 'Suggested reproduction', 'explanation': 'Proposed check only; this command was not run.', 'command': 'pnpm test -- result-hooks --timeout-recovery', 'outcome': 'not-run', 'output': 'No execution result is available in this illustrative report.'})

f3 = finding('broken-export', 'The public auth export still points to the renamed module', 'high', 'high', [
    view('barrel', 'Public entry point', 'This unchanged export still uses the old relative module name.', 'packages/auth/src/index.ts', [('Stale module path', 1, 2)]),
    view('rename', 'Renamed implementation', 'Before and After are different filenames, with the same exported functions.', 'packages/auth/src/session.ts', [('Session creation', 1, 3), ('Session expiration', 5, 7)], 'packages/auth/src/session-store.ts')],
    'Importing createSession through the auth package entry point cannot resolve ./session after the file rename.',
    'The implementation moved to session-store.ts while index.ts retained its original relative export. The origin is the stale reference; the supporting view shows the rename.',
    ['Resolve packages/auth/src/index.ts in a clean checkout.', 'Follow the ./session re-export.', 'Observe that only session-store.ts exists in the reviewed revision.'],
    'The package entry point resolves createSession and expireSession.', 'The old module path has no target.')

f4 = finding('invite-retention', 'Removing the cleanup job may leave expired invitations indefinitely', 'medium', 'unknown', [
    view('removed-job', 'Deleted cleanup job', 'The deleted file contains both the delete operation and its daily registration.', 'src/jobs/expire-pending-invites.ts', [('Expired-row cleanup', 1, 5), ('Daily registration', 7, 7)], None),
    view('writer', 'Invitation writer', 'The remaining writer records an expiration timestamp; it does not delete expired rows.', 'src/server/invites.ts', [('Persisted expiry', 1, 5)])],
    'If no replacement scheduler exists, expired invitation records remain stored beyond the documented cleanup window.',
    'The patch removes the only cleanup registration visible in this example. The writer still persists invitation data. Whether the deletion is a regression depends on the deployment configuration.',
    ['Confirm whether a replacement cleanup service is deployed.', 'If none exists, create an invitation and advance beyond its expiration plus 24 hours.', 'Check whether its database row remains.'],
    'Expired invitation records are removed within 24 hours.', 'Without a replacement job, the row is never removed by the illustrated code.', uncertain=True)

findings = [f1, f2, f3, f4]
entries = []
for i, f in enumerate(findings):
    reviewers = ['codex-astra', 'codex-sol'] if i < 2 else ['codex-astra'] if i == 2 else ['codex-sol']
    entries.append({'finding': f, 'sources': [{'reviewer': r, 'findingId': f['id']} for r in reviewers], 'disagreements': []})
entries[1]['disagreements'] = [{'reviewer': 'codex-sol', 'explanation': 'Illustrative disagreement: rates likelihood low because the exact production error messages are not captured. Consolidated likelihood is medium for the concrete timeout trigger shown here.'}]

run_id = 'EXAMPLE-complex-ui-playground'
changes = ['Tenant-aware project caching becomes slug-only caching.', 'Cancellation detection changes from error identity to a message pattern.', 'The session implementation is renamed without updating its public re-export.', 'The invitation cleanup job is removed; an empty-state copy file is added.']
request = {'schemaVersion': 2, 'runId': run_id, 'promptVersion': '2', 'scope': {
    'requested': 'Illustrative fixture · base → head', 'baseSha': BASE, 'headSha': HEAD,
    'changedPaths': [b or a for a, b in pairs if a != b or sources.get((BASE, a)) != sources.get((HEAD, b))],
    'workingTreeChanges': 'excluded', 'hadLocalChanges': False},
    'context': {'intent': 'SYNTHETIC UI EXAMPLE. Simplify project caching and error handling, rename session storage, and move invitation cleanup out of the application.',
        'acceptedExceptions': ['Example accepted exception: a replacement cleanup service may run outside this repository, provided its deployed schedule is verified.'], 'documents': []}}
outcomes = []
for id, model in [('codex-astra', 'gpt-6-astra'), ('codex-sol', 'gpt-5.6-sol'), ('claude-opus', 'claude-opus')]:
    failed = id == 'claude-opus'
    failure = {'kind': 'startup-timeout', 'message': 'SIMULATED: Claude emitted no startup event before the deadline. The bounded retry also timed out. Claude supplied no review; it contributed no findings.'} if failed else None
    raw = None if failed else {'schemaVersion': 2, 'runId': run_id, 'baseSha': BASE, 'headSha': HEAD, 'completeness': 'complete', 'whatChanged': changes,
        'coverage': {'inspected': ['Illustrative source paths and caller relationships; no real reviewer was launched.'], 'reviewedFiles': [{'revision': r, 'path': p} for r,p in sources], 'checks': [], 'limits': ['All reviewer outcomes and attributions are simulated.']},
        'findings': [e['finding'] for e in entries if any(s['reviewer'] == id for s in e['sources'])]}
    outcomes.append({'reviewer': id, 'requestedModel': model, 'effort': 'high', 'status': 'failed' if failed else 'completed', 'failure': failure, 'report': raw,
        'attempts': [{'number': n, 'startedAt': 'example start', 'finishedAt': 'example deadline', 'failure': failure, 'eventsPath': None, 'stderrPath': None} for n in ([1,2] if failed else [])]})

report = {'schemaVersion': 2, 'runId': run_id, 'request': request, 'reviewers': outcomes,
    'reviewStatus': 'partial', 'consolidationStatus': 'completed', 'consolidation': None,
    'whatChanged': changes, 'findings': entries, 'excluded': [],
    'warnings': ['ILLUSTRATIVE EXAMPLE — source, findings, reviewer outcomes, and revision labels are synthetic. No agents were run.', 'Simulated incomplete review: Claude failed to start on both attempts. Only the two simulated Codex reports are represented.'],
    'limits': ['This report demonstrates UI states and handoff data. It makes no claims about your repositories.', 'The invitation finding intentionally needs deployment verification. No checks were executed.'],
    'sourceFiles': [{'revision': r, 'path': p, 'language': 'ts', 'content': content} for (r,p),content in sources.items()],
    'fileViews': [{'id': f'file-{i}', 'label': f'{a} → {b}' if a and b and a != b else a or b,
        'explanation': 'Illustrative source; independently browsable even when no finding cites it.',
        'before': side(BASE, a, []), 'after': side(HEAD, b, [])} for i,(a,b) in enumerate(pairs)],
    'verification': {'status': 'not-run', 'details': 'UI playground. Automated tests were not run.'}}

ROOT.mkdir(parents=True, exist_ok=True)
(ROOT / 'report.json').write_text(json.dumps(report, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
render_report(report, ROOT / 'index.html')
print(ROOT / 'index.html')
