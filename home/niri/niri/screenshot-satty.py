#!/usr/bin/env python3
"""Select a region with Niri, then annotate it with Satty."""

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
            # Subscribe before opening the selector, so even fast captures are received.
            connection.settimeout(300)
            connection.connect(os.environ["NIRI_SOCKET"])
            connection.sendall(b'"EventStream"\n')
            with connection.makefile("r") as events:
                reply = json.loads(events.readline())
                if "Err" in reply:
                    raise RuntimeError(reply["Err"])
                subprocess.run(
                    ["niri", "msg", "action", "screenshot", "--path", str(screenshot)],
                    check=True,
                )
                try:
                    for line in events:
                        event = json.loads(line).get("ScreenshotCaptured", {})
                        if event.get("path") == str(screenshot):
                            break
                    else:
                        return
                except TimeoutError:
                    # Escape cancels the selector without emitting a capture event.
                    return

        output_directory = Path.home() / "Pictures" / "Screenshots"
        output_directory.mkdir(parents=True, exist_ok=True)
        timestamp = datetime.datetime.now().strftime("%Y-%m-%d_%H-%M-%S-%f")
        subprocess.run(
            [
                str(Path.home() / ".local" / "bin" / "satty"),
                "--filename", str(screenshot),
                "--output-filename", str(output_directory / f"Screenshot_{timestamp}.png"),
            ],
            check=True,
        )


if __name__ == "__main__":
    main()
