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
const helmet = require('helmet');
const { Document, Packer, Paragraph, TextRun, HeadingLevel } = require('docx');

const app = express();
const isProduction = process.env.NODE_ENV === 'production';
const allowedOrigins = process.env.ALLOWED_ORIGINS
  ?.split(',')
  .map((origin) => origin.trim())
  .filter(Boolean);
app.use(helmet());
app.use(cors({ origin: allowedOrigins?.length ? allowedOrigins : '*' }));
app.use(express.json({ limit: '5mb' }));
const port = process.env.PORT || 10000;

// ─── 1. Firebase Initialization ───────────────────────────────────────────────
try {
  let serviceAccount;
  if (fs.existsSync('/etc/secrets/firebase-service-account.json')) {
    console.log('✅ Found Firebase key in Render secrets!');
    serviceAccount = require('/etc/secrets/firebase-service-account.json');
  } else if (fs.existsSync('./firebase-service-account.json')) {
    console.log('✅ Found Firebase key locally!');
    serviceAccount = require('./firebase-service-account.json');
  } else if (process.env.FIREBASE_SERVICE_ACCOUNT) {
    console.log('✅ Found Firebase key in Environment Variable!');
    serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
  } else {
    throw new Error('Could NOT find the Firebase JSON file anywhere!');
  }
  admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
  console.log('🚀 Firebase initialized successfully!');
} catch (error) {
  console.error('🔥 Firebase Setup FAILED:', error.message);
}

const db = admin.apps.length ? admin.firestore() : null;
const genAI = process.env.GEMINI_API_KEY
  ? new GoogleGenerativeAI(process.env.GEMINI_API_KEY)
  : null;
const groq = process.env.GROQ_API_KEY
  ? new Groq({ apiKey: process.env.GROQ_API_KEY })
  : null;
const hasAiProvider = Boolean(genAI || groq);
const atsRateLimitDisabled = process.env.DISABLE_ATS_RATE_LIMIT === 'true';
const atsFreeDailyLimit = Math.max(
  1,
  Number.parseInt(process.env.ATS_FREE_DAILY_LIMIT || '3', 10) || 3
);

function rejectMissingAI(res) {
  return res.status(503).json({ error: 'AI service is not configured on this server.' });
}

// ─── 2. In-Memory LRU Cache ────────────────────────────────────────────────────
const ATS_CACHE = new Map();
const ATS_CACHE_MAX = 200;
const ATS_CACHE_TTL_MS = 30 * 60 * 1000;

function getCacheKey(resumeText, targetJD) {
  return crypto
    .createHash('sha256')
    .update(resumeText + (targetJD || ''))
    .digest('hex');
}

function cacheGet(key) {
  const entry = ATS_CACHE.get(key);
  if (!entry) return null;
  if (Date.now() - entry.ts > ATS_CACHE_TTL_MS) {
    ATS_CACHE.delete(key);
    return null;
  }
  return entry.data;
}

function cacheSet(key, data) {
  if (ATS_CACHE.size >= ATS_CACHE_MAX) {
    ATS_CACHE.delete(ATS_CACHE.keys().next().value);
  }
  ATS_CACHE.set(key, { data, ts: Date.now() });
}

// ─── 3. ATS Scoring Rubric ────────────────────────────────────────────────────
// FIX: date system note moved here into the rubric preamble, NOT injected into
// resume text where the model treats it as candidate content.
const SCORING_RUBRIC = `
You are a strict ATS and recruiter-quality reviewer. Score only from evidence in the resume and optional job description.
Today's date is ${new Date().toISOString().split('T')[0]}. Do NOT flag any dates before today as future dates. Graduation years, job start dates, and certification dates in the past are valid.

Rules:
- Do not reward vague, unsupported, or unrelated claims.
- Do not invent missing keywords, achievements, employers, degrees, dates, metrics, tools, or certifications.
- If a target job description is provided, weigh must-have responsibilities and tools above generic keywords.
- Keep category reasoning concise and evidence-based. Mention exact evidence or the exact gap.
- Scores must be integers. Each category is 0-20 and total_score must equal the sum of the five categories.

Categories:
1. KEYWORD_MATCH: role-specific tools, technologies, certifications, domain terms, and must-have requirements.
2. IMPACT_LANGUAGE: action verbs, ownership, scope, outcomes, and quantified impact already present in the resume.
3. STRUCTURE: clear sections, consistent bullet style, readable order, no clutter.
4. RELEVANCE: alignment of experience, skills, projects, and education to the target role.
5. ATS_COMPATIBILITY: plain text, standard headings, minimal graphics/tables, parseable contact info.

Return ONLY this exact JSON schema, no markdown:
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
  "top_3_improvements":  [],
  "evidence":            ["short resume evidence used for scoring"]
}`;

// ─── 4. Shared Validation Middleware ──────────────────────────────────────────
const validateAiInput = (fields) => (req, res, next) => {
  const injectionRe =
    /ignore (previous|all) instructions|system prompt|forget everything/i;
  for (const { key, required, maxLen, minLen } of fields) {
    const val = req.body[key];
    if (
      required &&
      (!val || typeof val !== 'string' || val.trim().length < (minLen || 1))
    )
      return res.status(400).json({ error: `'${key}' is required.` });
    if (val && typeof val === 'string') {
      if (maxLen && val.length > maxLen)
        return res
          .status(400)
          .json({ error: `'${key}' is too long (max ${maxLen} chars).` });
      if (injectionRe.test(val))
        return res.status(400).json({ error: 'Invalid content detected.' });
    }
  }
  next();
};

const validateAtsInput = (req, res, next) => {
  const { resumeText, targetJD } = req.body;
  if (!resumeText || typeof resumeText !== 'string')
    return res
      .status(400)
      .json({ error: 'resumeText is required and must be a string.' });
  if (resumeText.length > 15000)
    return res
      .status(400)
      .json({ error: 'Resume text exceeds maximum length (15,000 chars).' });
  if (targetJD && typeof targetJD !== 'string')
    return res.status(400).json({ error: 'targetJD must be a string.' });
  if (targetJD && targetJD.length > 10000)
    return res
      .status(400)
      .json({ error: 'Job description exceeds maximum length (10,000 chars).' });
  const injectionPatterns = /ignore previous|system prompt|forget instructions/i;
  if (
    injectionPatterns.test(resumeText) ||
    (targetJD && injectionPatterns.test(targetJD))
  )
    return res.status(400).json({ error: 'Invalid content detected.' });
  next();
};

const validateCoverLetterInput = (req, res, next) => {
  const { resumeText, jd, company, name } = req.body;
  if (
    !resumeText ||
    typeof resumeText !== 'string' ||
    resumeText.trim().length < 50
  )
    return res
      .status(400)
      .json({ error: 'Resume text is required (min 50 chars).' });
  if (!company || typeof company !== 'string' || company.trim().length < 2)
    return res.status(400).json({ error: 'Company name is required.' });
  if (!name || typeof name !== 'string' || name.trim().length < 2)
    return res.status(400).json({ error: 'Applicant name is required.' });
  if (resumeText.length > 12000)
    return res
      .status(400)
      .json({ error: 'Resume text too long (max 12,000 chars).' });
  if (jd && jd.length > 8000)
    return res
      .status(400)
      .json({ error: 'Job description too long (max 8,000 chars).' });
  if (company.length > 200)
    return res.status(400).json({ error: 'Company name too long.' });
  const injectionRe =
    /ignore (previous|all) instructions|system prompt|forget everything/i;
  if (injectionRe.test(resumeText) || injectionRe.test(jd || ''))
    return res.status(400).json({ error: 'Invalid content detected.' });
  next();
};

// ─── 5. Shared Safe JSON Parser ───────────────────────────────────────────────
// FIX: use greedy regex match instead of brittle string slicing.
// Handles trailing explanations and leftover markdown that the old approach missed.
function safeParseJson(rawText) {
  const stripped = rawText.replace(/```json|```/g, '').trim();
  // Grab the outermost { } or [ ] block — handles trailing prose after the JSON
  const match = stripped.match(/(\{[\s\S]*\}|\[[\s\S]*\])/);
  if (!match) throw new Error('No JSON object found in AI response.');
  return JSON.parse(match[1]);
}

function safeParseAtsResponse(rawText) {
  const parsed = safeParseJson(rawText);
  if (!parsed.categories) throw new Error('Missing categories in ATS response.');
  return normalizeAtsResponse(parsed);
}

function toText(value, fallback = '') {
  if (value === null || value === undefined) return fallback;
  if (typeof value === 'string') return value.trim();
  if (typeof value === 'number' || typeof value === 'boolean')
    return String(value);
  return fallback;
}

function toArray(value, limit = 20) {
  if (!Array.isArray(value)) return [];
  return value
    .map((item) => (typeof item === 'string' ? item.trim() : toText(item)))
    .filter(Boolean)
    .slice(0, limit);
}

function boundedInt(value, min = 0, max = 100) {
  const n = Number(value);
  if (!Number.isFinite(n)) return min;
  return Math.max(min, Math.min(max, Math.round(n)));
}

function normalizeCategory(raw) {
  return {
    score: boundedInt(raw?.score, 0, 20),
    reasoning: toText(raw?.reasoning).slice(0, 600),
  };
}

function normalizeAtsResponse(raw) {
  const categories = {
    keyword_match: normalizeCategory(raw.categories?.keyword_match),
    impact_language: normalizeCategory(raw.categories?.impact_language),
    structure: normalizeCategory(raw.categories?.structure),
    relevance: normalizeCategory(raw.categories?.relevance),
    ats_compatibility: normalizeCategory(raw.categories?.ats_compatibility),
  };
  const total = Object.values(categories).reduce((sum, c) => sum + c.score, 0);
  return {
    total_score: total,
    categories,
    critical_issues: (
      Array.isArray(raw.critical_issues) ? raw.critical_issues : []
    )
      .map((item) => ({
        issue: toText(item?.issue).slice(0, 220),
        fix: toText(item?.fix).slice(0, 260),
        priority: ['high', 'medium', 'low'].includes(item?.priority)
          ? item.priority
          : 'medium',
      }))
      .filter((item) => item.issue && item.fix)
      .slice(0, 5),
    matched_keywords: toArray(raw.matched_keywords || raw.keywords, 30),
    missing_keywords: toArray(raw.missing_keywords, 30),
    top_3_wins: toArray(raw.top_3_wins, 3),
    top_3_improvements: toArray(raw.top_3_improvements, 3),
    evidence: toArray(raw.evidence, 5),
  };
}

// FIX: soft_skills excluded from match_percentage calculation.
// They are returned separately but do not inflate the score.
function normalizeKeywordMatch(raw) {
  const required = toArray(raw.required_keywords, 25);
  const matched = toArray(raw.matched, 25);
  const missing = toArray(raw.missing, 25);
  const softSkills = toArray(raw.soft_skills, 10);

  // Recalculate percentage using only hard/technical keywords (required list),
  // excluding soft skills so "communication" doesn't pad the score.
  const hardRequired = required.filter(
    (k) => !softSkills.map((s) => s.toLowerCase()).includes(k.toLowerCase())
  );
  const hardMatched = matched.filter(
    (k) => !softSkills.map((s) => s.toLowerCase()).includes(k.toLowerCase())
  );
  const total = hardRequired.length || hardMatched.length + missing.length;
  const recalcPct = total ? Math.round((hardMatched.length / total) * 100) : 0;

  return {
    required_keywords: required,
    matched,
    missing,
    // Use recalculated hard-skills-only percentage; fall back to AI value if
    // the recalc produces 0 and the AI gave a non-zero value (edge case:
    // AI didn't split soft skills correctly).
    match_percentage:
      recalcPct > 0
        ? recalcPct
        : boundedInt(raw.match_percentage ?? recalcPct, 0, 100),
    must_have: toArray(raw.must_have, 15),
    preferred: toArray(raw.preferred, 15),
    tools: toArray(raw.tools, 15),
    responsibilities: toArray(raw.responsibilities, 15),
    soft_skills: softSkills,
    evidence: toArray(raw.evidence, 8),
  };
}

function normalizeTailoredResume(raw, originalSections) {
  const originalExperience = Array.isArray(originalSections.experience)
    ? originalSections.experience
    : [];
  const proposedExperience = Array.isArray(raw.experience) ? raw.experience : [];

  const experience = originalExperience.map((oldItem, index) => {
    const proposed =
      proposedExperience[index] &&
      typeof proposedExperience[index] === 'object'
        ? proposedExperience[index]
        : {};
    return {
      ...oldItem,
      // Only overwrite description — all metadata (title, company, dates,
      // location) is always taken from the original.
      description: toText(
        proposed.description || oldItem.description
      ).slice(0, 1800),
    };
  });

  const originalSkills = Array.isArray(originalSections.skills)
    ? originalSections.skills
    : [];
  const rawSkills = toArray(raw.skills, 80);
  const rawSkillKeys = rawSkills.map((skill) => skill.toLowerCase());
  const skills = [
    ...rawSkills,
    ...originalSkills
      .map((skill) => toText(skill))
      .filter(
        (skill) => skill && !rawSkillKeys.includes(skill.toLowerCase())
      ),
  ].slice(0, 80);

  const originalProjects = Array.isArray(originalSections.projects)
    ? originalSections.projects
    : [];
  const proposedProjects = Array.isArray(raw.projects) ? raw.projects : [];
  const projects = originalProjects.map((oldItem, index) => {
    const proposed =
      proposedProjects[index] && typeof proposedProjects[index] === 'object'
        ? proposedProjects[index]
        : {};
    return {
      ...oldItem,
      description: toText(
        proposed.description || oldItem.description
      ).slice(0, 1200),
    };
  });

  const originalEducation = Array.isArray(originalSections.education)
    ? originalSections.education
    : [];
  const proposedEducation = Array.isArray(raw.education) ? raw.education : [];
  const education = originalEducation.map((oldItem, index) => {
    const proposed =
      proposedEducation[index] && typeof proposedEducation[index] === 'object'
        ? proposedEducation[index]
        : {};
    return {
      ...oldItem,
      highlights: toText(
        proposed.highlights || oldItem.highlights || ''
      ).slice(0, 300),
    };
  });

  const originalCertifications = Array.isArray(originalSections.certifications)
    ? originalSections.certifications
    : [];
  const proposedCertifications = Array.isArray(raw.certifications)
    ? raw.certifications
    : [];
  let certifications = originalCertifications;
  if (proposedCertifications.length > 0) {
    const aiOrder = proposedCertifications
      .map((cert) =>
        toText(cert?.name || cert?.certification_name || '').toLowerCase()
      )
      .filter(Boolean);
    certifications = [...originalCertifications].sort((a, b) => {
      const ai = aiOrder.indexOf(toText(a.name).toLowerCase());
      const bi = aiOrder.indexOf(toText(b.name).toLowerCase());
      if (ai === -1 && bi === -1) return 0;
      if (ai === -1) return 1;
      if (bi === -1) return -1;
      return ai - bi;
    });
  }

  const originalSummary = toText(originalSections.personal?.summary);
  return {
    targetRole: toText(raw.targetRole).slice(0, 160),
    summary: toText(raw.summary, originalSummary).slice(0, 1200),
    experience,
    skills,
    projects,
    education,
    certifications,
    warnings: toArray(raw.warnings, 5),
    changes: Array.isArray(raw.changes)
      ? raw.changes
          .map((item) => ({
            section: toText(item?.section).slice(0, 80),
            before: toText(item?.before).slice(0, 500),
            after: toText(item?.after).slice(0, 500),
            reason: toText(item?.reason).slice(0, 300),
          }))
          .filter((item) => item.section && (item.after || item.reason))
          .slice(0, 30)
      : [],
  };
}

// FIX: return clean text instead of raw duty when hallucinated number is stripped.
function sanitizeBulletOutput(rawDuty, bullet) {
  const clean = toText(bullet)
    .replace(/^[-*]\s*/, '')
    .replace(/^"|"$/g, '')
    .trim();
  if (!clean) return rawDuty.trim();

  const sourceHasNumber = /\d/.test(rawDuty);
  const outputHasNumber = /\d/.test(clean);

  if (!sourceHasNumber && outputHasNumber) {
    // Strip the hallucinated number rather than discarding the whole improvement
    const stripped = clean.replace(/\b\d[\d,%.+\-x]*\b\s*/g, '').trim();
    console.warn('[improve-bullet] Stripped hallucinated number from output.');
    return stripped || rawDuty.trim();
  }

  return clean.split(/\r?\n/).find(Boolean)?.trim() || rawDuty.trim();
}

// ─── 6. Structured Resume Formatter ──────────────────────────────────────────
function formatStructuredResume(sections) {
  const p = sections.personal || {};
  const exp = (sections.experience || [])
    .map(
      (e) =>
        `[${e.title || ''}] at [${e.company || ''}] (${e.dates || ''})\n${e.description || ''}`
    )
    .join('\n\n');
  const edu = (sections.education || [])
    .map((e) => `${e.degree || ''} — ${e.institution || ''} (${e.year || ''})`)
    .join('\n');
  const skills = Array.isArray(sections.skills)
    ? sections.skills
        .map((s) => (typeof s === 'string' ? s : JSON.stringify(s)))
        .join(', ')
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
      setTimeout(
        () => reject(new Error(`AI call timed out after ${ms}ms`)),
        ms
      )
    ),
  ]);
}

// ─── 8. Auth Middleware ───────────────────────────────────────────────────────
const auth = async (req, res, next) => {
  if (!admin.apps.length) {
    return res
      .status(503)
      .json({ error: 'Authentication service is not configured.' });
  }
  const token = req.headers.authorization?.split('Bearer ')[1];
  if (!token) return res.status(401).json({ error: 'No token provided.' });
  try {
    req.user = await admin.auth().verifyIdToken(token);
    next();
  } catch (error) {
    console.error('Auth Error:', error.code);
    return res
      .status(401)
      .json({ error: 'Invalid or expired token. Please sign in again.' });
  }
};

// ─── 9. Rate Limiter ─────────────────────────────────────────────────────────
const rateLimit = async (uid, isPro, limit = 3) => {
  if (atsRateLimitDisabled) return true;
  if (isPro) return true;
  if (!db) return true;
  const today = new Date().toISOString().split('T')[0];
  const ref = db.collection('rate_limits').doc(`${uid}_${today}`);
  return db.runTransaction(async (t) => {
    const doc = await t.get(ref);
    const count = doc.data()?.count || 0;
    if (count >= limit) return false;
    t.set(ref, { count: count + 1 }, { merge: true });
    return true;
  });
};

// ─── 10. LinkedIn State Store ─────────────────────────────────────────────────
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
  redirectUri:
    process.env.LINKEDIN_REDIRECT_URI ||
    'https://ats-resume-server.onrender.com/api/linkedin/callback',
  scope: 'openid profile email',
};

// ─── Multer ───────────────────────────────────────────────────────────────────
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    if (
      file.mimetype === 'application/zip' ||
      file.mimetype === 'application/x-zip-compressed' ||
      file.originalname.endsWith('.zip')
    )
      cb(null, true);
    else cb(new Error('Only ZIP files allowed'), false);
  },
});

// ─── Cover letter rate-limit (Firestore-backed, survives restarts) ───────────
const COVER_LETTER_FREE_LIMIT = Math.max(
  1,
  Number.parseInt(process.env.COVER_LETTER_FREE_DAILY_LIMIT || '5', 10)
);

async function checkCoverLetterLimit(uid) {
  if (atsRateLimitDisabled) return true;

  // Check pro status from Firestore if available
  if (db) {
    try {
      const userDoc = await db.collection('users').doc(uid).get();
      if (userDoc.data()?.plan === 'pro') return true;
    } catch (_) {}
  }

  // Firestore-backed daily counter — survives server restarts
  if (db) {
    const today = new Date().toISOString().split('T')[0];
    const ref = db.collection('cover_limits').doc(`${uid}_${today}`);
    return db.runTransaction(async (t) => {
      const doc = await t.get(ref);
      const count = doc.data()?.count || 0;
      if (count >= COVER_LETTER_FREE_LIMIT) return false;
      t.set(ref, { count: count + 1, uid, date: today }, { merge: true });
      return true;
    });
  }

  // No DB — allow (fail open, not fail closed)
  return true;
}

// ═══════════════════════════════════════════════════════════════════════════════
// ROUTES
// ═══════════════════════════════════════════════════════════════════════════════

app.get('/', (req, res) => {
  res.json({
    status: 'ok',
    firebase: Boolean(db),
    ai: { gemini: Boolean(genAI), groq: Boolean(groq) },
  });
});

// ─── Improve Bullet ───────────────────────────────────────────────────────────
app.post(
  '/api/ai/improve-bullet',
  auth,
  validateAiInput([
    { key: 'rawDuty', required: true, maxLen: 1000 },
    { key: 'role', required: true, maxLen: 200 },
  ]),
  async (req, res) => {
    const { rawDuty, role } = req.body;
    if (!hasAiProvider) return rejectMissingAI(res);

    const wordCount = rawDuty.trim().split(/\s+/).length;
    const prompt = `You are an expert resume bullet editor.

Rewrite the duty into ONE resume bullet for the role: ${role || 'target role'}.

Rules:
- Preserve the user's facts exactly. Do not invent numbers, percentages, tools, employers, dates, revenue, users, team sizes, or outcomes.
- Use a number only if it already appears in the duty.
- Start with a strong past-tense action verb.
- Keep it under ${Math.max(24, wordCount + 4)} words.
- No markdown, no quotes, no explanations.
- Output only the single improved bullet line.

USER_DUTY:
${rawDuty}`;

    try {
      if (genAI) {
        const model = genAI.getGenerativeModel({
          model: 'gemini-2.5-flash',
          generationConfig: { temperature: 0.2, topP: 0.8 },
        });
        const result = await withTimeout(model.generateContent(prompt));
        return res.json({
          bullet: sanitizeBulletOutput(rawDuty, result.response.text()),
        });
      }
    } catch (e) {
      console.error('[improve-bullet] Gemini failed:', e.message);
    }

    if (groq) {
      try {
        const result = await withTimeout(
          groq.chat.completions.create({
            messages: [{ role: 'user', content: prompt }],
            model: 'llama-3.3-70b-versatile',
            max_tokens: 120,
            temperature: 0.2,
          })
        );
        return res.json({
          bullet: sanitizeBulletOutput(
            rawDuty,
            result.choices[0]?.message?.content || rawDuty
          ),
        });
      } catch (groqErr) {
        console.error('[improve-bullet] Groq failed:', groqErr.message);
      }
    }

    return res
      .status(503)
      .json({ error: 'AI service temporarily unavailable. Please try again.' });
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

  const allowed = await rateLimit(req.user.uid, isPro, atsFreeDailyLimit);
  if (!allowed)
    return res.status(429).json({
      error:
        'Daily ATS check limit reached. Upgrade to Pro for unlimited checks.',
    });

  const cacheKey = getCacheKey(resumeText, targetJD);
  const cached = cacheGet(cacheKey);
  if (cached) {
    console.log('✅ ATS cache hit.');
    return res.json({ ...cached, _cached: true });
  }

  if (!hasAiProvider) return rejectMissingAI(res);

  // FIX: system note is now in SCORING_RUBRIC (which includes today's date),
  // not injected into resumeText where the model reads it as candidate content.
  const resumeBody = sections ? formatStructuredResume(sections) : resumeText;
  const jdSection = targetJD
    ? `\n\n=== TARGET JOB DESCRIPTION ===\n${targetJD}`
    : '';
  const prompt = `${SCORING_RUBRIC}\n\n=== RESUME TO SCORE ===\n${resumeBody}${jdSection}`;

  let aiResult;

  try {
    if (genAI) {
      const model = genAI.getGenerativeModel({
        model: 'gemini-2.5-flash',
        generationConfig: { temperature: 0.2, topP: 0.8 },
      });
      // FIX: increased timeout from 30s to 45s — ATS is the most complex prompt
      const result = await withTimeout(model.generateContent(prompt), 45000);
      aiResult = { text: result.response.text(), engine: 'gemini' };
    } else {
      throw new Error('Gemini is not configured.');
    }
  } catch (e) {
    console.error('[ats-check] Gemini failed:', e.message);
    if (!groq)
      return res
        .status(503)
        .json({ error: 'AI service temporarily unavailable. Please try again.' });
    try {
      console.log('[ats-check] Falling back to Groq...');
      const result = await withTimeout(
        groq.chat.completions.create({
          messages: [
            {
              role: 'system',
              content: 'You are an ATS expert. Return ONLY valid JSON, no markdown.',
            },
            { role: 'user', content: prompt },
          ],
          model: 'llama-3.3-70b-versatile',
          max_tokens: 2048,
        }),
        45000
      );
      aiResult = { text: result.choices[0]?.message?.content || '', engine: 'llama3' };
    } catch (groqErr) {
      console.error('[ats-check] Groq fallback failed:', groqErr.message);
      return res
        .status(503)
        .json({ error: 'All AI engines failed. Please try again shortly.' });
    }
  }

  let parsed;
  try {
    parsed = safeParseAtsResponse(aiResult.text);
  } catch (parseErr) {
    console.error(
      '[ats-check] JSON parse failed:',
      parseErr.message,
      '\nRaw:',
      aiResult.text.slice(0, 300)
    );
    return res
      .status(500)
      .json({ error: 'AI returned malformed data. Please retry.' });
  }

  const response = { ...parsed, _engine: aiResult.engine };
  cacheSet(cacheKey, response);
  return res.json(response);
});

// ─── Generate Summary ─────────────────────────────────────────────────────────
app.post(
  '/api/ai/summary',
  auth,
  validateAiInput([
    { key: 'name', required: false, maxLen: 200 },
    { key: 'targetRole', required: false, maxLen: 200 },
  ]),
  async (req, res) => {
    const { name, targetRole, experiences = [], skills = [] } = req.body;
    if (!hasAiProvider) return rejectMissingAI(res);

    const prompt = `You are an expert resume summary editor.

Write a concise professional summary using ONLY the facts provided.

Rules:
- 3 to 4 sentences, 70 to 110 words total.
- No first-person pronouns.
- Do not invent metrics, employers, tools, titles, degrees, or certifications.
- If target role is empty, infer a broad role from the experience and skills.
- Prioritize current strengths, relevant domain keywords, and evidence-backed impact.
- Output only the summary text. No markdown.

CANDIDATE_NAME:
${name || 'Candidate'}

TARGET_ROLE:
${targetRole || 'Infer from resume context'}

EXPERIENCE_SIGNALS:
${experiences.slice(0, 8).join('\n')}

SKILLS:
${skills.slice(0, 20).join(', ')}`;

    try {
      if (genAI) {
        const model = genAI.getGenerativeModel({
          model: 'gemini-2.5-flash',
          generationConfig: { temperature: 0.2, topP: 0.8 },
        });
        const result = await withTimeout(model.generateContent(prompt));
        return res.json({ summary: result.response.text().trim() });
      }
    } catch (e) {
      console.error('[summary] Gemini failed:', e.message);
    }

    if (groq) {
      try {
        const result = await withTimeout(
          groq.chat.completions.create({
            messages: [{ role: 'user', content: prompt }],
            model: 'llama-3.3-70b-versatile',
            max_tokens: 300,
          })
        );
        return res.json({
          summary:
            result.choices[0]?.message?.content?.trim() ||
            'Generated fallback summary.',
        });
      } catch (groqErr) {
        console.error('[summary] Groq failed:', groqErr.message);
      }
    }

    return res
      .status(503)
      .json({ error: 'AI service temporarily unavailable. Please try again.' });
  }
);

// ─── Match JD ─────────────────────────────────────────────────────────────────
app.post(
  '/api/ai/match-jd',
  auth,
  validateAiInput([
    { key: 'resumeText', required: true, maxLen: 12000, minLen: 50 },
    { key: 'jd', required: true, maxLen: 8000, minLen: 20 },
  ]),
  async (req, res) => {
    const { resumeText, jd } = req.body;
    if (!hasAiProvider) return rejectMissingAI(res);

    const prompt = `You are a precise job-description matching engine.

Analyze the job description and compare it with the resume text.

Rules:
- Separate hard/technical requirements (tools, technologies, certifications, domain terms, responsibilities) from soft skills (communication, teamwork, leadership) in their respective arrays.
- Match semantically equivalent skills (e.g. REST APIs and API integration) but do not over-credit unrelated words.
- Do not invent resume skills. A match must be supported by resume evidence.
- "matched" and "missing" should contain only hard/technical keywords — not soft skills. Soft skills go only in soft_skills.
- match_percentage must reflect only hard/technical keyword coverage, not soft skills. This prevents generic soft skills from inflating the score.
- Return match_percentage as an integer 0-100.

Return ONLY valid JSON with this schema:
{
  "required_keywords": [],
  "matched": [],
  "missing": [],
  "match_percentage": 0,
  "must_have": [],
  "preferred": [],
  "tools": [],
  "responsibilities": [],
  "soft_skills": [],
  "evidence": ["matched keyword -> resume evidence"]
}

JOB_DESCRIPTION:
${jd}

RESUME_TEXT:
${resumeText}`;

    try {
      if (genAI) {
        const model = genAI.getGenerativeModel({
          model: 'gemini-2.5-flash',
          generationConfig: { temperature: 0.2, topP: 0.8 },
        });
        const result = await withTimeout(model.generateContent(prompt));
        const parsed = normalizeKeywordMatch(
          safeParseJson(result.response.text())
        );
        return res.json(parsed);
      }
    } catch (e) {
      console.error('[match-jd] Gemini failed:', e.message);
    }

    if (groq) {
      try {
        const result = await withTimeout(
          groq.chat.completions.create({
            messages: [
              {
                role: 'system',
                content: 'Return ONLY valid JSON, no markdown.',
              },
              { role: 'user', content: prompt },
            ],
            model: 'llama-3.3-70b-versatile',
            max_tokens: 1400,
            temperature: 0.2,
          })
        );
        const parsed = normalizeKeywordMatch(
          safeParseJson(result.choices[0]?.message?.content || '')
        );
        return res.json(parsed);
      } catch (groqErr) {
        console.error('[match-jd] Groq failed:', groqErr.message);
      }
    }

    return res
      .status(503)
      .json({ error: 'AI service temporarily unavailable. Please try again.' });
  }
);

// ─── Cover Letter ─────────────────────────────────────────────────────────────
function extractLetterText(rawText) {
  const cleaned = rawText
    .replace(/```[\w]*\n?/g, '')
    .replace(/```/g, '')
    .trim();
  if (cleaned.length < 200)
    throw new Error('Response too short to be a valid cover letter.');
  return cleaned;
}

function buildCoverLetterPrompt(name, company, resumeText, jd) {
  const jdSection = jd?.trim()
    ? `\n\nTARGET_JOB_DESCRIPTION:\n${jd.trim()}`
    : '\n\nTARGET_JOB_DESCRIPTION:\nNot provided. Write a general but evidence-based application letter.';
  return `You are an expert cover letter writer for modern hiring teams.

Write a polished, specific cover letter using only facts from the candidate resume and job description.

Critical rules:
- Do not invent achievements, metrics, tools, employers, dates, role titles, or company knowledge.
- If no metric exists in the resume, describe impact qualitatively instead of adding a fake number.
- Exactly 3 paragraphs, 230 to 330 words.
- Paragraph 1: targeted opening tied to the company/role and candidate fit.
- Paragraph 2: 2-3 strongest evidence-backed achievements or skill clusters from the resume.
- Paragraph 3: confident closing and call to action.
- Avoid generic phrases like "I am writing to express my interest" and "Please find attached".
- Flowing prose only, no bullet points.
- Start directly with "Dear Hiring Team,".
- End directly with "Sincerely,\\n${name}".
- Output only the letter text. No markdown.

CANDIDATE_NAME:
${name}

TARGET_COMPANY:
${company}

CANDIDATE_RESUME:
${resumeText}${jdSection}`;
}

// FIX: added rate limiting to cover letter — was the only AI endpoint without it
app.post(
  '/api/ai/cover-letter',
  auth,
  validateCoverLetterInput,
  async (req, res) => {
    const { resumeText, jd, company, name } = req.body;
    if (!hasAiProvider) return rejectMissingAI(res);

    const allowed = await checkCoverLetterLimit(req.user.uid);
    if (!allowed)
      return res.status(429).json({
        error:
          'Daily cover letter limit reached. Upgrade to Pro for unlimited generation.',
      });

    const prompt = buildCoverLetterPrompt(
      name.trim(),
      company.trim(),
      resumeText.trim(),
      jd?.trim()
    );

    try {
      if (genAI) {
        const model = genAI.getGenerativeModel({
          model: 'gemini-2.5-flash',
          generationConfig: {
            maxOutputTokens: 600,
            temperature: 0.7,
            topP: 0.9,
          },
        });
        const result = await withTimeout(model.generateContent(prompt));
        const letter = extractLetterText(result.response.text());
        return res.json({
          letter,
          engine: 'gemini',
          wordCount: letter.split(/\s+/).length,
        });
      }
    } catch (geminiErr) {
      console.error('[cover-letter] Gemini failed:', geminiErr.message);
    }

    if (!groq)
      return res
        .status(503)
        .json({ error: 'AI service temporarily unavailable. Please try again.' });

    try {
      const result = await withTimeout(
        groq.chat.completions.create({
          model: 'llama-3.3-70b-versatile',
          max_tokens: 600,
          temperature: 0.7,
          messages: [
            {
              role: 'system',
              content:
                'You are an expert cover letter writer. Output ONLY the letter text — no preamble, no markdown.',
            },
            { role: 'user', content: prompt },
          ],
        })
      );
      const letter = extractLetterText(
        result.choices[0]?.message?.content || ''
      );
      return res.json({
        letter,
        engine: 'groq',
        wordCount: letter.split(/\s+/).length,
      });
    } catch (groqErr) {
      console.error('[cover-letter] Groq failed:', groqErr.message);
      return res.status(503).json({
        error:
          'Both AI engines are temporarily unavailable. Please try again shortly.',
      });
    }
  }
);

// ─── Tailor Resume to JD ──────────────────────────────────────────────────────
app.post(
  '/api/ai/tailor-resume',
  auth,
  validateAiInput([{ key: 'jd', required: true, maxLen: 8000, minLen: 20 }]),
  async (req, res) => {
    const { resume, jd } = req.body;
    if (!resume) return res.status(400).json({ error: 'Missing resume object.' });

    const resumeJson = JSON.stringify(resume.sections || {});
    if (resumeJson.length > 20000)
      return res.status(400).json({ error: 'Resume data too large.' });

    if (!hasAiProvider) return rejectMissingAI(res);

    const prompt = `You are a senior resume tailoring editor. Your goal is to transform the candidate's entire resume to maximally match the job description, while staying 100% truthful to the facts in the resume.

Your job is to meaningfully tailor the resume to the JD while staying 100% truthful to the candidate's resume evidence.

=== SUMMARY ===
Rewrite personal.summary completely.
- 2-3 sentences, no first-person pronouns.
- Open with the target job title and years of experience if determinable.
- Include 3-5 high-value keywords from the JD that the resume genuinely supports.

=== EXPERIENCE ===
For each job, rewrite the description bullets to:
- Lead with the most JD-relevant responsibilities first.
- Replace generic phrases like "worked on", "responsible for", and "helped with" with strong past-tense action verbs.
- Naturally incorporate JD terminology where the original description supports it.
- 3-5 bullets per job. Keep all original factual content; reframe it toward the JD.
- Preserve title, company, dates, location exactly as given.

=== SKILLS - THIS IS THE MOST IMPORTANT SECTION ===
Build the best possible skills list for this specific JD. Be generous in adding skills.
- Include explicitly listed skills from the JD when the resume plausibly supports them.
- Infer adjacent skills from job titles and descriptions where reasonable.
- Reorder: JD must-have skills first, then JD preferred skills, then remaining original skills.
- Keep all original skills. Only add, never remove.
- Only put a skill in warnings if it requires deep specialized certification or niche experience with zero resume signal.

=== PROJECTS ===
Rewrite each project description to highlight aspects most relevant to the JD.
- Emphasize technologies, outcomes, and responsibilities that align with JD requirements.
- Keep name and dates unchanged.

=== EDUCATION ===
Add a "highlights" field, one sentence max, if the degree is relevant to the JD. Set it to "" if not relevant.
- Never change degree, institution, year, or gpa.

=== CERTIFICATIONS ===
Return certifications array reordered, most JD-relevant first. Never change content.

=== WHAT YOU MUST NOT TOUCH ===
- experience[*].title, company, dates, location — preserve exactly as given
- experience order — keep the same array order as the input, no reordering
- projects, education, and certifications may be returned for full-depth tailoring, but only editable fields may change
- awards and languages must be omitted from the output
- Do not add new experience, project, education, or certification entries

=== TRUTH RULES ===
- Do not invent employers, job titles, dates, degrees, certifications, tools, metrics, revenue, users, team sizes, or outcomes
- Use numbers only if they already exist in the resume JSON
- Do not keyword-stuff. Include JD terms only where they fit the evidence naturally

=== WARNINGS (KEEP SHORT) ===
Only include warnings when:
- The JD requires a specific certification or license the candidate clearly does not have.
- The JD requires deep domain expertise with zero resume signal.
Do not warn about common skills, soft skills, tools that can be inferred, or anything you already added to skills.
Maximum 5 warnings total. An empty array is fine and preferred over over-warning.

=== CHANGES ===
List 5-15 of the most impactful edits. Be specific.

=== OUTPUT QUALITY ===
- Summary: 2–3 concise sentences, role-specific, no first-person pronouns
- Experience descriptions: newline-separated bullet lines starting with strong action verbs. 3-5 bullets per job where evidence exists
- Prefer concrete phrasing over generic terms like "responsible for" or "worked on"

Return ONLY valid JSON. The compact fields below are required, and the full-depth fields that follow are also required:
{
  "targetRole": "string",
  "summary": "string",
  "experience": [array of objects — same length and order as input, each with only a "description" field updated],
  "skills": [array of skill strings],
  "warnings": ["JD requirement not supported by resume evidence"],
  "changes": [{"section":"summary|experience|skills","before":"string","after":"string","reason":"string"}]
}

FINAL FULL-DEPTH OUTPUT CONTRACT:
- In addition to summary, experience, and skills, tailor project descriptions, education highlights, and certification order.
- Preserve protected metadata exactly. Only rewrite experience.description, projects.description, education.highlights, skills order, targetRole, warnings, and changes.
- Return projects, education, and certifications in the same array lengths as the input.
- Do not add unsupported facts, entries, metrics, tools, employers, degrees, certifications, or dates.
- Include 5-15 changes across summary, experience, skills, projects, education, and certifications.

Full-depth JSON fields that must be present:
{
  "targetRole": "string",
  "summary": "string",
  "experience": [{"description": "rewritten bullet lines separated by newlines"}],
  "skills": ["jd-relevant skills first", "then remaining original skills"],
  "projects": [{"description": "rewritten to highlight JD relevance"}],
  "education": [{"highlights": "optional one-sentence relevance note, or empty string"}],
  "certifications": [{"name": "copy from input", "issuer": "copy from input", "year": "copy from input"}],
  "warnings": ["specific JD requirement not supported by resume"],
  "changes": [{"section":"summary|experience|skills|projects|education|certifications","before":"string","after":"string","reason":"string"}]
}

RESUME_JSON:
${resumeJson}

JOB_DESCRIPTION:
${jd}`;

    try {
      if (genAI) {
        const model = genAI.getGenerativeModel({
          model: 'gemini-2.5-flash',
          generationConfig: { temperature: 0.25, topP: 0.85 },
        });
        const result = await withTimeout(model.generateContent(prompt), 60000);
        const parsed = normalizeTailoredResume(
          safeParseJson(result.response.text()),
          resume.sections || {}
        );
        return res.json(parsed);
      }
    } catch (e) {
      console.error('[tailor-resume] Gemini failed:', e.message);
    }

    if (groq) {
      try {
        const result = await withTimeout(
          groq.chat.completions.create({
            messages: [
              {
                role: 'system',
                content:
                  'You are an expert resume coach. Return ONLY valid JSON matching the exact schema. No markdown, no explanation, no preamble.',
              },
              { role: 'user', content: prompt },
            ],
            model: 'llama-3.3-70b-versatile',
            max_tokens: 6000,
          }),
          60000
        );
        const parsed = normalizeTailoredResume(
          safeParseJson(result.choices[0]?.message?.content || ''),
          resume.sections || {}
        );
        return res.json(parsed);
      } catch (groqErr) {
        console.error('[tailor-resume] Groq failed:', groqErr.message);
      }
    }

    return res
      .status(503)
      .json({ error: 'AI service temporarily unavailable. Please try again.' });
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
          relax_quotes: true,
        });
      } catch {
        return [];
      }
    };

    const profile = readCSV('Profile.csv')[0] || {};
    const positions = readCSV('Positions.csv');
    const education = readCSV('Education.csv');
    const skills = readCSV('Skills.csv');

    if (!profile['First Name'] && positions.length === 0) {
      return res.status(422).json({
        error:
          'Could not parse LinkedIn export. Make sure you uploaded the correct ZIP file.',
      });
    }

    const resume = {
      name: [profile['First Name'], profile['Last Name']]
        .filter(Boolean)
        .join(' '),
      email: profile['Email Address'] || '',
      phone: profile['Phone Numbers'] || '',
      summary: profile['Summary'] || '',
      headline: profile['Headline'] || '',
      location: profile['Geo Location'] || '',
      experience: positions
        .map((p) => ({
          title: p['Title'] || '',
          company: p['Company Name'] || '',
          dates: [p['Started On'], p['Finished On'] || 'Present']
            .filter(Boolean)
            .join(' - '),
          location: p['Location'] || '',
          description: p['Description'] || '',
        }))
        .filter((e) => e.title || e.company),
      education: education
        .map((e) => ({
          degree: [e['Degree Name'], e['Field Of Study']]
            .filter(Boolean)
            .join(' in '),
          institution: e['School Name'] || '',
          year: e['End Date'] || e['Start Date'] || '',
        }))
        .filter((e) => e.institution),
      skills: skills
        .map((s) => s['Name'])
        .filter(Boolean)
        .slice(0, 50),
    };

    res.json({ success: true, resume, source: 'linkedin_zip' });
  } catch (err) {
    console.error('[linkedin-zip] Error:', err);
    res.status(500).json({ error: 'Failed to parse LinkedIn export file.' });
  }
});

// ─── LinkedIn OAuth ───────────────────────────────────────────────────────────
app.get('/api/linkedin/auth-url', auth, (req, res) => {
  if (!LINKEDIN.clientId)
    return res
      .status(503)
      .json({ error: 'LinkedIn OAuth is not configured on this server.' });

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

app.get('/api/linkedin/callback', async (req, res) => {
  const { code, state, error } = req.query;

  if (error)
    return res.redirect(
      `atsresumebuilder://linkedin-callback?error=${encodeURIComponent(error)}`
    );

  if (!state || !linkedinStateStore.has(state))
    return res.redirect(
      'atsresumebuilder://linkedin-callback?error=invalid_state'
    );

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
    const profileRes = await axios.get('https://api.linkedin.com/v2/userinfo', {
      headers: { Authorization: `Bearer ${accessToken}` },
    });

    const p = profileRes.data;
    const resume = {
      name:
        p.name || `${p.given_name || ''} ${p.family_name || ''}`.trim(),
      email: p.email || '',
      picture: p.picture || '',
      experience: [],
      education: [],
      skills: [],
    };

    const encoded = encodeURIComponent(JSON.stringify(resume));
    res.redirect(`atsresumebuilder://linkedin-callback?resume=${encoded}`);
  } catch (err) {
    console.error(
      '[linkedin-oauth] Error:',
      err.response?.data || err.message
    );
    res.redirect('atsresumebuilder://linkedin-callback?error=server_error');
  }
});

// ─── Export DOCX ───────────────────────────────────────────────────────────────
app.post('/api/export/docx', auth, async (req, res) => {
  try {
    const resume = req.body;
    if (!resume || !resume.sections)
      return res.status(400).json({ error: 'Missing resume data.' });

    const p = resume.sections.personal || {};
    const exp = resume.sections.experience || [];
    const edu = resume.sections.education || [];
    const skills = resume.sections.skills || [];

    const docChildren = [];

    docChildren.push(
      new Paragraph({
        text: (p.name || 'Untitled').toUpperCase(),
        heading: HeadingLevel.HEADING_1,
      })
    );

    const contactInfo = [p.email, p.phone, p.location, p.linkedin]
      .filter(Boolean)
      .join(' | ');
    if (contactInfo) {
      docChildren.push(new Paragraph({ text: contactInfo }));
    }

    if (p.summary) {
      docChildren.push(
        new Paragraph({ text: 'Professional Summary', heading: HeadingLevel.HEADING_2 })
      );
      docChildren.push(new Paragraph({ text: p.summary }));
    }

    if (exp.length > 0) {
      docChildren.push(
        new Paragraph({ text: 'Experience', heading: HeadingLevel.HEADING_2 })
      );
      exp.forEach((e) => {
        docChildren.push(
          new Paragraph({
            children: [
              new TextRun({ text: e.title || '', bold: true }),
              new TextRun({ text: ' — ' + (e.company || '') }),
            ],
          })
        );
        if (e.dates) docChildren.push(new Paragraph({ text: e.dates }));
        if (e.description)
          docChildren.push(new Paragraph({ text: e.description }));
      });
    }

    if (edu.length > 0) {
      docChildren.push(
        new Paragraph({ text: 'Education', heading: HeadingLevel.HEADING_2 })
      );
      edu.forEach((e) => {
        docChildren.push(
          new Paragraph({
            children: [
              new TextRun({ text: e.degree || '', bold: true }),
              new TextRun({ text: ' — ' + (e.institution || '') }),
            ],
          })
        );
        if (e.year) docChildren.push(new Paragraph({ text: e.year }));
      });
    }

    if (skills.length > 0) {
      docChildren.push(
        new Paragraph({ text: 'Skills', heading: HeadingLevel.HEADING_2 })
      );
      const skillsText = skills
        .map((s) => (typeof s === 'string' ? s : JSON.stringify(s)))
        .join(', ');
      docChildren.push(new Paragraph({ text: skillsText }));
    }

    const doc = new Document({
      sections: [{ properties: {}, children: docChildren }],
    });

    const buffer = await Packer.toBuffer(doc);
    res.setHeader('Content-Disposition', 'attachment; filename=resume.docx');
    res.setHeader(
      'Content-Type',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
    );
    res.send(buffer);
  } catch (err) {
    console.error('[export-docx] Error:', err.message);
    res.status(500).json({ error: 'Failed to generate DOCX document.' });
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
      await db
        .collection('share_links')
        .doc(token)
        .set({
          uid: req.user.uid,
          resumeId,
          expiry: admin.firestore.Timestamp.fromDate(expiry),
        });
    } catch (e) {
      console.error('[share-link] Firestore write failed:', e.message);
      return res
        .status(500)
        .json({ error: 'Could not create share link. Please try again.' });
    }
  }

  res.json({
    link: `${process.env.BACKEND_URL || 'http://localhost:10000'}/r/${token}`,
    expiry,
  });
});

// ═══════════════════════════════════════════════════════════════════════════════
// GLOBAL ERROR HANDLERS
// ═══════════════════════════════════════════════════════════════════════════════

app.use((err, req, res, next) => {
  console.error('[Global Express Error]', err.message);
  if (res.headersSent) return next(err);
  res.status(500).json({ error: 'An unexpected error occurred. Please try again.' });
});

process.on('unhandledRejection', (reason) => {
  console.error('[UnhandledRejection]', reason);
});

process.on('uncaughtException', (err) => {
  console.error('[UncaughtException]', err.message);
  setTimeout(() => process.exit(1), 1000);
});

app.listen(port, () => {
  console.log(`🌐 Server running on port ${port}`);
});
