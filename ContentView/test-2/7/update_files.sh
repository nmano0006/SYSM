#!/bin/bash
echo "Updating ContentView.swift..."
cat > ContentView.swift << 'CONTENTVIEW_EOF'
[PASTE THE COMPLETE ContentView.swift CODE HERE]
CONTENTVIEW_EOF

echo "Updating drive mounting capabilities.swift..."
cat > "drive mounting capabilities.swift" << 'DRIVE_EOF'
[PASTE THE drive mounting capabilities.swift CODE HERE]
DRIVE_EOF

echo "Files updated successfully!"
