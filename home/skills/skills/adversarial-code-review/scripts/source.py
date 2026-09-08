"""Validate review evidence against pinned Git source; never reads working files."""
from pathlib import PurePosixPath
import subprocess

def git(repo, *args):
    result = subprocess.run(["git", "-C", str(repo), *args], capture_output=True,
                            timeout=120)
    if result.returncode:
        raise ValueError(result.stderr.decode(errors="replace").strip())
    return result.stdout.decode("utf-8")


def revision(repo, ref):
    if not ref or ref.startswith("-"):
        raise ValueError("Invalid Git revision")
    return git(repo, "rev-parse", "--verify", ref + "^{commit}").strip()


class Source:
    def __init__(self, repo, scope):
        self.repo, self.scope, self.files = repo, scope, {}

    def file(self, sha, path):
        if sha not in (self.scope["baseSha"], self.scope["headSha"]):
            raise ValueError("Source does not match a pinned revision")
        if not path or PurePosixPath(path).is_absolute() or ".." in PurePosixPath(path).parts:
            raise ValueError("Source must be a repository-relative path")
        key = (sha, path)
        if key not in self.files:
            content = git(self.repo, "show", f"{sha}:{path}")
            if "\0" in content:
                raise ValueError("Binary source cannot be displayed as text")
            self.files[key] = content
        return self.files[key]

    def location(self, location, expected=None):
        sha, path = location["revision"], location["path"]
        if expected and sha != expected:
            raise ValueError("Location does not match the pinned revision")
        lines = self.file(sha, path).splitlines(keepends=True)
        start, end = location["startLine"], location["endLine"]
        if not 1 <= start <= end <= len(lines):
            raise ValueError(f"Invalid source range: {path}:{start}-{end}")
        return "".join(lines[start - 1:end])

    def findings(self, findings, documents=()):
        ids = set()
        for finding in findings:
            if not finding["id"].strip() or finding["id"] in ids:
                raise ValueError("Finding IDs must be nonempty and unique")
            ids.add(finding["id"])
            for field in ("title", "whatGoesWrong", "whyItHappens"):
                if not finding[field].strip():
                    raise ValueError(f"Empty finding {field}")
            cause = finding["problematicLocation"]
            expected = self.scope["baseSha" if cause["kind"] == "deletion" else "headSha"]
            self.location(cause["location"], expected)
            view_ids = set()
            origin_visible = False
            for view in finding["codeViews"]:
                if not view["id"].strip() or view["id"] in view_ids or not view["label"].strip() or not view["explanation"].strip():
                    raise ValueError("Code views require unique IDs, labels, and explanations")
                view_ids.add(view["id"])
                if view["before"]["kind"] == view["after"]["kind"] == "absent":
                    raise ValueError("Both source sides cannot be absent")
                for side, sha, reason in (("before", self.scope["baseSha"], "added"),
                                          ("after", self.scope["headSha"], "deleted")):
                    value = view[side]
                    if value["kind"] == "absent":
                        if value["reason"] != reason:
                            raise ValueError("Incorrect absent-side reason")
                        continue
                    for span in value["ranges"]:
                        if not span["label"].strip():
                            raise ValueError("Source ranges need explanatory labels")
                        location = {"revision": value["revision"], "path": value["path"],
                                    "startLine": span["startLine"], "endLine": span["endLine"]}
                        exact = self.location(location, sha)
                        if span["excerpt"].removesuffix("\n") != exact.removesuffix("\n"):
                            raise ValueError(f"{side} excerpt differs from pinned source")
                        span["excerpt"] = exact
                        origin = cause["location"]
                        if location["path"] == origin["path"] and location["revision"] == origin["revision"]:
                            origin_visible |= span["startLine"] <= origin["startLine"] <= origin["endLine"] <= span["endLine"]
            if not origin_visible:
                raise ValueError("A code view must include the primary location")
            assessment = finding["assessment"]
            if not assessment["reasoning"].strip():
                raise ValueError("Assessment needs reasoning")
            if assessment["status"] == "needs-verification" and (not assessment["assumptions"] or not assessment["verificationSteps"]):
                raise ValueError("Conditional findings need assumptions and verification steps")
            for evidence in finding["evidence"]:
                if evidence["kind"] == "source" and evidence["codeViewId"] not in view_ids:
                    raise ValueError("Evidence references an unknown code view")
                if evidence["kind"] == "document" and evidence["documentId"] not in documents:
                    raise ValueError("Evidence references a document not captured in review context")
                if evidence["kind"] == "external":
                    from urllib.parse import urlsplit
                    url = urlsplit(evidence["url"])
                    if url.scheme not in ("https", "http") or not url.netloc or url.username or url.password:
                        raise ValueError("External evidence must use an HTTP(S) URL without credentials")

