# Vite App Setup

sleep 3s # Wait for Git repository to download
cd memory-card-ai-demo
git fetch
# Check for uncommitted changes
if git diff-index --quiet HEAD -- && \
    [ -z "$(git status --porcelain --untracked-files=no)" ] && \
    [ -z "$(git log --branches --not --remotes)" ]; then
    echo "Repo is clean. Pulling latest changes..."
    git pull
else
    echo "Repo has uncommitted or unpushed changes. Skipping pull."
fi
git remote set-url origin https://${GH_TOKEN}@github.com/coder-contrib/memory-card-ai-demo.git 

npm install
nohup npm run dev >/tmp/memory-card.out 2>/tmp/memory-card.err &
echo $! > /tmp/memory-card.pid