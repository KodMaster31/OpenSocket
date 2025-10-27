import sys
import os
import socket
import subprocess
import time
import signal 

# Sabitler (Windows'ta gecici dosyalar icin %TEMP% kullanilir)
PID_DIR = os.path.join(os.environ.get('TEMP', r'C:\Temp'), "SocketControl")
PID_FILE_TEMPLATE = "socket.{}.pid"

# --- Yardimci Fonksiyonlar ---

def log_message(message):
    """Basit loglama islemi. Bu sefer SADECE Ingilizce karakterler kullanir."""
    LOG_FILE = os.path.join(PID_DIR, "socketctl.log")
    timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
    # encoding parametresi kaldirildi cunku artik Turkce karakter yok.
    try:
        os.makedirs(PID_DIR, exist_ok=True)
        with open(LOG_FILE, 'a') as f:
            f.write(f"[{timestamp}] {message}\n")
    except Exception as e:
        print(f"Loglama Hatasi: {e}", file=sys.stderr)

def port_kontrol(port):
    """Port numarasinin gecerliligini kontrol eder."""
    try:
        port = int(port)
        if not (1025 <= port <= 65535):
            print("\nHata: Port numarasi 1025 ile 65535 arasinda olmali. Ne salliyorsun?\n", file=sys.stderr)
            sys.exit(1)
        return port
    except ValueError:
        print("\nHata: Port numarasi tam sayi olmali. Harf falan girme.\n", file=sys.stderr)
        sys.exit(1)

def get_pid_file_path(port):
    """PID dosyasinin tam yolunu doner."""
    os.makedirs(PID_DIR, exist_ok=True)
    return os.path.join(PID_DIR, PID_FILE_TEMPLATE.format(port))

def durum_kontrol_sessiz(port):
    """
    Portun aktif olup olmadigini sessizce kontrol eder.
    Donen deger: (bool aktif, int pid)
    """
    pid_file = get_pid_file_path(port)

    if os.path.exists(pid_file):
        try:
            with open(pid_file, 'r') as f:
                pid = int(f.read().strip())
        except ValueError:
            log_message(f"Hata: Bozuk PID dosyasi {pid_file} temizlendi.")
            os.remove(pid_file)
            return False, 0
        
        # Windows'ta PID'nin calisip calismadigini kontrol etme: tasklist /FI
        try:
            # tasklist'ten sadece bu PID'yi ariyoruz
            result = subprocess.run(
                ['tasklist', '/FI', f"PID eq {pid}"], 
                capture_output=True, text=True, check=True, encoding='utf-8' # tasklist'ten gelen cevap UTF-8
            )
            
            if f" {pid} " in result.stdout:
                 log_message(f"PID {pid} aktif.")
                 return True, pid
            else:
                log_message(f"PID {pid} sureci bulunamadi, PID dosyasi temizlendi.")
                os.remove(pid_file)
                return False, 0
                
        except Exception as e:
            log_message(f"tasklist kontrolu sirasinda hata olustu: {e}")
            try:
                os.remove(pid_file)
            except:
                pass
            return False, 0
    else:
        return False, 0

# --- Ana Islevler ---

def opensocket_main(port_num):
    """Portu arka planda dinlemeye alir."""
    port = port_kontrol(port_num)
    aktif, pid = durum_kontrol_sessiz(port)
    log_message(f"opensocket {port} calistirildi.")

    if aktif:
        print(f"AKTIF: Port {port} dinlemede (PID: {pid}).")
        print(f"Hata: Port {port} zaten dinlemede. Bosuna yorma beni.", file=sys.stderr)
        sys.exit(1)

    print(f"\nSENIN ICIN port {port}'u arka planda dinlemeye aliyorum...")
    
    # Python betigini kendi kendine arka planda baslatma
    try:
        process = subprocess.Popen(
            [sys.executable, __file__, 'listen', str(port)],
            creationflags=subprocess.CREATE_NEW_CONSOLE,
            close_fds=True
        )
        
        # PID'yi dosyaya yaz
        pid_file = get_pid_file_path(port)
        with open(pid_file, 'w') as f:
            f.write(str(process.pid))
        
        log_message(f"Dinleme sureci baslatildi. Port: {port}, PID: {process.pid}")
        print(f"Port {port} basariyla acildi (PID: {process.pid}). Kapatmak icin: python socketctl.py shutdown {port}")
    
    except Exception as e:
        log_message(f"opensocket baslatma hatasi: {e}")
        print(f"\nBeklenmedik bir hata olustu: {e}", file=sys.stderr)
        sys.exit(1)


def shutdownsocket_main(port_num, force=False):
    """Port dinlemesini sonlandirir."""
    port = port_kontrol(port_num)
    aktif, pid = durum_kontrol_sessiz(port)
    log_message(f"shutdownsocket {port} {'(Force)' if force else '(Kibar)'} calistirildi.")

    if not aktif:
        print(f"\nHata: Port {port} zaten kapali gorunuyor. Temiz is.", file=sys.stderr)
        sys.exit(1)

    # Sureci sonlandirma
    try:
        # Kibarca sonlandirma (SIGTERM/taskkill)
        subprocess.run(['taskkill', '/PID', str(pid), '/T'], check=False, capture_output=True, encoding='utf-8')
        time.sleep(0.5)
        
        # Zorla kapatma mantigi (SIGKILL/taskkill /F)
        if force or (durum_kontrol_sessiz(port)[0]):
            if force:
                print(f"Uyari: Surec {pid} kibarca kapanmayi reddetti. SIDDET UYGULANIYOR (/F)!")
            
            subprocess.run(['taskkill', '/F', '/PID', str(pid), '/T'], check=False, capture_output=True, encoding='utf-8')
            time.sleep(0.5)

        # Son Kontrol
        if not durum_kontrol_sessiz(port)[0]:
            print(f"\nIs bitti. Port {port} (PID {pid}) kilictan gecirildi ve kapatildi.")
            if os.path.exists(get_pid_file_path(port)):
                os.remove(get_pid_file_path(port))
        else:
            log_message(f"Hata: Surec {pid} sonlandirilamadi.")
            print(f"\nHata: Surec {pid} sonlandirilamadi. Manuel kontrol gerekli.", file=sys.stderr)
            sys.exit(1)
            
    except Exception as e:
        log_message(f"shutdownsocket hatasi: {e}")
        print(f"Hata olustu: {e}", file=sys.stderr)
        sys.exit(1)


def status_main(port_num):
    """Portun durumunu ekrana basar."""
    port = port_kontrol(port_num)
    aktif, pid = durum_kontrol_sessiz(port)

    if aktif:
        print(f"AKTIF: Port {port} dinlemede (PID: {pid}).")
    else:
        print(f"KAPALI: Port {port} dinlemede degil.")

def list_main():
    """Tum aktif portlari listeler."""
    print("\n--- Aktif Socket Dinlemeleri ---")
    found = False
    
    if not os.path.exists(PID_DIR):
        print("  Aktif dinlemede olan port bulunamadi.")
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
                pass 

    if not found:
        print("  Aktif dinlemede olan port bulunamadi. Rahatlik batiyor mu?")
    print("-------------------------------------")


def listen_main(port_num):
    """Arka plan sureci tarafindan cagrilan asil dinleme islevi."""
    port = port_kontrol(port_num)
    
    server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1) 
    
    try:
        server_socket.bind(('0.0.0.0', port))
        server_socket.listen(5)
        log_message(f"Port {port} dinlemeye basladi (Surecin PID'si: {os.getpid()}).")
        
        while True:
            conn, addr = server_socket.accept()
            log_message(f"Port {port}'a baglanti geldi: {addr[0]}")
            conn.close() 

    except KeyboardInterrupt:
        log_message(f"Port {port} Klayve kesintisi ile kapaniyor.")
    except Exception as e:
        log_message(f"Port {port} dinleme sirasinda hata olustu: {e}")
    finally:
        server_socket.close()
        pid_file = get_pid_file_path(port)
        if os.path.exists(pid_file):
             log_message(f"Port {port} kapandi. PID dosyasi temizlendi.")
             os.remove(pid_file)


def usage():
    """Kullanim Kilavuzu."""
    print("\nUlan dangalak! Ne yapmami istiyorsun?")
    print("Kullanim (CMD veya PowerShell'de):")
    print("  python socketctl.py opensocket <PORT>    - Portu ac.")
    print("  python socketctl.py shutdown <PORT>      - Portu kapat (Kibarca).")
    print("  python socketctl.py shutdown -f <PORT>   - Portu kapat (Zorla).")
    print("  python socketctl.py status <PORT>        - Portun durumunu sorgula.")
    print("  python socketctl.py list                 - Tum aktif portlari listele.")
    sys.exit(1)


# --- Ana Program Girisi ---

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
            if len(sys.argv) != 4: usage() 
        
        shutdownsocket_main(sys.argv[port_arg_index], force)

    elif action == 'listen':
        if len(sys.argv) != 3: usage()
        listen_main(sys.argv[2])
    else:
        usage()
