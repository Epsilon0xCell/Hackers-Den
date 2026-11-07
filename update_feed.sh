#!/bin/bash

# I run this script two ways: by hand from the repo root, and from the
# deploy workflow (.github/workflows/static.yml), which runs it after the
# daily update workflow has regenerated dist/. Every path below is
# relative, so the working directory has to be the repo root. Run it from
# anywhere else and the copies and edits land in the wrong place or fail.
#
# This script runs under set -euo pipefail, and the steps that matter
# most carry explicit checks on top of it. If the JAR fails or leaves
# no page behind, the script stops with an error and a nonzero exit
# instead of theming whatever dist/ already held and printing success.
# The theme insertions are verified against the finished page near the
# end, so the success lines at the bottom only print when the page
# actually carries the theme.

set -euo pipefail

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

# Preserve the service worker the same way, but to a scratch file, not
# into the backup folder. The committed dist/service-worker.js is the
# copy I trust (the update workflow writes it there from its own
# heredoc). The JAR does not generate it, so without this copy a
# regeneration that wipes dist/ would leave the registration in the
# page ending pointing at a file that is not there.
SW_PRESERVE=".service-worker.js.preserve"
rm -f "$SW_PRESERVE"
if [ -f "dist/service-worker.js" ]; then
  cp -f dist/service-worker.js "$SW_PRESERVE"
fi

# The JAR reads config.yaml from the working directory and writes the
# whole site into dist/. I pass it no arguments because it takes none
# for this use. Its exit status is checked: a failed JAR run, or a run
# that leaves dist/index.html missing or empty, stops this script with
# an error instead of theming stale output.
echo "[+] Running RSSPAPER jar to generate fresh content..."
if ! java -jar rsspaper-1.2.4-standalone.jar; then
  echo "[!] ERROR: RSSPAPER jar failed. Refusing to theme stale output." >&2
  exit 1
fi
if [ ! -s "dist/index.html" ]; then
  echo "[!] ERROR: dist/index.html is missing or empty after generation." >&2
  exit 1
fi

# Restore the service worker if the JAR did not produce one, and drop
# the scratch copy either way. If there was no committed worker to
# preserve, the page ending below registers the worker only after a
# HEAD check, so the registration never points at a missing file.
if [ ! -f "dist/service-worker.js" ] && [ -f "$SW_PRESERVE" ]; then
  cp -f "$SW_PRESERVE" dist/service-worker.js
  echo "[+] Restored dist/service-worker.js from the committed copy"
fi
rm -f "$SW_PRESERVE"

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
# One pattern survives here. An earlier version carried a pattern with
# a literal backslash n in it, which can never match: sed reads one
# line at a time, so the pattern space never holds a newline. I tested
# that against GNU sed in Comment Wave 7 and removed the dead pattern.
# The pattern below collapses a closing div directly against a closing
# header tag when both sit on the same line, which is the only form of
# this fix the generator's line layout can produce.
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
# The insert is guarded on the terminal__header marker, and the close
# step below keys off the same flag, so running this script against an
# already themed page does not stack a second wrapper inside the first.
WRAPPERS_INSERTED=0
if ! grep -q "terminal__header" dist/index.html; then
  sed -i '/<header class="article__header terminal">/a \                        <div class="terminal__header">\n                            <span class="terminal__prompt">root@hackers-den:~$ cat article</span>\n                            <span class="terminal__date"></span>\n                        </div>\n                        <div class="article__content-wrapper">' dist/index.html
  WRAPPERS_INSERTED=1
fi

# The close step is scoped to article headers, and only to them. An
# earlier version replaced every closing header tag in the page, which
# added one stray close for the site header at the top, a header that
# never opens a content wrapper. A stubbed run of that version ended
# with 253 closing div tags against 252 opening ones, measured in
# Comment Wave 7. This perl pass tracks state instead: it remembers
# passing an article header and closes the wrapper at the first header
# close that follows it, so the finished page's div counts balance.
if [ "$WRAPPERS_INSERTED" -eq 1 ]; then
  perl -i -pe 'BEGIN { $in_article = 0 } $in_article = 1 if /<header class="article__header terminal">/; if ($in_article && s|</header>|</div>\n                    </header>|) { $in_article = 0 }' dist/index.html
fi

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

# The footer match anchors on the RSSpaper credit text the generator
# emits. The heart markup inside it is matched loosely, as anything up
# to the end of its span, because the exact bytes the generator puts
# there (the heart itself and a trailing variation selector) are the
# kind of detail that changes without notice. The replacement drops
# the RSSpaper credit line and points the footer link at my current
# account, Epsilon0xCell. The old script pointed it at CY83R-3X71NC710N,
# the locked out account this project started under. The grep after
# the replace proves the match landed: if the generator ever changes
# its footer text, this run fails here instead of shipping the old
# credit line.
echo "[+] Adding your attribution to the footer..."
perl -0777 -i -pe 's|Generated with <a class="footer__link" href="https://github\.com/tanrax/RSSpaper">RSSpaper</a> and a lot of <span class="footer__heard">.*?</span>|<a class="footer__link" href="https://github.com/Epsilon0xCell/Hackers-Den">Hackers-Den by Epsilon0xCell</a>|s' dist/index.html
if ! grep -q 'github.com/Epsilon0xCell/Hackers-Den' dist/index.html; then
  echo "[!] ERROR: footer attribution did not land. The generator footer text has changed." >&2
  exit 1
fi

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
# registers service-worker.js relative to the page, and only after a
# HEAD request confirms the file is actually served: the restore step
# near the top of this script puts the committed worker back into
# dist/ when the JAR does not produce one, and this check covers any
# build path where the file is still absent, so the reader never gets
# a registration that 404s.
sed -i '/<\/body>/,/<\/html>/d' dist/index.html

cat >> dist/index.html << 'MATRIX_END'
    <!-- Matrix Animation -->
    <script>
        document.addEventListener("DOMContentLoaded", function() {
            // Initialize Matrix theme
            console.log("🔒 Initializing Hackers-Den Matrix theme...");
            // Register the service worker from the site root so its scope
            // covers the whole site (a worker under static/ cannot). The
            // registration waits on a HEAD check so it only runs when
            // service-worker.js is really there.
            if ("serviceWorker" in navigator) {
                fetch("service-worker.js", { method: "HEAD" })
                    .then(function (response) {
                        if (response.ok) {
                            navigator.serviceWorker.register("service-worker.js");
                        }
                    })
                    .catch(function () {
                        // No service worker on this build. The page
                        // works without one.
                    });
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

# The success lines below print only after this verification passes.
# Every theme insertion gets checked against the finished page by its
# exact marker, and the div counts have to balance. If the generator
# changes its output so an insert stops landing, the run fails here
# with the missing marker named, instead of shipping an unthemed or
# malformed page under a success message.
echo "[+] Verifying theme markers in the finished page..."
for marker in 'static/css/matrix.css' 'static/css/custom-matrix.css' 'static/js/matrix-effects.js' 'class="matrix-bg"' 'surveillance-notification'; do
  if ! grep -qF "$marker" dist/index.html; then
    echo "[!] ERROR: theme marker missing from dist/index.html: $marker" >&2
    exit 1
  fi
done
DIV_OPEN=$(grep -o '<div' dist/index.html | wc -l)
DIV_CLOSE=$(grep -o '</div>' dist/index.html | wc -l)
if [ "$DIV_OPEN" -ne "$DIV_CLOSE" ]; then
  echo "[!] ERROR: div counts do not balance in dist/index.html: $DIV_OPEN opening against $DIV_CLOSE closing." >&2
  exit 1
fi
echo "[+] All theme markers present, div counts balance at $DIV_OPEN"

echo "[+] Matrix theme applied successfully!"
echo "[+] Your Hackers-Den is now ready at ./dist/index.html"

# Add final success message with timestamp
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
echo "[+] Build completed at $TIMESTAMP"
echo "[+] 🔒 SECURITY CLEARANCE GRANTED: ACCESS TO HACKERS-DEN AUTHORIZED 🔒"