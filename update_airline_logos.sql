-- UPDATE AIRLINE LOGOS IN SUPABASE
-- This script shows how to add logo URLs to your airlines table
-- You can get airline logos from various sources like:
-- - Airlines' official websites
-- - Logo APIs (e.g., clearbit.com/logo/[domain], brandfetch.com)
-- - Free logo repositories
-- - Upload to Supabase Storage and use the public URL

-- ========================================
-- METHOD 1: Update with external URLs
-- ========================================

-- Example: Update with logo URLs from external sources
UPDATE airlines 
SET logo_url = 'https://logo.clearbit.com/qatarairways.com'
WHERE iata_code = 'QR';

UPDATE airlines 
SET logo_url = 'https://logo.clearbit.com/singaporeair.com'
WHERE iata_code = 'SQ';

UPDATE airlines 
SET logo_url = 'https://logo.clearbit.com/cathaypacific.com'
WHERE iata_code = 'CX';

UPDATE airlines 
SET logo_url = 'https://logo.clearbit.com/emirates.com'
WHERE iata_code = 'EK';

UPDATE airlines 
SET logo_url = 'https://logo.clearbit.com/ana.co.jp'
WHERE iata_code = 'NH';

UPDATE airlines 
SET logo_url = 'https://logo.clearbit.com/turkishairlines.com'
WHERE iata_code = 'TK';

UPDATE airlines 
SET logo_url = 'https://logo.clearbit.com/koreanair.com'
WHERE iata_code = 'KE';

UPDATE airlines 
SET logo_url = 'https://logo.clearbit.com/jal.co.jp'
WHERE iata_code = 'JL';

UPDATE airlines 
SET logo_url = 'https://logo.clearbit.com/etihad.com'
WHERE iata_code = 'EY';

UPDATE airlines 
SET logo_url = 'https://logo.clearbit.com/airfrance.com'
WHERE iata_code = 'AF';

UPDATE airlines 
SET logo_url = 'https://logo.clearbit.com/klm.com'
WHERE iata_code = 'KL';

UPDATE airlines 
SET logo_url = 'https://logo.clearbit.com/qantas.com'
WHERE iata_code = 'QF';

UPDATE airlines 
SET logo_url = 'https://logo.clearbit.com/virgin-atlantic.com'
WHERE iata_code = 'VS';

UPDATE airlines 
SET logo_url = 'https://logo.clearbit.com/evaair.com'
WHERE iata_code = 'BR';

UPDATE airlines 
SET logo_url = 'https://logo.clearbit.com/srilankan.com'
WHERE iata_code = 'UL';

UPDATE airlines 
SET logo_url = 'https://logo.clearbit.com/vietnamairlines.com'
WHERE iata_code = 'VN';

UPDATE airlines 
SET logo_url = 'https://logo.clearbit.com/airnewzealand.com'
WHERE iata_code = 'NZ';

UPDATE airlines 
SET logo_url = 'https://logo.clearbit.com/garuda-indonesia.com'
WHERE iata_code = 'GA';

UPDATE airlines 
SET logo_url = 'https://logo.clearbit.com/thaiairways.com'
WHERE iata_code = 'TG';

UPDATE airlines 
SET logo_url = 'https://logo.clearbit.com/airasia.com'
WHERE iata_code = 'AK';

UPDATE airlines 
SET logo_url = 'https://logo.clearbit.com/delta.com'
WHERE iata_code = 'DL';

UPDATE airlines 
SET logo_url = 'https://logo.clearbit.com/united.com'
WHERE iata_code = 'UA';

UPDATE airlines 
SET logo_url = 'https://logo.clearbit.com/aa.com'
WHERE iata_code = 'AA';

UPDATE airlines 
SET logo_url = 'https://logo.clearbit.com/southwest.com'
WHERE iata_code = 'WN';

UPDATE airlines 
SET logo_url = 'https://logo.clearbit.com/jetblue.com'
WHERE iata_code = 'B6';

UPDATE airlines 
SET logo_url = 'https://logo.clearbit.com/alaskaair.com'
WHERE iata_code = 'AS';

UPDATE airlines 
SET logo_url = 'https://logo.clearbit.com/aircanada.com'
WHERE iata_code = 'AC';

UPDATE airlines 
SET logo_url = 'https://logo.clearbit.com/hawaiianairlines.com'
WHERE iata_code = 'HA';

UPDATE airlines 
SET logo_url = 'https://logo.clearbit.com/iberia.com'
WHERE iata_code = 'IB';

UPDATE airlines 
SET logo_url = 'https://logo.clearbit.com/austrian.com'
WHERE iata_code = 'OS';

UPDATE airlines 
SET logo_url = 'https://logo.clearbit.com/finnair.com'
WHERE iata_code = 'AY';

UPDATE airlines 
SET logo_url = 'https://logo.clearbit.com/flysas.com'
WHERE iata_code = 'SK';

UPDATE airlines 
SET logo_url = 'https://logo.clearbit.com/westjet.com'
WHERE iata_code = 'WS';

UPDATE airlines 
SET logo_url = 'https://logo.clearbit.com/ryanair.com'
WHERE iata_code = 'FR';

UPDATE airlines 
SET logo_url = 'https://logo.clearbit.com/goindigo.in'
WHERE iata_code = '6E';

UPDATE airlines 
SET logo_url = 'https://logo.clearbit.com/flydubai.com'
WHERE iata_code = 'FZ';

UPDATE airlines 
SET logo_url = 'https://logo.clearbit.com/wizzair.com'
WHERE iata_code = 'W6';

UPDATE airlines 
SET logo_url = 'https://logo.clearbit.com/airarabia.com'
WHERE iata_code = 'G9';

UPDATE airlines 
SET logo_url = 'https://logo.clearbit.com/flyscoot.com'
WHERE iata_code = 'TR';

UPDATE airlines 
SET logo_url = 'https://logo.clearbit.com/easyjet.com'
WHERE iata_code = 'U2';

-- ========================================
-- METHOD 2: Upload to Supabase Storage
-- ========================================
-- 1. Go to Supabase Dashboard → Storage
-- 2. Create a bucket called 'airline-logos' (make it public)
-- 3. Upload logo images (e.g., QR.png, SQ.png, etc.)
-- 4. Get the public URL for each logo
-- 5. Update the airlines table with the Supabase Storage URLs

-- Example with Supabase Storage URLs:
-- UPDATE airlines 
-- SET logo_url = 'https://[your-project-ref].supabase.co/storage/v1/object/public/airline-logos/QR.png'
-- WHERE iata_code = 'QR';

-- ========================================
-- METHOD 3: Use Wikipedia/Wikimedia logos
-- ========================================
-- Many airline logos are available on Wikimedia Commons with proper licensing
-- Example format:
-- UPDATE airlines 
-- SET logo_url = 'https://upload.wikimedia.org/wikipedia/commons/thumb/[path-to-logo].png/200px-[filename].png'
-- WHERE iata_code = 'XX';

-- ========================================
-- VERIFY YOUR UPDATES
-- ========================================
-- Check which airlines have logos set
SELECT name, iata_code, logo_url 
FROM airlines 
WHERE logo_url IS NOT NULL
ORDER BY name;

-- Check which airlines are missing logos
SELECT name, iata_code 
FROM airlines 
WHERE logo_url IS NULL
ORDER BY name;

