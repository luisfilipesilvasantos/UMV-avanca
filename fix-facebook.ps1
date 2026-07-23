Write-Host "=== LIMPAR DNS ==="
ipconfig /flushdns

Write-Host "=== REMOVER PROXY DO SISTEMA ==="
netsh winhttp reset proxy
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" ProxyEnable -Value 0

Write-Host "=== REDEFINIR CONFIGURAÇÕES DE TCP/IP ==="
netsh int ip reset
netsh winsock reset

Write-Host "=== LIMPAR FICHEIRO HOSTS ==="
$hostsPath = "C:\Windows\System32\drivers\etc\hosts"
$defaultHosts = "127.0.0.1 localhost"
Set-Content -Path $hostsPath -Value $defaultHosts

Write-Host "=== REMOVER CERTIFICADOS SUSPEITOS (AUTORIDADES RAIZ) ==="
$store = New-Object System.Security.Cryptography.X509Certificates.X509Store("Root","LocalMachine")
$store.Open("ReadWrite")

foreach ($cert in $store.Certificates) {
    if ($cert.Subject -notmatch "Microsoft" -and
        $cert.Subject -notmatch "DigiCert" -and
        $cert.Subject -notmatch "GlobalSign" -and
        $cert.Subject -notmatch "Google" -and
        $cert.Subject -notmatch "Apple" -and
        $cert.Subject -notmatch "Mozilla" -and
        $cert.Subject -notmatch "Amazon") {

        Write-Host "Removendo certificado suspeito: $($cert.Subject)"
        $store.Remove($cert)
    }
}

$store.Close()

Write-Host "=== LIMPAR CACHE DO EDGE/CHROME ==="
Remove-Item "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache\*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache\*" -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "=== FINALIZADO ==="
Write-Host "Reinicia o computador."

