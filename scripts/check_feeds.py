#!/usr/bin/env python3
# I wrote this script because the feed list in config.yaml used to rot
# in silence: nothing checked it, so a dead feed stayed listed until I
# noticed by hand, and one of them (Threatpost) had been serving a
# newest item from 2022 for years. This script is the check I run
# before I trust a config change and whenever I suspect a source died.
#
# It reads every feed URL out of config.yaml, fetches each one, and
# reports three things per feed: the HTTP status after redirects,
# whether the body parses as RSS or Atom, and the date of the newest
# item it carries. A feed counts as dead if the fetch fails, the body
# does not parse, it carries no items, or its newest item is more than
# 90 days old, which is the same line I prune config.yaml at. The
# script exits nonzero if any feed is dead, so it can gate a change.
#
# Usage: python3 scripts/check_feeds.py [path-to-config.yaml]

import re
import sys
import urllib.request
import urllib.error
import xml.etree.ElementTree as ET
from datetime import datetime, timezone
from email.utils import parsedate_to_datetime

STALE_DAYS = 90
TIMEOUT = 25
HEADERS = {"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) HackersDen-FeedCheck/1.0"}


def feed_urls(config_path):
    urls = []
    in_feeds = False
    with open(config_path) as fh:
        for line in fh:
            if line.startswith("feeds:"):
                in_feeds = True
                continue
            if in_feeds:
                m = re.match(r"\s+-\s+(https?://\S+)\s*$", line)
                if m:
                    urls.append(m.group(1))
    return urls


def parse_date(text):
    if not text:
        return None
    text = text.strip()
    try:
        d = parsedate_to_datetime(text)
        if d is not None:
            return d if d.tzinfo else d.replace(tzinfo=timezone.utc)
    except (TypeError, ValueError):
        pass
    try:
        d = datetime.fromisoformat(text.replace("Z", "+00:00"))
        return d if d.tzinfo else d.replace(tzinfo=timezone.utc)
    except ValueError:
        return None


def check(url, now):
    req = urllib.request.Request(url, headers=HEADERS)
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
            status = resp.status
            body = resp.read()
    except urllib.error.HTTPError as e:
        return ("DEAD", f"HTTP {e.code}", "-", "-")
    except Exception as e:  # timeouts, DNS, TLS: all mean no feed today
        return ("DEAD", f"{type(e).__name__}: {e}", "-", "-")
    try:
        root = ET.fromstring(body)
    except ET.ParseError as e:
        return ("DEAD", f"HTTP {status} but body does not parse ({e})", "-", "-")
    items = [el for el in root.iter()
             if el.tag == "item" or el.tag.endswith("}item")
             or el.tag == "entry" or el.tag.endswith("}entry")]
    if not items:
        return ("DEAD", f"HTTP {status}, parses, but carries no items", "0", "-")
    dates = []
    for item in items:
        for child in item:
            tag = child.tag.split("}")[-1]
            if tag in ("pubDate", "published", "updated", "date") and child.text:
                d = parse_date(child.text)
                if d is not None:
                    dates.append(d)
                break
    if not dates:
        return ("DEAD", f"HTTP {status}, {len(items)} items, none dated", str(len(items)), "-")
    newest = max(dates)
    age = (now - newest).days
    label = "STALE" if age > STALE_DAYS else "OK"
    return (label, f"HTTP {status}", str(len(items)), newest.date().isoformat())


def main():
    config_path = sys.argv[1] if len(sys.argv) > 1 else "config.yaml"
    urls = feed_urls(config_path)
    if not urls:
        print(f"No feed URLs found in {config_path}", file=sys.stderr)
        return 2
    now = datetime.now(timezone.utc)
    dead = 0
    print(f"Checking {len(urls)} feeds from {config_path} "
          f"(stale line: {STALE_DAYS} days, checked {now.date().isoformat()})")
    for url in urls:
        label, status, count, newest = check(url, now)
        if label != "OK":
            dead += 1
        print(f"{label:5s}  {status:45s} items={count:>5s}  newest={newest:12s} {url}")
        sys.stdout.flush()
    if dead:
        print(f"\n{dead} feed(s) dead or stale. Prune or fix them in config.yaml.")
        return 1
    print(f"\nAll {len(urls)} feeds alive with recent items.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
