# Racket RSS

## Goal
I want to develop a script that will create an RSS feed (technically a [JSON feed](https://jsonfeed.org/)) from a list of links that I add to my reading list.
Eventually, I want to add links from my clipboard on MacOS and from Safari on iOS, and then regularly generate an RSS file to read anywhere.

## Technical Plan:

1. Add links to a plaintext `.csv` file.
2. Generate JSON feed semi-regularly.
3. Read JSON feed from RSS clients.

## Details

### 1. Add links

- I think I will use [BitBar](https://github.com/matryer/bitbar) or similar utility (maybe [Hammerspoon](https://www.hammerspoon.org/)) on MacOS.
- I will probably write an iOS Shortcut to add articles from iOS.
- Sync the plaintext file with iCloud/Dropbox/etc.

### 2. Generate JSON feed

- I'm writing this part in Racket to learn the language, but it would make plenty of sense to use bash, Python, Go or even NodeJS.
- I'm using [`readability.js`](https://github.com/mozilla/readability) to extract plain text content.
  - I probably want a fallback of some kind when this doesn't work--probably just raw HTML with some minimal CSS.
  - I definitely want to add PDFs to this list, so I'll need a fallback for sure.
- I'll run this program regularly (twice a day?) with launchd, [inspired by this post](https://blog.jan-ahrens.eu/2017/01/13/cron-is-dead-long-live-launchd.html).
- I'll also write a bash script to commit this file to my [personal website](https://samuelstevens.me).

### 3. Read

- [NetNewsWire](https://netnewswire.com/) has a great iOS client that supports JSON feeds. I'll just add the JSON feed to my local account--badabing, badaboom, a personal RSS feed for any article I want.

...Instapaper and Pocket probably support this out of the box.

## Development

- `main.rkt` has most of the core logic and the script to execute.
- `readability.rkt` is a thin wrapper around `readability.js` to extract text content from an HTML string.
- `readinglist.rkt` parsed an existing reading list file.

## Issues

- Following redirects is a problem right now.
- Not sure how much of the JSON feed spec NetNewsWire supports. Maybe I should write it to use the original RSS XML format.
- What happens when the content isn't parsed correctly (PDFs, not "readable", etc.)?
- Slow...can I multithread?
