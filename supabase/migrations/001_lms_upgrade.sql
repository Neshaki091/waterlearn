-- ============================================================
-- WaterLearn LMS Upgrade Migration
-- Chạy file này trong Supabase Dashboard > SQL Editor
-- ============================================================

-- ── 1. Bảng classes (lớp học) ────────────────────────────────
CREATE TABLE IF NOT EXISTS public.classes (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT NOT NULL,
  description TEXT,
  level       TEXT NOT NULL DEFAULT 'beginner' CHECK (level IN ('beginner', 'intermediate', 'advanced')),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Seed dữ liệu mẫu
INSERT INTO public.classes (name, description, level) VALUES
  ('Docker Nhập môn',    'Học Docker từ số 0 - cài đặt, container, image cơ bản', 'beginner'),
  ('Docker Advanced',    'Swarm, Compose nâng cao, networking, production tips',   'advanced'),
  ('Git & GitHub Cơ bản','Quản lý mã nguồn với Git, pull request, branching',     'beginner'),
  ('RESTful API Design', 'Thiết kế API chuẩn REST, authentication, versioning',   'intermediate'),
  ('SQL & PostgreSQL',   'Truy vấn SQL, JOIN, index, transactions',               'beginner'),
  ('Linux Command Line', 'Các lệnh Linux thiết yếu cho developer',               'beginner');

-- ── 2. Bảng profiles (thông tin người dùng) ──────────────────
CREATE TABLE IF NOT EXISTS public.profiles (
  id               UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name        TEXT,
  total_points     INTEGER NOT NULL DEFAULT 0,
  streak           INTEGER NOT NULL DEFAULT 0,
  hearts           INTEGER NOT NULL DEFAULT 5,
  current_class_id UUID REFERENCES public.classes(id) ON DELETE SET NULL,
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ── 3. Cập nhật bảng lessons: thêm class_id ─────────────────
ALTER TABLE public.lessons
  ADD COLUMN IF NOT EXISTS class_id UUID REFERENCES public.classes(id) ON DELETE SET NULL;

-- ── 4. Bảng user_progress (tiến trình học) ───────────────────
CREATE TABLE IF NOT EXISTS public.user_progress (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  lesson_id    UUID NOT NULL REFERENCES public.lessons(id) ON DELETE CASCADE,
  class_id     UUID REFERENCES public.classes(id) ON DELETE SET NULL,
  completed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, lesson_id)
);

-- ── 5. Row Level Security (RLS) ──────────────────────────────

-- classes: Mọi người đều có thể đọc
ALTER TABLE public.classes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "classes_public_read"
  ON public.classes FOR SELECT USING (true);

-- profiles: Chỉ chủ sở hữu được đọc/sửa
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "profiles_owner_select"
  ON public.profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "profiles_owner_update"
  ON public.profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "profiles_owner_insert"
  ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);

-- user_progress: Chỉ chủ sở hữu được đọc/ghi
ALTER TABLE public.user_progress ENABLE ROW LEVEL SECURITY;
CREATE POLICY "progress_owner_select"
  ON public.user_progress FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "progress_owner_insert"
  ON public.user_progress FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "progress_owner_delete"
  ON public.user_progress FOR DELETE USING (auth.uid() = user_id);

-- ── 6. Trigger: Tự động tạo profile khi user đăng ký ─────────
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

-- ── 7. Function cộng điểm (tránh race condition) ─────────────
CREATE OR REPLACE FUNCTION public.increment_points(user_id UUID, delta INTEGER)
RETURNS VOID LANGUAGE sql SECURITY DEFINER AS $$
  UPDATE public.profiles
  SET total_points = total_points + delta,
      updated_at   = now()
  WHERE id = user_id;
$$;
