#!/data/data/com.termux/files/usr/bin/bash

# Termux ortamında socket yönetimi (KESİN DÜZELTİLMİŞ Sürüm)

# Sabitler
CMD_NAME=$(basename "$0")
PORT="$1"
ACTION="$1"
PIDFILE="/data/data/com.termux/files/usr/tmp/socket.${PORT}.pid"
LOGFILE="/data/data/com.termux/files/usr/tmp/socketctl.log"
DEBUG=false 

# --- Fonksiyonlar ---

log_message() {
    if $DEBUG; then
        echo "[DEBUG] $(date '+%H:%M:%S') - $1" >> "$LOGFILE"
    fi
}

port_kontrol() {
    local p="$1"
    if ! [[ "$p" =~ ^[0-9]+$ ]] || [ "$p" -le 1024 ] || [ "$p" -gt 65535 ]; then
        echo -e "\nHata: Port numarası 1025 ile 65535 arasında olmalı. Ne sallıyorsun?\n"
        exit 1
    fi
}

# Sadece Çıkış Kodu (Return Code) Veren Durum Kontrolü
# 0 = Aktif (Success)
# 1 = Kapalı/Süreç Yok (Failure)
durum_kontrol_sessiz() {
    local p="$1"
    local pid_dosyasi="/data/data/com.termux/files/usr/tmp/socket.${p}.pid"

    if [ -f "$pid_dosyasi" ]; then
        PID=$(cat "$pid_dosyasi")
        if kill -0 "$PID" 2>/dev/null; then
            log_message "Port $p aktif (PID: $PID)"
            return 0 # Aktif
        else
            log_message "Port $p PID dosyasi var ama surec yok. Temizleniyor."
            rm -f "$pid_dosyasi" 2>/dev/null
            return 1 # PID dosyası var ama süreç yok
        fi
    else
        log_message "Port $p kapali."
        return 1 # Kapalı
    fi
}

# Kullanıcıya Çıktı Veren Durum Kontrolü (Sadece 'socketctl status' için)
durum_kontrol_sozlu() {
    local p="$1"
    local pid_dosyasi="/data/data/com.termux/files/usr/tmp/socket.${p}.pid"
    
    if [ -f "$pid_dosyasi" ]; then
        PID=$(cat "$pid_dosyasi")
        if kill -0 "$PID" 2>/dev/null; then
            echo "AKTİF: Port $p dinlemede (PID: $PID)."
        else
            echo "PASİF: Port $p kapalı görünüyor. PID dosyası temizleniyor."
            rm -f "$pid_dosyasi" 2>/dev/null
        fi
    else
        echo "KAPALI: Port $p dinlemede değil."
    fi
}


# --- Ana İşlem Akışı ---

# Eğer direkt socketctl olarak çağrıldıysa, action ve port al
if [ "$CMD_NAME" == "socketctl" ]; then
    ACTION="$1"
    PORT="$2"
    
    # Hata ayıklama modu
    if [ "$ACTION" == "debug" ]; then
        if [ "$2" == "on" ]; then
            DEBUG=true
            echo -e "\nDEBUG modu AÇIK. Tüm saçmalıklar $LOGFILE dosyasına yazılıyor."
        elif [ "$2" == "off" ]; then
            DEBUG=false
            echo -e "\nDEBUG modu KAPALI. Rahatlayabilirsin."
            rm -f "$LOGFILE" 2>/dev/null
        else
            echo -e "\nDEBUG için 'on' ya da 'off' de. Ne o, laftan anlamıyor musun?"
        fi
        exit 0
    fi

    # Eğer sadece 'socketctl' yazıldıysa yardım metnini göster
    if [ -z "$ACTION" ]; then
        echo -e "\nUlan dangalak! Ne yapmamı istiyorsun?"
        echo -e "Kullanım:"
        echo -e "  socketctl status <PORT>  - Portun durumunu sorgula."
        echo -e "  socketctl debug [on|off] - Hata ayıklama modunu ayarla."
        echo -e "  opensocket <PORT>        - Portu aç."
        echo -e "  shutdownsocket <PORT>    - Portu kapat."
        exit 1
    fi
    
    if [ "$ACTION" == "status" ]; then
        if [ -z "$PORT" ]; then
            echo -e "\nStatus için port numarası gir, tembel!"
            exit 1
        fi
        port_kontrol "$PORT"
        durum_kontrol_sozlu "$PORT"
        exit 0
    fi
fi 

# opensocket veya shutdownsocket olarak çağrıldıysa
if [ -z "$PORT" ]; then
    echo -e "\nUlan dangalak! Portu girmeden ne yapmamı bekliyorsun? Kullanım şekli belli: $CMD_NAME <PORT>"
    exit 1
fi

port_kontrol "$PORT"

case "$CMD_NAME" in
    opensocket)
        log_message "opensocket $PORT komutu calisti."

        # SESSİZ KONTROL YAPILIYOR
        if durum_kontrol_sessiz "$PORT"; then
            echo -e "\nAKTİF: Port $PORT dinlemede (PID: $(cat "$PIDFILE"))."
            echo -e "\nHata: Port $PORT zaten dinlemede. Boşuna yorma beni."
            exit 1
        fi
        
        echo -e "\nSENİN İÇİN port $PORT'u arka planda dinlemeye alıyorum..."
        # nc'yi arka planda başlat
        nc -l -k -p "$PORT" -v > /dev/null 2>&1 &
        
        echo $! > "$PIDFILE"
        log_message "nc islemi baslatildi, PID: $! dosyaya yazildi."
        
        echo -e "Port $PORT başarıyla açıldı. Kapatmak için: shutdownsocket $PORT"
        ;;
        
    shutdownsocket)
        log_message "shutdownsocket $PORT komutu calisti."

        if ! durum_kontrol_sessiz "$PORT"; then
            echo -e "\nHata: Port $PORT zaten kapalı görünüyor. Temiz iş."
            exit 1
        fi
        
        PID=$(cat "$PIDFILE")
        log_message "Kapatilacak PID: $PID"
        
        kill "$PID" 2>/dev/null
        
        if [ $? -eq 0 ]; then
            echo -e "\nİş bitti. Port $PORT (PID $PID) kılıçtan geçirildi ve kapatıldı."
            rm -f "$PIDFILE"
            log_message "PID $PID basariyla sonlandirildi ve dosya silindi."
        else
            echo -e "\nHata: Süreç $PID bulunamadı. Muhtemelen Termux öldürdü. Dosyayı temizledim."
            rm -f "$PIDFILE"
            log_message "PID dosyasi vardi ancak surec calismiyordu. Dosya temizlendi."
        fi
        ;;
esac
