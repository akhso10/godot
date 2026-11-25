# Hasil pengujian

Godot 4.7.2 stable, renderer Compatibility. Tes sumber berjalan di Linux dalam profil penyimpanan tersendiri.

| Periksa | Hasil aktual |
| --- | --- |
| Impor editor | Sumber gambar, audio, GLB, material, scene dan GDScript berhasil diimpor. |
| Kampanye | 16 kombinasi pilihan akhir, 3.552 pemeriksaan lulus. Mencakup jawaban puzzle salah dan benar, temuan opsional, semua bab dan pemulihan JSON. |
| Alur UI | 736 pemeriksaan lulus. Mencakup menu, input pemain, tombol E melalui raycast, pilihan puzzle, jurnal, denah, penyimpanan, pemulihan cadangan, dan tiga layar ending. Tes memindahkan pemain antarstasiun untuk memeriksa setiap aksi. |
| Perjalanan fisik | 67 pemeriksaan lulus. Kapsul pemain melewati 18 lokasi misi dan tangga, pintu terkunci/terbuka, gerbang, serta pengujian dasar penjaga dan teman. |
| Resource | 559 resource dimuat; 109 PackedScene dibuat; 0 kegagalan. Manifest memeriksa 598 aset. |
| Tampilan | Menu, prolog, halaman sekolah, koridor dan denah dirender pada layar virtual 1280×720 dengan OpenGL Compatibility/Mesa llvmpipe. |
| Ekspor Windows | Export release x86-64 menghasilkan Sekolah.exe dan Sekolah.pck dengan template resmi 4.7.2. |
| Perangkat target | Pengujian hardware Axioo, durasi permainan manusia 45–75 menit, dan benchmark iGPU Intel masih terbuka. |

Uji integrasi headless mengembalikan 0 dan melaporkan sisa resource audio pada penutupan proses otomatis. Pemeriksaan tersebut tidak menilai kualitas atau pelafalan suara manusia. Uji fisik serta uji yang mencapai ending memakai skenario berbeda.

## Menjalankan ulang

```sh
godot --headless --editor --import
python tools/asset_audit.py
godot --headless --script res://tests/asset_resources.gd
godot --headless --script res://tests/story_routes.gd
XDG_DATA_HOME="$(mktemp -d)" godot --headless --fixed-fps 60 --script res://tests/world_routes.gd
XDG_DATA_HOME="$(mktemp -d)" godot --headless --fixed-fps 60 --script res://tests/integration.gd
```

Perbaikan yang diuji meliputi akses interaksi di sisi luar gerbang terkunci, navigasi kontrol jurnal setelah pergantian halaman dan pemulihan checkpoint sebelumnya apabila JSON utama terpotong.

## Pemeriksaan hasil distribusi

Ketiga ZIP di branch publik `downloads` berhasil diunduh melalui HTTPS. SHA-256 cocok dan setiap entri ZIP lulus pemeriksaan CRC. Proyek dari ZIP source dibuka di direktori bersih, diimpor ulang dan lulus 3.552 pemeriksaan cerita.

Pasangan EXE dan PCK hasil ekspor membuka jendela melalui Wine 10 (64-bit) dengan OpenGL Compatibility. Klik **Permainan baru** menampilkan ilustrasi prolog; klik **Masuk ke sekolah** menampilkan gerbang 3D, Reski, Akbar dan tujuan pertama. Menu keluar menutup proses. Ini adalah uji kompatibilitas di Linux. Pengujian native Windows dan pengukuran pada laptop target tetap menunggu perangkat.

## Regresi impor ZIP langsung di Project Manager (v1.0.1)

Di Godot Project Manager 4.7.2 edisi Windows melalui Wine, **Import** terhadap ZIP source v1.0.0 menghasilkan pesan “The following files failed extraction from package” dan “And 1130 more files.” Sebanyak 1.146 file di subfolder gagal ditulis; 10 file tingkat atas berhasil. Pengujian v1.0.0 sebelumnya menggunakan folder yang telah diekstrak oleh alat ZIP lain.

Pembuat ZIP kini menulis 64 entri folder source sebelum isinya. ZIP perbaikan diimpor dari tombol **Import** ke folder baru di drive C. Project Manager menampilkan judul dan ikon game. Seluruh 1.156 file hasil ekstraksi cocok byte demi byte dengan anggota ZIP. Pemeriksaan urutan folder dijalankan setiap kali paket dibuat.
