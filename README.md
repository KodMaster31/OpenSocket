
socketctl, Termux mobil ortamı için tasarlanmış kapsamlı bir Bash betiğidir. Temel amacı, kullanıcı tanımlı TCP portlarının arka planda güvenli ve sistematik bir şekilde dinlenmesini sağlamak ve bu süreçleri etkin bir şekilde yönetmektir. Program, standart Netcat (nc) aracını kullanarak socket yönetimini basitleştirmekte ve süreç takibi için PID (Process ID) dosyalarını kullanmaktadır.
Komutlar ve İşlevsellik
Program, sembolik bağlantılar (opensocket, shutdownsocket) ve ana betik (socketctl) aracılığıyla beş temel işlevi yerine getirmek üzere geliştirilmiştir:
1. Port Açma (opensocket <PORT>)
 * İşlev: Belirtilen port numarasını Netcat (nc -l -k -p) ile arka planda dinlemeye alır. -k (keep-alive) parametresi sayesinde ilk bağlantı kesilse bile dinleme süreci devam eder.
 * Kontrol: Portun zaten aktif olup olmadığı kontrol edilir. Aktif ise hata mesajı verir.
 * Yönetim: Dinleme sürecinin PID değeri, port numarasına özel bir dosyaya (/data/data/com.termux/files/usr/tmp/socket.<PORT>.pid) kaydedilir.
2. Port Kapatma (shutdownsocket <PORT>)
 * İşlev: Belirtilen port numarasının PID dosyasını okur ve süreci sonlandırır.
 * Kapatma Mekanizması:
   * Varsayılan olarak, sürece kibarca sonlandırma sinyali (SIGTERM) gönderilir.
   * Opsiyonel olarak, shutdownsocket -f <PORT> veya shutdownsocket --force <PORT> komutu ile sürece önce SIGTERM, bir saniye içinde sonlanmazsa zorla sonlandırma sinyali (SIGKILL) gönderilir.
 * Temizlik: Sürecin başarıyla sonlanmasının ardından ilgili PID dosyası silinir.
3. Durum Sorgulama (socketctl status <PORT>)
 * İşlev: Belirtilen port numarasının aktif dinlemede olup olmadığını kontrol eder ve ekrana detaylı bilgi sunar.
 * Yöntem: PID dosyasını kontrol eder ve bu PID'ye karşılık gelen sürecin hala çalışıp çalışmadığını kill -0 komutu ile doğrular. Süreç çalışmıyorsa PID dosyası temizlenir.
4. Aktif Portları Listeleme (socketctl list)
 * İşlev: Şu anda socketctl tarafından yönetilen ve aktif dinlemede olan tüm portları, ilgili PID numaralarıyla birlikte listeler.
 * Yöntem: Geçici PID dizinindeki tüm PID dosyaları taranır ve süreçleri hala aktif olan portlar raporlanır.
5. Hata Ayıklama (socketctl debug [on|off])
 * İşlev: Betiğin iç operasyonları ve komut akışları hakkında ayrıntılı günlük kaydı tutulmasını sağlar.
 * Yöntem: Debug modu açıldığında tüm operasyonlar, tarih ve saat damgası ile birlikte /data/data/com.termux/files/usr/tmp/socketctl.log dosyasına yazılır. Bu, hata tespiti ve performans takibi için kritik öneme sahiptir.
Teknik Gereksinimler ve Bağımlılıklar
Programın Termux ortamında düzgün çalışabilmesi için aşağıdaki temel paketlerin yüklü olması şarttır:
 * wget (İndirme ve güncelleme işlemleri için)
 * netcat-openbsd (Socket dinleme operasyonları için, komut içinde nc olarak çağrılır)
Güvenlik ve Süreç Yönetimi
 * PID Yönetimi: Program, süreçlerin doğru şekilde sonlandırılabilmesi için her dinleme sürecinin PID'sini geçici dosyalarda saklar.
 * Port Sınırlaması: Güvenlik ve sistem stabilitesi nedeniyle, port numaraları 1025 ile 65535 aralığıyla sınırlandırılmıştır. 1024 ve altındaki ayrıcalıklı portlara (privileged ports) erişim engellenmiştir.
 * Hata Kontrolü: Eksik veya hatalı argüman girişi (port numarası eksikliği, hatalı komutlar) durumunda kullanıcıya bilgilendirici hatalar döndürülür.
Termux'tan indirmek için;

wget -O $PREFIX/bin/socketctl https://raw.githubusercontent.com/KodMaster31/OpenSocket/refs/heads/main/socketctl.sh && chmod +x $PREFIX/bin/socketctl && ln -s $PREFIX/bin/socketctl $PREFIX/bin/opensocket && ln -s $PREFIX/bin/socketctl $PREFIX/bin/shutdownsocket
EĞER WİNDOWSTA BU SCRİPTİ İNDİRMEK İSTERSENİZ POWER SHEL'DE BUNU ÇALIŞTIRIN:

Invoke-WebRequest -Uri "https://raw.githubusercontent.com/KodMaster31/OpenSocket/refs/heads/main/SocketControl.ps1" -OutFile "SocketControl.ps1"
