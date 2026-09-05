"""Capture context and reproduce local dependencies without sharing writable trees."""
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import time


def capture_context(repo, config, context_path=None):
    context = dict(config.get("context", {}))
    if context_path:
        context.update(json.loads(Path(context_path).read_text()))
    if set(context) - {"intent", "acceptedExceptions", "documents"}:
        raise ValueError("Unknown review-context fields")
    result = {"intent": context.get("intent", ""),
              "acceptedExceptions": context.get("acceptedExceptions", []), "documents": []}
    if not isinstance(result["intent"], str) or not isinstance(result["acceptedExceptions"], list) or not all(isinstance(x, str) for x in result["acceptedExceptions"]):
        raise ValueError("Context needs a text intent and a list of accepted exceptions")
    ids = set()
    for document in context.get("documents", []):
        identifier = document["id"]
        if not isinstance(identifier, str) or not identifier or identifier in ids:
            raise ValueError("Context document IDs must be nonempty and unique")
        ids.add(identifier)
        path = (repo / document["path"]).resolve()
        content = path.read_text()
        result["documents"].append({"id": identifier, "title": document["title"],
                                    "path": str(path), "content": content,
                                    "sha256": hashlib.sha256(content.encode()).hexdigest()})
    return result


def node_matches(version, requirement):
    """Exact/major/minor pins and whitespace-separated comparator ranges.

    Return None for other semver syntax instead of assuming compatibility.
    """
    version = version.removeprefix("v")
    if not re.fullmatch(r"\d+\.\d+\.\d+", version):
        return False
    actual = tuple(map(int, version.split(".")))
    if re.fullmatch(r"v?\d+(\.\d+){0,2}", requirement):
        wanted = requirement.removeprefix("v").split(".")
        return actual[:len(wanted)] == tuple(map(int, wanted))
    tokens = requirement.split()
    if not tokens or any(not re.fullmatch(r"(>=|<=|>|<|=)\d+\.\d+\.\d+", token) for token in tokens):
        return None
    for token in tokens:
        operator, target = re.fullmatch(r"(>=|<=|>|<|=)(.*)", token).groups()
        wanted = tuple(map(int, target.split(".")))
        if not {">=": actual >= wanted, "<=": actual <= wanted, ">": actual > wanted,
                "<": actual < wanted, "=": actual == wanted}[operator]:
            return False
    return True


def resolve_environment(repo, head, settings, git):
    """Discover once; all workers inherit the same runtime and preparation plan."""
    plan = {"copyPaths": [], "pathPrefixes": list(settings.get("pathPrefixes", [])),
            "setupCommands": settings.get("setupCommands", []),
            "timeoutSeconds": settings.get("timeoutSeconds", 600),
            "nodeRequested": None, "nodeVersion": None, "limits": []}
    for filename in (".nvmrc", ".node-version"):
        try:
            wanted = git(repo, "show", f"{head}:{filename}").strip().removeprefix("v")
        except ValueError:
            continue
        plan["nodeRequested"] = wanted
        break
    if not plan["nodeRequested"]:
        try:
            rush = git(repo, "show", f"{head}:rush.json")
            match = re.search(r'"nodeSupportedVersionRange"\s*:\s*"([^"]+)"', rush)
            if match:
                plan["nodeRequested"] = match.group(1)
        except ValueError:
            pass
    if not plan["nodeRequested"]:
        try:
            package = json.loads(git(repo, "show", f"{head}:package.json"))
            plan["nodeRequested"] = package.get("engines", {}).get("node")
        except (ValueError, KeyError):
            pass
    if plan["nodeRequested"] and not plan["pathPrefixes"]:
        nvm = Path(os.environ.get("NVM_DIR", str(Path.home() / ".nvm"))) / "versions/node"
        choices = [p for p in nvm.glob("v*/bin") if (p / "node").is_file()
                   and node_matches(p.parent.name, plan["nodeRequested"]) is True]
        if choices:
            choices.sort(key=lambda p: tuple(int(n) for n in p.parent.name[1:].split(".")))
            plan["pathPrefixes"].append(str(choices[-1]))
    env = worker_env(plan)
    node = shutil.which("node", path=env["PATH"])
    if node:
        result = subprocess.run([node, "--version"], capture_output=True, text=True, timeout=10)
        plan["nodeVersion"] = result.stdout.strip()
    if plan["nodeRequested"]:
        actual = (plan["nodeVersion"] or "").removeprefix("v")
        wanted = plan["nodeRequested"]
        if node_matches(actual, wanted) is not True:
            plan["limits"].append(f"Requested Node {wanted}; available runtime is {actual or 'missing'}. Configure pathPrefixes to select the required runtime.")
    if settings.get("reuseDependencies", True):
        descriptors = [p for p in git(repo, "ls-tree", "-r", "--name-only", head).splitlines()
                       if Path(p).name in ("package.json", "rush.json", "pnpm-lock.yaml", "package-lock.json", "yarn.lock", "shrinkwrap.yaml")]
        compatible = all((repo / p).is_file() and (repo / p).read_text() == git(repo, "show", f"{head}:{p}") for p in descriptors)
        if not compatible:
            plan["limits"].append("Local dependency manifests differ from reviewed HEAD; dependency reuse skipped.")
        else:
            ignored = git(repo, "ls-files", "--others", "--ignored", "--exclude-standard", "--directory", "-z").split("\0")
            candidates = {p.rstrip("/") for p in ignored if p.rstrip("/").endswith("node_modules")}
            if (repo / "common/temp").is_dir() and not git(repo, "ls-files", "--", "common/temp").strip():
                candidates.add("common/temp")
            candidates.update(settings.get("copyPaths", []))
            for name in sorted(candidates, key=len):
                relative = Path(name)
                if relative.is_absolute() or ".." in relative.parts or not name or name == ".":
                    raise ValueError("Dependency copy paths must be repository-relative directories")
                if git(repo, "ls-files", "--", name).strip():
                    raise ValueError(f"Dependency copy would overwrite tracked files: {name}")
                if not any(relative.is_relative_to(Path(parent)) for parent in plan["copyPaths"]):
                    plan["copyPaths"].append(name)
    if not plan["copyPaths"] and not plan["setupCommands"]:
        plan["limits"].append("No dependency tree or setup commands available; source analysis can continue, but some checks may be unavailable.")
    return plan


def worker_env(plan):
    return {**os.environ, "PATH": os.pathsep.join([*plan["pathPrefixes"], os.environ.get("PATH", "")])}


def prepare_environment(repo, clone, plan, log_dir, stop):
    # macOS /var and /private/var can name the same directory. Compare canonical
    # roots when deciding whether a dependency link stays inside the snapshot.
    repo, clone = repo.resolve(), clone.resolve()
    log_dir.mkdir(parents=True, exist_ok=True)
    record = {"copied": [], "commands": [], "limits": list(plan["limits"]),
              "nodeRequested": plan["nodeRequested"], "nodeVersion": plan["nodeVersion"]}
    deadline = time.monotonic() + plan["timeoutSeconds"]

    def budget():
        if stop.is_set() or time.monotonic() >= deadline:
            raise TimeoutError("Environment preparation interrupted or exceeded its deadline")

    def copy_file(src, dst):
        budget()
        return shutil.copy2(src, dst)

    def rebase_links(destination):
        paths = [destination] if destination.is_symlink() else [p for base, dirs, files in os.walk(destination, followlinks=False) for p in (Path(base) / n for n in dirs + files) if p.is_symlink()]
        for link in paths:
            budget()
            original = repo / link.relative_to(clone)
            target = (original.parent / os.readlink(link)).resolve()
            link.unlink()
            if target.is_relative_to(repo):
                target_copy = clone / target.relative_to(repo)
                link.symlink_to(os.path.relpath(target_copy, link.parent))
            else:
                record["limits"].append(f"External dependency symlink omitted: {link.relative_to(clone)}. Use setupCommands to install it in the clone.")

    for name in plan["copyPaths"]:
        budget()
        src, dst = repo / name, clone / name
        try:
            dst.parent.mkdir(parents=True, exist_ok=True)
            if src.is_symlink():
                dst.symlink_to(os.readlink(src))
            else:
                shutil.copytree(src, dst, symlinks=True, copy_function=copy_file)
            rebase_links(dst)
            record["copied"].append(name)
        except (OSError, shutil.Error) as error:
            # Remove a partial copy so workers cannot mistake it for an intact install.
            if dst.is_symlink():
                dst.unlink()
            elif dst.exists():
                shutil.rmtree(dst)
            record["limits"].append(f"Could not copy {name}: {error}")
    env = worker_env(plan)
    for index, args in enumerate(plan["setupCommands"], 1):
        budget()
        path = log_dir / f"setup-{index}.log"
        with path.open("w") as log:
            process = subprocess.Popen(args, cwd=clone, env=env, stdout=log, stderr=subprocess.STDOUT,
                                       start_new_session=True)
            try:
                while process.poll() is None:
                    budget()
                    time.sleep(0.1)
                record["commands"].append({"argv": args, "exitCode": process.returncode, "logPath": str(path)})
                if process.returncode:
                    record["limits"].append(f"Setup command {index} failed; see {path}")
                    break
            finally:
                if process.poll() is None:
                    os.killpg(process.pid, signal.SIGKILL)
                    process.wait()
    record["status"] = "limited" if record["limits"] else "prepared"
    return record, env
