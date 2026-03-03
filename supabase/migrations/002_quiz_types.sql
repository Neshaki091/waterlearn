-- ============================================================
-- WaterLearn Migration 002 – Full Quiz Type Support
-- Chạy file này trong Supabase Dashboard > SQL Editor
-- SELF-CONTAINED: Tạo tất cả bảng cần thiết nếu chưa có
-- ============================================================

-- ── 0. Bảng classes (phải tạo trước vì lessons tham chiếu) ───
CREATE TABLE IF NOT EXISTS public.classes (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT NOT NULL,
  description TEXT,
  level       TEXT NOT NULL DEFAULT 'beginner'
                CHECK (level IN ('beginner', 'intermediate', 'advanced')),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.classes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "classes_public_read" ON public.classes;
CREATE POLICY "classes_public_read"
  ON public.classes FOR SELECT USING (true);

-- Seed classes mẫu (chỉ insert nếu bảng rỗng)
INSERT INTO public.classes (name, description, level)
SELECT * FROM (VALUES
  ('Docker Nhập môn',    'Học Docker từ số 0 - cài đặt, container, image cơ bản', 'beginner'),
  ('Docker Advanced',    'Swarm, Compose nâng cao, networking, production tips',   'advanced'),
  ('Git & GitHub Cơ bản','Quản lý mã nguồn với Git, pull request, branching',     'beginner'),
  ('RESTful API Design', 'Thiết kế API chuẩn REST, authentication, versioning',   'intermediate'),
  ('SQL & PostgreSQL',   'Truy vấn SQL, JOIN, index, transactions',               'beginner'),
  ('Linux Command Line', 'Các lệnh Linux thiết yếu cho developer',               'beginner')
) AS v(name, description, level)
WHERE NOT EXISTS (SELECT 1 FROM public.classes LIMIT 1);

-- ── 1. Bảng profiles ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.profiles (
  id               UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name        TEXT,
  total_points     INTEGER NOT NULL DEFAULT 0,
  streak           INTEGER NOT NULL DEFAULT 0,
  hearts           INTEGER NOT NULL DEFAULT 5,
  current_class_id UUID REFERENCES public.classes(id) ON DELETE SET NULL,
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "profiles_owner_select" ON public.profiles;
CREATE POLICY "profiles_owner_select"
  ON public.profiles FOR SELECT USING (auth.uid() = id);
DROP POLICY IF EXISTS "profiles_owner_update" ON public.profiles;
CREATE POLICY "profiles_owner_update"
  ON public.profiles FOR UPDATE USING (auth.uid() = id);
DROP POLICY IF EXISTS "profiles_owner_insert" ON public.profiles;
CREATE POLICY "profiles_owner_insert"
  ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);

-- ── 2. Bảng lessons ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.lessons (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title        TEXT NOT NULL,
  topic        TEXT NOT NULL,
  chapters     JSONB NOT NULL DEFAULT '[]'::jsonb,
  class_id     UUID REFERENCES public.classes(id) ON DELETE SET NULL,
  ai_generated BOOLEAN DEFAULT TRUE,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.lessons ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "lessons_public_read" ON public.lessons;
CREATE POLICY "lessons_public_read"
  ON public.lessons FOR SELECT USING (true);

-- ── 3. Bảng quizzes (đầy đủ với find_error / fix_syntax) ────
CREATE TABLE IF NOT EXISTS public.quizzes (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lesson_id     UUID NOT NULL REFERENCES public.lessons(id) ON DELETE CASCADE,
  question      TEXT NOT NULL,
  quiz_type     TEXT NOT NULL DEFAULT 'multiple_choice',
  options       JSONB,
  answer        TEXT NOT NULL,
  explanation   TEXT,
  buggy_code    TEXT,
  error_line    INTEGER,
  fixed_code    TEXT,
  code_language TEXT DEFAULT 'python',
  xp_reward     INTEGER NOT NULL DEFAULT 10,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Thêm cột nếu bảng đã tồn tại từ trước
ALTER TABLE public.quizzes
  ADD COLUMN IF NOT EXISTS quiz_type TEXT NOT NULL DEFAULT 'multiple_choice',
  ADD COLUMN IF NOT EXISTS buggy_code TEXT,
  ADD COLUMN IF NOT EXISTS error_line INTEGER,
  ADD COLUMN IF NOT EXISTS fixed_code TEXT,
  ADD COLUMN IF NOT EXISTS code_language TEXT DEFAULT 'python',
  ADD COLUMN IF NOT EXISTS xp_reward INTEGER NOT NULL DEFAULT 10;

ALTER TABLE public.quizzes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "quizzes_public_read" ON public.quizzes;
CREATE POLICY "quizzes_public_read"
  ON public.quizzes FOR SELECT USING (true);

-- ── 4. Bảng user_progress ────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.user_progress (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  lesson_id    UUID NOT NULL REFERENCES public.lessons(id) ON DELETE CASCADE,
  class_id     UUID REFERENCES public.classes(id) ON DELETE SET NULL,
  completed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, lesson_id)
);

ALTER TABLE public.user_progress ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "progress_owner_select" ON public.user_progress;
CREATE POLICY "progress_owner_select"
  ON public.user_progress FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "progress_owner_insert" ON public.user_progress;
CREATE POLICY "progress_owner_insert"
  ON public.user_progress FOR INSERT WITH CHECK (auth.uid() = user_id);

-- ── 5. Trigger: Tự tạo profile khi user đăng ký ─────────────
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1))
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ── 6. RPC cộng XP ──────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.add_xp(uid UUID, delta INTEGER)
RETURNS VOID LANGUAGE sql SECURITY DEFINER AS $$
  UPDATE public.profiles
  SET total_points = total_points + delta,
      updated_at   = now()
  WHERE id = uid;
$$;
