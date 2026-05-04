require('dotenv').config();
const express = require('express');
const cors = require('cors');
const admin = require('firebase-admin');
const { GoogleGenerativeAI } = require('@google/generative-ai');
const Groq = require('groq-sdk');
const crypto = require('crypto');
const fs = require('fs');
const AdmZip = require('adm-zip');
const { parse } = require('csv-parse/sync');
const multer = require('multer');
const axios = require('axios');

const app = express();
app.use(cors({ origin: process.env.ALLOWED_ORIGINS?.split(',') || '*' }));
app.use(express.json({ limit: '5mb' }));
const port = process.env.PORT || 10000;

// ─── 1. Firebase Initialization ───────────────────────────────────────────────
try {
  let serviceAccount;
  if (fs.existsSync('/etc/secrets/firebase-service-account.json')) {
    console.log("✅ Found Firebase key in Render secrets!");
    serviceAccount = require('/etc/secrets/firebase-service-account.json');
  } else if (fs.existsSync('./firebase-service-account.json')) {
    console.log("✅ Found Firebase key locally!");
    serviceAccount = require('./firebase-service-account.json');
  } else if (process.env.FIREBASE_SERVICE_ACCOUNT) {
    console.log("✅ Found Firebase key in Environment Variable!");
    serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
  } else {
    throw new Error("Could NOT find the Firebase JSON file anywhere!");
  }
  admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
  console.log("🚀 Firebase initialized successfully!");
} catch (error) {
  console.error("🔥 Firebase Setup FAILED:", error.message);
}

const db = admin.apps.length ? admin.firestore() : null;
const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY || 'MOCK_KEY');
const groq = process.env.GROQ_API_KEY ? new Groq({ apiKey: process.env.GROQ_API_KEY }) : null;

// ─── 2. In-Memory LRU Cache ────────────────────────────────────────────────────
const ATS_CACHE = new Map();
const ATS_CACHE_MAX = 200;
const ATS_CACHE_TTL_MS = 30 * 60 * 1000;

function getCacheKey(resumeText, targetJD) {
  return crypto.createHash('sha256').update(resumeText + (targetJD || '')).digest('hex');
}

function cacheGet(key) {
  const entry = ATS_CACHE.get(key);
  if (!entry) return null;
  if (Date.now() - entry.ts > ATS_CACHE_TTL_MS) { ATS_CACHE.delete(key); return null; }
  return entry.data;
}

function cacheSet(key, data) {
  if (ATS_CACHE.size >= ATS_CACHE_MAX) {
    ATS_CACHE.delete(ATS_CACHE.keys().next().value);
  }
  ATS_CACHE.set(key, { data, ts: Date.now() });
}

// ─── 3. ATS Scoring Rubric ────────────────────────────────────────────────────
const SCORING_RUBRIC = `
Score this resume across 5 categories (each out of 20):
1. KEYWORD_MATCH: Presence of role-relevant technical keywords
2. IMPACT_LANGUAGE: Use of strong action verbs and quantified achievements
3. STRUCTURE: Clear sections, consistent formatting, scannable layout
4. RELEVANCE: Experience and skills alignment to the target role
5. ATS_COMPATIBILITY: No tables, graphics, headers/footers, special chars

Return ONLY this exact JSON schema — no other text:
{
  "total_score": <sum of all 5>,
  "categories": {
    "keyword_match":     { "score": 0, "reasoning": "..." },
    "impact_language":   { "score": 0, "reasoning": "..." },
    "structure":         { "score": 0, "reasoning": "..." },
    "relevance":         { "score": 0, "reasoning": "..." },
    "ats_compatibility": { "score": 0, "reasoning": "..." }
  },
  "critical_issues":     [{ "issue": "...", "fix": "...", "priority": "high|medium|low" }],
  "matched_keywords":    [],
  "missing_keywords":    [],
  "top_3_wins":          [],
  "top_3_improvements":  []
}`;

// ─── 4. Shared Validation Middleware ──────────────────────────────────────────
const validateAiInput = (fields) => (req, res, next) => {
  const injectionRe = /ignore (previous|all) instructions|system prompt|forget everything/i;
  for (const { key, required, maxLen, minLen } of fields) {
    const val = req.body[key];
    if (required && (!val || typeof val !== 'string' || val.trim().length < (minLen || 1)))
      return res.status(400).json({ error: `'${key}' is required.` });
    if (val && typeof val === 'string') {
      if (maxLen && val.length > maxLen)
        return res.status(400).json({ error: `'${key}' is too long (max ${maxLen} chars).` });
      if (injectionRe.test(val))
        return res.status(400).json({ error: 'Invalid content detected.' });
    }
  }
  next();
};

const validateAtsInput = (req, res, next) => {
  const { resumeText, targetJD } = req.body;
  if (!resumeText || typeof resumeText !== 'string')
    return res.status(400).json({ error: 'resumeText is required and must be a string.' });
  if (resumeText.length > 15000)
    return res.status(400).json({ error: 'Resume text exceeds maximum length (15,000 chars).' });
  if (targetJD && typeof targetJD !== 'string')
    return res.status(400).json({ error: 'targetJD must be a string.' });
  if (targetJD && targetJD.length > 10000)
    return res.status(400).json({ error: 'Job description exceeds maximum length (10,000 chars).' });
  const injectionPatterns = /ignore previous|system prompt|forget instructions/i;
  if (injectionPatterns.test(resumeText) || (targetJD && injectionPatterns.test(targetJD)))
    return res.status(400).json({ error: 'Invalid content detected.' });
  next();
};

const validateCoverLetterInput = (req, res, next) => {
  const { resumeText, jd, company, name } = req.body;
  if (!resumeText || typeof resumeText !== 'string' || resumeText.trim().length < 50)
    return res.status(400).json({ error: 'Resume text is required (min 50 chars).' });
  if (!company || typeof company !== 'string' || company.trim().length < 2)
    return res.status(400).json({ error: 'Company name is required.' });
  if (!name || typeof name !== 'string' || name.trim().length < 2)
    return res.status(400).json({ error: 'Applicant name is required.' });
  if (resumeText.length > 12000)
    return res.status(400).json({ error: 'Resume text too long (max 12,000 chars).' });
  if (jd && jd.length > 8000)
    return res.status(400).json({ error: 'Job description too long (max 8,000 chars).' });
  if (company.length > 200)
    return res.status(400).json({ error: 'Company name too long.' });
  const injectionRe = /ignore (previous|all) instructions|system prompt|forget everything/i;
  if (injectionRe.test(resumeText) || injectionRe.test(jd || ''))
    return res.status(400).json({ error: 'Invalid content detected.' });
  next();
};

// ─── 5. Shared Safe JSON Parser ───────────────────────────────────────────────
function safeParseJson(rawText) {
  const cleaned = rawText
    .replace(/```json|```/g, '')
    .replace(/^[^{[]*/, '')
    .trim();
  const lastBrace = cleaned.lastIndexOf('}');
  const lastBracket = cleaned.lastIndexOf(']');
  const cutoff = Math.max(lastBrace, lastBracket);
  const trimmed = cutoff !== -1 ? cleaned.slice(0, cutoff + 1) : cleaned;
  return JSON.parse(trimmed);
}

function safeParseAtsResponse(rawText) {
  const parsed = safeParseJson(rawText);
  if (typeof parsed.total_score !== 'number') throw new Error('Missing total_score.');
  if (!parsed.categories) throw new Error('Missing categories.');
  if (!Array.isArray(parsed.critical_issues)) throw new Error('Missing critical_issues array.');
  return parsed;
}

// ─── 6. Structured Resume Formatter ──────────────────────────────────────────
function formatStructuredResume(sections) {
  const p = sections.personal || {};
  const exp = (sections.experience || []).map(e =>
    `[${e.title || ''}] at [${e.company || ''}] (${e.dates || ''})\n${e.description || ''}`
  ).join('\n\n');
  const edu = (sections.education || []).map(e =>
    `${e.degree || ''} — ${e.institution || ''} (${e.year || ''})`
  ).join('\n');
  const skills = Array.isArray(sections.skills)
    ? sections.skills.map(s => (typeof s === 'string' ? s : JSON.stringify(s))).join(', ')
    : '';
  return `
=== CANDIDATE ===
${p.name || ''} | ${p.email || ''} | ${p.phone || ''}

=== PROFESSIONAL SUMMARY ===
${p.summary || ''}

=== WORK EXPERIENCE ===
${exp}

=== SKILLS ===
${skills}

=== EDUCATION ===
${edu}
`.trim();
}

// ─── 7. AI Timeout Wrapper ────────────────────────────────────────────────────
function withTimeout(promise, ms = 30000) {
  return Promise.race([
    promise,
    new Promise((_, reject) =>
      setTimeout(() => reject(new Error(`AI call timed out after ${ms}ms`)), ms)
    )
  ]);
}

// ─── 8. Auth Middleware (kept as-is for testing) ──────────────────────────────
const auth = async (req, res, next) => {
  const token = req.headers.authorization?.split('Bearer ')[1];
  if (!token) return res.status(401).json({ error: 'No token' });
  try {
    req.user = await admin.auth().verifyIdToken(token);
    next();
  } catch (error) {
    console.error("Auth Error:", error.code);
    // TEMPORARY: Allow through for testing — remove before go-live
    req.user = { uid: 'auth_failed_but_allowed' };
    next();
  }
};

// ─── 9. Rate Limiter (kept bypassed for testing) ──────────────────────────────
const rateLimit = async (uid, isPro, limit = 3) => {
  return true; // TEMPORARY BYPASS — remove this line before go-live
  if (isPro) return true;
  if (!db) return true;
  const today = new Date().toISOString().split('T')[0];
  const ref = db.collection('rate_limits').doc(`${uid}_${today}`);
  return db.runTransaction(async (t) => {
    const doc = await t.get(ref);
    const count = (doc.data()?.count || 0);
    if (count >= limit) return false;
    t.set(ref, { count: count + 1 }, { merge: true });
    return true;
  });
};

// ─── 10. LinkedIn State Store (sweep-based, no memory leak) ──────────────────
const linkedinStateStore = new Map();
setInterval(() => {
  const cutoff = Date.now() - 10 * 60 * 1000;
  for (const [key, val] of linkedinStateStore) {
    if (val.ts < cutoff) linkedinStateStore.delete(key);
  }
}, 60 * 1000);

const LINKEDIN = {
  clientId: process.env.LINKEDIN_CLIENT_ID,
  clientSecret: process.env.LINKEDIN_CLIENT_SECRET,
  redirectUri: process.env.LINKEDIN_REDIRECT_URI || 'https://ats-resume-server.onrender.com/api/linkedin/callback',
  scope: 'openid profile email',
};

// ─── Multer (LinkedIn ZIP) ─────────────────────────────────────────────────────
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    if (
      file.mimetype === 'application/zip' ||
      file.mimetype === 'application/x-zip-compressed' ||
      file.originalname.endsWith('.zip')
    ) cb(null, true);
    else cb(new Error('Only ZIP files allowed'), false);
  }
});

// ═══════════════════════════════════════════════════════════════════════════════
// ROUTES
// ═══════════════════════════════════════════════════════════════════════════════

app.get('/', (req, res) => {
  res.send('ATS Resume Backend is Live and Firebase is connected!');
});

// ─── Improve Bullet ───────────────────────────────────────────────────────────
app.post('/api/ai/improve-bullet', auth,
  validateAiInput([
    { key: 'rawDuty', required: true, maxLen: 1000 },
    { key: 'role', required: true, maxLen: 200 },
  ]),
  async (req, res) => {
    const { rawDuty, role } = req.body;

    if (!process.env.GEMINI_API_KEY)
      return res.json({ bullet: `Optimised ${role} duty: Increased efficiency by 20% in ${rawDuty}` });

    const prompt = `You are an expert resume writer. Rewrite as strong, quantified, action-verb-led bullet. Past tense. Under 20 words. Role: ${role}. Duty: ${rawDuty}. Return ONLY the bullet.`;

    try {
      const model = genAI.getGenerativeModel({ model: 'gemini-2.5-flash' });
      const result = await withTimeout(model.generateContent(prompt));
      return res.json({ bullet: result.response.text().trim() });
    } catch (e) {
      console.error('[improve-bullet] Gemini failed:', e.message);
    }

    if (groq) {
      try {
        const result = await withTimeout(groq.chat.completions.create({
          messages: [{ role: 'user', content: prompt }],
          model: 'llama-3.3-70b-versatile',
          max_tokens: 100,
        }));
        return res.json({ bullet: result.choices[0]?.message?.content?.trim() || rawDuty });
      } catch (groqErr) {
        console.error('[improve-bullet] Groq failed:', groqErr.message);
      }
    }

    return res.status(503).json({ error: 'AI service temporarily unavailable. Please try again.' });
  }
);

// ─── ATS Check ────────────────────────────────────────────────────────────────
app.post('/api/ai/ats-check', auth, validateAtsInput, async (req, res) => {
  const { resumeText, targetJD, sections } = req.body;

  let isPro = false;
  if (db) {
    try {
      const userDoc = await db.collection('users').doc(req.user.uid).get();
      isPro = userDoc.data()?.plan === 'pro';
    } catch (e) {
      console.error('[ats-check] Firestore user lookup failed:', e.message);
    }
  }

  const allowed = await rateLimit(req.user.uid, isPro, 3);
  if (!allowed)
    return res.status(429).json({ error: 'Daily ATS check limit reached. Upgrade to Pro for unlimited checks.' });

  const cacheKey = getCacheKey(resumeText, targetJD);
  const cached = cacheGet(cacheKey);
  if (cached) {
    console.log('✅ ATS cache hit.');
    return res.json({ ...cached, _cached: true });
  }

  if (!process.env.GEMINI_API_KEY) {
    return res.json({
      total_score: 72,
      categories: {
        keyword_match: { score: 14, reasoning: 'Mock: good keyword presence.' },
        impact_language: { score: 15, reasoning: 'Mock: some action verbs present.' },
        structure: { score: 16, reasoning: 'Mock: clear sections.' },
        relevance: { score: 14, reasoning: 'Mock: mostly relevant.' },
        ats_compatibility: { score: 13, reasoning: 'Mock: no tables or images detected.' }
      },
      critical_issues: [{ issue: 'Missing quantified achievements', fix: 'Add metrics (%, $, #)', priority: 'high' }],
      matched_keywords: ['Flutter', 'Dart'],
      missing_keywords: ['Firebase', 'REST API'],
      top_3_wins: ['Clear structure', 'Relevant skills', 'Good contact info'],
      top_3_improvements: ['Add metrics', 'Stronger action verbs', 'Include missing keywords']
    });
  }

  const resumeBody = sections ? formatStructuredResume(sections) : resumeText;
  const jdSection = targetJD ? `\n\n=== TARGET JOB DESCRIPTION ===\n${targetJD}` : '';
  const prompt = `${SCORING_RUBRIC}\n\n=== RESUME TO SCORE ===\n${resumeBody}${jdSection}`;

  let aiResult;

  try {
    const model = genAI.getGenerativeModel({ model: 'gemini-2.5-flash' });
    const result = await withTimeout(model.generateContent(prompt));
    aiResult = { text: result.response.text(), engine: 'gemini' };
  } catch (e) {
    console.error('[ats-check] Gemini failed:', e.message);
    if (!groq)
      return res.status(503).json({ error: 'AI service temporarily unavailable. Please try again.' });
    try {
      console.log('[ats-check] Falling back to Groq...');
      const result = await withTimeout(groq.chat.completions.create({
        messages: [
          { role: 'system', content: 'You are an ATS expert. Return ONLY valid JSON, no markdown.' },
          { role: 'user', content: prompt }
        ],
        model: 'llama-3.3-70b-versatile',
        max_tokens: 2048,
      }));
      aiResult = { text: result.choices[0]?.message?.content || '', engine: 'llama3' };
    } catch (groqErr) {
      console.error('[ats-check] Groq fallback failed:', groqErr.message);
      return res.status(503).json({ error: 'All AI engines failed. Please try again shortly.' });
    }
  }

  let parsed;
  try {
    parsed = safeParseAtsResponse(aiResult.text);
  } catch (parseErr) {
    console.error('[ats-check] JSON parse failed:', parseErr.message, '\nRaw:', aiResult.text.slice(0, 300));
    return res.status(500).json({ error: 'AI returned malformed data. Please retry.' });
  }

  const response = { ...parsed, _engine: aiResult.engine };
  cacheSet(cacheKey, response);
  return res.json(response);
});

// ─── Generate Summary ─────────────────────────────────────────────────────────
app.post('/api/ai/summary', auth,
  validateAiInput([
    { key: 'name', required: true, maxLen: 200 },
    { key: 'targetRole', required: true, maxLen: 200 },
  ]),
  async (req, res) => {
    const { name, targetRole, experiences = [], skills = [] } = req.body;

    if (!process.env.GEMINI_API_KEY)
      return res.json({ summary: 'Mock summary for testing.' });

    const prompt = `Write a 3-4 sentence professional resume summary for ${name} targeting role ${targetRole}. Experience: ${experiences.slice(0, 5).join(', ')}. Skills: ${skills.slice(0, 15).join(', ')}. No "I". Professional tone. Return ONLY the summary.`;

    try {
      const model = genAI.getGenerativeModel({ model: 'gemini-2.5-flash' });
      const result = await withTimeout(model.generateContent(prompt));
      return res.json({ summary: result.response.text().trim() });
    } catch (e) {
      console.error('[summary] Gemini failed:', e.message);
    }

    if (groq) {
      try {
        const result = await withTimeout(groq.chat.completions.create({
          messages: [{ role: 'user', content: prompt }],
          model: 'llama-3.3-70b-versatile',
          max_tokens: 300,
        }));
        return res.json({ summary: result.choices[0]?.message?.content?.trim() || 'Generated fallback summary.' });
      } catch (groqErr) {
        console.error('[summary] Groq failed:', groqErr.message);
      }
    }

    return res.status(503).json({ error: 'AI service temporarily unavailable. Please try again.' });
  }
);

// ─── Match JD ─────────────────────────────────────────────────────────────────
app.post('/api/ai/match-jd', auth,
  validateAiInput([
    { key: 'resumeText', required: true, maxLen: 12000, minLen: 50 },
    { key: 'jd', required: true, maxLen: 8000, minLen: 20 },
  ]),
  async (req, res) => {
    const { resumeText, jd } = req.body;

    if (!process.env.GEMINI_API_KEY)
      return res.json({ required_keywords: [], matched: [], missing: [], match_percentage: 50 });

    const prompt = `Extract top 15 keywords from JD, check which are in resume. Return ONLY valid JSON: {"required_keywords":[],"matched":[],"missing":[],"match_percentage":0} JD: ${jd} Resume: ${resumeText}`;

    try {
      const model = genAI.getGenerativeModel({ model: 'gemini-2.5-flash' });
      const result = await withTimeout(model.generateContent(prompt));
      const parsed = safeParseJson(result.response.text());
      return res.json(parsed);
    } catch (e) {
      console.error('[match-jd] Gemini failed:', e.message);
    }

    if (groq) {
      try {
        const result = await withTimeout(groq.chat.completions.create({
          messages: [
            { role: 'system', content: 'Return ONLY valid JSON, no markdown.' },
            { role: 'user', content: prompt }
          ],
          model: 'llama-3.3-70b-versatile',
          max_tokens: 1024,
        }));
        const parsed = safeParseJson(result.choices[0]?.message?.content || '');
        return res.json(parsed);
      } catch (groqErr) {
        console.error('[match-jd] Groq failed:', groqErr.message);
      }
    }

    return res.status(503).json({ error: 'AI service temporarily unavailable. Please try again.' });
  }
);

// ─── Cover Letter ─────────────────────────────────────────────────────────────
function extractLetterText(rawText) {
  const cleaned = rawText.replace(/```[\w]*\n?/g, '').replace(/```/g, '').trim();
  if (cleaned.length < 200)
    throw new Error('Response too short to be a valid cover letter.');
  return cleaned;
}

function buildCoverLetterPrompt(name, company, resumeText, jd) {
  const jdSection = jd?.trim()
    ? `\n\nTARGET JOB DESCRIPTION:\n${jd.trim()}`
    : '\n\n(No job description provided — write a compelling general application.)';
  return `You are an expert cover letter writer. Write a professional, highly detailed, and compelling cover letter.

CRITICAL RULES:
- MUST be exactly 3 well-developed paragraphs.
- Length MUST be between 250 and 350 words. Fewer than 200 words is a failure.
- Paragraph 1: Opening hook + strong interest in the role (at least 3 sentences).
- Paragraph 2: Highlight 2-3 specific, quantified achievements from the resume (at least 4 sentences).
- Paragraph 3: Closing with a clear call to action (at least 3 sentences).
- Do NOT use phrases like "I am writing to express my interest" or "Please find attached".
- Flowing prose only — no bullet points.
- Start directly with "Dear Hiring Team,".
- End directly with "Sincerely,\\n${name}".
- Output ONLY the letter text. No explanations or markdown.

CANDIDATE NAME: ${name}
TARGET COMPANY: ${company}

CANDIDATE RESUME:
${resumeText}${jdSection}`;
}

app.post('/api/ai/cover-letter', auth, validateCoverLetterInput, async (req, res) => {
  const { resumeText, jd, company, name } = req.body;

  if (!process.env.GEMINI_API_KEY) {
    const mock = `Dear Hiring Team,\n\nI am excited to apply for the position at ${company}. With a strong background and a proven track record of delivering high-quality results, I am confident in my ability to make an immediate and positive impact on your team. I have long admired ${company}'s commitment to innovation and excellence, and I am eager to bring my expertise to support your strategic goals.\n\nThroughout my career, I have consistently demonstrated a commitment to excellence. As highlighted in my resume, I have successfully managed complex projects, collaborated with cross-functional teams, and implemented solutions that significantly improved efficiency. My recent work involved streamlining processes that reduced turnaround times by 30% and increased overall productivity across the team. These experiences have equipped me with the technical skills and problem-solving mindset required to thrive in this role.\n\nI would welcome the opportunity to discuss how my background, skills, and enthusiasm align with the needs of ${company}. Thank you for your time and consideration. I look forward to the possibility of contributing to your continued success.\n\nSincerely,\n${name}`;
    return res.json({ letter: mock, engine: 'mock', wordCount: mock.split(/\s+/).length });
  }

  const prompt = buildCoverLetterPrompt(name.trim(), company.trim(), resumeText.trim(), jd?.trim());

  try {
    const model = genAI.getGenerativeModel({
      model: 'gemini-2.5-flash',
      generationConfig: { maxOutputTokens: 600, temperature: 0.7, topP: 0.9 },
    });
    const result = await withTimeout(model.generateContent(prompt));
    const letter = extractLetterText(result.response.text());
    return res.json({ letter, engine: 'gemini', wordCount: letter.split(/\s+/).length });
  } catch (geminiErr) {
    console.error('[cover-letter] Gemini failed:', geminiErr.message);
  }

  if (!groq)
    return res.status(503).json({ error: 'AI service temporarily unavailable. Please try again.' });

  try {
    const result = await withTimeout(groq.chat.completions.create({
      model: 'llama-3.3-70b-versatile',
      max_tokens: 600,
      temperature: 0.7,
      messages: [
        { role: 'system', content: 'You are an expert cover letter writer. Output ONLY the letter text — no preamble, no markdown.' },
        { role: 'user', content: prompt },
      ],
    }));
    const letter = extractLetterText(result.choices[0]?.message?.content || '');
    return res.json({ letter, engine: 'groq', wordCount: letter.split(/\s+/).length });
  } catch (groqErr) {
    console.error('[cover-letter] Groq failed:', groqErr.message);
    return res.status(503).json({ error: 'Both AI engines are temporarily unavailable. Please try again shortly.' });
  }
});

// ─── Tailor Resume to JD ──────────────────────────────────────────────────────
app.post('/api/ai/tailor-resume', auth,
  validateAiInput([
    { key: 'jd', required: true, maxLen: 8000, minLen: 20 },
  ]),
  async (req, res) => {
    const { resume, jd } = req.body;
    if (!resume) return res.status(400).json({ error: 'Missing resume object.' });

    const resumeJson = JSON.stringify(resume.sections || {});
    if (resumeJson.length > 20000)
      return res.status(400).json({ error: 'Resume data too large.' });

    if (!process.env.GEMINI_API_KEY) {
      return res.json({
        summary: 'Mock tailored summary matching the job description.',
        experience: resume.sections?.experience || [],
        skills: resume.sections?.skills || [],
        targetRole: 'Mock Role'
      });
    }

    const prompt = `You are an expert resume coach. A user wants to tailor their resume to match a specific job description.

Here is their current resume data in JSON:
${resumeJson}

Here is the Job Description they are targeting:
${jd}

Your task:
1. Extract the target job title from the JD and return it as "targetRole".
2. Rewrite the "summary" field to be tightly tailored to this JD. Keep it 3-4 sentences. Professional. No "I". Highlight matching skills. Do NOT invent experience they don't have.
3. For each experience entry, improve the "description" field to emphasize responsibilities and achievements that align with the JD keywords. Keep all facts, only reframe them. Quantify where possible.
4. Add any missing critical skills from the JD to the skills list (only genuinely applicable ones).

Return ONLY valid JSON in this exact format, no markdown:
{
  "targetRole": "string",
  "summary": "string",
  "experience": [array of experience objects same shape as input, with improved description fields],
  "skills": [array of skill strings]
}`;

    try {
      const model = genAI.getGenerativeModel({ model: 'gemini-2.5-flash' });
      const result = await withTimeout(model.generateContent(prompt), 45000);
      const parsed = safeParseJson(result.response.text());
      return res.json(parsed);
    } catch (e) {
      console.error('[tailor-resume] Gemini failed:', e.message);
    }

    if (groq) {
      try {
        const result = await withTimeout(groq.chat.completions.create({
          messages: [
            { role: 'system', content: 'You are an expert resume coach. Return ONLY valid JSON, no markdown, no explanation.' },
            { role: 'user', content: prompt }
          ],
          model: 'llama-3.3-70b-versatile',
          max_tokens: 4096,
        }), 45000);
        const parsed = safeParseJson(result.choices[0]?.message?.content || '');
        return res.json(parsed);
      } catch (groqErr) {
        console.error('[tailor-resume] Groq failed:', groqErr.message);
      }
    }

    return res.status(503).json({ error: 'AI service temporarily unavailable. Please try again.' });
  }
);

// ─── LinkedIn ZIP Import ──────────────────────────────────────────────────────
app.post('/api/linkedin/import-zip', auth, upload.single('file'), (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ error: 'No file uploaded.' });

    const zip = new AdmZip(req.file.buffer);

    const readCSV = (filename) => {
      const entry = zip.getEntry(filename);
      if (!entry) return [];
      try {
        return parse(entry.getData().toString('utf8'), {
          columns: true,
          skip_empty_lines: true,
          trim: true,
          relax_quotes: true
        });
      } catch { return []; }
    };

    const profile = readCSV('Profile.csv')[0] || {};
    const positions = readCSV('Positions.csv');
    const education = readCSV('Education.csv');
    const skills = readCSV('Skills.csv');

    if (!profile['First Name'] && positions.length === 0) {
      return res.status(422).json({
        error: 'Could not parse LinkedIn export. Make sure you uploaded the correct ZIP file.'
      });
    }

    const resume = {
      name: [profile['First Name'], profile['Last Name']].filter(Boolean).join(' '),
      email: profile['Email Address'] || '',
      phone: profile['Phone Numbers'] || '',
      summary: profile['Summary'] || '',
      headline: profile['Headline'] || '',
      location: profile['Geo Location'] || '',
      experience: positions.map(p => ({
        title: p['Title'] || '',
        company: p['Company Name'] || '',
        dates: [p['Started On'], p['Finished On'] || 'Present'].filter(Boolean).join(' - '),
        location: p['Location'] || '',
        description: p['Description'] || ''
      })).filter(e => e.title || e.company),
      education: education.map(e => ({
        degree: [e['Degree Name'], e['Field Of Study']].filter(Boolean).join(' in '),
        institution: e['School Name'] || '',
        year: e['End Date'] || e['Start Date'] || '',
      })).filter(e => e.institution),
      skills: skills.map(s => s['Name']).filter(Boolean).slice(0, 50)
    };

    res.json({ success: true, resume, source: 'linkedin_zip' });

  } catch (err) {
    console.error('[linkedin-zip] Error:', err);
    res.status(500).json({ error: 'Failed to parse LinkedIn export file.' });
  }
});

// ─── LinkedIn OAuth: Get Auth URL ─────────────────────────────────────────────
app.get('/api/linkedin/auth-url', auth, (req, res) => {
  if (!LINKEDIN.clientId)
    return res.status(503).json({ error: 'LinkedIn OAuth is not configured on this server.' });

  const state = crypto.randomBytes(16).toString('hex');
  linkedinStateStore.set(state, { uid: req.user.uid, ts: Date.now() });

  const url = new URL('https://www.linkedin.com/oauth/v2/authorization');
  url.searchParams.set('response_type', 'code');
  url.searchParams.set('client_id', LINKEDIN.clientId);
  url.searchParams.set('redirect_uri', LINKEDIN.redirectUri);
  url.searchParams.set('scope', LINKEDIN.scope);
  url.searchParams.set('state', state);

  res.json({ url: url.toString() });
});

// ─── LinkedIn OAuth: Callback ─────────────────────────────────────────────────
app.get('/api/linkedin/callback', async (req, res) => {
  const { code, state, error } = req.query;

  if (error)
    return res.redirect(`atsresumebuilder://linkedin-callback?error=${encodeURIComponent(error)}`);

  if (!state || !linkedinStateStore.has(state))
    return res.redirect('atsresumebuilder://linkedin-callback?error=invalid_state');

  linkedinStateStore.delete(state);

  try {
    const tokenRes = await axios.post(
      'https://www.linkedin.com/oauth/v2/accessToken',
      new URLSearchParams({
        grant_type: 'authorization_code',
        code,
        redirect_uri: LINKEDIN.redirectUri,
        client_id: LINKEDIN.clientId,
        client_secret: LINKEDIN.clientSecret,
      }),
      { headers: { 'Content-Type': 'application/x-www-form-urlencoded' } }
    );

    const accessToken = tokenRes.data.access_token;

    const profileRes = await axios.get(
      'https://api.linkedin.com/v2/userinfo',
      { headers: { Authorization: `Bearer ${accessToken}` } }
    );

    const p = profileRes.data;
    const resume = {
      name: p.name || `${p.given_name || ''} ${p.family_name || ''}`.trim(),
      email: p.email || '',
      picture: p.picture || '',
      experience: [],
      education: [],
      skills: [],
    };

    const encoded = encodeURIComponent(JSON.stringify(resume));
    res.redirect(`atsresumebuilder://linkedin-callback?resume=${encoded}`);

  } catch (err) {
    console.error('[linkedin-oauth] Error:', err.response?.data || err.message);
    res.redirect('atsresumebuilder://linkedin-callback?error=server_error');
  }
});

// ─── Share Link Generator ──────────────────────────────────────────────────────
app.post('/api/share-link', auth, async (req, res) => {
  const { resumeId } = req.body;
  if (!resumeId) return res.status(400).json({ error: 'resumeId is required.' });

  const token = crypto.randomBytes(16).toString('hex');
  const expiry = new Date(Date.now() + 30 * 86400000);

  if (db) {
    try {
      await db.collection('share_links').doc(token).set({
        uid: req.user.uid,
        resumeId,
        expiry: admin.firestore.Timestamp.fromDate(expiry)
      });
    } catch (e) {
      console.error('[share-link] Firestore write failed:', e.message);
      return res.status(500).json({ error: 'Could not create share link. Please try again.' });
    }
  }

  res.json({
    link: `${process.env.BACKEND_URL || 'http://localhost:10000'}/r/${token}`,
    expiry
  });
});

// ═══════════════════════════════════════════════════════════════════════════════
// GLOBAL ERROR HANDLERS
// ═══════════════════════════════════════════════════════════════════════════════

// Global Express error handler — catches anything that slips through
app.use((err, req, res, next) => {
  console.error('[Global Express Error]', err.message);
  if (res.headersSent) return next(err);
  res.status(500).json({ error: 'An unexpected error occurred. Please try again.' });
});

// Process-level guards — prevent full crashes on unhandled rejections
process.on('unhandledRejection', (reason) => {
  console.error('[UnhandledRejection]', reason);
});

process.on('uncaughtException', (err) => {
  console.error('[UncaughtException]', err.message);
  setTimeout(() => process.exit(1), 1000);
});

// ─── Start Server ─────────────────────────────────────────────────────────────
app.listen(port, () => {
  console.log(`🌐 Server running on port ${port}`);
});