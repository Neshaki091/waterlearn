// Test nhiều model Gemini để tìm model có free tier
// Chạy: node test_gemini.js

const API_KEY = 'AIzaSyDcFIMO8_oPuPyNqMKOvpJHs2BgeKXL_g4';

const MODELS_TO_TEST = [
    'gemini-2.5-flash',
    'gemini-2.0-flash-lite',
    'gemini-2.0-flash',
    'gemini-2.0-flash-001',
];

async function testModel(model) {
    const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${API_KEY}`;

    const res = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            contents: [{ parts: [{ text: 'Nói "xin chào" bằng tiếng Việt' }] }],
            generationConfig: { maxOutputTokens: 30 },
        }),
    });

    if (res.ok) {
        const data = await res.json();
        const text = data.candidates?.[0]?.content?.parts?.[0]?.text || '';
        console.log(`✅ ${model} → OK! Response: "${text.trim()}"`);
        return true;
    } else {
        console.log(`❌ ${model} → Error ${res.status}`);
        return false;
    }
}

async function main() {
    console.log('🔍 Tìm model Gemini có free tier...\n');

    for (const model of MODELS_TO_TEST) {
        const ok = await testModel(model);
        if (ok) {
            console.log(`\n🎉 Dùng model: ${model}`);
            break;
        }
        // Chờ 2s giữa các request
        await new Promise(r => setTimeout(r, 2000));
    }
}

main().catch(console.error);
