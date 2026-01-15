#!/bin/bash

echo "Current directory: $(pwd)"
echo "Creating dark mode logo..."

# Check if we have the light logo
if [ ! -f "Assets.xcassets/SYSMLogo.imageset/SYSMLogo.png" ]; then
    echo "❌ ERROR: Cannot find SYSMLogo.png"
    echo "Expected at: $(pwd)/Assets.xcassets/SYSMLogo.imageset/SYSMLogo.png"
    exit 1
fi

# Create directory
mkdir -p Assets.xcassets/SYSMLogoDark.imageset

# Check for ImageMagick
if command -v magick &> /dev/null; then
    echo "✅ ImageMagick found, creating dark blue logos..."
    
    # Create dark blue version (60% colorize makes it darker)
    magick Assets.xcassets/SYSMLogo.imageset/SYSMLogo.png \
      -fill "rgb(0,50,120)" -colorize 60% \
      Assets.xcassets/SYSMLogoDark.imageset/SYSMLogoDark.png
    
    magick Assets.xcassets/SYSMLogo.imageset/SYSMLogo@2x.png \
      -fill "rgb(0,50,120)" -colorize 60% \
      Assets.xcassets/SYSMLogoDark.imageset/SYSMLogoDark@2x.png
    
    echo "✅ Created proper dark mode logos with ImageMagick"
else
    echo "⚠️  ImageMagick not found. Creating simple copies..."
    cp Assets.xcassets/SYSMLogo.imageset/SYSMLogo.png Assets.xcassets/SYSMLogoDark.imageset/SYSMLogoDark.png
    cp Assets.xcassets/SYSMLogo.imageset/SYSMLogo@2x.png Assets.xcassets/SYSMLogoDark.imageset/SYSMLogoDark@2x.png
    echo "💡 Install ImageMagick for better results: brew install imagemagick"
fi

# Create Contents.json
cat > Assets.xcassets/SYSMLogoDark.imageset/Contents.json << 'JSONEOF'
{
  "images": [
    {
      "filename": "SYSMLogoDark.png",
      "idiom": "universal",
      "scale": "1x"
    },
    {
      "filename": "SYSMLogoDark@2x.png",
      "idiom": "universal",
      "scale": "2x"
    }
  ],
  "info": {
    "author": "xcode",
    "version": 1
  }
}
JSONEOF

echo "✅ Dark logo files created in:"
echo "   $(pwd)/Assets.xcassets/SYSMLogoDark.imageset/"
echo ""
echo "📁 Files created:"
ls -la Assets.xcassets/SYSMLogoDark.imageset/
