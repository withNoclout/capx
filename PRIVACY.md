# CapX privacy policy

_Last updated: July 26, 2026_

CapX is a local-only macOS application. It has no account system, network client, advertising, analytics, telemetry, or crash-reporting service. CapX does not upload screenshots or usage data.

## Data CapX accesses

CapX reads the folder you explicitly choose and image files created in that folder after monitoring starts. It uses those files to build downsampled thumbnails and to perform actions you request, such as opening, revealing, copying, or dragging a screenshot.

CapX does not use macOS Screen Recording permission, inspect the contents of other windows, or hook private screenshot APIs.

## Data CapX stores

CapX stores these settings in the current macOS user's local preferences:

- a security-scoped bookmark and fallback path for the selected folder;
- sidebar side and display selection;
- sidebar visibility and recent-item limit;
- appearance mode; and
- automatic hide and clear delays.

The Recent and Pinned collections are session-scoped and are not restored after CapX quits. Thumbnail images are held in memory. CapX does not create a separate screenshot database.

## File and clipboard behavior

Dismiss and Clear All remove entries from the CapX interface only. They do not delete or modify the original image files. Copy writes file references to the macOS pasteboard only after you request it. Open, Reveal, and drag operations are also user-initiated.

## Network activity

CapX contains no application networking code. Installing CapX, using GitHub, or using macOS services may involve network activity governed by those services, not by CapX.

## Questions

Open an issue in this repository for privacy questions, but do not attach private screenshots, folder names, bookmarks, or other sensitive information to a public issue.
