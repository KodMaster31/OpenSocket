#!/data/data/com.termux/files/usr/bin/bash

# Hangi isimle çağrıldığına bak (opensocket veya shutdownsocket)
CMD_NAME=$(basename "$0")
PORT="$1"
PIDFILE="/data/data/com.termux/files/usr/tmp/socket.${PORT}.pid"

# --- Kaba Hata Kontrolü ve Yönlendirme ---
if [ -z "$PORT" ]; then
    echo -e "\nUlan! Portu girmeden ne yapmamı bekliyorsun? Kullanım şekli belli: $CMD_NAME <PORT>"
    exit 1
fi

# Port numarasını kontrol et
if ! [[ "$PORT" =~ ^[0-9]+$ ]] || [ "$PORT" -le 1024 ] || [ "$PORT" -gt 65535 ]; then
    echo -e "\nHata: Geçersiz port $PORT. 1025-65535 arası olmalı, gerisi çöp.\n"
    exit 1
fi

case "$CMD_NAME" in
    opensocket)
        # Port açma işlemi (open)
        if [ -f "$PIDFILE" ]; then
            echo -e "\nHata: Port $PORT zaten dinlemede (PID: $(cat "$PIDFILE")). Önce 'shutdownsocket $PORT' kullan.\n"
            exit 1
        fi
        
        echo -e "\nSENİN İÇİN port $PORT'u arka planda dinlemeye alıyorum..."
        # netcat'i arka planda başlat
        nc -l -k -p "$PORT" -v > /dev/null 2>&1 &
        
        # PID'yi dosyaya yaz
        echo $! > "$PIDFILE"
        
        echo -e "Port $PORT başarıyla açıldı. Kapatmak için: shutdownsocket $PORT"
        ;;
        
    shutdownsocket)
        # Port kapatma işlemi (close)
        if [ ! -f "$PIDFILE" ]; then
            echo -e "\nHata: Port $PORT zaten kapalı görünüyor. Beyinsiz gibi tekrar deneme.\n"
            exit 1
        fi
        
        # PID'yi al ve öldür
        PID=$(cat "$PIDFILE")
        kill "$PID" 2>/dev/null
        
        if [ $? -eq 0 ]; then
            echo -e "\nİş bitti. Port $PORT (PID $PID) kılıçtan geçirildi ve kapatıldı."
            rm -f "$PIDFILE"
        else
            echo -e "\nHata: Süreç $PID zaten yok olmuş. Termux mu öldürdü ne? Dosyayı temizledim."
            rm -f "$PIDFILE"
        fi
        ;;

    *)
        echo -e "\nÇağrılan komut adı anlaşılamadı. Sembolik linklerde bir b*kluk var galiba."
        exit 1
        ;;
esac
