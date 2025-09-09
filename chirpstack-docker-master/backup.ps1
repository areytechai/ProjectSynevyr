# ====== ChirpStack Postgres Yedekleme Scripti (GÜNCEL) ======
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# 0) Değişkenler
$stamp = Get-Date -Format "yyyyMMdd_HHmm"
$BackupRoot = "D:\chirpstack-backup"
$ProjectDir = "D:\chirpstack-docker-master"
$ServiceName = "postgres"              # docker-compose içindeki servis adı
$DumpName = "chirpstack_$stamp.dump"   # -Fc (custom) format -> pg_restore ile geri yüklenir
$TmpPathInContainer = "/tmp/$DumpName"

# 1) Klasör hazırlığı
New-Item -ItemType Directory -Force -Path $BackupRoot | Out-Null

# 2) Compose projesine geç ve container ID'yi al
Push-Location $ProjectDir
try {
    $containerId = (docker compose ps -q $ServiceName).Trim()
    if ([string]::IsNullOrWhiteSpace($containerId)) {
        throw "Docker compose servis '$ServiceName' için aktif container bulunamadı. 'docker compose up -d' ile servisi başlat."
    }

    Write-Host "Bulunan container: $containerId"

    # 3) Container içinde pg_dump ile .dump üret (custom format -Fc)
    Write-Host "Container içinde dump üretiliyor..."
    docker compose exec -T $ServiceName sh -lc "pg_dump -U chirpstack -d chirpstack -Fc -f $TmpPathInContainer"

    # 4) Dump dosyasını host'a kopyala
    $destDump = Join-Path $BackupRoot $DumpName
    Write-Host "Dump host'a kopyalanıyor: $destDump"
    docker cp "${containerId}:$TmpPathInContainer" "$destDump"

    # 5) Konfig yedekleri (configuration klasörü ve compose)
    $cfgDest = Join-Path $BackupRoot "config_$stamp"
    Write-Host "Konfig klasörü kopyalanıyor: $cfgDest"
    Copy-Item -Path (Join-Path $ProjectDir "configuration") -Destination $cfgDest -Recurse

    $composeCopy = Join-Path $BackupRoot "docker-compose_$stamp.yml"
    Copy-Item -Path (Join-Path $ProjectDir "docker-compose.yml") -Destination $composeCopy

    # 6) İsteğe bağlı: Config klasörünü ZIP’e sıkıştır (orijinali silmez)
    $cfgZip = Join-Path $BackupRoot "config_$stamp.zip"
    Write-Host "Konfig ZIP paketi oluşturuluyor: $cfgZip"
    Compress-Archive -Path $cfgDest -DestinationPath $cfgZip -Force

    # 7) Özet
    $dumpInfo = Get-Item $destDump
    $zipInfo  = Get-Item $cfgZip
    Write-Host ""
    Write-Host "==== Yedek Tamamlandı ===="
    Write-Host ("Dump: {0}  Boyut: {1:N0} bayt" -f $dumpInfo.FullName, $dumpInfo.Length)
    Write-Host ("Compose: {0}" -f $composeCopy)
    Write-Host ("Config klasörü: {0}" -f $cfgDest)
    Write-Host ("Config ZIP: {0}  Boyut: {1:N0} bayt" -f $zipInfo.FullName, $zipInfo.Length)
}
catch {
    Write-Error "Yedekleme hatası: $($_.Exception.Message)"
    exit 1
}
finally {
    Pop-Location | Out-Null
}
# ====== Son ======
