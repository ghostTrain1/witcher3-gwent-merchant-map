[Console]::OutputEncoding=[Text.UTF8Encoding]::new($false)
$ErrorActionPreference='Stop'
function SHA([string]$Path){$s=[Security.Cryptography.SHA256]::Create();try{return ([BitConverter]::ToString($s.ComputeHash([IO.File]::ReadAllBytes($Path)))).Replace('-','').ToLowerInvariant()}finally{$s.Dispose()}}
if(Get-Process witcher3 -ErrorAction SilentlyContinue){throw 'Exit The Witcher 3 before uninstalling.'}
$receiptPath=Join-Path $PSScriptRoot 'install_receipt.json'
$receipt=Get-Content -LiteralPath $receiptPath -Raw -Encoding UTF8 | ConvertFrom-Json
$root=[IO.Path]::GetFullPath($receipt.game).TrimEnd('\')+'\'
$remove=@()
foreach($f in $receipt.files){
    $path=[IO.Path]::GetFullPath($f.path)
    if(-not $path.StartsWith($root,[StringComparison]::OrdinalIgnoreCase)){throw 'Invalid receipt path.'}
    $relative=$path.Substring($root.Length)
    if(-not($relative.StartsWith('mods\modGwentPlayersMap\',[StringComparison]::OrdinalIgnoreCase) -or $relative -eq 'bin\config\r4game\user_config_matrix\pc\modGwentPlayersMap.xml')){throw 'Receipt is outside this mod.'}
    if(Test-Path -LiteralPath $path){if((SHA $path) -ne $f.sha256){throw "File was modified; refusing to delete it: $relative"};$remove+=$path}
}
foreach($path in $remove){Remove-Item -LiteralPath $path}
Move-Item -LiteralPath $receiptPath -Destination ($receiptPath+'.'+[guid]::NewGuid().ToString('N')+'.uninstalled')
"REMOVED_FILES=$($remove.Count)"
'Saved gameplay progress is not rolled back.'
