Proje Adı: Socketctl - Termux Ortamı için Gelişmiş Soket Yönetim Betiği
Sürüm: 1.0 (Bash/Netcat Tabanlı) Geliştirici: KodMaster31

1. Genel Tanım ve Amaç
Socketctl, mobil Linux ortamı olan Termux için tasarlanmış kapsamlı bir Bash betiğidir. Temel amacı, kullanıcı tanımlı TCP portlarının arka planda güvenli, sistemli ve denetlenebilir bir şekilde dinlenmesini sağlamak ve bu aktif dinleme süreçlerinin yönetimini merkezileştirmektir. Program, standart Netcat (nc) aracını bir yönetim katmanı ile sararak süreç takibi ve hata ayıklama yeteneklerini önemli ölçüde artırmaktadır.

2. Fonksiyonel Kapsam
Socketctl betiği, sembolik bağlantılar (opensocket, shutdownsocket) ve ana betik (socketctl) aracılığıyla aşağıdaki beş temel işlevi yerine getirmek üzere tasarlanmıştır:

2.1. Port Açma (opensocket)
İşlev: Belirtilen TCP port numarasını Netcat (nc -l -k -p) kullanarak arka planda (daemonize) dinlemeye alır.

Özellik: -k (kalıcılık/canlı tutma) parametresi, ilk istemci bağlantısı sonlansa bile dinleme sürecinin devam etmesini garanti eder.

Kontrol Mekanizması: Portun zaten aktif olup olmadığı kontrol edilir. Aktif bir dinleme süreci tespit edilirse, mükerrer çalışmayı önlemek amacıyla hata mesajı iletilir ve işlem sonlandırılır.

Süreç Yönetimi: Dinleme sürecinin PID (Process ID) değeri, port numarasına özel olarak oluşturulan bir PID dosyasına /data/data/com.termux/files/usr/tmp/socket.<port>.pid kaydedilir.

2.2. Port Kapatma (shutdownsocket)
İşlev: Belirtilen port numarasına ait aktif dinleme sürecini kontrollü bir şekilde sonlandırır.

Kapatma Mekanizması:

Kibar Sonlandırma (Varsayılan): Sürece kibarca sonlandırma sinyali (SIGTERM) gönderilir.

Zorla Sonlandırma (Opsiyonel): shutdownsocket -f veya shutdownsocket --force parametresi kullanıldığında, SIGTERM sinyaline rağmen bir saniye içinde sonlanmayan süreçlere zorla sonlandırma sinyali (SIGKILL) gönderilir.

Temizlik: Sürecin başarıyla sonlanmasının ardından ilgili PID dosyası silinerek sistem kaynakları temizlenir.

2.3. Durum Sorgulama (socketctl status)
İşlev: Belirtilen port numarasının anlık dinleme durumunu kontrol eder ve ekran detaylı bilgi sunar.

Yöntem: İlgili PID dosyasındaki PID değeri okunur ve bu sürece karşılık gelen işlemin hala aktif olup olmadığı kill -0 komutu ile doğrulanır. Süreç çalışmıyorsa PID dosyası geçersiz kabul edilerek silinir.

2.4. Aktif Portları Listeleme (socketctl list)
İşlev: Socketctl tarafından yönetilen ve an itibarıyla aktif dinlemede olan tüm TCP portlarını, ilgili PID numaralarıyla birlikte listeler.

Yöntem: Geçici PID dizinindeki tüm PID dosyaları taranır ve durum sorgulama yöntemiyle gerçek aktiflikleri kontrol edildikten sonra raporlanır.

2.5. Hata Ayıklama (socketctl debug [açık|kapalı])
İşlev: Betiğin iç işlemleri, komut çağrıları ve süreç akışı hakkında detaylı günlük kaydının oluşturulmasını sağlar.

Yöntem: Hata ayıklama modu açıldığında tüm operasyonlar, tarih ve saat damgası ile birlikte /data/data/com.termux/files/usr/tmp/socketctl.log dosyasında loglanır. Bu işlev, hata tespiti ve performans analizleri için kritik önem taşır.

3. Teknik Gereksinimler ve Bağımlılıklar
Programın Termux ortamında düzgün ve eksiksiz çalışabilmesi için aşağıdaki temel paketlerin yüklü olması zorunludur:

wget (İndirme ve güncelleme işlemleri için)

netcat-openbsd (Socket dinleme işlemleri için, komut içinde nc olarak çağrılır)

4. Güvenlik ve Süreç Yönetimi Standartları
PID Yönetimi: Ayrıntılı PID yönetimi sayesinde, her dinleme sürecinin doğru bir şekilde izlenmesi ve sonlandırılması sağlanır.

Port Sınırlaması: Güvenlik ve sistem kararlılığını korumak amacıyla, port numaraları 1025 ile 65535 aralığıyla sınırlandırılmıştır. Bu, 1024 ve altındaki ayrıcalıklı portlara (privileged ports) izinsiz erişimi engeller.

Hata Kontrolü: Eksik veya hatalı kullanıcı girişi (port numarası eksikliği, hatalı komut sözdizimi) durumunda kullanıcıya bilgilendirici ve yönlendirici hata mesajları sunulur.

5. Kurulum Prosedürü
5.1. Termux Ortamında Kurulum
Termux komut satırında tek bir komut ile indirme, çalıştırma izni verme ve sembolik bağlantıları kurma işlemleri tamamlanır:

Bash

wget -O $PREFIX/bin/socketctl https://raw.githubusercontent.com/KodMaster31/OpenSocket/refs/heads/main/socketctl.sh && chmod +x $PREFIX/bin/socketctl && ln -s $PREFIX/bin/socketctl $PREFIX/bin/opensocket && ln -s $PREFIX/bin/socketctl $PREFIX/bin/shutdownsocket
5.2. Windows (PowerShell) Ortamında Kurulum
Bu betiğin Windows'taki eşdeğeri olan PowerShell sürümünü indirmek ve çalıştırmak için aşağıdaki komutlar sırayla uygulanır:

İndirme:

PowerShell

Invoke-WebRequest -Uri "https://raw.githubusercontent.com/KodMaster31/OpenSocket/refs/heads/main/SocketControl.ps1" -OutFile "SocketControl.ps1"
Yürütme Yetkisi Verme: (Betiklerin yerel ortamda çalıştırılmasına izin verir.)

PowerShell

Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
Çalıştırma:

PowerShell

. .\SocketControl.ps1
