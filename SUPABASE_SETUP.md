## SUPABASE SETUP INSTRUCTIONS

### Step 1: Get Your Supabase Credentials

1. Go to https://app.supabase.com and sign into your account
2. Select your Crawldle project
3. Go to **Settings → API** (left sidebar)
4. Copy these values:
   - **Project URL**: `https://your-project-id.supabase.co`
   - **Anon Key**: The anonymous public key (starts with 'eyJ...')

### Step 2: Create the Database Tables

1. In Supabase, click **SQL Editor** (left sidebar)
2. Click **New Query**
3. Copy and paste the entire contents of `supabase_schema.sql`
4. Click **Run** to execute

You should see "Success" with no errors. All tables are now created!

### Step 3: Update index.html with Your Credentials

In the HTML file, find this section near the top of the `<head>`:
```javascript
// SUPABASE CONFIG - UPDATE THESE VALUES
const SUPABASE_URL = "https://your-project-id.supabase.co";
const SUPABASE_ANON_KEY = "your-anon-key-here";
```

Replace with values from Step 1.

### Step 4: Test It

1. Open your game in a browser
2. Play a game and complete it
3. Go back to Supabase → **Table Editor**
4. Click on `gameplay_sessions` table
5. You should see a new row with your game data!

---

## How the System Works

1. **Player ID**: Automatically generated on first visit, stored in browser localStorage
2. **Gameplay Data**: Captured when the game ends
3. **Device Info**: Browser type, OS, device (mobile/tablet/desktop)
4. **Geolocation**: Country based on IP address (optional, requires free API)
5. **Affiliate Tracking**: Records when players click on product links

All data is completely anonymous and privacy-respecting.
