PRAGMA foreign_keys = ON;

-- Core tasks table (minimal, no estimation columns)
CREATE TABLE IF NOT EXISTS tasks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    notes TEXT,
    is_completed INTEGER NOT NULL DEFAULT 0,
    due_date INTEGER, -- Unix timestamp in seconds
    created_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s', 'now') AS INTEGER)),
    completed_at INTEGER
);

-- Session tracking (Pomodoro intervals, breaks, and open stopwatch sessions)
CREATE TABLE IF NOT EXISTS time_sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    type TEXT NOT NULL DEFAULT 'pomodoro_work' CHECK (type IN ('pomodoro_work', 'short_break', 'long_break', 'free_track')),
    started_at INTEGER NOT NULL,
    ended_at INTEGER, -- NULL indicates an active session
    duration_seconds INTEGER GENERATED ALWAYS AS (
        CASE 
            WHEN ended_at IS NOT NULL THEN ended_at - started_at
            ELSE NULL 
        END
    ) STORED,
    is_completed INTEGER NOT NULL DEFAULT 1,
    notes TEXT,
    created_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s', 'now') AS INTEGER))
);

-- Pivot table: tasks to time sessions
CREATE TABLE IF NOT EXISTS task_time_sessions (
    task_id INTEGER NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    time_session_id INTEGER NOT NULL UNIQUE REFERENCES time_sessions(id) ON DELETE CASCADE,
    PRIMARY KEY (task_id, time_session_id)
);

-- Ensure only one active timer can run globally
CREATE UNIQUE INDEX IF NOT EXISTS idx_single_active_session 
    ON time_sessions ((1)) 
    WHERE ended_at IS NULL;

-- Pivot and aggregation lookup indexes
CREATE INDEX IF NOT EXISTS idx_task_time_sessions_task_id ON task_time_sessions (task_id);
CREATE INDEX IF NOT EXISTS idx_time_sessions_timeline ON time_sessions (started_at DESC);

PRAGMA user_version = 1;