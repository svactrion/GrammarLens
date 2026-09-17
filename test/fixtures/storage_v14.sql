-- Frozen v14 schema from 84deb915d6c812088b1c83f1e4031cfc209a3005.
-- Independent migration fixture. Do not regenerate from the new schema.
CREATE TABLE error_entries (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      topic_id TEXT NOT NULL,
      error_type TEXT NOT NULL,
      timestamp TEXT NOT NULL,
      prompt TEXT,
      user_answer TEXT,
      corrected_answer TEXT,
      explanation TEXT,
      rule TEXT,
      source TEXT NOT NULL DEFAULT 'topic_practice'
    );
CREATE TABLE review_settings (
      id INTEGER PRIMARY KEY CHECK (id = 0),
      sort_order TEXT NOT NULL
    );
CREATE TABLE theme_settings (
      id INTEGER PRIMARY KEY CHECK (id = 0),
      mode TEXT NOT NULL
    );
CREATE TABLE practice_settings (
      id INTEGER PRIMARY KEY CHECK (id = 0),
      question_count INTEGER NOT NULL
    );
CREATE TABLE topic_practice_stats (
      topic_id TEXT PRIMARY KEY,
      questions_answered INTEGER NOT NULL DEFAULT 0
    );
CREATE TABLE user_profile (
      id INTEGER PRIMARY KEY CHECK (id = 0),
      name TEXT NOT NULL,
      learning_goal TEXT NOT NULL,
      age INTEGER,
      occupation TEXT,
      avatar TEXT
    );
CREATE TABLE daily_session_usage (
      day TEXT PRIMARY KEY,
      session_count INTEGER NOT NULL DEFAULT 0
    );
CREATE TABLE free_practice_usage (
      day TEXT PRIMARY KEY,
      session_count INTEGER NOT NULL DEFAULT 0
    );
CREATE TABLE daily_test_sets (
      day TEXT PRIMARY KEY,
      questions_json TEXT NOT NULL,
      completed_at TEXT,
      answers_json TEXT
    );
CREATE TABLE debug_settings (
      id INTEGER PRIMARY KEY CHECK (id = 0),
      access_override TEXT
    );
CREATE TABLE IF NOT EXISTS device_identity (
      id INTEGER PRIMARY KEY CHECK (id = 0),
      device_id TEXT NOT NULL
    );
