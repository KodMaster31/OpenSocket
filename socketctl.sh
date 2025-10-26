#!/data/data/com.termux/files/usr/bin/bash

# Termux ortamında socket yönetimi (ULTIMATE SÜRÜM)

# Sabitler
CMD_NAME=$(basename "$0")
PORT="$1"
ACTION="$1"
PIDDIR="/data/data/com.termux/files/usr/tmp"
LOGFILE="$PIDDIR/socketctl.log"
DEBUG=false 

# --- Yardımcı Fonksiyonlar ---

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

get_pidfile() {
    echo "$PIDDIR/socket.${1}.pid"
}

# 0 = Aktif, 1 = Kapalı/Süreç Yok
durum_kontrol_sessiz() {
    local p="$1"
    local pid_dosyasi=$(get_pidfile "$p")

    if [ -f "$pid_dosyasi" ]; then
        PID=$(cat "$pid_dosyasi")
        if kill -0 "$PID" 2>/dev/null; then
            log_message "Port $p aktif (PID: $PID)"
            return 0 
        else
            log_message "Port $p PID dosyasi var ama surec yok. Temizleniyor."
            rm -f "$pid_dosyasi" 2>/dev/null
            return 1 
        fi
    else
        log_message "Port $p kapali."
        return 1 
    fi
}

# --- Ana İşlevler ---

# Kullanıcıya Çıktı Veren Durum Kontrolü
socketctl_status() {
    local p="$1"
    local pid_dosyasi=$(get_pidfile "$p")

    if [ -f "$pid_dosyasi" ]; then
        PID=$(cat "$pid_dosyasi")
        if kill -0 "$PID" 2>/dev/null; then
            echo "AKTİF: Port $p dinlemede (PID: $PID). Netcat ile."
        else
            echo "PASİF: Port $p kapalı görünüyor. PID dosyası temizleniyor."
            rm -f "$pid_dosyasi" 2>/dev/null
        fi
    else
        echo "KAPALI: Port $p dinlemede değil."
    fi
}

# Yeni: Listeleme İşlevi
socketctl_list() {
    echo -e "\n--- Aktif Socket Dinlemeleri ---"
    
    # PID dizinindeki tüm socket.*.pid dosyalarını döngüye al
    local found=false
    for pidfile in $PIDDIR/socket.*.pid; do
        # Dosya yoksa veya döngü hatasıysa atla
        [ -e "$pidfile" ] || continue
        
        local port_num=$(basename "$pidfile" | awk -F'[.]' '{print $2}')
        
        if durum_kontrol_sessiz "$port_num"; then
            PID=$(cat "$pidfile")
            echo "  Port: $port_num (PID: $PID)"
            found=true
        fi
    done

    if ! $found; then
        echo "  Aktif dinlemede olan port bulunamadı. Rahatlık batıyor mu?"
    fi
    echo "-------------------------------------"
}

# Yeni: Zorla Kapatma İşlevi
shutdown_socket_force() {
    local p="$1"
    local pid_dosyasi=$(get_pidfile "$p")

    if ! durum_kontrol_sessiz "$p"; then
        echo -e "\nHata: Port $p zaten kapalı görünüyor. Temiz iş."
        exit 1
    fi
    
    PID=$(cat "$pid_dosyasi")
    log_message "Force kapatma baslatiliyor. PID: $PID"

    # Önce kibarca dene (SIGTERM)
    kill "$PID" 2>/dev/null
    sleep 1

    if kill -0 "$PID" 2>/dev/null; then
        echo "Uyarı: Süreç $PID kibarca kapanmayı reddetti. ŞİDDET UYGULANIYOR (SIGKILL)!"
        kill -9 "$PID" 2>/dev/null
    fi

    if [ $? -eq 0 ]; then
        echo -e "\nİş bitti. Port $p (PID $PID) kılıçtan geçirildi ve KAPATILDI (Zorla)."
        rm -f "$pid_dosyasi"
        log_message "PID $PID zorla sonlandirildi."
    else
        echo -e "\nHata: Süreç $PID bulunamadı veya sonlandırılamadı. Dosyayı temizledim."
        rm -f "$pid_dosyasi"
        log_message "PID dosyasi vardi ancak surec calismiyordu. Dosya temizlendi."
    fi
}


# --- Program Girişi (Routing) ---

# Eğer direkt socketctl olarak çağrıldıysa
if [ "$CMD_NAME" == "socketctl" ]; then
    ACTION="$1"
    PORT="$2"
    
    case "$ACTION" in
        status)
            if [ -z "$PORT" ]; then echo -e "\nStatus için port numarası gir, tembel!"; exit 1; fi
            port_kontrol "$PORT"
            socketctl_status "$PORT"
            ;;
        
        list)
            socketctl_list
            ;;

        debug)
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
            ;;
            
        *)
            echo -e "\nUlan dangalak! Ne yapmamı istiyorsun?"
            echo -e "Kullanım:"
            echo -e "  socketctl status <PORT>  - Portun durumunu sorgula."
            echo -e "  socketctl list           - Tüm aktif portları listele."
            echo -e "  socketctl debug [on|off] - Hata ayıklama modunu ayarla."
            echo -e "  opensocket <PORT>        - Portu aç."
            echo -e "  shutdownsocket <PORT>    - Portu kapat."
            exit 1
            ;;
    esac
    exit 0
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

        if durum_kontrol_sessiz "$PORT"; then
            echo -e "\nAKTİF: Port $PORT dinlemede (PID: $(cat $(get_pidfile "$PORT")))."
            echo -e "\nHata: Port $PORT zaten dinlemede. Boşuna yorma beni."
            exit 1
        fi
        
        echo -e "\nSENİN İÇİN port $PORT'u arka planda dinlemeye alıyorum..."
        nc -l -k -p "$PORT" -v > /dev/null 2>&1 &
        
        echo $! > "$(get_pidfile "$PORT")"
        log_message "nc islemi baslatildi, PID: $! dosyaya yazildi."
        
        echo -e "Port $PORT başarıyla açıldı. Kapatmak için: shutdownsocket $PORT (veya zorla kapatmak için: shutdownsocket -f $PORT)"
        ;;
        
    shutdownsocket)
        # Zorla kapatma argümanı kontrolü
        if [ "$1" == "-f" ] || [ "$1" == "--force" ]; then
            PORT="$2"
            port_kontrol "$PORT"
            shutdown_socket_force "$PORT"
            exit 0
        fi

        log_message "shutdownsocket $PORT komutu calisti."

        if ! durum_kontrol_sessiz "$PORT"; then
            echo -e "\nHata: Port $PORT zaten kapalı görünüyor. Temiz iş."
            exit 1
        fi
        
        PID=$(cat "$(get_pidfile "$PORT")")
        log_message "Kapatilacak PID: $PID"
        
        kill "$PID" 2>/dev/null
        
        if [ $? -eq 0 ]; then
            echo -e "\nİş bitti. Port $PORT (PID $PID) kılıçtan geçirildi ve kapatıldı."
            rm -f "$(get_pidfile "$PORT")"
            log_message "PID $PID basariyla sonlandirildi ve dosya silindi."
        else
            echo -e "\nHata: Süreç $PID bulunamadı. Muhtemelen Termux öldürdü. Dosyayı temizledim."
            rm -f "$(get_pidfile "$PORT")"
            log_message "PID dosyasi vardi ancak surec calismiyordu. Dosya temizlendi."
        fi
        ;;
esac
