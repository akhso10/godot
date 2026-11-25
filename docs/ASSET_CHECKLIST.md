# Pemeriksaan aset

## Berkas sumber

- Model karakter berskeleton ada di `assets/models/characters/`. GLB menyimpan animasi pada model. Sudut depan, samping dan belakang yang dirender dari model tersedia di `assets/character_studies/`.
- Katalog 40 barang ada di `assets/items/catalog/`. Tiap entri mempunyai GLB, ikon 256 px, versi 128 px dan master 1024 px transparan. Tas menampilkan ikon 256 px. Master render disimpan untuk penyuntingan.
- Material permukaan terdiri dari 29 definisi. Setiap definisi merujuk ke albedo, normal dan roughness. Bahan logam mempunyai peta metalik tambahan. Generator periodik bisa dijalankan lagi pada resolusi yang berbeda.
- Kit sekolah ada di `assets/models/environment/`. Skrip dunia menempatkan perabot, lampu, dan bagian struktur. Lantai dan sejumlah dinding memakai geometri berulang melalui MultiMesh.
- Efek suara, musik dan ambience menggunakan Vorbis. Dialog cerita dapat dibaca dalam bahasa Indonesia.
- Aset produksi tambahan disertakan di ZIP aset. Kolom `usage` membedakan jalur runtime, varian resolusi, referensi seni dan komponen pustaka.

## Uji dan pemutakhiran

Jalankan dari akar checkout. Generator manifest memerlukan Python 3.10+ dan Pillow. Mode standar membandingkan isi manifest dengan hasil pemeriksaan saat ini. Gunakan `--write` untuk memperbarui setelah ada perubahan yang disengaja.

```sh
python tools/asset_audit.py --write
python tools/asset_audit.py
godot --headless --editor --import
godot --headless --script res://tests/asset_resources.gd
```

Pemeriksa Python mendekode gambar raster, memeriksa identitas SVG, struktur GLB 2 dengan mesh dan adegan, rig dan klip pada karakter, header Vorbis, referensi `res://` literal, dimensi dan transparansi ikon, ID unik, ukuran dan hash. Berkas berbeda yang memakai basename sama pada ukuran atau bahan berbeda mendapat ID berdasarkan jalur. Tekstur di atas 2048 px dilaporkan untuk ditinjau.

Pemeriksa Godot memuat resource yang diimpor dan membuat instance dari setiap PackedScene. Perubahan pemuat aset dinamis perlu ditinjau di `tools/asset_audit.py`. Label `Integrated` menunjukkan rujukan dari kode game, campuran audio atau data misi. Label ini tidak menggantikan pemeriksaan visual atau sesi bermain langsung.
