# E-Arsip Kesbangpol Konawe Utara — Versi Online Multiuser

Prototipe siap dipasang menggunakan **Supabase Auth + PostgreSQL + Supabase Storage (private bucket)** dan hosting statis (mis. Netlify). Menggunakan 10 kategori dan 39 subfolder sesuai spreadsheet sumber. Tidak ada file arsip dinas yang dimasukkan ke paket.

## Persiapan (wajib)

1. Buat **proyek Supabase baru** di https://supabase.com/ dan pilih wilayah server sesuai kebijakan instansi.
2. Buka **SQL Editor**, tempel seluruh isi `schema.sql`, lalu jalankan sekali. Script membuat `profiles`, `archives`, `archive_audit`, bucket privat `arsip-private`, trigger audit, dan aturan Row Level Security (RLS).
3. **Authentication → Providers / Signups**: nonaktifkan pendaftaran akun publik. Akun pegawai dibuat secara administratif di **Authentication → Users → Add user**. Tentukan email, kata sandi sementara, dan kewajiban reset password melalui prosedur instansi.
4. Buat satu akun pertama, salin **UUID** akun di Authentication → Users. Di SQL Editor jalankan:
   ```sql
   update public.profiles set role='admin' where id='UUID_AKUN_ADMIN';
   ```
   Pastikan akun itu benar-benar administrator kantor.
5. Buka **Project Settings → API Keys**, ambil **Project URL** dan **publishable key** (atau legacy anon key). Edit `config.js`:
   ```js
   window.EARSIP_CONFIG = {supabaseUrl:'https://YOUR-PROJECT.supabase.co',supabaseKey:'YOUR_PUBLISHABLE_KEY'};
   ```
   **Jangan** pernah menggunakan `service_role` atau secret key pada HTML/JS.
6. Unggah isi folder ini (`index.html`, `app.js`, `style.css`, `config.js`, `struktur.json`) ke hosting HTTPS seperti Netlify Drop atau hosting internal. Pilih domain dan TLS resmi. Jangan mengunggah `schema.sql` atau berkas cadangan ke folder publik.
7. Login melalui website dengan akun yang sudah dibuat. Admin dapat membuka halaman Pengguna untuk mengubah peran. Pendaftaran akun baru tetap melalui panel Supabase, bukan website.

## Hak akses

| Peran | Baca/unduh | Tambah/ubah | Hapus arsip | Kelola peran | Lihat audit |
|---|---|---|---|---|---|
| Admin | Ya | Ya | Ya | Ya | Ya |
| Petugas (operator) | Ya | Ya | Tidak | Tidak | Tidak |
| Pimpinan (viewer) | Ya | Tidak | Tidak | Tidak | Tidak |

Proteksi diterapkan di sisi server memakai RLS dan bucket Storage privat. **Semua pengguna terdaftar dapat membaca semua arsip**: jika ada arsip rahasia/per unit, tambahkan RLS per klasifikasi sebelum memakai dokumen tersebut. File disimpan secara privat; aplikasi mengunduh memakai sesi login dan tidak mengeluarkan tautan publik.

## Penting sebelum dipakai untuk data instansi asli

- Ini adalah **prototipe fungsional**, belum diaudit atau diuji penetrasi; belum menyertakan MFA wajib, pembatasan hak akses berdasarkan tingkat kerahasiaan/unit, retensi dokumen, antivirus berkas, enkripsi kunci yang dikelola instansi, dan pemulihan bencana teruji.
- Siapkan jadwal backup **database DAN storage** di luar layanan utama, serta prosedur pemulihan. Ekspor CSV pada aplikasi hanya mengekspor metadata, **bukan file asli**.
- Batasi kapasitas berkas ke 25 MB saat ini; kuota dan batas Supabase dapat berbeda sesuai paket.
- Pada penggantian file atau kegagalan penyimpanan metadata, **berkas lama/yatim dapat tertinggal** di Storage; admin perlu audit dan pembersihan rutin. Sebelum pemakaian intensif, terapkan server-side workflow atomik / job pembersihan.
- Saat logout dari komputer bersama, pastikan sesi benar-benar berakhir. Atur kebijakan akun, masa aktif, audit dan MFA sesuai pengelola TI instansi.
- Di tahap awal, `config.js` boleh kosong lalu diisi melalui halaman setup di browser. Untuk deployment bersama, **isi `config.js` terlebih dahulu**, jangan mengandalkan konfigurasi tersimpan per browser.
- Bila ada lebih dari 5.000 arsip, halaman perlu ditambah pagination server-side; versi ini memuat maksimal 5.000 metadata.

## Isi paket

- `index.html`: aplikasi web
- `style.css`: tampilan responsif
- `app.js`: autentikasi, dashboard, pencarian, CRUD arsip, unggah/unduh, hak akses, audit
- `config.js`: URL proyek + public key
- `struktur.json`: salinan struktur Excel asli
- `schema.sql`: skema database, kebijakan RLS dan storage

## Mengganti nama aplikasi

Ubah teks **E-ARSIP KESBANGPOL** pada `index.html`, termasuk tag `<title>`. Nama domain diatur pada penyedia hosting.
