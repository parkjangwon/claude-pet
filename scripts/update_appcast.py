#!/usr/bin/env python3
"""
appcast.xml 에 새 <item> 블록을 삽입한다.

사용 예:
    python3 scripts/update_appcast.py \
        --version 1.0.7 \
        --signature "abc123==" \
        --length 4194758 \
        --appcast docs/appcast.xml
"""

import argparse
import re
import sys
from datetime import datetime, timezone, timedelta
from pathlib import Path


REPO = "cchh494/claude-pet"
KST = timezone(timedelta(hours=9))


def infer_build_number(appcast_text: str, version: str) -> str:
    """
    appcast.xml 에 있는 기존 sparkle:version 값들 중 최대값 + 1 을 반환.
    없으면 버전의 patch 번호를 사용.
    """
    builds = [
        int(m.group(1))
        for m in re.finditer(r"<sparkle:version>(\d+)</sparkle:version>", appcast_text)
    ]
    if builds:
        return str(max(builds) + 1)
    parts = version.split(".")
    return parts[-1] if parts else "1"


def build_item_block(version: str, build: str, signature: str, length: str) -> str:
    pub_date = datetime.now(KST).strftime("%a, %d %b %Y %H:%M:%S +0900")
    url = f"https://github.com/{REPO}/releases/download/v{version}/ClaudePet.zip"
    notes_url = f"https://github.com/{REPO}/releases/tag/v{version}"

    return (
        f"        <item>\n"
        f"            <title>Version {version}</title>\n"
        f"            <sparkle:releaseNotesLink>{notes_url}</sparkle:releaseNotesLink>\n"
        f"            <pubDate>{pub_date}</pubDate>\n"
        f"            <sparkle:shortVersionString>{version}</sparkle:shortVersionString>\n"
        f"            <sparkle:version>{build}</sparkle:version>\n"
        f"            <enclosure\n"
        f'                url="{url}"\n'
        f'                sparkle:edSignature="{signature}"\n'
        f'                length="{length}"\n'
        f'                type="application/octet-stream"/>\n'
        f"        </item>\n"
    )


def version_already_exists(appcast_text: str, version: str) -> bool:
    pattern = rf"<sparkle:shortVersionString>{re.escape(version)}</sparkle:shortVersionString>"
    return re.search(pattern, appcast_text) is not None


def insert_item(appcast_text: str, item_block: str) -> str:
    """
    appcast.xml 의 <channel> 안, 첫 번째 <item> 바로 앞에 새 item 을 삽입한다.
    기존 <item> 이 없으면 </channel> 앞에 삽입한다.
    """
    first_item_match = re.search(r"^(\s*)<item>", appcast_text, re.MULTILINE)
    if first_item_match:
        insert_pos = first_item_match.start()
        return appcast_text[:insert_pos] + item_block + "\n" + appcast_text[insert_pos:]

    close_channel_match = re.search(r"^(\s*)</channel>", appcast_text, re.MULTILINE)
    if close_channel_match:
        insert_pos = close_channel_match.start()
        return appcast_text[:insert_pos] + item_block + appcast_text[insert_pos:]

    raise RuntimeError("Could not find <item> or </channel> in appcast.xml")


def main() -> int:
    parser = argparse.ArgumentParser(description="Update appcast.xml with a new release item")
    parser.add_argument("--version", required=True, help="Marketing version, e.g. 1.0.7")
    parser.add_argument("--build", help="Build number (sparkle:version). Auto-derived if omitted.")
    parser.add_argument("--signature", required=True, help="EdDSA signature (base64)")
    parser.add_argument("--length", required=True, help="ZIP file size in bytes")
    parser.add_argument("--appcast", default="docs/appcast.xml", help="Path to appcast.xml")
    args = parser.parse_args()

    appcast_path = Path(args.appcast)
    if not appcast_path.exists():
        print(f"❌ appcast.xml not found at {appcast_path}", file=sys.stderr)
        return 1

    text = appcast_path.read_text(encoding="utf-8")

    if version_already_exists(text, args.version):
        print(f"⚠️  Version {args.version} already in appcast.xml — skipping insert")
        return 0

    build = args.build or infer_build_number(text, args.version)
    item_block = build_item_block(args.version, build, args.signature, args.length)

    new_text = insert_item(text, item_block)
    appcast_path.write_text(new_text, encoding="utf-8")

    print(f"✅ Inserted v{args.version} (build {build}) into {appcast_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
