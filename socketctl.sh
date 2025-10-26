#!/data/data/com.termux/files/usr/bin/bash

# Termux ortamında socket yönetimi (Geliştirilmiş Sürüm)

# Sabitler
CMD_NAME=$(basename "$0")
PORT="$1"
ACTION="$1" # 'socketctl status 3131' gibi çağrımlar için
PIDFILE="/data/data/com.termux/files/usr/tmp/socket.${PORT}.pid"
LOGFILE="/data/data/com.termux/files/usr/tmp/socketctl.log"
DEBUG=false # Hata ayıklama modu kapalı

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

durum_kontrol() {
    local p="$1"
    if [ -f "$PIDFILE" ]; then
        PID=$(cat "$PIDFILE")
        # Sürecin hala çalışıp çalışmadığını kontrol et
        if kill -0 "$PID" 2>/dev/null; then
            echo "AKTİF: Port $p dinlemede (PID: $PID)."
            return 0 # Aktif
        else
            echo "PASİF: Port $p kapalı görünüyor. PID dosyası temizleniyor."
            rm -f "$PIDFILE"
            return 1 # PID dosyası var ama süreç yok
        fi
    else
        echo "KAPALI: Port $p dinlemede değil."
        return 1 # Kapalı
    fi
}

# --- Ana İşlem Akışı ---

# Eğer direkt socketctl olarak çağrıldıysa, action ve port al
if [ "$CMD_NAME" == "socketctl" ]; then
    ACTION="$1"
    PORT="$2"
    
    # Hata ayıklama modunu aç/kapat kontrolü
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
        port_kontrol "$PORT"
        durum_kontrol "$PORT"
        exit 0
    fi
fi 

# opensocket veya shutdownsocket olarak çağrıldıysa
if [ -z "$PORT" ]; then
    echo -e "\nUlan dangalak! Portu girmeden ne yapmamı bekliyorsun? Kullanım şekli belli: $CMD_NAME <PORT>"
    exit 1
fi

# Port kontrolü
port_kontrol "$PORT"

case "$CMD_NAME" in
    opensocket)
        log_message "opensocket $PORT komutu calisti."

        if durum_kontrol "$PORT"; then
            echo -e "\nHata: Port $PORT zaten dinlemede. Boşuna yorma beni."
            exit 1
        fi
        
        echo -e "\nSENİN İÇİN port $PORT'u arka planda dinlemeye alıyorum..."
        # nc'yi arka planda başlat, -k ile bağlantı kopsa da dinlemeye devam etsin.
        nc -l -k -p "$PORT" -v > /dev/null 2>&1 &
        
        # PID'yi dosyaya yaz
        echo $! > "$PIDFILE"
        log_message "nc islemi baslatildi, PID: $! dosyaya yazildi."
        
        echo -e "Port $PORT başarıyla açıldı. Kapatmak için: shutdownsocket $PORT"
        ;;
        
    shutdownsocket)
        log_message "shutdownsocket $PORT komutu calisti."

        if [ ! -f "$PIDFILE" ]; then
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

    socketctl)
        # Eğer socketctl çağrıldıysa ve status değilse buraya düşer
        echo -e "\nNe yaptığını bilmiyorsun. 'status' komutunu mu unuttun?"
        exit 1
        ;;
esac
