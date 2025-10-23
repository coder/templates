sleep 3s # Wait for Git repository to download
cd realworld-django-rest-framework-angular
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
./start-dev.sh