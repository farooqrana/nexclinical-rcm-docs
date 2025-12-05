# Quick GitHub Pages Setup for NexClinical Documentation
# Run this script to publish your documentation to the web

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "NexClinical Documentation Publisher" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if git is initialized
if (-not (Test-Path ".git")) {
    Write-Host "📁 Initializing Git repository..." -ForegroundColor Yellow
    git init
    Write-Host "✅ Git initialized" -ForegroundColor Green
} else {
    Write-Host "✅ Git already initialized" -ForegroundColor Green
}

# Check if docs folder exists
if (-not (Test-Path "docs")) {
    Write-Host "❌ Error: docs/ folder not found" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "📝 Preparing to commit documentation..." -ForegroundColor Yellow

# Stage all changes
git add docs/
git add .gitignore -ErrorAction SilentlyContinue

# Commit
$commitMessage = "Add NexClinical RCM documentation for web publishing"
git commit -m $commitMessage

Write-Host "✅ Changes committed" -ForegroundColor Green
Write-Host ""

# Check if remote exists
$remoteUrl = git remote get-url origin 2>$null

if ($remoteUrl) {
    Write-Host "🌐 Remote repository found: $remoteUrl" -ForegroundColor Green
    Write-Host ""
    $push = Read-Host "Push to GitHub now? (y/n)"
    
    if ($push -eq 'y') {
        Write-Host "⬆️  Pushing to GitHub..." -ForegroundColor Yellow
        git push origin main
        Write-Host "✅ Pushed successfully!" -ForegroundColor Green
    }
} else {
    Write-Host "⚠️  No remote repository configured" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "1. Create a new repository on GitHub: https://github.com/new" -ForegroundColor White
    Write-Host "2. Repository name: nexclinical-rcm" -ForegroundColor White
    Write-Host "3. Make it Private (docs still shareable)" -ForegroundColor White
    Write-Host "4. Run these commands:" -ForegroundColor White
    Write-Host ""
    Write-Host '   git remote add origin https://github.com/YOUR-USERNAME/nexclinical-rcm.git' -ForegroundColor Gray
    Write-Host '   git branch -M main' -ForegroundColor Gray
    Write-Host '   git push -u origin main' -ForegroundColor Gray
    Write-Host ""
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "After pushing to GitHub:" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Go to your repository on GitHub" -ForegroundColor White
Write-Host "2. Click 'Settings' → 'Pages'" -ForegroundColor White
Write-Host "3. Source: 'main' branch, '/docs' folder" -ForegroundColor White
Write-Host "4. Click 'Save'" -ForegroundColor White
Write-Host ""
Write-Host "Your docs will be live at:" -ForegroundColor Green
Write-Host "https://YOUR-USERNAME.github.io/nexclinical-rcm/" -ForegroundColor Cyan
Write-Host ""
Write-Host "Wait 2-3 minutes after enabling Pages." -ForegroundColor Yellow
Write-Host ""
