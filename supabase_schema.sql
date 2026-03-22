-- ============================================
-- CRAWLDLE ANALYTICS DATABASE SCHEMA
-- Run these SQL statements in your Supabase dashboard
-- ============================================

-- Table 1: GAMEPLAY_SESSIONS
-- Stores core gameplay data for each player session
CREATE TABLE IF NOT EXISTS gameplay_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    player_id TEXT NOT NULL,
    game_date DATE NOT NULL,
    game_number INTEGER NOT NULL,
    crawler_of_day TEXT NOT NULL,
    guess_count INTEGER NOT NULL,
    game_status TEXT NOT NULL CHECK (game_status IN ('won', 'lost', 'incomplete')),
    first_guess TEXT,
    guesses_order JSONB,
    emoji_grid TEXT NOT NULL,
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

-- Table 3: DAILY_STATS (Aggregate data)
-- Summary stats for each day (useful for dashboards)
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

-- Add index for faster date queries
CREATE INDEX idx_daily_stats_date ON daily_stats(game_date);

-- Table 4: PLAYER_STREAKS (Optional, for loyalty/engagement)
-- Tracks consecutive daily plays and wins
CREATE TABLE IF NOT EXISTS player_streaks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    player_id TEXT NOT NULL UNIQUE,
    current_streak INTEGER DEFAULT 0,
    longest_streak INTEGER DEFAULT 0,
    win_streak INTEGER DEFAULT 0,
    last_played_date DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Add index for player lookups
CREATE INDEX idx_streak_player_id ON player_streaks(player_id);

-- ============================================
-- ROW LEVEL SECURITY (RLS) POLICIES (SECURE VERSION)
-- ============================================

-- Enable RLS on all tables
ALTER TABLE gameplay_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE affiliate_clicks ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_stats ENABLE ROW LEVEL SECURITY;
ALTER TABLE player_streaks ENABLE ROW LEVEL SECURITY;

-- ============================================
-- GAMEPLAY_SESSIONS POLICIES
-- ============================================
-- Public READ (leaderboards, stats viewing)
-- Note: USING (true) for SELECT is intentional - for public read access
CREATE POLICY "Public can view gameplay sessions"
ON gameplay_sessions FOR SELECT
USING (true);

-- Restrict INSERT to authenticated requests via Supabase Functions/API
-- This policy prevents direct client inserts while allowing backend functions to write
CREATE POLICY "Only service role can insert gameplay sessions"
ON gameplay_sessions FOR INSERT
WITH CHECK (auth.role() = 'service_role' OR current_user = 'postgres');

-- ============================================
-- AFFILIATE_CLICKS POLICIES
-- ============================================
-- Public READ (for analytics dashboard)
CREATE POLICY "Public can view affiliate clicks"
ON affiliate_clicks FOR SELECT
USING (true);

-- Restrict INSERT to authenticated backend requests
CREATE POLICY "Only service role can insert affiliate clicks"
ON affiliate_clicks FOR INSERT
WITH CHECK (auth.role() = 'service_role' OR current_user = 'postgres');

-- ============================================
-- DAILY_STATS POLICIES
-- ============================================
-- Public READ (for daily stats display)
CREATE POLICY "Public can view daily stats"
ON daily_stats FOR SELECT
USING (true);

-- Restrict INSERT/UPDATE to backend functions only
CREATE POLICY "Only service role can insert daily stats"
ON daily_stats FOR INSERT
WITH CHECK (auth.role() = 'service_role' OR current_user = 'postgres');

CREATE POLICY "Only service role can update daily stats"
ON daily_stats FOR UPDATE
USING (auth.role() = 'service_role' OR current_user = 'postgres')
WITH CHECK (auth.role() = 'service_role' OR current_user = 'postgres');

-- ============================================
-- PLAYER_STREAKS POLICIES
-- ============================================
-- Public READ
CREATE POLICY "Public can view player streaks"
ON player_streaks FOR SELECT
USING (true);

-- Restrict INSERT/UPDATE to backend functions only
CREATE POLICY "Only service role can insert player streaks"
ON player_streaks FOR INSERT
WITH CHECK (auth.role() = 'service_role' OR current_user = 'postgres');

CREATE POLICY "Only service role can update player streaks"
ON player_streaks FOR UPDATE
USING (auth.role() = 'service_role' OR current_user = 'postgres')
WITH CHECK (auth.role() = 'service_role' OR current_user = 'postgres');
