param(
    [string]$RootPath = "./archive/deployments",
    [string]$OutputFile = "template-contributors.csv",
    [int]$MaxDepth = 10
)

$originalPath = Get-Location
$allResults = @()

$rootPathResolved = Resolve-Path $RootPath
$templatePaths = Get-ChildItem -Path $RootPath -Recurse -Depth $MaxDepth -Filter "template.json" | 
    ForEach-Object { $_.Directory.FullName }

foreach ($templatePath in $templatePaths) {
    $templateJsonPath = Join-Path $templatePath "template.json"
    $versionsJsonPath = Join-Path $templatePath "versions.json"
    
    if ((Test-Path $templateJsonPath) -and (Test-Path $versionsJsonPath)) {
        $template = Get-Content $templateJsonPath | ConvertFrom-Json
        $versions = Get-Content $versionsJsonPath | ConvertFrom-Json
        
        $contributors = $versions | ForEach-Object { $_.TemplateVersion.created_by } | 
            Group-Object -Property id | 
            Sort-Object Count -Descending
        
        $contributorString = ($contributors | ForEach-Object { 
            $user = $_.Group[0]
            "$($user.username) ($($_.Count))"
        }) -join ", "
        
        $relativePath = $templatePath.Replace($rootPathResolved.Path, "").TrimStart('\', '/')
        $pathParts = $relativePath -split '[/\\]'
        $deployment = if ($pathParts.Length -ge 1) { $pathParts[0] } else { "" }
        $templateFolder = if ($pathParts.Length -ge 3) { $pathParts[2] } else { "" }
        
        $allResults += [PSCustomObject]@{
            Deployment = $deployment
            Organization = $template.organization_name
            TemplateFolder = $templateFolder
            TemplateId = $template.id
            CreatedAt = $template.created_at
            UpdatedAt = $template.updated_at
            TemplateName = $template.name
            TemplateDisplayName = $template.display_name
            CreatorName = $template.created_by_name
            ActiveUserCount = $template.active_user_count
            OrganizationName = $template.organization_name
            OrganizationDisplayName = $template.organization_display_name
            Contributors = $contributorString
        }
    }
}

Set-Location $originalPath
$allResults | Export-Csv -Path $OutputFile -NoTypeInformation
