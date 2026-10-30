#!/usr/bin/env python3
"""Capture the focused screen and open Satty for cropping and annotation."""

import datetime
import json
import os
from pathlib import Path
import socket
import subprocess
import tempfile


def main():
    with tempfile.TemporaryDirectory(prefix="satty-", dir=os.environ.get("XDG_RUNTIME_DIR")) as directory:
        screenshot = Path(directory) / "capture.png"
        with socket.socket(socket.AF_UNIX) as connection:
            # Wait for the completed PNG before handing it to Satty.
            connection.settimeout(10)
            connection.connect(os.environ["NIRI_SOCKET"])
            connection.sendall(b'"EventStream"\n')
            with connection.makefile("r") as events:
                reply = json.loads(events.readline())
                if "Err" in reply:
                    raise RuntimeError(reply["Err"])
                subprocess.run(
                    ["niri", "msg", "action", "screenshot-screen", "--path", str(screenshot)],
                    check=True,
                )
                for line in events:
                    event = json.loads(line).get("ScreenshotCaptured", {})
                    if event.get("path") == str(screenshot):
                        break
                else:
                    raise RuntimeError("Niri disconnected before completing the screenshot")

        output_directory = Path.home() / "Pictures" / "Screenshots"
        output_directory.mkdir(parents=True, exist_ok=True)
        timestamp = datetime.datetime.now().strftime("%Y-%m-%d_%H-%M-%S-%f")
        subprocess.run(
            [
                str(Path.home() / ".local" / "bin" / "satty"),
                "--filename", str(screenshot),
                "--fullscreen", "current-screen",
                "--initial-tool", "crop",
                "--early-exit", "copy",
                "--copy-command", "wl-copy",
                "--output-filename", str(output_directory / f"Screenshot_{timestamp}.png"),
            ],
            check=True,
        )


if __name__ == "__main__":
    main()
