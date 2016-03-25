$src = ".\APIMUtils.psm1"
$dest = "$home\Documents\WindowsPowerShell\Modules\APIMUtils\APIMUtils.psm1"
New-Item -ItemType File -Path $dest -Force
Copy-Item $src $dest -Force
