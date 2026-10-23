from pathlib import Path
import json,sys
r=Path(__file__).resolve().parents[1]; d=json.loads((r/'site/records.json').read_text()); h=(r/'site/index.html').read_text();assert len(d)>=8;assert all(x.get('source','').startswith('https://') for x in d);assert 'Lexington Roots Atlas' in h and '__DATA__' not in h;assert 'v0.1.0' in h;print('PASS: content, source URLs, embedded data, version')
