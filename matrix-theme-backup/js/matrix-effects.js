/**
 * I wrote this file as the runtime half of the theme. update_feed.sh
 * copies it into dist/static/js/ and the themed page loads it there.
 * The name says Matrix and most of the site copy says green, but the
 * colors I actually paint with in this file are red: the rain builds
 * its color from a red channel of 200 or more with green and blue
 * usually at 0, and addDynamicStyles() below sets a variable named
 * --terminal-green to #cc0000, which is red. I keep the names as they
 * are and note the mismatch here instead of pretending they agree.
 * The surveillance pieces are decoration. The disclaimer function at
 * the bottom of the startup list says so on the page itself.
 */

// Everything starts on DOMContentLoaded, in the order written here.
// The order matters twice: updateTerminalDates() can only fill the
// terminal date spans that update_feed.sh inserted if they are in the
// DOM already, and addDynamicStyles() runs last, so the style element
// it appends lands after every other sheet in the head and wins ties.
document.addEventListener('DOMContentLoaded', function() {
  // Initialize the Matrix rain animation with hacker-themed elements
  initHackerRain();
  
  // Add cybersecurity-themed interactive effects
  addInteractiveEffects();
  
  // Initialize article sequencing for a staggered reveal effect
  initArticleSequencing();
  
  // Add terminal date timestamps to all terminal headers
  updateTerminalDates();
  
  // Add fictional hacker-themed elements
  addFictionalSurveillanceElements();
  
  // Add disclaimer about fictional nature to ensure no legal issues
  addFictionalDisclaimer();

  // Make sure Matrix effect extends to full page height
  adjustMatrixHeight();
  
  // Add event listener to adjust Matrix height on window resize
  window.addEventListener('resize', adjustMatrixHeight);
  
  // Add event listener to adjust Matrix height when page content changes
  window.addEventListener('scroll', checkAndAdjustMatrixHeight);
  
  // Add data overlay to make sure content is readable
  addDynamicStyles();
});

/**
 * Initialize the advanced hacker-themed digital rain animation
 */
function initHackerRain() {
  // The container is the div with id matrix-rain. update_feed.sh inserts
  // that div into the generated page, and the theme templates carry it
  // by hand. If neither did, this function returns and the rest of the
  // file still runs: no rain, but the other effects are independent.
  const matrixContainer = document.getElementById('matrix-rain');
  if (!matrixContainer) return;
  
  // Create a canvas element for the Matrix rain
  const canvas = document.createElement('canvas');
  matrixContainer.appendChild(canvas);
  
  // Get the 2D context of the canvas
  const ctx = canvas.getContext('2d');
  
  // The width is the window width at load and is never set again. The
  // resize listener calls adjustMatrixHeight(), which changes heights
  // only, so a window made wider after load leaves a strip on the right
  // with no rain. The height takes the largest of five measurements of
  // the same document, because they disagree across browsers, plus 200.
  canvas.width = window.innerWidth;
  canvas.height = Math.max(
    document.body.scrollHeight,
    document.body.offsetHeight,
    document.documentElement.clientHeight,
    document.documentElement.scrollHeight,
    document.documentElement.offsetHeight
  ) + 200; // Add extra height to ensure it covers the entire page
  
  // Set the font for the Matrix rain characters
  const fontSize = 14;
  
  // Calculate the number of drops based on canvas width
  const drops = [];
  const columns = Math.ceil(canvas.width / fontSize);
  
  // Each drop starts above the canvas, at a negative row. The start
  // range is the full canvas height in rows, so on a long page some
  // columns stay empty for a long while before their first character
  // arrives. That stagger is what keeps the first screen from filling
  // all at once.
  for (let i = 0; i < columns; i++) {
    drops[i] = Math.floor(Math.random() * -canvas.height / fontSize);
  }
  
  // Create array for text brightness
  const brightness = [];
  for (let i = 0; i < columns; i++) {
    brightness[i] = 0.5 + Math.random() * 0.5;
  }
  
  // Create array for drop speeds
  const speeds = [];
  for (let i = 0; i < columns; i++) {
    speeds[i] = 0.5 + Math.random() * 1.5;
  }
  
  // I weighted this list on purpose. Binary digits appear in two runs,
  // at the start and again at the end, so they come up far more often
  // than any other character. Drawing picks uniformly from the array,
  // so the duplicates are the weighting.
  const hackerChars = [
    '0', '1', '0', '0', '1', // More binary for hacker feel
    'a', 'b', 'c', 'd', 'e', 'f', 
    'A', 'B', 'C', 'D', 'E', 'F',
    '!', '@', '#', '$', '%', '^', '&', '*',
    '[', ']', '{', '}', '<', '>', '/',
    '⌘', '⌥', '⇧', '⌃', '⎋', '⏏', '⏎',
    '░', '▒', '▓', '█', '▄', '▀', '■', '▪', '●',
    'α', 'β', 'Δ', 'π', 'μ', 'Ω', 'λ',
    '0', '1', '0', '1', '0', '1' // Extra binary for the hacker look
  ];
  
  // Special hacker phrases to occasionally insert
  const hackerPhrases = [
    "BREACH",
    "ACCESS",
    "DENIED",
    "ROOT",
    "ADMIN",
    "HACK",
    "SECURE",
    "CRYPTO",
    "SYSTEM",
    "KERNEL"
  ];
  
  // Matrix rain drawing function with hacker twist
  function drawHackerRain() {
    // Add a semi-transparent black rectangle to create the fade effect
    ctx.fillStyle = "rgba(0, 0, 0, 0.05)";
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    
    // At roughly 60 frames a second, a 0.003 chance per frame lands a
    // horizontal phrase about once every five or six seconds. The
    // phrase is painted once, in a single frame, and the fade fill on
    // the next frames is what erases it, so it reads as a flash.
    if (Math.random() > 0.997) {
      const phrase = hackerPhrases[Math.floor(Math.random() * hackerPhrases.length)];
      const x = Math.random() * (canvas.width - 200);
      const y = Math.random() * canvas.height;
      
      ctx.font = "bold 24px 'Source Code Pro', monospace";
      ctx.fillStyle = `rgba(255, 0, 0, 0.7)`;
      ctx.fillText(phrase, x, y);
    }
    
    // Loop through each column to draw characters
    for (let i = 0; i < drops.length; i++) {
      // Random chance to display a hacker phrase vertically
      if (Math.random() > 0.99 && Math.random() > 0.8) {
        const phrase = hackerPhrases[Math.floor(Math.random() * hackerPhrases.length)];
        if (drops[i] * fontSize > 0) {
          for (let j = 0; j < phrase.length; j++) {
            if (drops[i] * fontSize + j * fontSize < canvas.height) {
              // Red color theme for hacker feel
              ctx.fillStyle = `rgba(255, 0, 0, ${brightness[i] * 0.8})`;
              ctx.font = `${fontSize * 0.8}px 'Source Code Pro', monospace`;
              ctx.fillText(phrase[j], i * fontSize, drops[i] * fontSize + j * fontSize);
            }
          }
        }
      } else {
        // Calculate position
        const x = i * fontSize;
        const y = drops[i] * fontSize;
        
        // Use red color scheme for hacker feel, vary brightness
        let colorR = Math.floor(200 * brightness[i] + 50); // More red for hacker theme
        let colorG = Math.floor(50 * brightness[i] * (Math.random() > 0.8 ? 1 : 0));
        let colorB = Math.floor(50 * brightness[i] * (Math.random() > 0.9 ? 1 : 0));
        
        ctx.fillStyle = `rgba(${colorR}, ${colorG}, ${colorB}, ${brightness[i]})`;
        
        // Set font size with slight variation
        const actualFontSize = fontSize * (0.9 + Math.random() * 0.2);
        ctx.font = `${actualFontSize}px 'Source Code Pro', monospace`;
        
        // Draw the character
        const char = hackerChars[Math.floor(Math.random() * hackerChars.length)];
        ctx.fillText(char, x, y);
        
        // A drop past the bottom does not reset at once. It resets on
        // a 1 percent chance per frame, so most drops fall some way off
        // the canvas before they restart. The column is blank for that
        // stretch, which is part of why the rain looks uneven.
        if (y > canvas.height && Math.random() > 0.99) {
          drops[i] = 0;
          
          // Randomize brightness and speed for variety
          brightness[i] = 0.5 + Math.random() * 0.5;
          speeds[i] = 0.5 + Math.random() * 1.5;
        }
        
        // Increment drop position based on speed
        drops[i] += speeds[i];
      }
    }
    
    // Add horizontal scan lines for hacker effect
    for (let i = 0; i < canvas.height; i += 100) {
      if (Math.random() > 0.985) {
        const scanOpacity = 0.1 + Math.random() * 0.2;
        ctx.fillStyle = `rgba(255, 0, 0, ${scanOpacity})`;
        ctx.fillRect(0, i, canvas.width, 1);
      }
    }
    
    // Continue animation
    requestAnimationFrame(drawHackerRain);
  }
  
  // Start the animation
  drawHackerRain();
}

// Setting canvas.height here also clears the canvas, because assigning
// to a canvas dimension resets its surface. The rain redraws on the
// next animation frame, so the clear shows as at most one blank frame.
// This function never touches canvas.width, which is the resize gap I
// noted in initHackerRain().
function adjustMatrixHeight() {
  const matrixBg = document.querySelector('.matrix-bg');
  if (matrixBg) {
    // Set the height to match the document height, ensuring it covers everything
    const docHeight = Math.max(
      document.body.scrollHeight,
      document.body.offsetHeight,
      document.documentElement.clientHeight,
      document.documentElement.scrollHeight,
      document.documentElement.offsetHeight
    );
    matrixBg.style.height = docHeight + 'px';
    
    // Also adjust any canvas elements
    const canvas = matrixBg.querySelector('canvas');
    if (canvas) {
      canvas.height = docHeight;
    }
  }
}

// Scroll events fire far more often than I want to measure the
// document. The flag on window means a burst of scroll events schedules
// one recalculation, and the flag clears inside the frame callback, so
// the next burst can schedule another.
function checkAndAdjustMatrixHeight() {
  // Use requestAnimationFrame to avoid excessive height recalculations
  if (!window.matrixHeightRAF) {
    window.matrixHeightRAF = true;
    requestAnimationFrame(() => {
      adjustMatrixHeight();
      window.matrixHeightRAF = false;
    });
  }
}

/**
 * Add fictional NSA/Government surveillance-themed elements and effects
 * Note: This is entirely fictional and for entertainment purposes only
 */
function addFictionalSurveillanceElements() {
  // The three pieces in this function guard themselves differently.
  // The scanline is appended with no check at all. The camera block
  // checks for an existing .surveillance-cam first, and the backup
  // template page carries one in its markup, so on that page this
  // block skips and the static empty div stays as it is. The access
  // tracker is always built, and only its insertion is guarded.
  const scanline = document.createElement('div');
  scanline.className = 'surveillance-scanline';
  scanline.setAttribute('aria-hidden', 'true'); // This is decorative
  document.body.appendChild(scanline);
  
  // Add simulated surveillance camera effect in the bottom center
  const surveillanceCam = document.querySelector('.surveillance-cam');
  if (!surveillanceCam) {
    const camEffect = document.createElement('div');
    camEffect.className = 'surveillance-cam';
    camEffect.style.top = 'auto'; // Override the default top position
    camEffect.style.bottom = '15px'; // Position at bottom
    camEffect.style.right = '50%'; // Center horizontally
    camEffect.style.transform = 'translateX(50%)'; // Center adjustment
    camEffect.style.zIndex = '10001'; // Ensure it's above other elements
    camEffect.setAttribute('aria-hidden', 'true'); // This is decorative
    document.body.appendChild(camEffect);
    
    // Create the red recording dot
    const recDot = document.createElement('div');
    recDot.className = 'recording-dot';
    recDot.setAttribute('aria-hidden', 'true'); // This is decorative
    camEffect.appendChild(recDot);
    
    // Create camera text
    const camText = document.createElement('div');
    camText.className = 'camera-text';
    camText.textContent = '[ RECORDING ]';
    camText.setAttribute('aria-hidden', 'true'); // This is decorative
    camEffect.appendChild(camText);
  }
  
  // The IP address and the file count in this markup are random
  // numbers made on the reader's machine at load. They are set
  // dressing, not a log of anything, and they change on every load.
  const accessTracker = document.createElement('div');
  accessTracker.className = 'access-tracker';
  accessTracker.innerHTML = `
    <div class="access-tracker__header">SYSTEM ACCESS LOG:</div>
    <div class="access-tracker__item">Login from IP ${Math.floor(Math.random() * 255)}.${Math.floor(Math.random() * 255)}.${Math.floor(Math.random() * 255)}.${Math.floor(Math.random() * 255)}</div>
    <div class="access-tracker__item">Data files accessed: ${Math.floor(Math.random() * 100) + 20}</div>
    <div class="access-tracker__item blinking">Recording session</div>
  `;
  
  // The backup template page already carries a static .access-tracker
  // in its markup, so on that page this insertion is skipped and the
  // static lines stay. On the generated page there is none, so this
  // random one is what shows.
  const footer = document.querySelector('.footer');
  if (footer && !document.querySelector('.access-tracker')) {
    footer.parentNode.insertBefore(accessTracker, footer);
  }
}

/**
 * Add fictional disclaimer to ensure no legal issues
 */
function addFictionalDisclaimer() {
  // Create fictional disclaimer to avoid any legal issues
  const disclaimer = document.createElement('div');
  disclaimer.className = 'fictional-disclaimer';
  disclaimer.innerHTML = "NOTE: This is a fictional cybersecurity-themed design for entertainment purposes only. No actual surveillance, monitoring, or hacking is taking place.";
  
  // Add at page bottom in footer
  const footer = document.querySelector('.footer');
  if (footer && !document.querySelector('.fictional-disclaimer')) {
    footer.appendChild(disclaimer);
  }
}

/**
 * Add interactive UI effects for cybersecurity theme
 */
function addInteractiveEffects() {
  // The hover effect below works on text, not on the link's markup.
  // It reads textContent, clears the link, and retypes the plain text,
  // so any element inside a title link would be lost for that hover.
  // The titles the generator emits are plain text, which is the only
  // reason this is safe here.
  const articleTitles = document.querySelectorAll('.article__title a');
  articleTitles.forEach(title => {
    // Add cursor blink effect on hover
    title.addEventListener('mouseenter', function() {
      // The mouseleave handler below deletes this flag while a typing
      // interval can still be running. The interval does not check the
      // flag, so leaving mid type does not stop the typing: the text
      // keeps filling in, and the finished line ends with a cursor
      // character typed as plain text instead of the span.
      if (this.dataset.processing) return; // Prevent multiple executions
      
      this.dataset.processing = 'true';
      const cursor = document.createElement('span');
      cursor.className = 'terminal-cursor';
      cursor.textContent = '█';
      cursor.setAttribute('aria-hidden', 'true');
      this.appendChild(cursor);
      
      // Simulate typing effect
      const originalText = this.textContent;
      const textWithoutCursor = originalText.replace('█', '');
      
      this.textContent = ''; // Clear text
      let i = 0;
      
      const typeInterval = setInterval(() => {
        if (i < textWithoutCursor.length) {
          this.textContent += textWithoutCursor.charAt(i);
          i++;
        } else {
          clearInterval(typeInterval);
          this.textContent = textWithoutCursor + '█'; // Add cursor at end
          delete this.dataset.processing;
        }
      }, 20);
    });
    
    title.addEventListener('mouseleave', function() {
      // Remove cursor and restore original text
      const cursor = this.querySelector('.terminal-cursor');
      if (cursor) {
        cursor.remove();
      }
      delete this.dataset.processing;
    });
  });
  
  // Add glitch effect to title on scroll
  const title = document.querySelector('.title');
  if (title) {
    window.addEventListener('scroll', function() {
      if (window.scrollY > 50 && !title.classList.contains('glitching')) {
        title.classList.add('glitching');
        
        // Remove class after animation completes
        setTimeout(() => {
          title.classList.remove('glitching');
        }, 1000);
      }
    });
  }
  
  // Add an intelligence briefing style header
  const mainHeader = document.querySelector('.header');
  if (mainHeader) {
    const briefingHeader = document.createElement('div');
    briefingHeader.className = 'document-header';
    briefingHeader.innerHTML = `
      <div class="document-stamp">CONFIDENTIAL</div>
      <div class="document-number">FILE-${Math.floor(Math.random() * 10000)}-D</div>
    `;
    mainHeader.parentNode.insertBefore(briefingHeader, mainHeader);
  }
}

/**
 * Update all terminal headers with current date and time
 */
function updateTerminalDates() {
  // One timestamp is built once and stamped into every terminal
  // header, so all articles on the page show the same second. That
  // second is the reader's local time at load. It is not the article's
  // published date: the templates that carry a real published date put
  // it in .article__date, a different element this function never
  // touches.
  const dateElements = document.querySelectorAll('.terminal__date');
  const now = new Date();
  
  // Format: YYYY-MM-DD HH:MM:SS
  const timestamp = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')} ${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')}:${String(now.getSeconds()).padStart(2, '0')}`;
  
  dateElements.forEach(element => {
    element.textContent = timestamp;
  });
}

/**
 * Initialize article sequencing for staggered reveal
 */
function initArticleSequencing() {
  // The delay below is index times 0.1 seconds, counted over every
  // article on the page, so the last article on a 62 article page gets
  // a 6.1 second transition delay once it scrolls into view. That is a
  // second stagger system next to the one in the theme CSS, which
  // animates on the --article-index property update_feed.sh writes
  // inline, at 0.15 seconds per index. The two were not tuned against
  // each other, and both run on the built page.
  const articles = document.querySelectorAll('.feed__article');
  
  // Using Intersection Observer for revealing articles as they scroll into view
  const observer = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        entry.target.classList.add('article-visible');
        observer.unobserve(entry.target);
      }
    });
  }, {
    threshold: 0.2
  });
  
  // The observer unobserves after the first reveal, so an article
  // never hides again once it has shown.
  articles.forEach((article, index) => {
    article.style.transitionDelay = `${index * 0.1}s`;
    observer.observe(article);
  });
}

// This style block only exists when this file runs. It repeats the
// .feed__article hide that the canonical theme CSS already carries,
// and adds the .article-visible rule the observer above uses, so the
// page has two reveals for the same elements: the CSS animation in
// matrix.css and this class. Inside the block there is also a rule
// that sets an href property on link[rel="icon"] as if it were CSS.
// href is not a CSS property, so that rule does nothing. The working
// favicon is the link element created after this block.
function addDynamicStyles() {
  const style = document.createElement('style');
  style.textContent = `
    /* Surveillance theme CSS */
    :root {
      --nsa-blue: #660000;
      --nsa-dark-blue: #330000;
      --surveillance-amber: #ffbf00;
      --terminal-green: #cc0000;
    }
    
    body {
      transform: translate3d(var(--camera-x, 0), var(--camera-y, 0), 0);
      transition: transform 1s ease-out;
      background-color: #0a0000;
      margin: 0;
      padding: 0;
      min-height: 100vh;
      position: relative;
    }
    
    .surveillance-scanline {
      position: fixed;
      top: 0;
      left: 0;
      width: 100%;
      height: 3px;
      background: rgba(255, 0, 0, 0.15);
      box-shadow: 0 0 5px rgba(255, 0, 0, 0.2);
      opacity: 0.7;
      z-index: 9999;
      pointer-events: none;
      animation: scanline 8s linear infinite;
    }
    
    @keyframes scanline {
      0% { top: -5px; }
      100% { top: 100%; }
    }
    
    .confidential-watermark {
      position: fixed;
      top: 40%;
      left: 50%;
      transform: translate(-50%, -50%) rotate(-30deg);
      font-size: 10vw;
      color: rgba(150, 0, 0, 0.05);
      font-family: 'Source Code Pro', monospace;
      letter-spacing: 0.2em;
      z-index: 99999;
      pointer-events: none;
      user-select: none;
      text-transform: uppercase;
      font-weight: 900;
      text-shadow: 0 0 15px rgba(150, 0, 0, 0.1);
    }
    
    .document-header {
      display: flex;
      justify-content: space-between;
      padding: 8px;
      background-color: rgba(0, 10, 30, 0.8);
      border-bottom: 1px solid var(--nsa-blue);
      margin-bottom: 20px;
    }
    
    .document-stamp {
      color: var(--surveillance-amber);
      font-family: var(--matrix-font, 'Source Code Pro', monospace);
      font-size: 0.8rem;
      font-weight: bold;
      letter-spacing: 1px;
      padding: 2px 6px;
      border: 1px dashed var(--surveillance-amber);
      border-radius: 2px;
    }
    
    .document-number {
      color: rgba(200, 200, 200, 0.7);
      font-family: var(--matrix-font, 'Source Code Pro', monospace);
      font-size: 0.8rem;
      letter-spacing: 1px;
    }
    
    .redacted {
      background: #111;
      color: transparent !important;
      border-radius: 2px;
      padding: 0.1em 0.3em;
      position: relative;
      box-shadow: 0 0 1px #000;
    }
    
    .timestamp {
      position: absolute;
      bottom: 5px;
      right: 5px;
      color: rgba(0, 200, 255, 0.5);
      font-family: var(--matrix-font, 'Source Code Pro', monospace);
      font-size: 0.7rem;
      z-index: 100;
    }
    
    .access-bar {
      position: absolute;
      bottom: 0;
      left: 0;
      height: 2px;
      width: 0%;
      background: var(--surveillance-amber);
      animation: accessData 2s forwards;
      z-index: 999;
    }
    
    @keyframes accessData {
      0% { width: 0%; }
      100% { width: 100%; }
    }
    
    .terminal__header {
      background-color: rgba(30, 0, 0, 0.95) !important;
      border-bottom: 1px solid rgba(200, 0, 0, 0.3) !important;
    }
    
    .terminal__prompt {
      color: var(--surveillance-amber) !important;
    }
    
    /* Make subtitle more intelligence-brief like */
    .subtitle__text {
      color: #eee !important;
      text-transform: uppercase;
    }
    
    .subtitle__separator {
      color: var(--surveillance-amber) !important;
    }
    
    /* Dark overlay for the shadowy feel without directly using a static image */
    body::before {
      content: "";
      position: fixed;
      top: 0; left: 0; right: 0; bottom: 0;
      pointer-events: none;
      z-index: 9999;
      background: repeating-linear-gradient(
        0deg,
        rgba(0,0,0,0.1) 0px,
        rgba(0,0,0,0.11) 2px,
        rgba(0,0,0,0.13) 4px,
        transparent 6px
      ), 
      /* Self-generated noise pattern instead of external URL */
      radial-gradient(rgba(0,0,0,0.2) 1px, transparent 1px);
      background-size: 100% 6px, 4px 4px;
      opacity: 0.6;
    }
    
    /* Create an SVG favicon */
    link[rel="icon"] {
      href: "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'%3E%3Crect width='100' height='100' fill='%23000000'/%3E%3Ctext x='50' y='50' font-family='monospace' font-size='80' fill='%23ff0000' text-anchor='middle' dominant-baseline='middle'%3E1%3C/text%3E%3Ctext x='50' y='80' font-family='monospace' font-size='12' fill='%23ff0000' text-anchor='middle' dominant-baseline='middle'%3EHACKERS%3C/text%3E%3C/svg%3E";
    }
    
    /* Fix scrollbar issues */
    html, body {
      overflow-x: hidden;
    }
    
    .feed__article {
      opacity: 0;
      transform: translateY(20px);
      transition: opacity 0.5s ease, transform 0.5s ease;
    }
    
    .article-visible {
      opacity: 1;
      transform: translateY(0);
    }
    
    .container {
      min-height: calc(100vh - 100px);
    }
  `;
  
  document.head.appendChild(style);

  // The pages already link a favicon in their head. This appends a
  // second icon link instead of replacing the first, and which one a
  // browser uses is up to the browser.
  // Create SVG favicon
  const favicon = document.createElement('link');
  favicon.rel = 'icon';
  favicon.type = 'image/svg+xml';
  favicon.href = "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'%3E%3Crect width='100' height='100' fill='%23000000'/%3E%3Ctext x='50' y='50' font-family='monospace' font-size='80' fill='%23ff0000' text-anchor='middle' dominant-baseline='middle'%3E1%3C/text%3E%3Ctext x='50' y='80' font-family='monospace' font-size='12' fill='%23ff0000' text-anchor='middle' dominant-baseline='middle'%3EHACKERS%3C/text%3E%3C/svg%3E";
  document.head.appendChild(favicon);
}