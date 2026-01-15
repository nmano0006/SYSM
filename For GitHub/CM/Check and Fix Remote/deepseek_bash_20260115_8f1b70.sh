# Check current remotes
git remote -v

# If no output or wrong remote, add the correct one
git remote remove origin 2>/dev/null  # Remove if exists
git remote add origin https://github.com/nmano0006/SYSM.git

# Verify
git remote -v