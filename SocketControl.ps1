<#
.SYNOPSIS
SocketControl - PowerShell tabanlı TCP Port Yönetim Betiği (socketctl muadili).

.DESCRIPTION
Bu betik, belirli bir TCP portunu arka planda dinlemeye almak (Open-Socket),
dinlemeyi durdurmak (Close-Socket), durumunu kontrol etmek (Get-SocketStatus)
ve aktif portları listelemek (List-Sockets) için kullanılır.
PID bilgileri, kolay yönetim için geçici bir dizinde (C:\Temp\SocketControl\) tutulur.

.PARAMETER Port
İşlem yapılacak TCP port numarası (1025-65535 arası).
#>

# Sabitler
$PID_DIR = "C:\Temp\SocketControl"
$LOG_FILE = "$PID_DIR\SocketControl.log"

# --- Ortam Hazırlığı ---

# PID dizinini oluştur
if (-not (Test-Path $PID_DIR)) {
    New-Item -Path $PID_DIR -ItemType Directory | Out-Null
}

# --- Yardımcı Fonksiyonlar ---

function Log-Message {
    param([Parameter(Mandatory=$true)][string]$Message)
    
    "$((Get-Date -Format 'HH:mm:ss')) - $Message" | Out-File -FilePath $LOG_FILE -Append
}

function Get-PidFile {
    param([Parameter(Mandatory=$true)][int]$Port)
    return "$PID_DIR\socket.$Port.pid"
}

function Test-PortValid {
    param([Parameter(Mandatory=$true)][int]$Port)
    if ($Port -le 1024 -or $Port -gt 65535) {
        Write-Error "Hata: Port numarası 1025 ile 65535 arasında olmalı. Ne sallıyorsun?"
        exit 1
    }
}

# 0 = Aktif, 1 = Kapalı/Süreç Yok
function Test-SocketActive {
    param([Parameter(Mandatory=$true)][int]$Port)
    
    $PidFile = Get-PidFile -Port $Port
    if (Test-Path $PidFile) {
        $SocketPID = [int](Get-Content $PidFile) # PID DEĞİŞKENİ BURADA DÜZELTİLDİ
        
        # Sürecin hala çalışıp çalışmadığını kontrol et
        try {
            Get-Process -Id $SocketPID | Out-Null
            Log-Message "Port $Port aktif (PID: $SocketPID)"
            return $true # Aktif
        } catch {
            Log-Message "Port $Port PID dosyasi var ama surec yok. Temizleniyor."
            Remove-Item $PidFile -Force -ErrorAction SilentlyContinue
            return $false # PID dosyası var ama süreç yok
        }
    } else {
        Log-Message "Port $Port kapali."
        return $false # Kapalı
    }
}

# --- Ana Komutlar ---

function Open-Socket {
    param([Parameter(Mandatory=$true)][int]$Port)
    
    Test-PortValid -Port $Port
    Log-Message "Open-Socket $Port komutu calisti."
    
    if (Test-SocketActive -Port $Port) {
        $SocketPID = [int](Get-Content (Get-PidFile -Port $Port)) # PID DEĞİŞKENİ BURADA DÜZELTİLDİ
        Write-Error "Hata: Port $Port zaten dinlemede (PID: $SocketPID). Boşuna yorma beni."
        exit 1
    }
    
    Write-Host "`nSENİN İÇİN port $Port'u arka planda dinlemeye alıyorum..."

    # Arka plan süreci olarak listener başlatma betiği
    $ScriptBlock = {
        param($ListenPort, $PidFile)
        
        try {
            $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Any, $ListenPort)
            $listener.Start()
            
            # Ana süreç PID'si PID dosyasına yazılır. $PID, Start-Job'ın otomatik atadığı PID'dir.
            $PID | Out-File -FilePath $PidFile -Force
            
            while ($true) {
                Start-Sleep -Seconds 1 
            }
        }
        finally {
            if ($listener -ne $null) {
                $listener.Stop()
            }
        }
    }

    Start-Job -ScriptBlock $ScriptBlock -ArgumentList $Port, (Get-PidFile -Port $Port) | Out-Null
    
    Start-Sleep -Seconds 2
    
    $SocketPID = [int](Get-Content (Get-PidFile -Port $Port)) # PID DEĞİŞKENİ BURADA DÜZELTİLDİ
    Log-Message "TcpListener islemi (Job) baslatildi, PID: $SocketPID dosyaya yazildi."
    
    Write-Host "Port $Port başarıyla açıldı (PID: $SocketPID). Kapatmak için: Close-Socket $Port"
}


function Close-Socket {
    param(
        [Parameter(Mandatory=$true)][int]$Port,
        [switch]$Force # Zorla kapatma opsiyonu
    )

    Test-PortValid -Port $Port
    Log-Message "Close-Socket $Port komutu calisti. Force: $Force"

    if (-not (Test-SocketActive -Port $Port)) {
        Write-Host "`nHata: Port $Port zaten kapalı görünüyor. Temiz iş."
        exit 1
    }
    
    $PidFile = Get-PidFile -Port $Port
    $SocketPID = [int](Get-Content $PidFile) # PID DEĞİŞKENİ BURADA DÜZELTİLDİ
    
    Stop-Process -Id $SocketPID -Force:$false -ErrorAction SilentlyContinue
    Log-Message "PID $SocketPID'ye durdurma sinyali gönderildi."
    
    if ($Force.IsPresent) {
        Start-Sleep -Seconds 1
        if (Get-Process -Id $SocketPID -ErrorAction SilentlyContinue) {
            Write-Warning "Süreç $SocketPID kibarca kapanmayı reddetti. ŞİDDET UYGULANIYOR (-Force)!"
            Stop-Process -Id $SocketPID -Force
            Log-Message "PID $SocketPID zorla sonlandirildi (Force)."
        }
    }

    if (-not (Get-Process -Id $SocketPID -ErrorAction SilentlyContinue)) {
        Write-Host "`nİş bitti. Port $Port (PID $SocketPID) kılıçtan geçirildi ve kapatıldı."
        Remove-Item $PidFile -Force -ErrorAction SilentlyContinue
    } else {
        Write-Error "`nHata: Süreç $SocketPID sonlandırılamadı. Manuel kontrol gerekli."
    }
}

function Get-SocketStatus {
    param([Parameter(Mandatory=$true)][int]$Port)
    
    Test-PortValid -Port $Port
    if (Test-SocketActive -Port $Port) {
        $SocketPID = [int](Get-Content (Get-PidFile -Port $Port)) # PID DEĞİŞKENİ BURADA DÜZELTİLDİ
        Write-Host "AKTİF: Port $Port dinlemede (PID: $SocketPID)."
    } else {
        Write-Host "KAPALI: Port $Port dinlemede değil."
    }
}

function List-Sockets {
    Write-Host "`n--- Aktif Socket Dinlemeleri ---"
    $found = $false
    
    Get-ChildItem $PID_DIR -Filter "socket.*.pid" -ErrorAction SilentlyContinue | ForEach-Object {
        $Port = [int]($_.BaseName -replace "socket.")
        
        if (Test-SocketActive -Port $Port) {
            $SocketPID = [int](Get-Content $_.FullName) # PID DEĞİŞKENİ BURADA DÜZELTİLDİ
            Write-Host "  Port: $Port (PID: $SocketPID)"
            $found = $true
        }
    }
    
    if (-not $found) {
        Write-Host "  Aktif dinlemede olan port bulunamadı. Rahatlık batıyor mu?"
    }
    Write-Host "-------------------------------------"
}
