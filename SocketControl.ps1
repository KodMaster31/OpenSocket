<#
.SYNOPSIS
SocketControl - PowerShell tabanlı TCP Port Yönetim Betiği (socketctl muadili).
Mustafa için KodMaster31/OpenSocket mantığı ile yazılmıştır.

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
    
    # PowerShell'de debug modu yerine her zaman log yazalım, kullanıcı isterse dosyaya bakar.
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
        $PID = [int](Get-Content $PidFile)
        
        # Sürecin hala çalışıp çalışmadığını kontrol et
        try {
            Get-Process -Id $PID | Out-Null
            Log-Message "Port $Port aktif (PID: $PID)"
            return $true # Aktif
        } catch {
            Log-Message "Port $Port PID dosyasi var ama surec yok. Temizleniyor."
            Remove-Item $PidFile -Force
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
        $PID = [int](Get-Content (Get-PidFile -Port $Port))
        Write-Error "Hata: Port $Port zaten dinlemede (PID: $PID). Boşuna yorma beni."
        exit 1
    }
    
    Write-Host "`nSENİN İÇİN port $Port'u arka planda dinlemeye alıyorum..."

    # PowerShell'de port dinlemek Netcat yerine TcpListener ile yapılır ve bu, 
    # ayrı bir PowerShell örneği olarak arka planda başlatılmalıdır.
    
    # Arka plan süreci olarak listener başlatma betiği
    $ScriptBlock = {
        param($ListenPort, $PidFile)
        
        # TcpListener objesi oluşturulur
        $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Any, $ListenPort)
        
        try {
            $listener.Start()
            
            # Ana süreç PID'si PID dosyasına yazılır
            $pid = $PID
            $pid | Out-File -FilePath $PidFile -Force
            
            # Sürekli dinleme döngüsü (Bağlantı geldiğinde kapatılmasın diye sonsuz döngü)
            while ($true) {
                # Bağlantı beklemek, veri almak, göndermek burada yapılır.
                # Basit bir dinleme betiği için, sadece süreci ayakta tutmak yeterlidir.
                Start-Sleep -Seconds 1 # İşlemciyi yormamak için kısa bir bekleme
            }
        }
        finally {
            if ($listener -ne $null) {
                $listener.Stop()
            }
            Remove-Item $PidFile -Force # Süreç kapanınca dosyayı sil
        }
    }

    # Yeni bir PowerShell süreci başlat ve betiği arka planda çalıştır
    Start-Job -ScriptBlock $ScriptBlock -ArgumentList $Port, (Get-PidFile -Port $Port) | Out-Null
    
    # PID dosyasının oluşmasını beklemek için kısa bir gecikme
    Start-Sleep -Seconds 2
    
    $PID = [int](Get-Content (Get-PidFile -Port $Port))
    Log-Message "TcpListener islemi baslatildi, PID: $PID dosyaya yazildi."
    
    Write-Host "Port $Port başarıyla açıldı (PID: $PID). Kapatmak için: Close-Socket $Port"
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
    $PID = [int](Get-Content $PidFile)
    
    # Süreç kapatma (SIGTERM muadili)
    Stop-Process -Id $PID -Force:$false -ErrorAction SilentlyContinue
    Log-Message "PID $PID'ye durdurma sinyali gönderildi."
    
    # Zorla kapatma mantığı (SIGKILL muadili)
    if ($Force -or (Get-Process -Id $PID -ErrorAction SilentlyContinue)) {
        Start-Sleep -Seconds 1
        if (Get-Process -Id $PID -ErrorAction SilentlyContinue) {
             if ($Force) {
                Write-Warning "Süreç $PID kibarca kapanmayı reddetti. ŞİDDET UYGULANIYOR (-Force)!"
            }
            Stop-Process -Id $PID -Force
            Log-Message "PID $PID zorla sonlandirildi (Force)."
        }
    }

    if (-not (Get-Process -Id $PID -ErrorAction SilentlyContinue)) {
        Write-Host "`nİş bitti. Port $Port (PID $PID) kılıçtan geçirildi ve kapatıldı."
        Remove-Item $PidFile -Force
    } else {
        Write-Error "`nHata: Süreç $PID sonlandırılamadı. Manuel kontrol gerekli."
    }
}

function Get-SocketStatus {
    param([Parameter(Mandatory=$true)][int]$Port)
    
    Test-PortValid -Port $Port
    if (Test-SocketActive -Port $Port) {
        $PID = [int](Get-Content (Get-PidFile -Port $Port))
        Write-Host "AKTİF: Port $Port dinlemede (PID: $PID)."
    } else {
        Write-Host "KAPALI: Port $Port dinlemede değil."
    }
}

function List-Sockets {
    Write-Host "`n--- Aktif Socket Dinlemeleri ---"
    $found = $false
    
    Get-ChildItem $PID_DIR -Filter "socket.*.pid" | ForEach-Object {
        $Port = [int]($_.BaseName -replace "socket." -replace ".pid")
        if (Test-SocketActive -Port $Port) {
            $PID = [int](Get-Content $_.FullName)
            Write-Host "  Port: $Port (PID: $PID)"
            $found = $true
        }
    }
    
    if (-not $found) {
        Write-Host "  Aktif dinlemede olan port bulunamadı. Rahatlık batıyor mu?"
    }
    Write-Host "-------------------------------------"
}

# --- Komut Çağrım Noktası ---

# Betiğin direkt çalıştırılması durumunda ana fonksiyonları dışarı aktar.
# Bu, betiğin bir modül gibi çağrılmasını sağlar.
Export-ModuleMember -Function Open-Socket, Close-Socket, Get-SocketStatus, List-Sockets

# Eğer kullanıcı betiği direkt nokta operatörü ile çağırmazsa (yani ". .\SocketControl.ps1" yapmazsa)
# script sadece fonksiyonları tanımlar. Bu yüzden manuel olarak komut çalıştırma mantığı gerekmez.
# Kullanıcının betiği çalıştırma şekli:
# 1. PowerShell'i aç
# 2. Set-ExecutionPolicy RemoteSigned (Gerekiyorsa)
# 3. . .\SocketControl.ps1 (Nokta ile kaynak göstererek çalıştır)
# 4. Open-Socket 3131 (Artık fonksiyonlar çağrılabilir)
