# Airline Logos Integration with Supabase

## ✅ **Already Implemented**

Your Flutter app is **already set up** to display airline logos from Supabase! Here's what's in place:

### 1. **Database Structure**
- ✅ `airlines` table has `logo_url` column
- ✅ Service fetches `logo_url` from Supabase
- ✅ Leaderboard displays logos from network URLs

### 2. **Flutter Code**
- ✅ `Image.network()` for remote logos
- ✅ Loading indicator while fetching
- ✅ Fallback flight icon if logo fails
- ✅ Proper error handling

### 3. **How It Works**
```dart
// The app checks if logo_url starts with 'http'
if (logoUrl != null && logoUrl.startsWith('http')) {
  // Load from network (Supabase)
  Image.network(logoUrl)
} else {
  // Show fallback flight icon
  Icon(Icons.flight)
}
```

---

## 🚀 **How to Add Logos to Supabase**

### **Option 1: External Logo URLs (Easiest)**

Use free logo services like Clearbit:

```sql
-- Run in Supabase SQL Editor
UPDATE airlines 
SET logo_url = 'https://logo.clearbit.com/qatarairways.com'
WHERE iata_code = 'QR';

UPDATE airlines 
SET logo_url = 'https://logo.clearbit.com/singaporeair.com'
WHERE iata_code = 'SQ';

UPDATE airlines 
SET logo_url = 'https://logo.clearbit.com/emirates.com'
WHERE iata_code = 'EK';
```

**Pros:**
- ✅ Instant - just update the database
- ✅ No file hosting needed
- ✅ Clearbit handles logo updates

**Cons:**
- ⚠️ Depends on external service
- ⚠️ Rate limits may apply
- ⚠️ Not all airlines may have logos

---

### **Option 2: Supabase Storage (Recommended)**

Store logos in your Supabase project:

#### **Step 1: Create Storage Bucket**
1. Go to Supabase Dashboard → **Storage**
2. Click **New bucket**
3. Name: `airline-logos`
4. Make it **Public** ✅
5. Click **Create bucket**

#### **Step 2: Upload Logo Files**
1. Click on the `airline-logos` bucket
2. Click **Upload** button
3. Upload logo files (e.g., `QR.png`, `SQ.png`, `EK.png`)
4. Use **IATA codes** as filenames for easy reference

#### **Step 3: Get Public URLs**
1. Click on an uploaded file
2. Copy the **Public URL**
3. It will look like:
   ```
   https://[your-project-ref].supabase.co/storage/v1/object/public/airline-logos/QR.png
   ```

#### **Step 4: Update Database**
```sql
-- Update with your Supabase Storage URLs
UPDATE airlines 
SET logo_url = 'https://[your-project-ref].supabase.co/storage/v1/object/public/airline-logos/QR.png'
WHERE iata_code = 'QR';

UPDATE airlines 
SET logo_url = 'https://[your-project-ref].supabase.co/storage/v1/object/public/airline-logos/SQ.png'
WHERE iata_code = 'SQ';

-- Repeat for all airlines...
```

**Pros:**
- ✅ Full control over logos
- ✅ No external dependencies
- ✅ Fast loading (same infrastructure)
- ✅ Custom branding possible

**Cons:**
- ⚠️ Need to source and upload logos
- ⚠️ Manual updates required

---

### **Option 3: Wikimedia Commons**

Use free, open-source airline logos:

```sql
UPDATE airlines 
SET logo_url = 'https://upload.wikimedia.org/wikipedia/commons/thumb/3/30/Qatar_Airways_Logo.svg/200px-Qatar_Airways_Logo.svg.png'
WHERE iata_code = 'QR';
```

**Pros:**
- ✅ Free and legal to use
- ✅ High quality
- ✅ Reliable hosting

**Cons:**
- ⚠️ Need to find correct Wikimedia URLs
- ⚠️ Not all airlines available

---

## 🎨 **Where to Get Airline Logos**

### **Free Sources:**
1. **Clearbit Logo API**
   - URL: `https://logo.clearbit.com/[airline-domain].com`
   - Example: `https://logo.clearbit.com/qatarairways.com`

2. **Wikimedia Commons**
   - Search: `https://commons.wikimedia.org/`
   - Look for airline logos with proper licensing

3. **Airlines' Official Websites**
   - Download from press/media kits
   - Check terms of use

4. **Logo APIs:**
   - Brandfetch: `https://brandfetch.com`
   - Logo.dev: `https://img.logo.dev/`

### **Paid/Premium:**
- Getty Images
- Shutterstock
- Custom design services

---

## 📋 **Quick Setup Script**

I've created a ready-to-use SQL script with Clearbit logo URLs for all 40 airlines.

**To use it:**
1. Open **Supabase Dashboard**
2. Go to **SQL Editor**
3. Open `update_airline_logos.sql`
4. Click **Run**

This will instantly add logo URLs for:
- Qatar Airways, Singapore Airlines, Emirates
- All other top 40 airlines in your leaderboard

---

## ✅ **Verify Logos Are Working**

### **1. Check Database**
```sql
-- See which airlines have logos
SELECT name, iata_code, logo_url 
FROM airlines 
WHERE logo_url IS NOT NULL
ORDER BY name;

-- Find airlines missing logos
SELECT name, iata_code 
FROM airlines 
WHERE logo_url IS NULL
ORDER BY name;
```

### **2. Test in App**
1. Run your Flutter app
2. Navigate to **Leaderboard** tab
3. Logos should appear in the cards
4. If a logo fails, you'll see a flight icon

---

## 🔧 **Troubleshooting**

### **Logo not displaying?**
- ✅ Check URL is valid (open in browser)
- ✅ Verify URL starts with `http://` or `https://`
- ✅ Check Supabase RLS policies allow reading from airlines table
- ✅ Look for errors in Flutter console

### **Slow loading?**
- ✅ Use optimized image sizes (200x200px recommended)
- ✅ Consider Supabase Storage for faster loading
- ✅ Implement caching in Flutter (optional)

### **Logo quality issues?**
- ✅ Use SVG or high-res PNG (200x200 minimum)
- ✅ Ensure transparent backgrounds
- ✅ Compress images before uploading

---

## 🎯 **Next Steps**

1. **Run the SQL script** (`update_airline_logos.sql`) to add logos
2. **Test in your app** - logos should appear immediately
3. **Optional:** Upload custom logos to Supabase Storage for better control
4. **Monitor:** Check which logos fail and replace with better URLs

---

## 📱 **App Behavior**

- **Loading:** Shows spinner while fetching logo
- **Success:** Displays airline logo
- **Failure:** Shows flight icon fallback
- **No URL:** Shows flight icon

All logos are cached by the device automatically for better performance!

