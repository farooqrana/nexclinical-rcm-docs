# Alternative: Instant Web Publishing (No GitHub Account Needed)
# This uploads your documentation to a free hosting service

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Quick Web Publishing Options" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Choose your preferred method:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. GitHub Pages (Best - Professional, Free Forever)" -ForegroundColor White
Write-Host "   Run: .\publish-docs.ps1" -ForegroundColor Gray
Write-Host ""
Write-Host "2. HackMD (Instant - No Account Needed)" -ForegroundColor White
Write-Host "   - Go to: https://hackmd.io" -ForegroundColor Gray
Write-Host "   - Click 'New Note'" -ForegroundColor Gray
Write-Host "   - Copy/paste content from NEXCLINICAL_RCM_PLATFORM_OVERVIEW.md" -ForegroundColor Gray
Write-Host "   - Click 'Share' → Get public link" -ForegroundColor Gray
Write-Host "   - Takes 2 minutes!" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Notion (Beautiful - Free)" -ForegroundColor White
Write-Host "   - Go to: https://notion.so" -ForegroundColor Gray
Write-Host "   - Create free account" -ForegroundColor Gray
Write-Host "   - Create new page" -ForegroundColor Gray
Write-Host "   - Import markdown file" -ForegroundColor Gray
Write-Host "   - Click 'Share' → 'Share to web'" -ForegroundColor Gray
Write-Host ""
Write-Host "4. GitBook (Professional - Free Tier)" -ForegroundColor White
Write-Host "   - Go to: https://gitbook.com" -ForegroundColor Gray
Write-Host "   - Sign up with GitHub" -ForegroundColor Gray
Write-Host "   - Import from repository or markdown" -ForegroundColor Gray
Write-Host "   - Beautiful book-style documentation" -ForegroundColor Gray
Write-Host ""

$choice = Read-Host "Which method? (1-4)"

switch ($choice) {
    "1" {
        Write-Host ""
        Write-Host "Running GitHub Pages setup..." -ForegroundColor Green
        & "$PSScriptRoot\publish-docs.ps1"
    }
    "2" {
        Write-Host ""
        Write-Host "Opening HackMD..." -ForegroundColor Green
        Start-Process "https://hackmd.io/new"
        Write-Host ""
        Write-Host "Instructions:" -ForegroundColor Yellow
        Write-Host "1. Click 'New Note' on the website" -ForegroundColor White
        Write-Host "2. Open NEXCLINICAL_RCM_PLATFORM_OVERVIEW.md in VS Code" -ForegroundColor White
        Write-Host "3. Copy all content (Ctrl+A, Ctrl+C)" -ForegroundColor White
        Write-Host "4. Paste into HackMD" -ForegroundColor White
        Write-Host "5. Click 'Share' button → Get shareable link" -ForegroundColor White
        Write-Host ""
        Write-Host "Done! You'll have a beautiful web page instantly." -ForegroundColor Green
    }
    "3" {
        Write-Host ""
        Write-Host "Opening Notion..." -ForegroundColor Green
        Start-Process "https://www.notion.so/signup"
        Write-Host ""
        Write-Host "Instructions:" -ForegroundColor Yellow
        Write-Host "1. Sign up for free account" -ForegroundColor White
        Write-Host "2. Create new page" -ForegroundColor White
        Write-Host "3. Click '...' menu → 'Import' → Select markdown file" -ForegroundColor White
        Write-Host "4. Click 'Share' → 'Share to web'" -ForegroundColor White
        Write-Host "5. Copy the public link" -ForegroundColor White
        Write-Host ""
        Write-Host "Notion has beautiful templates and formatting!" -ForegroundColor Green
    }
    "4" {
        Write-Host ""
        Write-Host "Opening GitBook..." -ForegroundColor Green
        Start-Process "https://www.gitbook.com/signup"
        Write-Host ""
        Write-Host "Instructions:" -ForegroundColor Yellow
        Write-Host "1. Sign up with GitHub account" -ForegroundColor White
        Write-Host "2. Create new space" -ForegroundColor White
        Write-Host "3. Import markdown file" -ForegroundColor White
        Write-Host "4. Your docs will be at: yourspace.gitbook.io" -ForegroundColor White
        Write-Host ""
        Write-Host "GitBook is perfect for professional documentation!" -ForegroundColor Green
    }
    default {
        Write-Host "Invalid choice. Run script again." -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Need help? Check docs/SETUP_INSTRUCTIONS.md" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
