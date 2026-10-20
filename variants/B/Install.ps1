param([string]$GameDir)
[Console]::OutputEncoding=[Text.UTF8Encoding]::new($false)
$ErrorActionPreference='Stop'
function SHA([string]$Path){$s=[Security.Cryptography.SHA256]::Create();try{return ([BitConverter]::ToString($s.ComputeHash([IO.File]::ReadAllBytes($Path)))).Replace('-','').ToLowerInvariant()}finally{$s.Dispose()}}
if(Get-Process witcher3 -ErrorAction SilentlyContinue){throw 'Exit The Witcher 3 before installing.'}
if(-not $GameDir){$GameDir=Read-Host 'Game folder containing bin and content'}
$GameDir=(Resolve-Path -LiteralPath $GameDir).Path.TrimEnd('\')
$root=$GameDir+'\'
$manifest=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$receiptPath=Join-Path $PSScriptRoot 'install_receipt.json'
if(Test-Path -LiteralPath $receiptPath){throw 'Receipt already exists. Uninstall this copy before reinstalling.'}
foreach($required in @('bin','content')){if(-not(Test-Path -LiteralPath (Join-Path $GameDir $required))){throw 'Not a game installation folder.'}}
$scripts=Join-Path $GameDir 'content\content0\scripts'
$checks=@(@{path='game\gui\menus\mapMenu.ws';pattern='function\s+UpdateEntityPins\s*\('},@{path='game\player\r4Player.ws';pattern='function\s+SetGwintMinigameState\s*\('})
if($manifest.variant -eq 'B'){
    $checks+=@{path='game\gui\menus\inventoryMenu.ws';pattern='function\s+UpdateMerchantData\s*\('}
    $checks+=@{path='game\gui\hud\modules\hudModuleMinimap2.ws';pattern='function\s+UpdatePlayerPositionAndRotation\s*\('}
}
foreach($check in $checks){
    $path=Join-Path $scripts $check.path
    if(-not(Test-Path -LiteralPath $path)){throw "Required Remastered script is absent: $($check.path)"}
    if((Get-Content -LiteralPath $path -Raw -Encoding UTF8) -notmatch $check.pattern){throw "Required game API is absent: $($check.path)"}
}
$planned=@()
foreach($f in $manifest.files){
    $relative=$f.path.Replace('/','\')
    if(-not($relative.StartsWith('mods\modGwentPlayersMap\',[StringComparison]::OrdinalIgnoreCase) -or $relative -eq 'bin\config\r4game\user_config_matrix\pc\modGwentPlayersMap.xml')){throw 'Unexpected file in package manifest.'}
    $source=Join-Path (Join-Path $PSScriptRoot 'release') $relative
    $target=[IO.Path]::GetFullPath((Join-Path $GameDir $relative))
    if(-not $target.StartsWith($root,[StringComparison]::OrdinalIgnoreCase)){throw 'Target path escaped game directory.'}
    if((SHA $source) -ne $f.sha256){throw "Package hash mismatch: $relative"}
    if(Test-Path -LiteralPath $target){throw "Existing file will not be overwritten. Uninstall A/B or an existing Gwent Players Map first: $relative"}
    $planned+=@{source=$source;path=$target;relative=$relative;sha256=$f.sha256}
}
$installed=@()
try{
    foreach($f in $planned){
        $parent=Split-Path -Parent $f.path
        if(-not(Test-Path -LiteralPath $parent)){New-Item -ItemType Directory -Path $parent -Force | Out-Null}
        Copy-Item -LiteralPath $f.source -Destination $f.path
        $installed+=@{path=$f.path;relative=$f.relative;sha256=$f.sha256}
        if((SHA $f.path) -ne $f.sha256){throw 'Post-install hash mismatch.'}
    }
    @{game=$GameDir;variant=$manifest.variant;files=$installed} | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $receiptPath -Encoding UTF8
    "INSTALLED_VARIANT=$($manifest.variant) FILES=$($installed.Count)"
    'No personal save files were read or written by the installer.'
}catch{
    foreach($f in $installed){if((Test-Path -LiteralPath $f.path) -and (SHA $f.path) -eq $f.sha256){Remove-Item -LiteralPath $f.path}}
    throw
}
