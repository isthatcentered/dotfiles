"""Standalone rendering plus browser checks using an isolated Chrome context."""
from html import unescape
import json
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import tempfile
import time
import uuid

SKILL = Path(__file__).resolve().parent.parent


def render_report(report, destination):
    # Escape < so source such as </script> cannot close the inert JSON element.
    data = json.dumps(report, ensure_ascii=True).replace("<", "\\u003c").replace("&", "\\u0026")
    template = (SKILL / "assets/report.html").read_text()
    if template.count("__REPORT_DATA__") != 1:
        raise ValueError("Report template must contain exactly one data slot")
    Path(destination).write_text(template.replace("__REPORT_DATA__", data))


def browser_command(config):
    configured = config["browserCommand"]
    if configured == "disabled":
        return None
    if configured != "auto":
        return shutil.which(configured)
    for name in ("chrome-devtools", "google-chrome", "chromium", "chromium-browser",
                 "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"):
        found = shutil.which(name)
        if found:
            return found
    return None


def verify_with_devtools(browser, checked, timeout):
    """Use the installed browser CLI in a separate context; never touch existing tabs."""
    page_id = None
    deadline = time.monotonic() + timeout

    def call(*args):
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise TimeoutError("Browser verification deadline exceeded")
        result = subprocess.run([browser, *args, "--output-format=json"], capture_output=True,
                                text=True, timeout=remaining, check=True)
        # CLI notifications can precede the final single-line JSON envelope.
        for line in reversed(result.stdout.splitlines()):
            try:
                value = json.loads(line)
                if isinstance(value, dict):
                    return value
            except ValueError:
                continue
        raise ValueError("Browser CLI returned no JSON response")

    try:
        response = call("new_page", checked.as_uri(), "--background", "true",
                       "--isolatedContext", "review-" + uuid.uuid4().hex)
        selected = next((page for page in response.get("pages", []) if page.get("selected")), None)
        if not selected:
            raise ValueError("Browser CLI did not identify the verification tab")
        page_id = str(selected["id"])
        while time.monotonic() < deadline:
            call("select_page", page_id)
            expression = "() => location.href === " + json.dumps(checked.as_uri()) + " ? document.getElementById('review-verification')?.textContent || null : null"
            response = call("evaluate_script", expression)
            message = response.get("message", "")
            match = re.search(r"```json\s*([\s\S]*?)\s*```", message)
            if match:
                result = json.loads(match.group(1))
                if result:
                    return json.loads(result)
            time.sleep(0.2)
        raise TimeoutError("Browser checks did not finish before deadline")
    finally:
        if page_id:
            subprocess.run([browser, "close_page", page_id], capture_output=True, timeout=10)


def verify_report(path, config):
    browser = browser_command(config)
    if not browser:
        return {"status": "skipped", "details": "Chrome DevTools CLI/Chrome/Chromium not available or browser checks disabled."}
    with tempfile.TemporaryDirectory(prefix="review-ui-check-") as temporary:
        root = Path(temporary)
        checked = root / "index.html"
        test = (SKILL / "scripts/verify-ui.js").read_text()
        document = Path(path).read_text().replace("</body>", "<script>" + test + "</script></body>")
        checked.write_text(document)
        if Path(browser).name == "chrome-devtools":
            try:
                return verify_with_devtools(browser, checked, config["browserTimeoutSeconds"])
            except (OSError, ValueError, subprocess.SubprocessError) as error:
                return {"status": "failed", "details": str(error)}
        command = [browser, "--headless", "--disable-gpu", "--no-first-run",
                   "--password-store=basic", "--use-mock-keychain", "--disable-background-networking",
                   "--no-default-browser-check", "--allow-file-access-from-files",
                   "--user-data-dir=" + str(root / "profile"), "--dump-dom",
                   "--virtual-time-budget=10000", checked.as_uri()]
        process = None
        try:
            process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                       text=True, start_new_session=True)
            stdout, stderr = process.communicate(timeout=config["browserTimeoutSeconds"])
            match = re.search(r'<pre id="review-verification">(.*?)</pre>', stdout, re.S)
            if match:
                return json.loads(unescape(match.group(1)))
            return {"status": "failed", "details": "Browser did not return verification results. " + stderr[-1000:]}
        except (OSError, ValueError, subprocess.TimeoutExpired) as error:
            return {"status": "failed", "details": str(error)}
        finally:
            if process:
                try:
                    os.killpg(process.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                process.communicate()
