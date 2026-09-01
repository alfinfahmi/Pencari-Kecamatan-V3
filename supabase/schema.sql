-- =====================================================================
-- Skema Supabase untuk Pencari Kecamatan & Falakiyah (LF Ma'had 'Aly Lirboyo)
-- Jalankan seluruh file ini di Supabase Dashboard -> SQL Editor -> New query
-- =====================================================================

-- 1) ROLE PENGGUNA
-- ---------------------------------------------------------------------
create type public.user_role as enum ('umum', 'kontributor', 'admin');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  nama text,
  role public.user_role not null default 'umum',
  created_at timestamptz not null default now()
);

-- Setiap user baru otomatis dapat baris profile dengan role 'umum'.
-- Admin harus menaikkan role kontributor/admin secara MANUAL lewat
-- Supabase Dashboard -> Table Editor -> profiles -> ubah kolom 'role'.
-- (Sengaja tidak dibuat self-service, sesuai matriks hak akses: hanya
-- Admin LF Lirboyo yang boleh mengelola akun.)
create function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, nama, role)
  values (new.id, new.raw_user_meta_data->>'nama', 'umum');
  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();


-- 2) TABEL USULAN KOREKSI KOORDINAT
-- ---------------------------------------------------------------------
create type public.status_koreksi as enum ('pending', 'approved', 'rejected');

create table public.koreksi_koordinat (
  id uuid primary key default gen_random_uuid(),
  kecamatan_id text not null,             -- FK logis ke id di data_koordinat.json (bukan FK relasional, karena data master ada di JSON lokal, bukan tabel Postgres)
  kecamatan_nama text not null,
  kabupaten_nama text,
  provinsi_nama text not null,

  -- Data LAMA (untuk perbandingan di panel moderasi)
  lat_lama double precision,
  lng_lama double precision,
  elevasi_lama integer,

  -- Data BARU yang diusulkan
  lat_baru double precision not null,
  lng_baru double precision not null,
  elevasi_baru integer,

  catatan_pengusul text,
  catatan_evaluasi text,                  -- diisi kontributor/admin saat approve/reject

  status public.status_koreksi not null default 'pending',
  diusulkan_oleh uuid references public.profiles(id),
  ditinjau_oleh uuid references public.profiles(id),

  created_at timestamptz not null default now(),
  reviewed_at timestamptz
);

-- 3) ROW LEVEL SECURITY -- sesuai Matriks Hak Akses
-- ---------------------------------------------------------------------
alter table public.profiles enable row level security;
alter table public.koreksi_koordinat enable row level security;

-- profiles: semua user login boleh baca (perlu tahu role sendiri & nama
-- pengusul lain di panel moderasi), tapi TIDAK BOLEH ubah role sendiri.
create policy "profiles_select_all_authenticated"
  on public.profiles for select
  using (auth.role() = 'authenticated');

create policy "profiles_update_only_admin"
  on public.profiles for update
  using (
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin')
  );

-- koreksi_koordinat:
-- - Pengguna Umum, Kontributor, Admin: SEMUA boleh INSERT (kirim usulan).
create policy "koreksi_insert_semua_user_login"
  on public.koreksi_koordinat for insert
  with check (auth.role() = 'authenticated');

-- - Pengguna Umum hanya boleh lihat usulan MILIK SENDIRI.
-- - Kontributor & Admin boleh lihat SEMUA usulan (untuk moderasi).
create policy "koreksi_select_sesuai_role"
  on public.koreksi_koordinat for select
  using (
    diusulkan_oleh = auth.uid()
    or exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role in ('kontributor', 'admin')
    )
  );

-- - HANYA Kontributor & Admin yang boleh UPDATE (approve/reject).
create policy "koreksi_update_hanya_kontributor_admin"
  on public.koreksi_koordinat for update
  using (
    exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role in ('kontributor', 'admin')
    )
  );

-- 4) TRIGGER: catat siapa & kapan saat status berubah dari pending
-- ---------------------------------------------------------------------
create function public.set_reviewed_meta()
returns trigger as $$
begin
  if new.status <> 'pending' and old.status = 'pending' then
    new.ditinjau_oleh := auth.uid();
    new.reviewed_at := now();
  end if;
  return new;
end;
$$ language plpgsql security definer;

create trigger before_update_koreksi
  before update on public.koreksi_koordinat
  for each row execute procedure public.set_reviewed_meta();

-- =====================================================================
-- CATATAN PENTING:
-- Data master kecamatan (7.274 entri) ada di data_koordinat.json LOKAL
-- di dalam aplikasi (terenkripsi AES-256), BUKAN di tabel Postgres ini.
-- Artinya trigger "otomatis memperbarui tabel master begitu disetujui"
-- TIDAK BISA benar-benar otomatis end-to-end tanpa langkah tambahan:
-- setelah admin approve di panel ini, perubahan baru akan terasa di
-- SEMUA perangkat pengguna lain setelah:
--   (a) admin menjalankan ulang convert_to_json.py + encrypt_data.py
--       dengan data terbaru, LALU
--   (b) merilis update aplikasi baru (APK/build baru).
-- Ini konsekuensi langsung dari desain "100% offline, data di-bundle ke
-- aplikasi" -- database Supabase hanya menyimpan ANTREAN USULAN, bukan
-- menjadi sumber data utama aplikasi secara real-time.
-- =====================================================================
