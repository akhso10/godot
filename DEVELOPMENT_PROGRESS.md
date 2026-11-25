# Progres pengembangan

Versi 1.0.0 memiliki prolog dan lima bab yang dimainkan di dua lantai SMA Nusa Bangsa. Cerita bercabang pada kesaksian, siaran Laras, dan pilihan menjemput Reski dan Akbar. Ada 53 definisi misi utama, dengan 51–53 misi per permainan, 15 temuan tambahan, lima teka-teki dan tiga ending.

| Bagian | Implementasi |
| --- | --- |
| Pemain | Kamera orang pertama, tabrakan, lari, stamina, jongkok, langkah, persembunyian, senter, baterai dan radio |
| Dunia | Halaman, pos, gerbang berengsel, kelas, koridor dan tangga, lab, UKS, perpustakaan, ruang arsip dan kontrol speaker |
| Karakter | Model berskeleton Raka, Reski, Akbar, Laras dan Penjaga. Kamera orang pertama memakai model tangan tersendiri |
| Audio dan kejutan | Musik, hujan, bel, radio, langkah lokal, alarm, lampu, penampakan dan peristiwa terpicu progres |
| Antarmuka | Menu, kontrol, pengaturan tersimpan, jurnal, denah dua lantai, tas dengan ikon, arsip seni, pemutar audio dan penampil animasi |
| Aset | 40 item dengan GLB dan tiga ukuran gambar, 29 material, latar dan potret, ilustrasi cerita dan ending. Inventaris file di ASSET_MANIFEST.csv |
| Penyimpanan | Checkpoint lokal berversi dan salinan cadangan. Saat file utama rusak game mencoba cadangan |
| Platform | Godot 4.7.2 Compatibility, profil awal 1280×720, skala 3D 85%, batas 30 FPS. Windows 64-bit dan sumber dapat dimainkan offline |

## Batas pengujian dan cakupan

Durasi 45–75 menit serta 30–60 FPS pada Axioo Hype 3 Gen 12 masih berupa target. Dialog disampaikan lewat teks Indonesia dengan musik dan efek asli. Penampilan prolog, pergantian bab dan ending memakai ilustrasi dengan teks. Pencahayaan varian latar dalam arsip visual menggunakan shader; model karakter serta ruang yang dijelajahi dirender dalam 3D. Lihat TEST_REPORT.md untuk hasil pengujian otomatis dan batasnya.
