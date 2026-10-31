param (
    [switch]$SkipBuild,
    [switch]$OnlyEsp,
    [switch]$OnlyApk
)

$argsList = @()
if ($SkipBuild) { $argsList += "--skip-build" }
if ($OnlyEsp) { $argsList += "--only-esp" }
if ($OnlyApk) { $argsList += "--only-apk" }

node scripts/auto_publish_release.js @argsList
