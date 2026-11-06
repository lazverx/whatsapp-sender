# WhatsApp Auto Sender (Windows Desktop Automation)

Tool otomasi pengiriman pesan pembuka (*broadcast* pembuka) WhatsApp semi-otomatis & otomatis berbasis Windows PowerShell Engine dan Win32 API. Dirancang untuk kebutuhan broadcast protokoler eksekutif (seperti peserta program LDP PLN) dengan perlindungan anti-spam filter WhatsApp.

## 🚀 Fitur Utama

1. **Dual Template System (Pak & Bu)**:
   - Otomatis mendeteksi sapaan gender peserta dari kontak (`Pak` atau `Bu`).
   - Menggunakan `template_pak.txt` untuk sapaan pria (*Bapak/Pak*), dan `template_bu.txt` untuk sapaan wanita (*Ibu/Bu*).
2. **Win32 API Focus Locking Engine**:
   - Memanfaatkan `SwitchToThisWindow`, `SetForegroundWindow`, dan `keybd_event` untuk mengatasi *focus locking* pada WhatsApp Desktop (UWP/WebView2) di Windows 10 & 11.
   - Mengirim tombol `ENTER` secara native ke jendela chat tanpa drop keystrokes.
3. **Safety Delay Randomizer**:
   - Jeda acak antar pengiriman (default: 5 s.d. 10 detik) agar ritme pengiriman tidak berpola kaku sehingga aman dari deteksi spam bot WhatsApp.
4. **Dukungan Format Kontak Fleksibel**:
   - Otomatis menormalisasi nomor HP (`08...` atau `+62...` menjadi format standar internasional `62...`).
   - Mendukung format `Nomor, Nama Lengkap`.
5. **Mode Otomatis & Semi-Otomatis**:
   - **Mode Otomatis**: Buka chat -> tunggu loading chat -> fokus jendela -> kirim pesan -> hitung jeda acak -> lanjut kontak berikutnya.
   - **Mode Semi-Otomatis**: Buka chat -> user memeriksa pesan terlebih dahulu -> tekan Enter di terminal untuk konfirmasi kirim dan lanjut.

---

## 📁 Struktur Berkas

```
whatsapp-sender/
├── kirim_wa.bat                 # Launcher 1-klik untuk menjalankan program
├── kirim_wa.ps1                 # Core automation engine (PowerShell + Win32 API)
├── nomor.txt                    # Daftar target nomor WhatsApp & nama peserta
├── template_pak.txt             # Template pesan khusus peserta Bapak / Pak
├── template_bu.txt              # Template pesan khusus peserta Ibu / Bu
├── template.txt                 # Template cadangan / universal (Bapak/Ibu)
├── PANDUAN.txt                  # Dokumentasi panduan operasional bahasa Indonesia
└── riwayat_kirim.log            # Log riwayat status pengiriman
```

---

## 🛠️ Cara Penggunaan

1. **Siapkan WhatsApp**:
   - Pastikan aplikasi **WhatsApp Desktop (Windows)** sudah login dan terbuka di laptop/PC.
2. **Atur Kontak**:
   - Buka `nomor.txt`, masukkan kontak 1 nomor per baris:
     ```text
     6281234567890, Pak Budi Santoso
     6281118736321, Bu Siti Rahma
     ```
3. **Sesuaikan Template**:
   - Edit teks pada `template_pak.txt` dan `template_bu.txt`.
   - Gunakan placeholder `[Nama Lengkap]` di mana nama beserta sapaan akan disisipkan.
4. **Jalankan**:
   - Klik 2x pada file `kirim_wa.bat`.
   - Pilih target WhatsApp (Aplikasi Desktop disarankan).
   - Pilih mode pengiriman (Otomatis / Semi-otomatis).

---

## 👤 Pengembang & Handover
- **Praktikan**: Faiz Akhrian Putra (SMK Negeri 1 Gunungputri)
- **Instansi PKL**: Clevio Coder Camp / Yayasan Clevio Social Innovation
- **Periode**: Juli – November 2026
