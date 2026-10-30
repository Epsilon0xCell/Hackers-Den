#!/bin/bash

# I run this script two ways: by hand from the repo root, and from the
# deploy workflow (.github/workflows/static.yml), which runs it after the
# daily update workflow has regenerated dist/. Every path below is
# relative, so the working directory has to be the repo root. Run it from
# anywhere else and the copies and edits land in the wrong place or fail.
#
# There is no set -e in this script and almost no exit status is checked.
# If the JAR fails, the theme steps still run against whatever dist/
# already holds, and the last lines still print success. I read the
# output, not the final line, when I want to know whether a run worked.

echo "[+] Starting RSS feed update process..."

# The backup has to happen before the JAR runs, and that order is the
# whole point of this section. The JAR regenerates dist/ and does not
# know about my theme files, so anything theme shaped that lives only in
# dist/ can be wiped by a regeneration. I copy the theme files out first,
# then copy them back in after generation, further down.
echo "[+] Ensuring theme backup is complete..."
mkdir -p matrix-theme-backup/css matrix-theme-backup/img matrix-theme-backup/js

# Each backup copy only happens if the file is in dist/ right now. On a
# fresh checkout the committed dist/ has no matrix.css at all, so these
# blocks skip and the copies already committed under matrix-theme-backup/
# are what the restore step below uses. The backup folder is the source
# I trust, not a copy the script must create first.
if [ -f "dist/static/css/matrix.css" ]; then
  echo "[+] Backing up CSS files..."
  cp -f dist/static/css/matrix.css matrix-theme-backup/css/
fi

# Backup custom-matrix.css if we already have it
if [ -f "dist/static/css/custom-matrix.css" ]; then
  cp -f dist/static/css/custom-matrix.css matrix-theme-backup/css/
fi

# Backup any JavaScript effects
if [ -f "dist/static/js/matrix-effects.js" ]; then
  echo "[+] Backing up JavaScript files..."
  cp -f dist/static/js/matrix-effects.js matrix-theme-backup/js/
fi

# The JAR reads config.yaml from the working directory and writes the
# whole site into dist/. I pass it no arguments because it takes none
# for this use. Its exit status is not checked: if it fails, the rest of
# this script themes the old dist/ and still reports success at the end.
echo "[+] Running RSSPAPER jar to generate fresh content..."
java -jar rsspaper-1.2.4-standalone.jar

# Create necessary directories
mkdir -p dist/static/js dist/static/img

# Step 2: Apply Matrix theme customizations
echo "[+] Applying Matrix theme customizations..."

# Ensure static directories exist
mkdir -p dist/static/css dist/static/js dist/static/fonts dist/static/img

# Copy matrix.css to dist folder
cp -f matrix-theme-backup/css/matrix.css dist/static/css/
echo "[+] Matrix theme CSS copied"

# Copy custom-matrix.css to dist folder
cp -f matrix-theme-backup/css/custom-matrix.css dist/static/css/
echo "[+] Custom matrix theme CSS copied"

# Copy matrix-effects.js to dist folder
cp -f matrix-theme-backup/js/matrix-effects.js dist/static/js/
echo "[+] Matrix theme JavaScript effects copied"

# Copy the newsreader-not-cover.png to the static/img directory
echo "[+] Copying newsreader-not-cover.png fallback image..."
cp -f newsreader-not-cover.png dist/static/img/
echo "[+] Image copied to dist/static/img/newsreader-not-cover.png"

# This block is guarded on the directory, not on the font files. Once
# the directory exists, even empty, the block never runs again. On the
# current tree it always takes the warning branch: the zip it looks for
# was removed after it turned out to be a saved web page, not an archive,
# and the Google Fonts link added further down is the font path the site
# actually uses.
if [ ! -d "dist/static/fonts/source-code-pro" ]; then
  echo "[+] Installing Source Code Pro font..."
  mkdir -p dist/static/fonts/source-code-pro
  
  if [ -f "source-code-pro.zip" ]; then
    if unzip -o source-code-pro.zip -d dist/static/fonts/source-code-pro; then
      echo "[+] Font installed"
    else
      echo "[!] Warning: source-code-pro.zip could not be extracted. Using web font instead."
    fi
  else
    echo "[!] Warning: source-code-pro.zip not found. Using web font instead."
  fi
fi

# The guard greps the whole page for the word matrix.css, and the insert
# is anchored on the exact desktop.css link line the generator emits,
# media attribute included. If the generator changes that line, the sed
# matches nothing, no link is added, and the page ships without the
# theme while this script still prints success. I check the output for
# the two links instead of trusting the echo.
echo "[+] Updating stylesheet references..."
if ! grep -q "matrix.css" dist/index.html; then
  sed -i 's|<link href="static/css/desktop.css" rel="stylesheet" media="all and (min-width: 601px)">|<link href="static/css/desktop.css" rel="stylesheet" media="all and (min-width: 601px)">\n    <link rel="stylesheet" href="static/css/matrix.css">\n    <link rel="stylesheet" href="static/css/custom-matrix.css">|' dist/index.html
fi

# This insert puts the script tag in front of the closing body tag. It
# has to stay in front of it: near the end of this script I delete
# everything from the closing body tag to the end of the file and append
# a fresh ending, and a script tag sitting after the body tag would be
# deleted by that step.
echo "[+] Adding JavaScript references..."
if ! grep -q "matrix-effects.js" dist/index.html; then
  sed -i 's|</body>|<script src="static/js/matrix-effects.js"></script>\n</body>|' dist/index.html
fi

echo "[+] Fixing HTML structure..."
# The first of these three patterns can never match. It contains a
# literal backslash n, and sed reads one line at a time, so the pattern
# space never holds a newline for it to match against. I tested that
# against GNU sed in Comment Wave 7. The third pattern is the one that
# does this job, and only when both tags sit on the same line.
sed -i 's|</div>\n                    </header>|</header>|g' dist/index.html
sed -i 's|<hr class="separator">|<hr class="separator">|g' dist/index.html
sed -i 's|</div>\s*</header>|</header>|g' dist/index.html

# Both this insert and the surveillance banner below anchor on the body
# line, and each new insert goes directly under that line. The banner
# step runs second, so in the finished page the banner sits above the
# matrix-bg div even though the background was inserted first. I verified
# that order in a stubbed run: banner first, then matrix-bg.
echo "[+] Adding Matrix background animation..."
if ! grep -q "matrix-bg" dist/index.html; then
  sed -i '/<body>/a \    <!-- Matrix Background -->\n    <div class="matrix-bg">\n        <div class="matrix-rain" id="matrix-rain"></div>\n    </div>' dist/index.html
fi

# Add surveillance notification banner
echo "[+] Adding surveillance notification banner..."
if ! grep -q "surveillance-notification" dist/index.html; then
  sed -i '/<body>/a \    <!-- Surveillance Notification -->\n    <div class="surveillance-notification">THIS CONNECTION IS BEING MONITORED</div>' dist/index.html
fi

# The match is the exact header tag with no other attributes. If the
# generator ever emits an extra attribute on article headers, this
# replace and the terminal header insert that depends on it both miss,
# and the articles ship unthemed with no error anywhere.
echo "[+] Adding terminal styling to articles..."
sed -i 's|<header class="article__header">|<header class="article__header terminal">|g' dist/index.html

# Fix article structure
echo "[+] Restructuring articles for terminal style..."
# Fix article header images - replace only the header image <p> element
# with a <div>, including its own closing tag. A global </p> replacement
# would corrupt every paragraph in the generated articles.
perl -0777 -i -pe 's|<p class="article__header-img">(.*?)</p>|<div class="article__header-img">$1</div>|gs' dist/index.html

# The terminal date span is left empty here on purpose. matrix-effects.js
# fills every .terminal__date with the reader's current date and time
# when the page loads, so the date on a themed article is the day it is
# read, not the day the article was published.
sed -i '/<header class="article__header terminal">/a \                        <div class="terminal__header">\n                            <span class="terminal__prompt">root@hackers-den:~$ cat article</span>\n                            <span class="terminal__date"></span>\n                        </div>\n                        <div class="article__content-wrapper">' dist/index.html

# This close step is broader than the open step above, and that mismatch
# costs one stray tag. The opens happen only after article headers, but
# this replace fires on every closing header tag in the page, including
# the site header at the top, which never opened a content wrapper. A
# stubbed run of this script ends with 253 closing div tags against 252
# opening ones. The extra close is ignored by browsers, which is why it
# has survived, but the count is real and I measured it in Comment Wave 7.
sed -i 's|</header>|</div>\n                    </header>|g' dist/index.html

# Every replace in this block is an exact match on text the generator
# emits by default. Two theme-color lines are targeted because the
# generator output carries the color in two forms, one tag ending
# without a slash and one with. If a default string changes upstream,
# that one replace quietly does nothing.
echo "[+] Updating page metadata..."
sed -i 's|<meta name="description" content="My static news generator">|<meta name="description" content="Hackers-Den - Matrix-themed cybersecurity and hacking news aggregator">|' dist/index.html
sed -i 's|<meta name="generator" content="RSSPAPER">|<meta name="generator" content="Hackers-Den">|' dist/index.html
sed -i 's|<meta name="theme-color" content="#2e3440">|<meta name="theme-color" content="#000000">|' dist/index.html
sed -i 's|<meta name="theme-color" content="#5e81ac" />|<meta name="theme-color" content="#00ff00" />|' dist/index.html

# Update the subtitle
echo "[+] Updating site subtitle..."
sed -i 's|<span class="subtitle__separator">~</span> <span class="subtitle__text">My static generate newspaper</span> <span class="subtitle__separator">~</span>|<span class="subtitle__separator">[</span> <span class="subtitle__text">Cybersecurity Intelligence</span> <span class="subtitle__separator">]</span>|' dist/index.html

# The footer match includes the heart character the generator emits.
# The replacement drops the RSSpaper credit line and points the footer
# link at the CY83R-3X71NC710N address this project used when I wrote
# the script.
echo "[+] Adding your attribution to the footer..."
sed -i 's|Generated with <a class="footer__link" href="https://github.com/tanrax/RSSpaper">RSSpaper</a> and a lot of <span class="footer__heard">❤️</span>️|<a class="footer__link" href="https://github.com/CY83R-3X71NC710N/Hackers-Den">Hackers-Den By CY83R-3X71NC710N</a>|' dist/index.html

# The guard is the word preload anywhere in the page, not these three
# links. It passes on the generator output I have now, which contains no
# preload at all. If a future template adds any preload link of its own,
# and the themes/matrix template in this repo already carries one for
# the Newsreader font, this block is skipped and the Source Code Pro
# stylesheet never gets added.
echo "[+] Adding font preloading for performance..."
if ! grep -q "preload" dist/index.html; then
  sed -i '/<head>/a \    <link rel="preconnect" href="https://fonts.googleapis.com">\n    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>\n    <link href="https://fonts.googleapis.com/css2?family=Source+Code+Pro:wght@400;700&display=swap" rel="stylesheet">' dist/index.html
fi

# Add article numbers as custom properties for staggered animations
echo "[+] Adding article indexing for animations..."
# The generator emits <article class="feed__article article">, and the file
# must not be edited with sed while a shell loop is still reading it, so the
# numbering is done in a single perl pass in document order.
perl -i -pe 'BEGIN { $i = 0 } s|<article class="feed__article article">|"<article class=\"feed__article article\" style=\"--article-index: " . $i++ . "\">" |ge' dist/index.html

# The anchor is the favicon link line. The guard greps for manifest.json
# anywhere in the page, so a manifest link in any other form also counts
# as present and this insert is skipped.
echo "[+] Adding PWA support..."
if ! grep -q "manifest.json" dist/index.html; then
  sed -i '/<link rel="icon"/a \    <link rel="manifest" href="manifest.json">' dist/index.html
fi

# Create .nojekyll file to prevent GitHub Pages from using Jekyll processing
echo "[+] Creating .nojekyll file to prevent GitHub Pages Jekyll processing..."
touch ./dist/.nojekyll

echo "[+] Ensuring script is inside body tag..."
# This deletes from the first closing body tag to the end of the file,
# whatever the generator put there, and the heredoc below writes the
# only ending the finished page gets. The inline script in that ending
# registers service-worker.js relative to the page. This script never
# creates that file: it comes from the committed dist/ or from the step
# in update.yml that writes it, so a build path that does neither gives
# the reader a registration that 404s.
sed -i '/<\/body>/,/<\/html>/d' dist/index.html

cat >> dist/index.html << 'MATRIX_END'
    <!-- Matrix Animation -->
    <script>
        document.addEventListener("DOMContentLoaded", function() {
            // Initialize Matrix theme
            console.log("🔒 Initializing Hackers-Den Matrix theme...");
            // Register the service worker from the site root so its scope
            // covers the whole site (a worker under static/ cannot).
            if ("serviceWorker" in navigator) {
                navigator.serviceWorker.register("service-worker.js");
            }
        });
    </script>
</body>
</html>
MATRIX_END

# This rewrites .vscode/extensions.json on every run with no check. Any
# recommendation I add to that file by hand is gone after the next run
# of this script.
echo "[+] Adding VSCode extension recommendations..."
mkdir -p .vscode
cat > .vscode/extensions.json << 'EOL'
{
  "recommendations": [
    "ritwickdey.liveserver",
    "dbaeumer.vscode-eslint",
    "esbenp.prettier-vscode"
  ]
}
EOL

# As noted at the top, this line prints even when steps above failed.
# The checks I trust are the ones I run on the output file itself: tag
# counts, the article index count, and the theme references.
echo "[+] Matrix theme applied successfully!"
echo "[+] Your Hackers-Den is now ready at ./dist/index.html"

# Add final success message with timestamp
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
echo "[+] Build completed at $TIMESTAMP"
echo "[+] 🔒 SECURITY CLEARANCE GRANTED: ACCESS TO HACKERS-DEN AUTHORIZED 🔒"