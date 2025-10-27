import sys
import os
import socket
import subprocess
import time
import signal # Linux/Termux kill sinyali için (taşınabilirlik amaçlı)

# Sabitler (Windows'ta geçici dosyalar için %TEMP% kullanılır)
PID_DIR = os.path.join(os.environ.get('TEMP', r'C:\Temp'), "SocketControl")
PID_FILE_TEMPLATE = "socket.{}.pid"

# --- Yardımcı Fonksiyonlar ---

def log_message(message):
    """Basit loglama işlevi."""
    LOG_FILE = os.path.join(PID_DIR, "socketctl.log")
    timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
    with open(LOG_FILE, 'a') as f:
        f.write(f"[{timestamp}] {message}\n")

def port_kontrol(port):
    """Port numarasının geçerliliğini kontrol eder."""
    try:
        port = int(port)
        if not (1025 <= port <= 65535):
            print("\nHata: Port numarası 1025 ile 65535 arasında olmalı. Ne sallıyorsun?\n", file=sys.stderr)
            sys.exit(1)
        return port
    except ValueError:
        print("\nHata: Port numarası tam sayı olmalı. Harf falan girme.\n", file=sys.stderr)
        sys.exit(1)

def get_pid_file_path(port):
    """PID dosyasının tam yolunu döner."""
    os.makedirs(PID_DIR, exist_ok=True)
    return os.path.join(PID_DIR, PID_FILE_TEMPLATE.format(port))

def durum_kontrol_sessiz(port):
    """
    Portun aktif olup olmadığını sessizce kontrol eder.
    Dönen değer: (bool aktif, int pid)
    """
    pid_file = get_pid_file_path(port)

    if os.path.exists(pid_file):
        try:
            with open(pid_file, 'r') as f:
                pid = int(f.read().strip())
        except ValueError:
            log_message(f"Hata: Bozuk PID dosyası {pid_file} temizlendi.")
            os.remove(pid_file)
            return False, 0
        
        # Windows'ta PID'nin çalışıp çalışmadığını kontrol etme: tasklist /FI
        try:
            # Tasklist'ten sadece bu PID'yi arıyoruz
            result = subprocess.run(
                ['tasklist', '/FI', f"PID eq {pid}"], 
                capture_output=True, text=True, check=True, encoding='cp857'
            )
            
            # Eğer tasklist PID'yi bulduysa, başlık satırları hariç bir sonuç satırı olur.
            if f" {pid} " in result.stdout:
                 log_message(f"PID {pid} aktif.")
                 return True, pid
            else:
                 # Süreç yok, dosyayı temizle
                log_message(f"PID {pid} süreci bulunamadı, PID dosyası temizlendi.")
                os.remove(pid_file)
                return False, 0
                
        except Exception as e:
            # tasklist çalışmazsa veya hata verirse (Genelde Windows'ta çalışır)
            log_message(f"tasklist kontrolü sırasında hata oluştu: {e}")
            os.remove(pid_file)
            return False, 0
    else:
        return False, 0

# --- Ana İşlevler ---

def opensocket_main(port_num):
    """Portu arka planda dinlemeye alır."""
    port = port_kontrol(port_num)
    aktif, pid = durum_kontrol_sessiz(port)
    log_message(f"opensocket {port} çalıştırıldı.")

    if aktif:
        print(f"AKTİF: Port {port} dinlemede (PID: {pid}).")
        print(f"Hata: Port {port} zaten dinlemede. Boşuna yorma beni.", file=sys.stderr)
        sys.exit(1)

    print(f"\nSENİN İÇİN port {port}'u arka planda dinlemeye alıyorum...")
    
    # Python betiğini kendi kendine arka planda başlatma
    try:
        # sys.executable: Çalışan python yorumlayıcısının yolu
        # __file__: Mevcut scriptin yolu
        # 'listen': Arka plan dinleme işlevini çağıran komut
        
        # subprocess.CREATE_NEW_CONSOLE: Windows'ta yeni, görünmez bir konsol açar. (Daha stabil)
        process = subprocess.Popen(
            [sys.executable, __file__, 'listen', str(port)],
            creationflags=subprocess.CREATE_NEW_CONSOLE, # Windows'a özel
            close_fds=True
        )
        
        # PID'yi dosyaya yaz
        pid_file = get_pid_file_path(port)
        with open(pid_file, 'w') as f:
            f.write(str(process.pid))
        
        log_message(f"Dinleme süreci başlatıldı. Port: {port}, PID: {process.pid}")
        print(f"Port {port} başarıyla açıldı (PID: {process.pid}). Kapatmak için: python socketctl.py shutdown {port}")
    
    except Exception as e:
        log_message(f"opensocket başlatma hatası: {e}")
        print(f"\nBeklenmedik bir hata oluştu: {e}", file=sys.stderr)
        sys.exit(1)


def shutdownsocket_main(port_num, force=False):
    """Port dinlemesini sonlandırır."""
    port = port_kontrol(port_num)
    aktif, pid = durum_kontrol_sessiz(port)
    log_message(f"shutdownsocket {port} {'(Force)' if force else '(Kibar)'} çalıştırıldı.")

    if not aktif:
        print(f"\nHata: Port {port} zaten kapalı görünüyor. Temiz iş.", file=sys.stderr)
        sys.exit(1)

    # Süreci sonlandırma
    try:
        # Kibarca sonlandırma (SIGTERM/taskkill)
        subprocess.run(['taskkill', '/PID', str(pid), '/T'], check=False, capture_output=True)
        time.sleep(0.5)
        
        # Zorla kapatma mantığı (SIGKILL/taskkill /F)
        if force or (durum_kontrol_sessiz(port)[0]):
            if force:
                print(f"Uyarı: Süreç {pid} kibarca kapanmayı reddetti. ŞİDDET UYGULANIYOR (/F)!")
            
            subprocess.run(['taskkill', '/F', '/PID', str(pid), '/T'], check=False, capture_output=True)
            time.sleep(0.5)

        # Son Kontrol
        if not durum_kontrol_sessiz(port)[0]:
            print(f"\nİş bitti. Port {port} (PID {pid}) kılıçtan geçirildi ve kapatıldı.")
            # PID dosyası, dinleme sürecinin listen_main'deki 'finally' bloğu tarafından da temizlenir.
            # Ama biz de temizleyelim.
            if os.path.exists(get_pid_file_path(port)):
                os.remove(get_pid_file_path(port))
        else:
            log_message(f"Hata: Süreç {pid} sonlandırılamadı.")
            print(f"\nHata: Süreç {pid} sonlandırılamadı. Manuel kontrol gerekli.", file=sys.stderr)
            sys.exit(1)
            
    except Exception as e:
        log_message(f"shutdownsocket hatası: {e}")
        print(f"Hata oluştu: {e}", file=sys.stderr)
        sys.exit(1)


def status_main(port_num):
    """Portun durumunu ekrana basar."""
    port = port_kontrol(port_num)
    aktif, pid = durum_kontrol_sessiz(port)

    if aktif:
        print(f"AKTİF: Port {port} dinlemede (PID: {pid}).")
    else:
        print(f"KAPALI: Port {port} dinlemede değil.")

def list_main():
    """Tüm aktif portları listeler."""
    print("\n--- Aktif Socket Dinlemeleri ---")
    found = False
    
    if not os.path.exists(PID_DIR):
        print("  Aktif dinlemede olan port bulunamadı.")
        return

    for filename in os.listdir(PID_DIR):
        if filename.startswith("socket.") and filename.endswith(".pid"):
            try:
                port_str = filename.split('.')[1]
                port = int(port_str)
                aktif, pid = durum_kontrol_sessiz(port)
                
                if aktif:
                    print(f"  Port: {port} (PID: {pid})")
                    found = True
            except:
                pass # Hatalı dosya adlarını yoksay

    if not found:
        print("  Aktif dinlemede olan port bulunamadı. Rahatlık batıyor mu?")
    print("-------------------------------------")


def listen_main(port_num):
    """Arka plan süreci tarafından çağrılan asıl dinleme işlevi."""
    port = port_kontrol(port_num)
    
    # Socket'i başlat
    server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1) # Portu hemen tekrar kullanabilmek için
    
    try:
        # Dinleme sürecine ait PID'yi dosyadan okuma (PID'yi Popen zaten yazdı)
        
        server_socket.bind(('0.0.0.0', port))
        server_socket.listen(5)
        log_message(f"Port {port} dinlemeye başladı (Sürecin PID'si: {os.getpid()}).")
        
        # Sonsuza kadar dinle (Netcat -k muadili)
        while True:
            # Burası blocking (engelleyici) olduğu için süreç uyurken çok az CPU kullanır.
            conn, addr = server_socket.accept()
            # Bağlantı geldi, hiçbir şey yapmayıp hemen kapatıyoruz (Netcat'in basit dinleme işlevi gibi).
            log_message(f"Port {port}'a bağlantı geldi: {addr[0]}")
            conn.close() 

    except KeyboardInterrupt:
        # Terminalde Ctrl+C ile kapatılırsa
        log_message(f"Port {port} Klayve kesintisi ile kapatılıyor.")
    except Exception as e:
        # Dinleme hatası oluşursa
        log_message(f"Port {port} dinleme sırasında hata oluştu: {e}")
    finally:
        server_socket.close()
        # Dinleme süreci kapandığında PID dosyasını sil
        pid_file = get_pid_file_path(port)
        if os.path.exists(pid_file):
             log_message(f"Port {port} kapandı. PID dosyası temizlendi.")
             os.remove(pid_file)


def usage():
    """Kullanım Kılavuzu."""
    print("\nUlan dangalak! Ne yapmamı istiyorsun?")
    print("Kullanım (CMD veya PowerShell'de):")
    print("  python socketctl.py opensocket <PORT>    - Portu aç.")
    print("  python socketctl.py shutdown <PORT>      - Portu kapat (Kibarca).")
    print("  python socketctl.py shutdown -f <PORT>   - Portu kapat (Zorla).")
    print("  python socketctl.py status <PORT>        - Portun durumunu sorgula.")
    print("  python socketctl.py list                 - Tüm aktif portları listele.")
    sys.exit(1)


# --- Ana Program Girişi ---

if __name__ == "__main__":
    if len(sys.argv) < 2:
        usage()
        
    action = sys.argv[1].lower()
    
    if action == 'list':
        list_main()
    elif action == 'status':
        if len(sys.argv) != 3: usage()
        status_main(sys.argv[2])
    elif action == 'opensocket':
        if len(sys.argv) != 3: usage()
        opensocket_main(sys.argv[2])
    elif action == 'shutdown':
        if len(sys.argv) < 3 or len(sys.argv) > 4: usage()
        
        force = False
        port_arg_index = 2
        
        if sys.argv[2].lower() in ['-f', '--force']:
            force = True
            port_arg_index = 3
            if len(sys.argv) != 4: usage() # Zorla kapama için 4 argüman olmalı.
        
        shutdownsocket_main(sys.argv[port_arg_index], force)

    elif action == 'listen':
        # Bu, sadece opensocket komutu tarafından arka planda çağrılır.
        if len(sys.argv) != 3: usage()
        listen_main(sys.argv[2])
    else:
        usage()
