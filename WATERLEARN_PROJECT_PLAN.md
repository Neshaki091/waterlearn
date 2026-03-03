# 📘 WaterLearn — Kế Hoạch Thực Hiện Dự Án

> **Phiên bản:** 1.0.0 | **Ngày cập nhật:** 25/02/2026  
> **Tech Stack:** Flutter · Supabase · Gemini 1.5 Flash  
> **Kiến trúc:** Clean Architecture · Provider · Edge Functions

---

## Mục Lục

1. [Tổng Quan Dự Án](#1-tổng-quan-dự-án)
2. [System Architecture](#2-system-architecture)
3. [Database Schema (PostgreSQL)](#3-database-schema-postgresql)
4. [Security Strategy](#4-security-strategy)
5. [Feature Roadmap](#5-feature-roadmap)
6. [Tech Stack Details](#6-tech-stack-details)
7. [Step-by-Step Implementation](#7-step-by-step-implementation)

---

## 1. Tổng Quan Dự Án

**WaterLearn** là ứng dụng học tập chuyên ngành IT kết hợp đố mẹo giải trí theo phong cách Duolingo. Ứng dụng sử dụng AI (Gemini 1.5 Flash) để tự động sinh bài giảng, quiz, và cá nhân hoá lộ trình học dựa trên cấp độ của lớp học.

### Mục Tiêu Chính

| Mục tiêu | Mô tả |
|---|---|
| 🎓 Học tập AI-powered | Gemini tự động sinh nội dung bài học theo chủ đề & cấp độ |
| 🎮 Gamification | Tim, điểm XP, chuỗi streak, hiệu ứng hoạt hình |
| 🔐 Bảo mật toàn diện | RLS, Supabase Vault, Secret Header |
| 📊 Thống kê học tập | Dashboard theo dõi tiến độ cá nhân & nhóm |
| 🔔 Nhắc nhở thông minh | Webhook gửi thông báo định kỳ qua Edge Function |

---

## 2. System Architecture

### 2.1 Sơ Đồ Luồng Hoạt Động

```
┌─────────────────────────────────────────────────────────────────┐
│                         FLUTTER CLIENT                          │
│  ┌──────────┐  ┌──────────────┐  ┌──────────────────────────┐  │
│  │  Auth UI │  │ Course/Quiz  │  │  Progress / Gamification  │  │
│  │(Supabase │  │    Screen    │  │       Dashboard           │  │
│  │  Auth)   │  │              │  │                           │  │
│  └────┬─────┘  └──────┬───────┘  └──────────┬───────────────┘  │
│       │               │                      │                  │
│       └───────────────┴──────────────────────┘                  │
│                         Supabase Client SDK                      │
└──────────────────────────────┬──────────────────────────────────┘
                               │ HTTPS + JWT
                               ▼
┌──────────────────────────────────────────────────────────────────┐
│                        SUPABASE BACKEND                          │
│                                                                  │
│  ┌──────────────┐   ┌─────────────────────────────────────────┐  │
│  │  Supabase    │   │           Edge Functions (Deno)          │  │
│  │    Auth      │   │                                         │  │
│  │              │   │  ┌──────────────────────────────────┐   │  │
│  │  - JWT Token │   │  │  /generate-course                │   │  │
│  │  - RLS Auto  │   │  │  1. Xác thực X-App-Secret        │   │  │
│  │    Context   │   │  │  2. Đọc Gemini Key từ Vault      │   │  │
│  └──────────────┘   │  │  3. Gọi Gemini 1.5 Flash API     │   │  │
│                     │  │  4. Parse JSON response           │   │  │
│  ┌──────────────┐   │  │  5. Ghi vào DB (lessons, quizzes)│   │  │
│  │  PostgreSQL  │◄──│  └──────────────────────────────────┘   │  │
│  │  Database    │   │                                         │  │
│  │  (RLS on)    │   │  ┌──────────────────────────────────┐   │  │
│  └──────────────┘   │  │  /update-progress                │   │  │
│                     │  │  /send-reminder (Webhook)         │   │  │
│  ┌──────────────┐   │  └──────────────────────────────────┘   │  │
│  │  Supabase    │   └─────────────────────────────────────────┘  │
│  │   Vault      │                        │                       │
│  │ (GEMINI_KEY) │                        │ fetch()               │
│  │ (APP_SECRET) │                        ▼                       │
│  └──────────────┘         ┌──────────────────────────┐          │
│                           │   Gemini 1.5 Flash API    │          │
│                           │  (Google AI Studio)       │          │
│                           └──────────────────────────┘          │
└──────────────────────────────────────────────────────────────────┘
```

### 2.2 Luồng Generate Course Chi Tiết

```
Flutter App
    │
    ├── 1. Người dùng chọn Class (e.g., "Lập trình Python - Cơ bản")
    │
    ├── 2. Gọi supabase.functions.invoke('generate-course', body: {
    │       'class_id': 'uuid...',
    │       'topic': 'Vòng lặp trong Python'
    │   }, headers: { 'X-App-Secret': appSecret })
    │
    ▼
Edge Function /generate-course
    │
    ├── 3. Kiểm tra X-App-Secret với Vault
    ├── 4. Truy vấn class info (level, subject) từ DB
    ├── 5. Xây dựng prompt động cho Gemini
    ├── 6. Gọi Gemini API → nhận JSON (lessons + quizzes)
    ├── 7. INSERT vào bảng lessons, quizzes
    └── 8. Trả về { lesson_id, quiz_ids } cho Flutter

Flutter App
    │
    └── 9. Điều hướng sang LessonView → QuizScreen
```

### 2.3 Luồng Đánh Giá Câu Hỏi `fix_syntax` / `find_error`

```
Người dùng nhận câu hỏi fix_syntax / find_error
    │
    ├── Flutter hiển thị đoạn code có lỗi (dùng flutter_highlight)
    │   Mỗi dòng code là một widget có thể tap/chọn
    │
    ├── Người dùng chọn dòng lỗi HOẶC chọn phương án sửa đúng
    │
    ├── Flutter gửi { quiz_id, user_answer } lên Edge Function /evaluate-answer
    │
    ▼
Edge Function /evaluate-answer
    │
    ├── [Loại: find_error]
    │   └── So sánh user_answer với correct_answer (số thứ tự dòng)
    │       → Đúng nếu line_index khớp chính xác
    │
    ├── [Loại: fix_syntax]
    │   ├── Chiến lược 1 – So sánh chuỗi chuẩn hoá:
    │   │   • Trim whitespace, lowercase
    │   │   • Xoá comment, chuẩn hoá indent
    │   │   • So sánh normalized_user với normalized_correct
    │   │
    │   └── Chiến lược 2 – Mô phỏng thực thi (sandbox giả lập):
    │       • Gửi đoạn code đã sửa kèm test case đơn giản tới Gemini
    │       • Gemini trả về: { "is_correct": true/false, "reason": "..." }
    │       • Dùng kết quả này thay vì so sánh chuỗi
    │
    ├── Cập nhật bảng user_progress (score, attempts)
    ├── Trừ tim nếu sai → cập nhật profiles.hearts
    └── Trả về { is_correct, explanation, xp_earned }

Flutter App
    │
    ├── Nhận kết quả → phát Lottie animation (đúng/sai)
    ├── Hiển thị panel "Trước và Sau" (diff view)
    └── Cập nhật UI: tim, XP điểm
```

---

## 3. Database Schema (PostgreSQL)

### 3.1 Sơ Đồ Quan Hệ (ERD)

```
profiles (1) ──────────── (N) user_progress
   │                              │
   │                              ├── class_id ──► classes
   │                              └── lesson_id ─► lessons
   │
   └── (N) class_enrollments ──► (1) classes
                                       │
                                  (1) classes
                                       │
                                   (N) lessons
                                       │
                                   (N) quizzes
```

### 3.2 Chi Tiết Các Bảng

#### Bảng `profiles`
```sql
CREATE TABLE public.profiles (
  id            UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username      TEXT UNIQUE NOT NULL,
  full_name     TEXT,
  avatar_url    TEXT,
  role          TEXT NOT NULL DEFAULT 'student' CHECK (role IN ('student', 'teacher', 'admin')),
  xp_points     INTEGER NOT NULL DEFAULT 0,
  hearts        INTEGER NOT NULL DEFAULT 5,
  max_hearts    INTEGER NOT NULL DEFAULT 5,
  streak_days   INTEGER NOT NULL DEFAULT 0,
  last_study_at TIMESTAMPTZ,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Tự động tạo profile khi user đăng ký
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, username, full_name, avatar_url)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'username', split_part(NEW.email, '@', 1)),
    NEW.raw_user_meta_data->>'full_name',
    NEW.raw_user_meta_data->>'avatar_url'
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
```

#### Bảng `classes`
```sql
CREATE TABLE public.classes (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title       TEXT NOT NULL,
  description TEXT,
  subject     TEXT NOT NULL,           -- e.g., 'Python', 'JavaScript', 'Network'
  level       TEXT NOT NULL CHECK (level IN ('beginner', 'intermediate', 'advanced')),
  thumbnail   TEXT,
  teacher_id  UUID REFERENCES public.profiles(id),
  is_public   BOOLEAN NOT NULL DEFAULT TRUE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

#### Bảng `class_enrollments`
```sql
CREATE TABLE public.class_enrollments (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  class_id   UUID NOT NULL REFERENCES public.classes(id) ON DELETE CASCADE,
  user_id    UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  enrolled_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(class_id, user_id)
);
```

#### Bảng `lessons`
```sql
CREATE TABLE public.lessons (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  class_id     UUID NOT NULL REFERENCES public.classes(id) ON DELETE CASCADE,
  title        TEXT NOT NULL,
  content      JSONB NOT NULL,          -- Mảng các step: [{type:'text',...}, {type:'code',...}]
  order_index  INTEGER NOT NULL DEFAULT 0,
  duration_min INTEGER,                  -- Thời gian ước tính (phút)
  ai_generated BOOLEAN DEFAULT FALSE,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Ví dụ cấu trúc JSONB content:
-- [
--   { "type": "text", "value": "Vòng lặp for trong Python..." },
--   { "type": "code", "language": "python", "value": "for i in range(5):\n    print(i)" },
--   { "type": "image", "url": "https://..." },
--   { "type": "tip", "value": "Mẹo: Dùng enumerate() khi cần index" }
-- ]
```

#### Bảng `quizzes`
```sql
CREATE TABLE public.quizzes (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lesson_id       UUID NOT NULL REFERENCES public.lessons(id) ON DELETE CASCADE,
  question        TEXT NOT NULL,
  quiz_type       TEXT NOT NULL CHECK (quiz_type IN (
                    'multiple_choice',  -- Chọn 1 trong 4 đáp án
                    'true_false',       -- Đúng / Sai
                    'fill_blank',       -- Điền vào chỗ trống
                    'code_output',      -- Dự đoán kết quả đầu ra
                    'find_error',       -- Tìm dòng code bị sai trong đoạn code
                    'fix_syntax'        -- Chọn phương án sửa đúng cho code bị hỏng
                  )),
  options         JSONB,                 -- ["A. for", "B. while", "C. do", "D. foreach"]
  correct_answer  TEXT NOT NULL,
  -- Với find_error: correct_answer = số thứ tự dòng lỗi (e.g. "2")
  -- Với fix_syntax: correct_answer = đoạn code đã sửa đúng (chuỗi)
  buggy_code      TEXT,                  -- [find_error / fix_syntax] Đoạn code có lỗi cần phân tích
  error_line      INTEGER,               -- [find_error] Số thứ tự dòng chứa lỗi (0-indexed)
  fixed_code      TEXT,                  -- [fix_syntax] Đoạn code đúng để hiển thị so sánh "Trước/Sau"
  code_language   TEXT DEFAULT 'python', -- Ngôn ngữ lập trình của đoạn code
  explanation     TEXT,                  -- Giải thích đáp án
  difficulty      INTEGER DEFAULT 1 CHECK (difficulty BETWEEN 1 AND 5),
  xp_reward       INTEGER DEFAULT 10,
  order_index     INTEGER DEFAULT 0,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Ví dụ dữ liệu cho quiz dạng find_error:
-- {
--   quiz_type:     'find_error',
--   question:      'Đoạn code Python sau có lỗi ở dòng nào?',
--   buggy_code:    'def greet(name):\n    print("Hello, " + name\n\ngreet("World")',
--   error_line:    1,          -- dòng 2 (0-indexed = 1) thiếu dấu đóng ngoặc
--   correct_answer:'1',
--   explanation:   'Dòng 2 thiếu dấu đóng ngoặc ) sau name',
--   code_language: 'python'
-- }
--
-- Ví dụ dữ liệu cho quiz dạng fix_syntax:
-- {
--   quiz_type:     'fix_syntax',
--   question:      'Chọn phương án sửa đúng cho đoạn code bị lỗi:',
--   buggy_code:    'for i in range(5)\n    print(i)',
--   options:       ["A. for i in range(5):\n    print(i)",
--                  "B. for i in range(5):\nprint(i)",
--                  "C. for i in range(5):\n  print i",
--                  "D. For i in range(5):\n    print(i)"],
--   correct_answer:'A',
--   fixed_code:    'for i in range(5):\n    print(i)',
--   explanation:   'Thiếu dấu ":" sau lệnh for và cần thụt lề đúng',
--   code_language: 'python'
-- }
```

#### Bảng `user_progress`
```sql
CREATE TABLE public.user_progress (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  class_id        UUID NOT NULL REFERENCES public.classes(id) ON DELETE CASCADE,
  lesson_id       UUID NOT NULL REFERENCES public.lessons(id) ON DELETE CASCADE,
  quiz_id         UUID REFERENCES public.quizzes(id),
  status          TEXT NOT NULL CHECK (status IN ('in_progress', 'completed', 'failed')),
  score           INTEGER DEFAULT 0,
  time_spent_sec  INTEGER DEFAULT 0,
  attempts        INTEGER DEFAULT 1,
  completed_at    TIMESTAMPTZ,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, lesson_id, quiz_id)
);

-- Index tối ưu truy vấn thống kê
CREATE INDEX idx_user_progress_user_class ON public.user_progress(user_id, class_id);
CREATE INDEX idx_user_progress_completed ON public.user_progress(user_id, completed_at DESC);
```

#### Bảng `heart_logs` (Gamification)
```sql
CREATE TABLE public.heart_logs (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  delta       INTEGER NOT NULL,           -- -1 (mất tim) hoặc +1 (nhận tim)
  reason      TEXT,                        -- 'wrong_answer', 'daily_refill', 'purchase'
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

---

## 4. Security Strategy

### 4.1 Row Level Security (RLS)

```sql
-- =============================================
-- BẬT RLS CHO TẤT CẢ CÁC BẢNG
-- =============================================
ALTER TABLE public.profiles          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.classes           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.class_enrollments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lessons           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quizzes           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_progress     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.heart_logs        ENABLE ROW LEVEL SECURITY;

-- =============================================
-- POLICIES CHO BẢNG profiles
-- =============================================
-- Người dùng chỉ xem được profile của chính mình và profile public
CREATE POLICY "profiles_select" ON public.profiles
  FOR SELECT USING (auth.uid() = id OR role = 'teacher');

-- Người dùng chỉ sửa được profile của mình
CREATE POLICY "profiles_update" ON public.profiles
  FOR UPDATE USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- =============================================
-- POLICIES CHO BẢNG classes
-- =============================================
-- Mọi người xem được lớp public; teacher xem được lớp của mình
CREATE POLICY "classes_select" ON public.classes
  FOR SELECT USING (
    is_public = TRUE
    OR teacher_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.class_enrollments
      WHERE class_id = classes.id AND user_id = auth.uid()
    )
  );

-- Chỉ teacher mới tạo/sửa/xóa lớp
CREATE POLICY "classes_insert" ON public.classes
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('teacher','admin'))
  );

CREATE POLICY "classes_update" ON public.classes
  FOR UPDATE USING (teacher_id = auth.uid());

CREATE POLICY "classes_delete" ON public.classes
  FOR DELETE USING (teacher_id = auth.uid());

-- =============================================
-- POLICIES CHO BẢNG user_progress
-- =============================================
-- Người dùng chỉ xem/ghi tiến trình của chính mình
CREATE POLICY "progress_select" ON public.user_progress
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "progress_insert" ON public.user_progress
  FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "progress_update" ON public.user_progress
  FOR UPDATE USING (user_id = auth.uid());

-- =============================================
-- POLICIES CHO BẢNG lessons & quizzes
-- =============================================
-- Người enrolled mới xem được lesson/quiz của lớp đó
CREATE POLICY "lessons_select" ON public.lessons
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.class_enrollments
      WHERE class_id = lessons.class_id AND user_id = auth.uid()
    )
    OR EXISTS (
      SELECT 1 FROM public.classes
      WHERE id = lessons.class_id AND teacher_id = auth.uid()
    )
  );

CREATE POLICY "quizzes_select" ON public.quizzes
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.lessons l
      JOIN public.class_enrollments ce ON ce.class_id = l.class_id
      WHERE l.id = quizzes.lesson_id AND ce.user_id = auth.uid()
    )
  );
```

### 4.2 Quản Lý Secret Key với Supabase Vault

#### Bước 1 – Lưu Key vào Vault qua Dashboard

```
Supabase Dashboard → Settings → Vault → New Secret

Tên: GEMINI_API_KEY
Giá trị: AIza...YOUR_KEY_HERE

Tên: APP_SECRET_KEY  
Giá trị: waterlearn_super_secret_2026
```

#### Bước 2 – Đọc Key trong Edge Function

```typescript
// supabase/functions/generate-course/index.ts
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

Deno.serve(async (req: Request) => {
  // === Bước 1: Xác thực X-App-Secret ===
  const appSecret = req.headers.get("X-App-Secret");
  
  // Lấy secret từ Vault để so sánh
  const supabaseAdmin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );
  
  const { data: secretData } = await supabaseAdmin.rpc('vault_decrypt', {
    secret_id: 'APP_SECRET_KEY'
  });
  
  if (appSecret !== secretData) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { "Content-Type": "application/json" }
    });
  }

  // === Bước 2: Lấy Gemini API Key từ Vault ===
  const { data: geminiKeyData } = await supabaseAdmin.rpc('vault_decrypt', {
    secret_id: 'GEMINI_API_KEY'
  });
  const GEMINI_API_KEY = geminiKeyData as string;

  // === Bước 3: Xác thực người dùng qua JWT ===
  const jwt = req.headers.get("Authorization")?.replace("Bearer ", "");
  const supabaseClient = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: `Bearer ${jwt}` } } }
  );
  
  const { data: { user }, error: authError } = await supabaseClient.auth.getUser();
  if (authError || !user) {
    return new Response(JSON.stringify({ error: "Invalid token" }), { status: 401 });
  }

  // === Bước 4: Gọi Gemini API ===
  const { class_id, topic } = await req.json();
  
  // Lấy thông tin class
  const { data: classData } = await supabaseAdmin
    .from("classes")
    .select("title, subject, level")
    .eq("id", class_id)
    .single();

  const prompt = buildGeminiPrompt(classData, topic);
  
  const geminiResponse = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${GEMINI_API_KEY}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [{ parts: [{ text: prompt }] }],
        generationConfig: {
          response_mime_type: "application/json",
          temperature: 0.7,
          maxOutputTokens: 4096
        }
      })
    }
  );

  const geminiData = await geminiResponse.json();
  const courseContent = JSON.parse(
    geminiData.candidates[0].content.parts[0].text
  );

  // === Bước 5: Lưu vào Database ===
  const { data: lesson, error: lessonError } = await supabaseAdmin
    .from("lessons")
    .insert({
      class_id,
      title: courseContent.lesson_title,
      content: courseContent.steps,
      ai_generated: true,
      order_index: courseContent.order_index ?? 0
    })
    .select()
    .single();

  if (lessonError) throw lessonError;

  // Insert quizzes
  const quizzesPayload = courseContent.quizzes.map((q: any, idx: number) => ({
    lesson_id: lesson.id,
    question: q.question,
    quiz_type: q.type,
    options: q.options,
    correct_answer: q.correct_answer,
    explanation: q.explanation,
    xp_reward: q.xp_reward ?? 10,
    order_index: idx
  }));

  await supabaseAdmin.from("quizzes").insert(quizzesPayload);

  return new Response(
    JSON.stringify({ lesson_id: lesson.id }),
    { headers: { "Content-Type": "application/json" } }
  );
});

function buildGeminiPrompt(classData: any, topic: string): string {
  return `
Bạn là giáo viên chuyên ngành ${classData.subject}.
Tạo một bài giảng về chủ đề "${topic}" cho cấp độ ${classData.level}.

Trả về JSON với cấu trúc chính xác sau:
{
  "lesson_title": "string",
  "order_index": number,
  "steps": [
    { "type": "text",  "value": "string" },
    { "type": "code",  "language": "string", "value": "string" },
    { "type": "tip",   "value": "string" }
  ],
  "quizzes": [
    {
      "question": "string",
      "type": "multiple_choice | true_false | fill_blank | code_output | find_error | fix_syntax",
      "options": ["A. ...", "B. ...", "C. ...", "D. ..."],
      "correct_answer": "string",
      "explanation": "string",
      "xp_reward": 10,

      // CHỈ có khi type = find_error hoặc fix_syntax:
      "buggy_code": "string (đoạn code có lỗi)",
      "error_line": "number | null (0-indexed, chỉ dùng cho find_error)",
      "fixed_code": "string (đoạn code đúng, chỉ dùng cho fix_syntax)",
      "code_language": "python | javascript | java | ..."
    }
  ]
}

Hướng dẫn về quiz "Syntax Traps" (bẫy cú pháp - BẮT BUỘC tạo ít nhất 2 câu):
- find_error: Tạo đoạn code 4-8 dòng có đúng 1 lỗi cú pháp. Các lỗi gợi ý:
  • Quên dấu ":" sau if/for/def/class
  • Sai thụt lề (indentation) - đặc biệt hiệu quả với Python
  • Dùng sai từ khoá (e.g. "Else" thay vì "else", "Then" thay vì ":")
  • Quên đóng ngoặc đơn (), ngoặc vuông [], ngoặc nhọn {}
  • Dùng "=" thay vì "==" trong điều kiện so sánh
  • Thiếu dấu "," giữa các tham số hàm
- fix_syntax: Cung cấp 4 options, trong đó chỉ 1 option có code đúng hoàn toàn;
  3 options còn lại chứa các lỗi khác nhau (tinh vi, dễ nhầm lẫn).

Tạo 5-8 steps bài giảng và 4-6 câu hỏi quiz đa dạng (mix nhiều loại type).
`;
}
```

#### Bước 3 – Gọi từ Flutter Client với Secret Header

```dart
// lib/services/course_service.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CourseService {
  final _supabase = Supabase.instance.client;
  
  Future<String> generateCourse({
    required String classId,
    required String topic,
  }) async {
    final response = await _supabase.functions.invoke(
      'generate-course',
      body: {'class_id': classId, 'topic': topic},
      headers: {
        'X-App-Secret': dotenv.env['APP_SECRET'] ?? '',
      },
    );
    
    if (response.status != 200) {
      throw Exception('Failed to generate course: ${response.data}');
    }
    
    return response.data['lesson_id'] as String;
  }
}
```

---

## 5. Feature Roadmap

### Giai Đoạn 1: MVP — Authentication & AI Course Generation

**Thời gian ước tính: 3–4 tuần**

```
✅ Sprint 1.1 – Foundation
   ├── Cài đặt Supabase project (Auth, DB, Edge Functions)
   ├── Khởi tạo Flutter project với Clean Architecture
   ├── Cấu hình supabase_flutter & provider
   ├── Tạo toàn bộ database schema (migrations)
   └── Bật RLS cho tất cả các bảng

✅ Sprint 1.2 – Authentication Flow
   ├── Màn hình Splash (kiểm tra session)
   ├── Màn hình Đăng ký / Đăng nhập (Email + Google OAuth)
   ├── Màn hình Cài đặt Profile (username, avatar)
   └── AuthProvider để quản lý trạng thái đăng nhập

✅ Sprint 1.3 – Class & Course Browse
   ├── Màn hình ClassSelector (danh sách lớp học)
   ├── Màn hình ClassDetail (thông tin, danh sách lesson)
   ├── Chức năng Enroll vào lớp học
   └── ClassProvider + ClassRepository

✅ Sprint 1.4 – AI Course Generation
   ├── Edge Function generate-course (Deno + Gemini)
   ├── Cấu hình Vault (GEMINI_API_KEY, APP_SECRET)
   ├── Màn hình LessonView (hiển thị steps dạng timeline)
   └── Màn hình QuizScreen (làm quiz sau bài học)
```

### Giai Đoạn 2: Gamification — Tăng Tính Hấp Dẫn

**Thời gian ước tính: 2–3 tuần**

```
🎮 Sprint 2.1 – Hearts System
   ├── UserStatusWidget (hiển thị tim, XP, streak trên AppBar)
   ├── Logic trừ tim khi trả lời sai
   ├── Refill tim sau 4 giờ (Edge Function scheduled)
   └── Màn hình Game Over khi hết tim

🎮 Sprint 2.2 – XP & Streak
   ├── Cộng XP sau mỗi quiz đúng (dựa theo xp_reward)
   ├── Tính streak_days (cập nhật last_study_at)
   ├── Màn hình Leaderboard (xếp hạng theo XP)
   └── Push Notification nhắc nhở streak

🎮 Sprint 2.3 – Hiệu Ứng & Animation
   ├── Lottie animation khi trả lời đúng / sai
   ├── ConfettiAnimation khi hoàn thành bài học
   ├── Progress bar animation trong LessonView
   └── XP gain animation (số điểm bay lên)

🎮 Sprint 2.4 – Quiz Style (Duolingo) & Interactive Code Quiz
   ├── Tap-to-select option với highlight màu
   ├── Color transition: grey → green (đúng) / red (sai)
   ├── Chức năng "Bỏ qua" câu hỏi (-1 tim)
   ├── Review mode sau khi hoàn thành quiz
   │
   ├── [find_error UI] Interactive Code Viewer
   │   ├── Hiển thị từng dòng code bằng flutter_highlight (syntax highlighting)
   │   ├── Mỗi dòng là một InkWell widget – người dùng tap vào dòng để chọn lỗi
   │   ├── Dòng đang chọn: highlight màu vàng với border đậm
   │   └── Sau khi nộp: dòng đúng chuyển sang 🟢, dòng sai chuyển sang 🔴
   │
   └── [fix_syntax UI] Before/After Diff Panel
       ├── Sau khi trả lời, hiển thị panel so sánh 2 cột:
       │   ┌──────────────┬─────────────────┐
       │   │  ❌ Trước    │   ✅ Sau         │
       │   │  buggy_code  │   fixed_code     │
       │   └──────────────┴─────────────────┘
       ├── Các dòng thay đổi được highlight khác màu (đỏ nhạt ↔ xanh nhạt)
       └── Nút "Xem giải thích" mở bottom sheet với explanation từ AI
```

### Giai Đoạn 3: Advanced — Thống Kê & Thông Báo

**Thời gian ước tính: 2–3 tuần**

```
📊 Sprint 3.1 – Learning Analytics
   ├── Dashboard cá nhân (biểu đồ học tập theo tuần)
   ├── Thống kê: bài đã học, quiz đúng/sai, thời gian học
   ├── Gợi ý bài học tiếp theo (dựa trên progress)
   └── fl_chart hoặc syncfusion_flutter_charts

📊 Sprint 3.2 – Teacher Dashboard
   ├── Màn hình quản lý lớp học (CRUD classes)
   ├── Xem tiến trình học viên trong lớp
   ├── Thêm/sửa bài học thủ công
   └── Export báo cáo lớp học

🔔 Sprint 3.3 – Webhooks & Notifications
   ├── Edge Function /send-reminder (chạy theo Cron)
   ├── Tích hợp Firebase Cloud Messaging (FCM) hoặc OneSignal
   ├── Nhắc nhở học bài hàng ngày (streak protection)
   └── Thông báo khi có bài học mới trong lớp

🔐 Sprint 3.4 – Security & Performance
   ├── Audit RLS policies
   ├── Thêm rate limiting cho Edge Functions
   ├── Tối ưu query với index
   └── Xử lý offline mode (hive hoặc isar)
```

---

## 6. Tech Stack Details

### 6.1 Flutter Packages

```yaml
# pubspec.yaml
dependencies:
  flutter:
    sdk: flutter

  # === SUPABASE ===
  supabase_flutter: ^2.5.0        # SDK chính cho Auth, DB, Storage, Functions

  # === STATE MANAGEMENT ===
  provider: ^6.1.2                # State management (ChangeNotifier)
  
  # === ENVIRONMENT ===
  flutter_dotenv: ^5.1.0          # Đọc biến môi trường từ .env

  # === ANIMATION ===
  lottie: ^3.1.2                  # Hiệu ứng JSON animation (đúng/sai/confetti)
  confetti: ^0.7.0                # Hiệu ứng confetti khi hoàn thành

  # === UI & DESIGN ===
  google_fonts: ^6.2.1            # Font chữ đẹp (Nunito, Poppins)
  shimmer: ^3.0.0                 # Loading skeleton effect
  cached_network_image: ^3.3.1    # Cache ảnh từ URL

  # === CODE DISPLAY (Quiz Syntax) ===
  flutter_highlight: ^0.7.0       # Syntax highlighting cho code quiz (find_error, fix_syntax)
  re_highlight: ^0.3.0            # Engine highlight hỗ trợ 180+ ngôn ngữ lập trình
  # Ghi chú: flutter_highlight bọc re_highlight để render widget;
  # dùng HightlightView(code, language: 'python', theme: githubTheme)
  
  # === NAVIGATION ===
  go_router: ^13.2.0              # Declarative routing

  # === CHARTS & ANALYTICS ===
  fl_chart: ^0.68.0               # Biểu đồ học tập (line, bar, pie)

  # === LOCAL STORAGE ===
  shared_preferences: ^2.2.3      # Lưu settings đơn giản
  hive_flutter: ^1.1.0            # Local cache cho offline mode
  hive: ^2.2.3

  # === UTILITIES ===
  intl: ^0.19.0                   # Format ngày giờ, số
  timeago: ^3.6.1                 # "2 phút trước" format
  uuid: ^4.3.3                    # Generate UUID phía client

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
  hive_generator: ^2.0.1
  build_runner: ^2.4.8
```

### 6.2 Cấu Trúc Thư Mục (Clean Architecture)

```
lib/
├── main.dart
├── app.dart                        # MaterialApp + GoRouter setup
├── core/
│   ├── constants/
│   │   ├── app_colors.dart
│   │   ├── app_strings.dart
│   │   └── supabase_constants.dart
│   ├── errors/
│   │   └── app_exception.dart
│   └── utils/
│       └── debouncer.dart
├── models/
│   ├── profile_model.dart
│   ├── class_model.dart
│   ├── lesson_model.dart
│   ├── quiz_model.dart
│   └── user_progress_model.dart
├── repositories/
│   ├── auth_repository.dart
│   ├── class_repository.dart
│   ├── lesson_repository.dart
│   └── progress_repository.dart
├── providers/
│   ├── auth_provider.dart
│   ├── class_provider.dart
│   ├── lesson_provider.dart
│   └── gamification_provider.dart
├── screens/
│   ├── splash/
│   │   └── splash_screen.dart
│   ├── auth/
│   │   ├── login_screen.dart
│   │   └── register_screen.dart
│   ├── home/
│   │   └── home_screen.dart
│   ├── class/
│   │   ├── class_selector_screen.dart
│   │   └── class_detail_screen.dart
│   ├── lesson/
│   │   └── lesson_view_screen.dart
│   ├── quiz/
│   │   └── quiz_screen.dart
│   └── profile/
│       └── profile_screen.dart
├── widgets/
│   ├── user_status_widget.dart
│   ├── quiz_option_card.dart
│   ├── lesson_step_card.dart
│   └── xp_animation_widget.dart
└── services/
    ├── supabase_service.dart
    └── course_service.dart

supabase/
├── functions/
│   ├── generate-course/
│   │   ├── index.ts
│   │   └── deno.json
│   ├── update-progress/
│   │   └── index.ts
│   └── send-reminder/
│       └── index.ts
└── migrations/
    ├── 001_initial_schema.sql
    ├── 002_rls_policies.sql
    └── 003_gamification.sql
```

---

## 7. Step-by-Step Implementation

### Bước 1: Khởi Tạo Supabase Project

```bash
# Cài đặt Supabase CLI
npm install -g supabase

# Login vào Supabase
supabase login

# Khởi tạo trong thư mục dự án
cd waterlearn
supabase init

# Liên kết với project trên cloud (lấy project-id từ Dashboard)
supabase link --project-ref YOUR_PROJECT_REF
```

### Bước 2: Khởi Tạo Flutter Project

```bash
# Tạo Flutter project mới
flutter create waterlearn --org com.yourname
cd waterlearn

# Thêm dependencies
flutter pub add supabase_flutter provider flutter_dotenv lottie google_fonts go_router fl_chart

# Tạo file .env (KHÔNG commit lên git!)
echo "SUPABASE_URL=https://your-project.supabase.co" > .env
echo "SUPABASE_ANON_KEY=your-anon-key" >> .env
echo "APP_SECRET=waterlearn_super_secret_2026" >> .env

# Thêm .env vào .gitignore
echo ".env" >> .gitignore

# Thêm .env vào assets trong pubspec.yaml
# assets:
#   - .env
```

### Bước 3: Cấu Hình main.dart

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load .env file
  await dotenv.load(fileName: ".env");
  
  // Khởi tạo Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        // Thêm các provider khác...
      ],
      child: const WaterLearnApp(),
    ),
  );
}
```

### Bước 4: Chạy Database Migrations

```bash
# Chạy migration lên Supabase Cloud
supabase db push

# Hoặc chạy trực tiếp file SQL qua Dashboard:
# Supabase Dashboard → SQL Editor → New Query → Paste SQL → Run
```

### Bước 5: Cấu Hình Vault trên Dashboard

```
1. Vào Supabase Dashboard → Settings → Vault
2. Click "Add new secret"
3. Thêm 2 secrets:
   - Name: GEMINI_API_KEY  | Value: AIza...
   - Name: APP_SECRET_KEY  | Value: waterlearn_super_secret_2026
4. Lưu lại Secret ID để dùng trong Edge Function
```

### Bước 6: Deploy Edge Functions

```bash
# Deploy function generate-course
supabase functions deploy generate-course --no-verify-jwt

# Deploy function update-progress
supabase functions deploy update-progress

# Deploy function send-reminder
supabase functions deploy send-reminder

# Xem logs của function
supabase functions logs generate-course --tail

# Test function cục bộ (development)
supabase functions serve generate-course --env-file .env.local
```

### Bước 7: Cấu Hình Google OAuth (Tùy chọn)

```
1. Supabase Dashboard → Authentication → Providers → Google
2. Bật Google provider
3. Lấy Client ID & Secret từ Google Cloud Console
4. Thêm Redirect URL: https://your-project.supabase.co/auth/v1/callback
5. Trong Flutter, cấu hình deeplink cho Android/iOS
```

### Bước 8: Cấu Hình Row Level Security

```bash
# Chạy file SQL policies
supabase db push

# Kiểm tra RLS trên Dashboard:
# Database → Tables → [chọn bảng] → RLS tab
# Đảm bảo RLS status = "Enabled"
```

### Bước 9: Test End-to-End

```bash
# Chạy Flutter app trên emulator/device
flutter run

# Kiểm tra logs realtime
supabase functions logs generate-course --tail

# Test Supabase Query trực tiếp
supabase db query "SELECT * FROM public.profiles LIMIT 5"
```

### Bước 10: Cấu Hình Cron Job (Giai Đoạn 3)

```sql
-- Kích hoạt pg_cron extension
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Chạy refill hearts mỗi 4 giờ
SELECT cron.schedule(
  'refill-hearts',
  '0 */4 * * *',
  $$
    UPDATE public.profiles
    SET hearts = LEAST(hearts + 1, max_hearts)
    WHERE hearts < max_hearts;
  $$
);

-- Gọi send-reminder Edge Function mỗi ngày lúc 7h sáng (ICT)
SELECT cron.schedule(
  'send-study-reminder',
  '0 0 * * *',  -- 7h sáng ICT = 0h UTC
  $$
    SELECT net.http_post(
      url := 'https://your-project.supabase.co/functions/v1/send-reminder',
      headers := jsonb_build_object('Authorization', 'Bearer ' || current_setting('app.service_role_key'))
    );
  $$
);
```

---

## Checklist Triển Khai

### Giai Đoạn 1 – MVP
- [ ] Tạo Supabase project và cấu hình
- [ ] Chạy database migrations (schema + RLS)
- [ ] Lưu secrets vào Supabase Vault
- [ ] Deploy Edge Function `generate-course`
- [ ] Flutter: Auth flow (Login, Register, Splash)
- [ ] Flutter: ClassSelector screen
- [ ] Flutter: LessonView screen (timeline steps)
- [ ] Flutter: QuizScreen (multiple choice)
- [ ] Test end-to-end với Gemini API

### Giai Đoạn 2 – Gamification
- [ ] UserStatusWidget (tim, XP, streak)
- [ ] Heart deduction logic
- [ ] XP accumulation & Leaderboard
- [ ] Lottie animations (correct/wrong/complete)
- [ ] Duolingo-style quiz UI

### Giai Đoạn 3 – Advanced
- [ ] Analytics Dashboard với fl_chart
- [ ] Teacher Dashboard (CRUD classes)
- [ ] Send-reminder Edge Function + Cron
- [ ] Offline mode với Hive cache
- [ ] Performance audit & optimization

---

*Tài liệu được tạo bởi: Senior Solution Architect*  
*WaterLearn Project — v1.0.0 — 2026*
