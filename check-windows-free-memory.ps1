param(
  [int] $w = 80,
  [int] $c = 90
)

$total = (get-WMIObject win32_operatingsystem | Measure-Object TotalVisibleMemorySize -sum).sum
$free = (get-WMIObject -class win32_operatingsystem).freephysicalmemory
$percentUsed = $free / $total * 100

if ($percentUsed -ge $c) {
  Write-Host ("CRITICAL: {0:F2}% of memory is used ({1:N0}MB free)" -f $percentUsed, ($free/1024))
  exit 3
}
elseif ($percentUsed -ge $w) {
  Write-Host ("WARNING: {0:F2}% of memory is used ({1:N0}MB free)" -f $percentUsed, ($free/1024))
  exit 1
}
else {
  Write-Host ("OK: {0:F2}% of memory is used ({1:N0}MB free)" -f $percentUsed, ($free/1024))
  exit 0
}