#!/bin/bash
find scripts -name "*.sh" -type f -exec sed -i 's/\r$//' {} \;
chmod +x scripts/*.sh
echo "Done! All scripts fixed."
