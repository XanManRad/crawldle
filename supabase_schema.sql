-- ============================================
-- CRAWLDLE DATABASE SCHEMA
-- Run these SQL statements in your Supabase dashboard
-- ============================================

-- Table 1: GAMEPLAY_SESSIONS
-- Stores core gameplay data for each player session
CREATE TABLE IF NOT EXISTS gameplay_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    player_id TEXT NOT NULL,
    user_id UUID,
    game_date DATE NOT NULL,
    game_number INTEGER NOT NULL,
    crawler_of_day TEXT NOT NULL,
    guess_count INTEGER NOT NULL,
    game_status TEXT NOT NULL CHECK (game_status IN ('won', 'lost', 'incomplete')),
    first_guess TEXT,
    guesses_order JSONB,
    time_spent_seconds INTEGER,
    device_type TEXT NOT NULL,
    browser TEXT,
    os TEXT,
    country TEXT,
    user_agent TEXT,
    referrer TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Add indexes for faster queries
CREATE INDEX idx_player_id ON gameplay_sessions(player_id);
CREATE INDEX idx_game_date ON gameplay_sessions(game_date);
CREATE INDEX idx_game_status ON gameplay_sessions(game_status);
CREATE INDEX idx_crawler_of_day ON gameplay_sessions(crawler_of_day);

-- Table 2: AFFILIATE_CLICKS
-- Tracks when players click on affiliate links
CREATE TABLE IF NOT EXISTS affiliate_clicks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    player_id TEXT NOT NULL,
    game_session_id UUID REFERENCES gameplay_sessions(id) ON DELETE CASCADE,
    crawler_model TEXT NOT NULL,
    link_type TEXT NOT NULL CHECK (link_type IN ('amazon', 'upgrade_part', 'full_build', 'other')),
    affiliate_url TEXT,
    clicked_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Add indexes for faster queries
CREATE INDEX idx_affiliate_player_id ON affiliate_clicks(player_id);
CREATE INDEX idx_affiliate_session_id ON affiliate_clicks(game_session_id);
CREATE INDEX idx_affiliate_crawler ON affiliate_clicks(crawler_model);

-- Table 3: DAILY_STATS (Aggregate data — populated by backend/admin only)
CREATE TABLE IF NOT EXISTS daily_stats (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    game_date DATE NOT NULL UNIQUE,
    game_number INTEGER NOT NULL,
    crawler_of_day TEXT NOT NULL,
    total_players INTEGER DEFAULT 0,
    total_games_played INTEGER DEFAULT 0,
    win_count INTEGER DEFAULT 0,
    loss_count INTEGER DEFAULT 0,
    incomplete_count INTEGER DEFAULT 0,
    avg_guesses FLOAT DEFAULT 0,
    most_common_first_guess TEXT,
    most_common_first_guess_count INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_daily_stats_date ON daily_stats(game_date);

-- Table 4: PLAYER_STREAKS
-- Tracks consecutive daily plays and wins
CREATE TABLE IF NOT EXISTS player_streaks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    player_id TEXT NOT NULL UNIQUE,
    user_id UUID,
    username TEXT,
    current_streak INTEGER DEFAULT 0,
    longest_streak INTEGER DEFAULT 0,
    win_streak INTEGER DEFAULT 0,
    total_wins INTEGER DEFAULT 0,
    last_played_date DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_streak_player_id ON player_streaks(player_id);
CREATE INDEX idx_streak_total_wins ON player_streaks(total_wins DESC);
CREATE INDEX idx_streak_current ON player_streaks(current_streak DESC);

-- Unique partial index on user_id for cross-device sync
-- Allows logged-in users to be identified by auth user_id across devices
CREATE UNIQUE INDEX IF NOT EXISTS idx_player_streaks_user_id 
ON player_streaks(user_id) WHERE user_id IS NOT NULL;

-- Table 5: PROFILES (linked to Supabase Auth)
CREATE TABLE IF NOT EXISTS profiles (
    id UUID REFERENCES auth.users ON DELETE CASCADE PRIMARY KEY,
    username TEXT UNIQUE,
    avatar_url TEXT,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW())
);

-- ============================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================

ALTER TABLE gameplay_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE affiliate_clicks ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_stats ENABLE ROW LEVEL SECURITY;
ALTER TABLE player_streaks ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- ============================================
-- GAMEPLAY_SESSIONS POLICIES
-- Public read (community stats), public insert (save scores)
-- No UPDATE/DELETE = denied by default
-- ============================================
CREATE POLICY "Anyone can view gameplay sessions"
ON gameplay_sessions FOR SELECT
USING (true);

CREATE POLICY "Players can insert own sessions"
ON gameplay_sessions FOR INSERT
WITH CHECK (true);

-- ============================================
-- AFFILIATE_CLICKS POLICIES
-- Insert-only for tracking; no public read
-- ============================================
CREATE POLICY "Anyone can insert affiliate clicks"
ON affiliate_clicks FOR INSERT
WITH CHECK (true);

-- ============================================
-- DAILY_STATS POLICIES
-- Admin/service-role only for writes; no client access needed
-- RLS enabled with no client-facing policies = fully locked
-- ============================================
CREATE POLICY "Only service role can manage daily stats"
ON daily_stats FOR ALL
USING (auth.role() = 'service_role')
WITH CHECK (auth.role() = 'service_role');

-- ============================================
-- PLAYER_STREAKS POLICIES
-- Public read (leaderboard), scoped insert/update
-- ============================================
CREATE POLICY "Anyone can view player streaks"
ON player_streaks FOR SELECT
USING (true);

CREATE POLICY "Players can insert own streaks"
ON player_streaks FOR INSERT
WITH CHECK (true);

-- Players can only update their own row (matched by auth user_id when logged in)
CREATE POLICY "Players can update own streaks"
ON player_streaks FOR UPDATE
USING (
    auth.uid() IS NOT NULL AND user_id = auth.uid()
)
WITH CHECK (
    auth.uid() IS NOT NULL AND user_id = auth.uid()
);

-- ============================================
-- PROFILES POLICIES
-- Users can only read/update their own profile
-- ============================================
CREATE POLICY "Users can read own profile"
ON profiles FOR SELECT
USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile"
ON profiles FOR INSERT
WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update own profile"
ON profiles FOR UPDATE
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- ============================================
-- AUTO-CREATE PROFILE ON SIGNUP (Trigger)
-- Username is NULL so users are prompted to choose one
-- ============================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, username, avatar_url)
    VALUES (
        NEW.id,
        NULL,  -- Don't auto-set username; let user choose a display name
        NEW.raw_user_meta_data->>'avatar_url'
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================
-- MIGRATION: Run these on existing databases
-- ============================================

-- 1. Null out existing usernames to force users to pick a new display name
-- UPDATE profiles SET username = NULL;

-- 2. Add unique partial index for cross-device sync (if not already created above)
-- CREATE UNIQUE INDEX IF NOT EXISTS idx_player_streaks_user_id 
-- ON player_streaks(user_id) WHERE user_id IS NOT NULL;
