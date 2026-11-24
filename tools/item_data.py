"""Asset IDs, Indonesian catalogue text, and reference length in metres."""
ROWS = """
flashlight|Senter petugas|Cahaya senter masih berfungsi. Tutup baterainya berbau logam.|alat|0.17
battery|Baterai cadangan|Sel kering yang tertinggal di laci jaga. Simpan untuk senter.|persediaan|0.055
classroom_key|Kunci XII RPL|Pada pelat kuningan terukir nomor ruang kelas.|kunci|0.074
teachers_office_key|Kunci ruang guru|Gantungan merahnya kusam karena sering berpindah tangan.|kunci|0.085
infirmary_key|Kunci UKS|Gantungan putih dengan lambang pertolongan pertama.|kunci|0.08
archive_key|Kunci ruang arsip|Ada serpihan arang pada mata kunci.|kunci|0.09
emergency_gate_key|Kunci gerbang darurat|Kunci baja besar untuk gerbang halaman.|kunci|0.14
locker_key|Kunci loker|Kunci mungil bernomor 07.|kunci|0.045
master_key|Kunci induk|Bekas goresan berbentuk bintang pada kepalanya.|kunci|0.10
fuse_red|Sekering segitiga|Badan merah, tanda segitiga. Salah satu jalur panel.|komponen|0.06
fuse_blue|Sekering lingkaran|Badan biru dengan tanda lingkaran timbul.|komponen|0.06
fuse_yellow|Sekering persegi|Badan kuning dengan tanda persegi timbul.|komponen|0.06
screwdriver|Obeng minus|Ujung bajanya cocok untuk sekrup kotak listrik.|alat|0.19
walkie_talkie|Radio komunikasi|Saluran sekolah masih mendesis di tengah hujan.|alat|0.22
smartphone_raka|Ponsel Raka|Jam pada layar berhenti di tengah malam.|pribadi|0.15
smartphone_reski|Ponsel Reski|Casing hijau. Tersimpan catatan tugas kelompok.|pribadi|0.15
smartphone_akbar|Ponsel Akbar|Ada pesan keluar yang tak kunjung terkirim.|pribadi|0.15
access_card|Kartu akses|Garis magnetik untuk membuka akses staf.|kartu|0.086
library_card|Kartu perpustakaan|Stempel peminjaman menunjukkan rak koleksi lama.|kartu|0.086
assignment_folder|Map tugas|Lembar tugas kelompok Raka, Reski, dan Akbar.|dokumen|0.32
attendance_book|Buku absensi|Satu baris dalam daftar kelas sengaja dikosongkan.|bukti|0.30
school_yearbook|Buku tahunan|Sampul keras peringatan angkatan XII.|bukti|0.28
damaged_photo|Foto kelas rusak|Sudut kanan foto menyisakan bekas panas.|bukti|0.15
original_photo|Foto kelas asli|Susunan siswa terlihat utuh di cetakan pertama.|bukti|0.15
cassette_tape|Kaset Laras|Tulisan tangan pada sisi A hampir pudar.|bukti|0.10
voice_recorder|Perekam saku|Masih tercium bau hangus pada lubang mikrofon.|alat|0.12
fire_report|Laporan kebakaran|Salinan laporan resmi tentang kebakaran arsip.|bukti|0.297
witness_statement_01|Kesaksian penjaga|Pos jaga mencatat lampu di lorong padam lebih dulu.|bukti|0.297
witness_statement_02|Kesaksian guru|Peringatan tentang panel pernah sampai ke ruang guru.|bukti|0.297
witness_statement_03|Kesaksian siswa|Seorang teman melihat Laras membawa map ke arsip.|bukti|0.297
electrical_diagram|Diagram kelistrikan|Urutan simbol jalur tertera pada skema sekolah.|bukti|0.297
medicine_box|Kotak P3K|Kotak putih dengan engsel logam dan lambang hijau.|persediaan|0.26
emergency_lever|Tuas darurat|Pegangan merah untuk melepas palang gerbang.|alat|0.25
water_bottle|Botol Akbar|Penyok kecil di sisi botol ini dikenali Raka.|pribadi|0.24
old_newspaper|Kliping koran lama|Berita kebakaran sekolah terselip di kolom daerah.|bukti|0.26
mystery_note|Catatan tanpa nama|Beberapa kata pada kertas lipat ini digarisbawahi.|bukti|0.15
black_notebook|Buku catatan Laras|Sampul hitam mengilat pada bagian yang sering digenggam.|bukti|0.20
padlock|Gembok|Gagang baja beratnya tergores di satu sisi.|alat|0.07
microphone|Mikrofon pengumuman|Kepala jaring berbau debu di depan panel speaker.|alat|0.18
backpack|Tas sekolah|Tas kanvas olive dengan tali gantung abu-abu.|pribadi|0.42
""".strip().splitlines()
ITEMS = [r.split('|') for r in ROWS]
