-- =====================================================
-- PS Salon Yönetim — Masa Dondurma & Raporlama Migration
-- =====================================================

-- 1. oturumlar tablosuna dondurma ve kol geçmişi alanlarını ekle
ALTER TABLE oturumlar
  ADD COLUMN IF NOT EXISTS dondurma_ani TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS toplam_dondurulma_suresi_sn INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS kol_gecmisi JSONB DEFAULT '[]'::jsonb;

-- 2. raporlar tablosu oluştur
CREATE TABLE IF NOT EXISTS raporlar (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  oturum_id UUID REFERENCES oturumlar(id),
  masa_id UUID REFERENCES masalar(id),
  masa_ad TEXT NOT NULL,
  konsol_tipi TEXT NOT NULL DEFAULT 'PS5',
  baslangic TIMESTAMPTZ NOT NULL,
  bitis TIMESTAMPTZ NOT NULL,
  oynanan_dk INTEGER NOT NULL DEFAULT 0,
  kol_sayisi INTEGER NOT NULL DEFAULT 2,
  konsol_ucreti DOUBLE PRECISION NOT NULL DEFAULT 0,
  kol_ekstra_ucreti DOUBLE PRECISION NOT NULL DEFAULT 0,
  siparis_ucreti DOUBLE PRECISION NOT NULL DEFAULT 0,
  toplam_tutar DOUBLE PRECISION NOT NULL DEFAULT 0,
  odeme_yontemi TEXT NOT NULL DEFAULT 'nakit',   -- nakit | kart | parcali
  nakit_tutar DOUBLE PRECISION NOT NULL DEFAULT 0,
  kart_tutar DOUBLE PRECISION NOT NULL DEFAULT 0,
  olusturulma_tarihi TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3. RLS (Row Level Security) — eğer Supabase auth kullanılıyorsa
-- ALTER TABLE raporlar ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY "Service role full access" ON raporlar FOR ALL USING (true);

-- 4. İndeksler
CREATE INDEX IF NOT EXISTS idx_raporlar_olusturulma
  ON raporlar(olusturulma_tarihi DESC);
CREATE INDEX IF NOT EXISTS idx_raporlar_masa_id
  ON raporlar(masa_id);
CREATE INDEX IF NOT EXISTS idx_raporlar_odeme_yontemi
  ON raporlar(odeme_yontemi);

-- =====================================================
-- PS Salon Yönetim — Kasa Takibi (daily_reports) Migration
-- =====================================================

-- 5. Günlük kasa tablosu
CREATE TABLE IF NOT EXISTS daily_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tarih DATE NOT NULL UNIQUE,                       -- Her gün tek satır
  -- Otonom veriler (raporlardan hesaplanan)
  auto_cash DOUBLE PRECISION NOT NULL DEFAULT 0,    -- Raporlardan gelen nakit toplam
  auto_pos  DOUBLE PRECISION NOT NULL DEFAULT 0,    -- Raporlardan gelen kart/POS toplam
  -- Manuel override değerleri (null = otonom veri kullanılır)
  manual_cash DOUBLE PRECISION,                     -- Kullanıcının manuel girdiği nakit
  manual_pos  DOUBLE PRECISION,                     -- Kullanıcının manuel girdiği POS
  -- Gider (muhasebe tablosundaki giderlerden otonom toplanır)
  auto_expense DOUBLE PRECISION NOT NULL DEFAULT 0, -- Otonom gider toplamı
  manual_expense DOUBLE PRECISION,                  -- Manuel gider override
  -- Hesaplanan / cache
  devreden_bakiye DOUBLE PRECISION NOT NULL DEFAULT 0, -- Önceki gün bakiyesi + nakit - gider
  -- Meta
  notlar TEXT,                                      -- Kullanıcı notu
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 6. daily_reports indeksleri
CREATE INDEX IF NOT EXISTS idx_daily_reports_tarih
  ON daily_reports(tarih DESC);

-- 7. updated_at otomatik güncelleme trigger
CREATE OR REPLACE FUNCTION update_daily_reports_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_daily_reports_updated_at
  BEFORE UPDATE ON daily_reports
  FOR EACH ROW
  EXECUTE FUNCTION update_daily_reports_updated_at();

-- =====================================================
-- PS Salon Yönetim — Muhasebe Ödeme Yöntemi Migration
-- =====================================================

-- 8. muhasebe tablosuna ödeme yöntemi kolonu ekle
ALTER TABLE muhasebe
  ADD COLUMN IF NOT EXISTS odeme_yontemi TEXT NOT NULL DEFAULT 'nakit';
  -- 'nakit' veya 'kart'

-- =====================================================
-- PS Salon Yönetim — daily_reports Çok Kullanıcı Desteği
-- =====================================================
-- ÖNEMLI: Bu SQL'i Supabase Dashboard → SQL Editor'da çalıştırın.
-- 9. user_id kolonu ekle
ALTER TABLE daily_reports
  ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id);

-- 10. Eski tek-başına tarih UNIQUE kısıtını kaldır
ALTER TABLE daily_reports DROP CONSTRAINT IF EXISTS daily_reports_tarih_key;

-- 11. Kullanıcı + tarih kombinasyonuna UNIQUE kısıt ekle
ALTER TABLE daily_reports
  ADD CONSTRAINT daily_reports_tarih_user_id_key UNIQUE (tarih, user_id);

-- 12. Performans indeksi
CREATE INDEX IF NOT EXISTS idx_daily_reports_user_id
  ON daily_reports(user_id);

-- =====================================================
-- PS Salon Yönetim — Bütçeli Oturum (Ücretle Başlatma) Migration
-- =====================================================
-- 13. oturumlar tablosuna bütçe kolonu ekle
ALTER TABLE oturumlar
  ADD COLUMN IF NOT EXISTS butce DOUBLE PRECISION;
