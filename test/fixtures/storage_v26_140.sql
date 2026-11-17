-- Frozen v26 schema: 1.4.0 build 7, the live App Store version,
-- from c37757a (lib/services/storage_service.dart, onCreate in order).
-- Independent migration fixture. Do not regenerate from the new schema.
CREATE TABLE IF NOT EXISTS error_entries (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      topic_id TEXT NOT NULL,
      error_type TEXT NOT NULL,
      timestamp TEXT NOT NULL,
      prompt TEXT,
      user_answer TEXT,
      corrected_answer TEXT,
      explanation TEXT,
      rule TEXT,
      source TEXT NOT NULL DEFAULT 'topic_practice',
      user_blanks TEXT,
      feedback_json TEXT
    );
CREATE TABLE IF NOT EXISTS review_settings (
      id INTEGER PRIMARY KEY CHECK (id = 0),
      sort_order TEXT NOT NULL
    );
CREATE TABLE IF NOT EXISTS theme_settings (
      id INTEGER PRIMARY KEY CHECK (id = 0),
      mode TEXT NOT NULL
    );
CREATE TABLE IF NOT EXISTS text_size_settings (
      id INTEGER PRIMARY KEY CHECK (id = 0),
      size TEXT NOT NULL
    );
CREATE TABLE IF NOT EXISTS language_settings (
      id INTEGER PRIMARY KEY CHECK (id = 0),
      language TEXT NOT NULL
    );
CREATE TABLE IF NOT EXISTS practice_settings (
      id INTEGER PRIMARY KEY CHECK (id = 0),
      question_count INTEGER NOT NULL
    );
CREATE TABLE IF NOT EXISTS topic_practice_stats (
      topic_id TEXT PRIMARY KEY,
      questions_answered INTEGER NOT NULL DEFAULT 0
    );
CREATE TABLE IF NOT EXISTS user_profile (
      id INTEGER PRIMARY KEY CHECK (id = 0),
      name TEXT NOT NULL,
      learning_goal TEXT NOT NULL,
      avatar TEXT
    );
CREATE TABLE IF NOT EXISTS daily_session_usage (
      day TEXT PRIMARY KEY,
      session_count INTEGER NOT NULL DEFAULT 0
    );
CREATE TABLE IF NOT EXISTS free_practice_usage (
      day TEXT PRIMARY KEY,
      session_count INTEGER NOT NULL DEFAULT 0
    );
CREATE TABLE IF NOT EXISTS daily_test_sets (
      day TEXT PRIMARY KEY,
      questions_json TEXT NOT NULL,
      completed_at TEXT,
      answers_json TEXT,
      source TEXT NOT NULL DEFAULT 'generated'
    );
CREATE TABLE IF NOT EXISTS debug_settings (
      id INTEGER PRIMARY KEY CHECK (id = 0),
      access_override TEXT
    );
CREATE TABLE IF NOT EXISTS device_identity (
      id INTEGER PRIMARY KEY CHECK (id = 0),
      device_id TEXT NOT NULL
    );
CREATE TABLE IF NOT EXISTS climb_daily_entries (
      day TEXT PRIMARY KEY NOT NULL,
      completed_at TEXT NOT NULL,
      step INTEGER NOT NULL CHECK (step IN (0, 1)),
      correct_count INTEGER NOT NULL CHECK (correct_count >= 0),
      wrong_count INTEGER NOT NULL CHECK (wrong_count >= 0),
      skipped_count INTEGER NOT NULL CHECK (skipped_count >= 0),
      rule_version INTEGER NOT NULL
    );
CREATE TABLE IF NOT EXISTS monthly_medal_results (
      month TEXT PRIMARY KEY NOT NULL,
      tier TEXT CHECK (tier IN ('bronze', 'silver', 'gold')),
      score INTEGER NOT NULL CHECK (score >= 0),
      max_score INTEGER NOT NULL CHECK (max_score > 0),
      active_days INTEGER NOT NULL CHECK (active_days >= 0),
      correct_count INTEGER NOT NULL CHECK (correct_count >= 0),
      wrong_count INTEGER NOT NULL CHECK (wrong_count >= 0),
      skipped_count INTEGER NOT NULL CHECK (skipped_count >= 0),
      rule_version INTEGER NOT NULL,
      finalized_at TEXT NOT NULL
    );
CREATE TABLE IF NOT EXISTS welcome_badge (
      id INTEGER PRIMARY KEY CHECK (id = 0),
      earned_at TEXT NOT NULL,
      rule_version INTEGER NOT NULL,
      backfilled INTEGER NOT NULL CHECK (backfilled IN (0, 1))
    );
CREATE TABLE IF NOT EXISTS ai_consent (
      id INTEGER PRIMARY KEY CHECK (id = 0),
      granted INTEGER NOT NULL CHECK (granted IN (0, 1)),
      decided_at TEXT NOT NULL,
      consent_version INTEGER NOT NULL
    );
CREATE TABLE IF NOT EXISTS one_time_flags (
      key TEXT PRIMARY KEY,
      set_at TEXT NOT NULL
    );
CREATE TABLE IF NOT EXISTS climb_month_themes (
      month TEXT PRIMARY KEY NOT NULL,
      theme_id TEXT NOT NULL,
      assigned_at TEXT NOT NULL
    );
