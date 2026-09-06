"""Build throwaway design alternatives on the existing playground page."""
import base64
import json
from pathlib import Path
root = Path(__file__).resolve().parent
report = json.dumps(json.loads((root / 'report.json').read_text())).replace('<', '\\u003c')
icons = {name: 'data:image/svg+xml;base64,' + base64.b64encode((root / f'vendor/{name}.svg').read_bytes()).decode() for name in ('openai', 'claude')}
logo = 'data:image/svg+xml;base64,' + base64.b64encode((root / 'assets/review-logo.svg').read_bytes()).decode()
font = base64.b64encode((root / 'vendor/dm-sans.ttf').read_bytes()).decode()
css = (root / 'designs.css').read_text() + '\n' + (root / 'flow-designs.css').read_text() + '\n' + (root / 'brand-designs.css').read_text()
css = css.replace('__DM_SANS_FONT__', font)
css += '\n/* Embedded DM Sans license:\n' + (root / 'vendor/dm-sans-LICENSE.txt').read_text().replace('*/', '* /') + '\n*/'
js = (root / 'designs.js').read_text() + '\n' + (root / 'flow-designs.js').read_text() + '\nrender();'
highlighter = (root / 'vendor/highlight.min.js').read_text().replace('</script', '<\\/script')
html = f'''<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Review design playground</title><link rel="icon" type="image/svg+xml" href="{logo}"><style>{css}</style></head><body><div id="app"></div><script id="report-data" type="application/json">{report}</script><script>{highlighter}</script><script>const agentIcons = {json.dumps(icons)}; const appLogo = {json.dumps(logo)};\n{js}</script></body></html>'''
(root / 'index.html').write_text(html)
print(root / 'index.html')
