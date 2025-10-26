Program Adı
​socketctl (Ana Çalıştırılabilir Dosya)
​Komut İsimleri (Sembolik Bağlantılar)
​opensocket
​shutdownsocket
​Geliştirici
​KodiMaster31 (Mustafa)
​Amaç
​Bu bash betiği, Termux ortamında kullanıcı tanımlı bir TCP portunu arka planda dinlemeye almak (opensocket) ve bu dinleme işlemini güvenli bir şekilde sonlandırmak (shutdownsocket) amacıyla tasarlanmıştır. Program, Netcat (nc) aracı üzerinden socket yönetimini kolaylaştırmaktadır.
​Kurulum Kaynağı (Repository)
​Adres: https://github.com/KodMaster31/OpenSocket
​Dosya: socketctl.sh
​Ham (Raw) Bağlantı: https://raw.githubusercontent.com/KodMaster31/OpenSocket/refs/heads/main/socketctl.sh
​Ön Koşullar ve Bağımlılıklar
​Programın Termux mobil ortamında stabil çalışması için aşağıdaki paketlerin sistemde yüklü olması zorunludur:
​wget (Dosya indirme aracı)
​netcat-openbsd (Socket dinleme aracı, komut içi nc olarak kullanılır)
​Kurulum Prosedürü (Tek Satır Komut)
​Aşağıdaki komut, gerekli bağımlılıkların kontrolü ve kurulumu yapılmadan, yalnızca betiğin indirilmesi ve sistem komutları olarak tanımlanması işlemlerini gerçekleştirir. Bu komutun başarılı olması için kullanıcının önceden wget ve netcat-openbsd paketlerini kurmuş olması gerekmektedir.
Kullanım Kılavuzu
​Program, komut adı ve dinlenmesi/kapatılması istenen port numarası argümanı ile çalıştırılır.
Port Açma opensocket <PORT_NUMARASI> Belirtilen TCP portunu arka planda sürekli dinlemeye alır.
Port Kapatma shutdownsocket <PORT_NUMARASI> Belirtilen port numarasında aktif olan dinleme sürecini sonlandırır.
Örnekler:
​3131 numaralı portu dinlemeye alma:
opensocket 3131
​3131 numaralı porttaki dinlemeyi sonlandırma:
shutdownsocket 3131
​Teknik İşleyiş Özeti
​Çalıştırma Tespiti: Betik, $0 değişkeni ile hangi sembolik link (yani opensocket veya shutdownsocket) üzerinden çağrıldığını tespit eder.
​PID Yönetimi: Dinlemeye alınan her port için, sürecin PID (Process ID) değeri, $PREFIX/tmp/socket.<PORT>.pid formatında geçici bir dosyaya kaydedilir.
​Açma (opensocket): Belirtilen port boş ise, netcat (nc -l -k -p $PORT) komutunu arka planda çalıştırır ve PID'yi ilgili PID dosyasına yazar. -k parametresi, ilk bağlantı kesilse bile dinlemeyi sürdürmesini sağlar.
​Kapatma (shutdownsocket): İlgili PID dosyasından süreç kimliğini okur ve kill komutu ile bu süreci sonlandırır. Ardından geçici PID dosyası silinir.
​Hata Kontrolü: Program, geçersiz port numarası girilmesi veya zaten açık/kapalı olan bir port üzerinde işlem yapılmaya çalışılması gibi durumlarda kullanıcıya uyarılar sunar.
