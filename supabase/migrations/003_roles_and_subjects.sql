-- ============================================================
-- 003_roles_and_subjects.sql
-- Thêm role cho profiles + seed toàn bộ subject IT
-- ============================================================

-- 1. Thêm cột role vào profiles
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS role TEXT NOT NULL DEFAULT 'user'
    CHECK (role IN ('user', 'admin'));

-- 1b. Thêm cột status vào lessons (generating → ready / failed)
ALTER TABLE public.lessons
  ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'ready'
    CHECK (status IN ('generating', 'ready', 'failed'));

-- 2. Set admin cho user hiện tại (thay email nếu cần)
-- UPDATE public.profiles SET role = 'admin' WHERE id = '<your-user-id>';

-- 3. Seed IT Subjects (classes) ─── Từ cơ bản đến nâng cao ──────────────

-- Xóa seed cũ nếu có
DELETE FROM public.classes WHERE name IN (
  'Nhập môn Lập trình', 'Python cơ bản', 'HTML & CSS', 'JavaScript cơ bản',
  'Git & GitHub', 'SQL cơ bản', 'Cấu trúc dữ liệu', 'Thuật toán',
  'Mạng máy tính', 'Hệ điều hành Linux',
  'Lập trình Hướng đối tượng', 'Java nâng cao', 'RESTful API',
  'Docker & Container', 'Cơ sở dữ liệu nâng cao', 'React.js',
  'Node.js & Express', 'Flutter & Dart', 'TypeScript', 'CI/CD Pipeline',
  'Kiến trúc Microservices', 'Cloud Computing (AWS)', 'Kubernetes',
  'Machine Learning cơ bản', 'An ninh mạng', 'Blockchain & Web3',
  'System Design', 'DevOps nâng cao', 'AI & Deep Learning', 'Rust Programming'
);

-- ─── Beginner (10 môn) ───
INSERT INTO public.classes (name, description, level) VALUES
  ('Nhập môn Lập trình', 'Tư duy logic, biến, hàm, vòng lặp, điều kiện', 'beginner'),
  ('Python cơ bản', 'Cú pháp Python, kiểu dữ liệu, hàm, file I/O', 'beginner'),
  ('HTML & CSS', 'Cấu trúc web, thẻ HTML, CSS layout, responsive', 'beginner'),
  ('JavaScript cơ bản', 'DOM, events, async/await, ES6+', 'beginner'),
  ('Git & GitHub', 'Version control, branch, merge, pull request', 'beginner'),
  ('SQL cơ bản', 'SELECT, JOIN, GROUP BY, INDEX, transaction', 'beginner'),
  ('Cấu trúc dữ liệu', 'Array, linked list, stack, queue, tree, graph', 'beginner'),
  ('Thuật toán', 'Sorting, searching, recursion, dynamic programming', 'beginner'),
  ('Mạng máy tính', 'TCP/IP, DNS, HTTP, OSI model, subnetting', 'beginner'),
  ('Hệ điều hành Linux', 'CLI, file system, process, shell scripting', 'beginner');

-- ─── Intermediate (10 môn) ───
INSERT INTO public.classes (name, description, level) VALUES
  ('Lập trình Hướng đối tượng', 'OOP: kế thừa, đa hình, trừu tượng, SOLID', 'intermediate'),
  ('Java nâng cao', 'Collections, streams, multithreading, Spring Boot', 'intermediate'),
  ('RESTful API', 'HTTP methods, status codes, authentication, best practices', 'intermediate'),
  ('Docker & Container', 'Image, container, Dockerfile, docker-compose, volumes', 'intermediate'),
  ('Cơ sở dữ liệu nâng cao', 'Normalization, indexing, query optimization, NoSQL', 'intermediate'),
  ('React.js', 'Components, hooks, state management, routing', 'intermediate'),
  ('Node.js & Express', 'Server-side JS, middleware, REST API, MongoDB', 'intermediate'),
  ('Flutter & Dart', 'Widgets, state management, navigation, Supabase', 'intermediate'),
  ('TypeScript', 'Types, interfaces, generics, decorators, config', 'intermediate'),
  ('CI/CD Pipeline', 'GitHub Actions, Jenkins, testing, deployment automation', 'intermediate');

-- ─── Advanced (10 môn) ───
INSERT INTO public.classes (name, description, level) VALUES
  ('Kiến trúc Microservices', 'Service mesh, API gateway, event-driven, CQRS', 'advanced'),
  ('Cloud Computing (AWS)', 'EC2, S3, Lambda, RDS, CloudFormation, IAM', 'advanced'),
  ('Kubernetes', 'Pods, services, deployments, Helm, monitoring', 'advanced'),
  ('Machine Learning cơ bản', 'Regression, classification, neural networks, scikit-learn', 'advanced'),
  ('An ninh mạng', 'OWASP, encryption, penetration testing, firewall', 'advanced'),
  ('Blockchain & Web3', 'Smart contracts, Solidity, DeFi, consensus algorithms', 'advanced'),
  ('System Design', 'Scalability, load balancing, caching, database sharding', 'advanced'),
  ('DevOps nâng cao', 'Terraform, Ansible, monitoring, observability', 'advanced'),
  ('AI & Deep Learning', 'CNN, RNN, transformers, PyTorch, model deployment', 'advanced'),
  ('Rust Programming', 'Ownership, borrowing, lifetimes, concurrency, WebAssembly', 'advanced');

-- 4. RLS cho profiles (cho phép đọc role)
DROP POLICY IF EXISTS "profiles_read_own" ON public.profiles;
CREATE POLICY "profiles_read_own"
  ON public.profiles FOR SELECT
  USING (auth.uid() = id);

-- 5. Cho phép admin insert classes
DROP POLICY IF EXISTS "classes_admin_insert" ON public.classes;
CREATE POLICY "classes_admin_insert"
  ON public.classes FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
    )
  );

-- 6. Cho phép user đọc lessons (đã có) nhưng chỉ admin insert
DROP POLICY IF EXISTS "lessons_admin_insert" ON public.lessons;
CREATE POLICY "lessons_admin_insert"
  ON public.lessons FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
    )
  );
