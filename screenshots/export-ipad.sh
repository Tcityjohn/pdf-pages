#!/bin/bash

# Export iPad App Store screenshots using Chrome headless
# Target: 12.9" iPad Pro (2048x2732 pixels)

SCREENSHOTS_DIR="/Users/johncarter/Documents/GitHub/pdf-pages/screenshots"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

declare -a MOCKUPS=(
    "ipad_01_final|Extract Any<br>Pages|From any PDF, in seconds|ipad_01_home.png"
    "ipad_02_final|Tap to<br>Select|Choose exactly the pages you need|ipad_02_grid.png"
    "ipad_03_final|Browse Your<br>Files|Open any PDF from your device|ipad_03_picker.png"
)

for mockup in "${MOCKUPS[@]}"; do
    IFS='|' read -r filename headline subheadline source_img <<< "$mockup"

    echo "Generating $filename..."

    cat > "$SCREENSHOTS_DIR/${filename}.html" << HTMLEOF
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <style>
        @import url('https://fonts.googleapis.com/css2?family=DM+Sans:wght@400;500;600&family=Fraunces:opsz,wght@9..144,500;9..144,600&display=swap');
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            width: 2048px;
            height: 2732px;
            overflow: hidden;
            font-family: 'DM Sans', -apple-system, sans-serif;
        }
        .mockup {
            width: 2048px;
            height: 2732px;
            position: relative;
            overflow: hidden;
            background: linear-gradient(165deg, #E63946 0%, #D32F3F 50%, #B52534 100%);
            display: flex;
            flex-direction: column;
        }
        .mockup::before {
            content: '';
            position: absolute;
            top: -100px;
            left: 50%;
            transform: translateX(-50%);
            width: 1000px;
            height: 1000px;
            background: radial-gradient(circle, rgba(255,150,150,0.15) 0%, transparent 70%);
            pointer-events: none;
        }
        .text-banner {
            padding: 140px 100px 70px;
            text-align: center;
            position: relative;
            z-index: 2;
        }
        .headline {
            font-family: 'Fraunces', serif;
            font-size: 88px;
            font-weight: 600;
            color: #fff;
            line-height: 1.1;
            text-shadow: 0 4px 30px rgba(0,0,0,0.3);
            letter-spacing: -1px;

        }
        .subheadline {
            font-family: 'DM Sans', sans-serif;
            font-size: 38px;
            font-weight: 400;
            color: rgba(255,255,255,0.85);
            margin-top: 20px;
            letter-spacing: 0.5px;
        }
        .screenshot-container {
            flex: 1;
            display: flex;
            align-items: flex-start;
            justify-content: center;
            padding: 20px 65px 0;
            position: relative;
        }
        .screenshot-frame {
            position: relative;
            width: 100%;
            height: 100%;
            border-radius: 40px;
            overflow: hidden;
            box-shadow:
                0 25px 80px rgba(0,0,0,0.4),
                0 0 0 12px rgba(255,255,255,0.1),
                inset 0 0 0 1px rgba(255,255,255,0.1);
            background: #000;
        }
        .screenshot-frame img {
            width: 100%;
            height: 100%;
            object-fit: cover;
            object-position: top center;
        }
    </style>
</head>
<body>
    <div class="mockup">
        <div class="text-banner">
            <h2 class="headline">${headline}</h2>
            <p class="subheadline">${subheadline}</p>
        </div>
        <div class="screenshot-container">
            <div class="screenshot-frame">
                <img src="file://${SCREENSHOTS_DIR}/${source_img}" alt="Screenshot">
            </div>
        </div>
    </div>
</body>
</html>
HTMLEOF

    "$CHROME" \
        --headless \
        --disable-gpu \
        --screenshot="$SCREENSHOTS_DIR/${filename}.png" \
        --window-size=2048,2732 \
        --hide-scrollbars \
        "file://$SCREENSHOTS_DIR/${filename}.html" \
        2>/dev/null

    echo "  -> ${filename}.png created"
done

echo ""
echo "Done! iPad screenshots:"
ls -la "$SCREENSHOTS_DIR"/ipad_*_final.png
