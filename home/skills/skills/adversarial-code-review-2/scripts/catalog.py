"""Build source navigation independently of findings, preserving rename pairs."""
import hashlib


def file_views(source, outcomes, git):
    base, head = source.scope["baseSha"], source.scope["headSha"]
    changes = git(source.repo, "diff", "--name-status", "-z", "-M", base, head, "--").split("\0")
    pairs = []
    while changes and changes[0]:
        status, path = changes.pop(0), changes.pop(0)
        if status.startswith(("R", "C")):
            pairs.append((path, changes.pop(0)))
        elif status == "A":
            pairs.append((None, path))
        elif status == "D":
            pairs.append((path, None))
        else:
            pairs.append((path, path))
    covered = {path for pair in pairs for path in pair if path}
    for outcome in outcomes:
        if outcome["report"]:
            for ref in outcome["report"]["coverage"].get("reviewedFiles", []):
                if ref["path"] not in covered:
                    pairs.append((ref["path"], ref["path"]))
                    covered.add(ref["path"])
    views, limits = [], []

    def side(sha, path, reason):
        if path is None:
            return {"kind": "absent", "reason": reason}
        try:
            # Large/binary files remain discoverable without bloating every report.
            size = int(git(source.repo, "cat-file", "-s", f"{sha}:{path}").strip())
            if size > 2_000_000:
                raise ValueError("File exceeds the 2 MB source-browser limit")
            source.file(sha, path)
            return {"kind": "present", "revision": sha, "path": path, "ranges": []}
        except (ValueError, UnicodeError) as error:
            limits.append(f"Source browser: {path} @ {sha[:9]} unavailable: {error}")
            return {"kind": "unavailable", "revision": sha, "path": path, "reason": str(error)}

    for before, after in pairs:
        identifier = hashlib.sha256(str((before, after)).encode()).hexdigest()[:16]
        views.append({"id": identifier, "label": f"{before} → {after}" if before and after and before != after else before or after,
                      "explanation": "Source captured at the reviewed revisions.",
                      "before": side(base, before, "added"), "after": side(head, after, "deleted")})
    return views, limits
