#!/usr/bin/env python3
"""Update local feed and website metadata from the notarized, signed artifact."""
import email.utils
import html
import json
import os
import plistlib
import re
from pathlib import Path
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parent.parent


def notes_html(text):
    """Render release notes Markdown (paragraphs, - bullets, `code`) as HTML for Sparkle."""
    blocks, bullets = [], []
    inline = lambda line: re.sub(r'`([^`]+)`', r'<code>\1</code>', html.escape(line.strip(), quote=False))
    for line in text.splitlines() + ['']:
        if line.startswith('- '):
            bullets.append(f'<li>{inline(line[2:])}</li>')
            continue
        if bullets:
            blocks.append(f'<ul>{"".join(bullets)}</ul>')
            bullets = []
        if line.strip():
            blocks.append(f'<p>{inline(line)}</p>')
    return '\n'.join(blocks)


release = Path(os.environ.get('RELEASE_DIR', root / 'dist'))
info = plistlib.loads((release / 'export/nowish.app/Contents/Info.plist').read_bytes())
version, build = info['CFBundleShortVersionString'], info['CFBundleVersion']
assert re.fullmatch(r'\d+\.\d+\.\d+', version), 'Expected semantic version'
assert str(build).isdigit()
notes_path = root / f'release-notes/{version}.md'
assert notes_path.is_file(), f'Write {notes_path.relative_to(root)} before publishing'
notes = notes_html(notes_path.read_text())
assert notes, 'Release notes are empty'
assert json.loads((release / 'app-notarization.json').read_text())['status'] == 'Accepted'
assert json.loads((release / 'dmg-notarization.json').read_text())['status'] == 'Accepted'
attributes = dict(re.findall(r'(sparkle:edSignature|length)="([^"]+)"', (release / 'sparkle-signature.txt').read_text()))
assert int(attributes['length']) == (release / 'Nowish.dmg').stat().st_size
ns = 'http://www.andymatuschak.org/xml-namespaces/sparkle'
ET.register_namespace('sparkle', ns)
feed = ET.parse(root / 'appcast.xml')
channel = feed.getroot().find('channel')
assert channel is not None
builds = [int(item.findtext(f'{{{ns}}}version')) for item in channel.findall('item')]
assert not builds or int(build) > max(builds), 'Build number must increase'
url = f'https://github.com/noelrohi/nowish/releases/download/v{version}/Nowish.dmg'
item = ET.Element('item')
ET.SubElement(item, 'title').text = f'Nowish {version}'
ET.SubElement(item, 'pubDate').text = email.utils.formatdate(usegmt=True)
ET.SubElement(item, f'{{{ns}}}version').text = str(build)
ET.SubElement(item, f'{{{ns}}}shortVersionString').text = version
ET.SubElement(item, f'{{{ns}}}minimumSystemVersion').text = info['LSMinimumSystemVersion']
ET.SubElement(item, 'description').text = notes
ET.SubElement(item, 'enclosure', {
    'url': url, 'type': 'application/octet-stream',
    f'{{{ns}}}edSignature': attributes['sparkle:edSignature'], 'length': attributes['length']
})
channel.insert(3, item)
ET.indent(feed, space='  ')
feed.write(root / 'appcast.xml', encoding='utf-8', xml_declaration=True)
(root / 'site/release.json').write_text(json.dumps({'version': version, 'url': url}, indent=2) + '\n')
print(f'Prepared feed for v{version}, build {build}')
