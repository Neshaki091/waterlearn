// Setup type definitions for built-in Supabase Runtime APIs
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

// ─── Types ────────────────────────────────────────────────────────────────────

interface Section { heading: string; body: string; }
interface Chapter { title: string; sections: Section[]; }
interface Quiz {
  question: string; quiz_type: string; options?: string[];
  answer: string; explanation?: string; buggy_code?: string;
  error_line?: number; fixed_code?: string;
  code_language?: string; xp_reward?: number;
}

// ─── Prompts ──────────────────────────────────────────────────────────────────

function outlinePrompt(topic: string, level: string): string {
  return (
    `Bạn là chuyên gia IT. Tạo DÀN Ý chi tiết cho khóa học "${topic}" (${level}).` +
    ` Gồm CHÍNH XÁC 15 chương, mỗi chương liệt kê 3 mục con.` +
    ` Các chương phải đi từ cơ bản → nâng cao, KHÔNG trùng lặp nội dung.` +
    ` JSON: {"outline":[{"chapter":"Chương 1: ...","sections":["1.1 ...","1.2 ...","1.3 ..."]}]}` +
    ` CHỈ trả JSON.`
  );
}

function chapterPrompt(topic: string, batch: number, level: string, outline: string): string {
  const s = batch * 3 + 1;
  return (
    `Dưới đây là DÀN Ý TOÀN BỘ khóa học "${topic}":\n${outline}\n\n` +
    `Hãy viết NỘI DUNG CHI TIẾT cho CHƯƠNG ${s}, ${s + 1}, ${s + 2}.` +
    ` Mỗi chương có 3 sections theo đúng dàn ý trên.` +
    ` Mỗi section body: 2-3 đoạn văn, có ví dụ code nếu phù hợp.` +
    ` KHÔNG lặp lại nội dung của các chương khác.` +
    ` JSON: {"chapters":[{"title":"...","sections":[{"heading":"...","body":"..."}]}]}` +
    ` CHỈ trả JSON.`
  );
}

function quizPrompt(topic: string, batch: number, level: string, outline: string): string {
  return (
    `Dàn ý khóa "${topic}":\n${outline}\n\n` +
    `Tạo 20 câu quiz KHÁC NHAU cho batch ${batch + 1}/5. Không trùng batch khác.` +
    ` Batch ${batch + 1} tập trung vào chương ${batch * 3 + 1}-${batch * 3 + 3}.` +
    ` Mix: multiple_choice (70%), find_error (15%), fix_syntax (15%).` +
    ` JSON: {"quizzes":[{"question":"...","quiz_type":"multiple_choice","options":["A. ...","B. ...","C. ...","D. ..."],"answer":"A","explanation":"...","xp_reward":10}]}` +
    ` find_error: options=null, answer=error_line (0-indexed), buggy_code, xp_reward=15.` +
    ` fix_syntax: buggy_code, fixed_code, 4 options, xp_reward=20.` +
    ` CHỈ trả JSON.`
  );
}

// ─── Repair truncated JSON ────────────────────────────────────────────────────

function repairJson(raw: string): Record<string, unknown[]> {
  let str = raw.replace(/^```json\s*/i, "").replace(/```\s*$/, "").trim();
  try { return JSON.parse(str); } catch { /* continue */ }

  const lastGood = Math.max(str.lastIndexOf('}'), str.lastIndexOf(']'));
  if (lastGood > 0) str = str.slice(0, lastGood + 1);

  let ob = 0, os = 0;
  for (const c of str) {
    if (c === '{') ob++; if (c === '}') ob--;
    if (c === '[') os++; if (c === ']') os--;
  }
  while (ob > 0) { str += '}'; ob--; }
  while (os > 0) { str += ']'; os--; }

  try { return JSON.parse(str); } catch {
    console.error("[repair] Failed");
    return {};
  }
}

// ─── Call Gemini ──────────────────────────────────────────────────────────────

async function callGemini(apiKey: string, prompt: string): Promise<Record<string, unknown[]>> {
  const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${apiKey}`;

  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      contents: [{ parts: [{ text: prompt }] }],
      generationConfig: {
        response_mime_type: "application/json",
        temperature: 0.8,
        maxOutputTokens: 32768,
      },
    }),
  });

  if (!res.ok) {
    const err = await res.text();
    throw new Error(`Gemini ${res.status}: ${err.slice(0, 200)}`);
  }

  const data = await res.json();
  const text = data?.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
  if (!text) return {};
  return repairJson(text);
}

const delay = (ms: number) => new Promise(r => setTimeout(r, ms));
const BATCH_DELAY = 5000; // 5s giữa mỗi call — tránh rate limit

// ─── Background generation (chạy sau khi trả response về client) ─────────────

async function generateInBackground(
  apiKey: string,
  supabase: ReturnType<typeof createClient>,
  lessonId: string,
  topic: string,
  level: string,
) {
  try {
    // ══ STEP 0: Outline ══
    console.log("[step0] Generating outline...");
    const outlineResult = await callGemini(apiKey, outlinePrompt(topic, level));
    const outlineArr = outlineResult.outline as { chapter: string; sections: string[] }[] | undefined;

    let outlineText = "";
    if (outlineArr?.length) {
      outlineText = outlineArr
        .map(o => `${o.chapter}: ${o.sections?.join(", ") ?? ""}`)
        .join("\n");
      console.log(`[step0] Outline: ${outlineArr.length} chapters`);
    } else {
      outlineText = Array.from({ length: 15 }, (_, i) =>
        `Chương ${i + 1}: Phần ${i + 1} của ${topic}`
      ).join("\n");
      console.log("[step0] Using fallback outline");
    }

    await delay(BATCH_DELAY);

    // ══ STEP 1: Chapters (tuần tự, tránh rate limit) ══
    const allChapters: Chapter[] = [];
    for (let i = 0; i < 5; i++) {
      console.log(`[chapters] ${i + 1}/5...`);
      try {
        const result = await callGemini(apiKey, chapterPrompt(topic, i, level, outlineText));
        const chapters = result.chapters as Chapter[] | undefined;
        if (chapters?.length) allChapters.push(...chapters);
        console.log(`[chapters] ${i + 1}/5: ${chapters?.length ?? 0} ok`);
      } catch (e) {
        console.error(`[chapters] ${i + 1}/5 error: ${e}`);
      }
      await delay(BATCH_DELAY);
    }

    // ══ STEP 2: Quizzes (tuần tự, tránh rate limit) ══
    const allQuizzes: Quiz[] = [];
    for (let i = 0; i < 5; i++) {
      console.log(`[quizzes] ${i + 1}/5...`);
      try {
        const result = await callGemini(apiKey, quizPrompt(topic, i, level, outlineText));
        const quizzes = result.quizzes as Quiz[] | undefined;
        if (quizzes?.length) allQuizzes.push(...quizzes);
        console.log(`[quizzes] ${i + 1}/5: ${quizzes?.length ?? 0} ok`);
      } catch (e) {
        console.error(`[quizzes] ${i + 1}/5 error: ${e}`);
      }
      await delay(BATCH_DELAY);
    }

    console.log(`[done] ${allChapters.length} chapters, ${allQuizzes.length} quizzes`);

    // ══ Update lesson with content ══
    const { error: updateErr } = await supabase
      .from("lessons")
      .update({
        chapters: allChapters,
        status: allChapters.length > 0 ? "ready" : "failed",
      })
      .eq("id", lessonId);

    if (updateErr) console.error("[update] Error:", updateErr);

    // ══ Insert quizzes ══
    if (allQuizzes.length > 0) {
      const rows = allQuizzes.map(q => ({
        lesson_id: lessonId,
        question: q.question,
        quiz_type: q.quiz_type ?? "multiple_choice",
        options: q.options ?? null,
        answer: q.answer,
        explanation: q.explanation ?? null,
        buggy_code: q.buggy_code ?? null,
        error_line: q.error_line ?? null,
        fixed_code: q.fixed_code ?? null,
        code_language: q.code_language ?? "python",
        xp_reward: q.xp_reward ?? 10,
      }));

      const { error: qErr } = await supabase.from("quizzes").insert(rows);
      if (qErr) console.error("[quizzes] DB error:", qErr);
    }

    console.log(`[complete] Lesson ${lessonId} is ready!`);
  } catch (err) {
    console.error("[background] Fatal error:", err);
    await supabase.from("lessons").update({ status: "failed" }).eq("id", lessonId);
  }
}

// ─── Main Handler ─────────────────────────────────────────────────────────────

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type, Authorization",
      },
    });
  }

  const cors = { "Access-Control-Allow-Origin": "*", "Content-Type": "application/json" };

  try {
    const { topic, class_id: classId } = await req.json();
    if (!topic?.trim()) {
      return new Response(JSON.stringify({ error: "Missing topic" }), { status: 400, headers: cors });
    }

    const apiKey = Deno.env.get("GEMINI_API_KEY");
    if (!apiKey) throw new Error("GEMINI_API_KEY not set");

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      { auth: { persistSession: false } },
    );

    let level = "beginner";
    if (classId) {
      const { data } = await supabase.from("classes").select("level").eq("id", classId).single();
      level = data?.level ?? "beginner";
    }

    // ══ Tạo lesson rỗng (status = 'generating') → trả về ngay ══
    const { data: lesson, error: lErr } = await supabase
      .from("lessons")
      .insert({
        title: `${topic} — Toàn Diện`,
        topic: topic.trim(),
        chapters: [],
        class_id: classId ?? null,
        ai_generated: true,
        status: "generating",
      })
      .select("id")
      .single();

    if (lErr) throw lErr;

    // ══ Chạy nền: Edge Function tiếp tục xử lý sau khi trả response ══
    // @ts-ignore - EdgeRuntime.waitUntil is available in Supabase Edge Functions
    EdgeRuntime.waitUntil(
      generateInBackground(apiKey, supabase, lesson.id, topic.trim(), level)
    );

    // ══ Trả response ngay lập tức (< 1 giây) ══
    return new Response(
      JSON.stringify({
        success: true,
        lesson_id: lesson.id,
        status: "generating",
        message: "Bài học đang được tạo. Bạn có thể thoát app và quay lại sau.",
      }),
      { status: 202, headers: cors },
    );
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : JSON.stringify(err);
    console.error("[error]", msg);
    return new Response(JSON.stringify({ error: msg }), { status: 500, headers: cors });
  }
});
