# 🌾 CommodiFlow

![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)
![Supabase](https://img.shields.io/badge/Supabase-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)
![Gemini](https://img.shields.io/badge/Gemini_AI-8E75B2?style=for-the-badge&logo=googlebard&logoColor=white)
![Dart](https://img.shields.io/badge/dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white)

**CommodiFlow** adalah sistem pembukuan cerdas dan manajemen inventori (stok) yang dirancang khusus untuk broker dan produsen komoditas (seperti hasil panen jagung, dsb.). Aplikasi ini memanfaatkan kekuatan kecerdasan buatan (Google Gemini AI) untuk mengotomatisasi pencatatan nota, meminimalisir *human error*, dan menyajikan laporan keuangan yang komprehensif.

---

## ✨ Fitur Utama

- 🤖 **AI-Powered Receipt Scanner:** Tidak perlu mengetik manual! Cukup foto nota pembelian/penjualan, dan Gemini AI akan otomatis mengekstrak **Nominal**, **Tanggal**, **Kategori**, dan **Tonase (Kg)**.
- 🔐 **Single Sign-On (SSO):** Login aman dan instan menggunakan Akun Google (dipersembahkan oleh Supabase Auth).
- 📦 **Manajemen Inventori Cerdas:** Lacak pergerakan stok gudang secara otomatis berdasarkan transaksi (Barang Masuk & Keluar) menggunakan satuan Kilogram/Ton.
- 📊 **Dashboard Analitik Interaktif:** Visualisasi data yang memukau menggunakan `fl_chart`:
  - *Bar Chart* untuk Arus Kas (Pemasukan vs Pengeluaran).
  - *Pie Chart* untuk Proporsi Biaya Terbesar.
  - *Line Chart* untuk Tren Pergerakan Stok Gudang.
- ☁️ **Cloud Native:** Seluruh data transaksi dan bukti gambar nota tersimpan aman di cloud menggunakan ekosistem Supabase (PostgreSQL & Storage).

---

## 📸 Cuplikan Layar (Screenshots)

> **Catatan Developer:** *Silakan ganti URL gambar di bawah dengan tautan gambar antarmuka aplikasi (UI) Anda yang sebenarnya.*

| Dashboard Home | AI Scanner & Input | Laporan Analitik |
| :---: | :---: | :---: |
| <img src="https://via.placeholder.com/250x500.png?text=Home+Screen" width="200"> | <img src="https://via.placeholder.com/250x500.png?text=AI+Scanner" width="200"> | <img src="https://via.placeholder.com/250x500.png?text=Analytics+Chart" width="200"> |

---

## 🛠️ Teknologi yang Digunakan

- **Frontend:** Flutter & Dart
- **Backend & Database:** Supabase (PostgreSQL)
- **Authentication:** Supabase Auth (Google Provider)
- **AI Engine:** Google Generative AI (`gemini-3.6-flash`)
- **Visualisasi Data:** `fl_chart`
- **Animasi:** `lottie`

---

## 🚀 Panduan Instalasi

Ikuti langkah-langkah berikut untuk menjalankan CommodiFlow di mesin lokal Anda:

### 1. Kloning Repositori
```bash
git clone https://github.com/zainiirochman/CommodiFlow.git
cd commodi-flow
