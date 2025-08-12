param(
    [string]$RootPath = "./archive/repos",
    [string]$OutputFile = "repo-contributors.csv",
    [int]$MaxDepth = 10
)

$originalPath = Get-Location
$allResults = @()

$gitRepos = Get-ChildItem -Path $RootPath -Directory | Where-Object {
    Test-Path (Join-Path $_.FullName ".git")
}

foreach ($repo in $gitRepos) {
    Set-Location $repo.FullName
    
    $terraformFolders = Get-ChildItem -Recurse -Depth $MaxDepth -Filter "*.tf" | 
        ForEach-Object { $_.Directory.FullName } |
        Select-Object -Unique |
        ForEach-Object { $_.Replace($repo.FullName, "").TrimStart('\', '/') }
    
    if ((Get-ChildItem -Path $repo.FullName -Filter "*.tf").Count -gt 0) {
        $terraformFolders = @(".") + $terraformFolders
    }
    
    foreach ($folder in $terraformFolders) {
        $commits = git log --pretty=format:"%an" --follow -- "$folder/*"
        
        if ($commits) {
            $contributors = $commits | Group-Object | Sort-Object Count -Descending
            
            $contributorString = ($contributors | ForEach-Object { "$($_.Name) ($($_.Count))" }) -join ", "
            
            $allResults += [PSCustomObject]@{
                Location = "https://github.com/coder/$($repo.Name)"
                Folder = $folder
                Contributors = $contributorString
            }
        }
    }
}

Set-Location $originalPath
$allResults | Export-Csv -Path $OutputFile -NoTypeInformation
