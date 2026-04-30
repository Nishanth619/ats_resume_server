require('dotenv').config();
const express = require('express');
const cors = require('cors');
const admin = require('firebase-admin');
const { GoogleGenerativeAI } = require('@google/generative-ai');
const crypto = require('crypto');
const app = express();
app.use(cors({ origin: '*' }));
app.use(express.json({ limit: '5mb' }));

// Initialise Firebase Admin
const fs = require('fs');
try {
  let credential;
  if (fs.existsSync('/etc/secrets/firebase-service-account.json')) {
    // Render Secret Files path
    credential = admin.credential.cert(require('/etc/secrets/firebase-service-account.json'));
    console.log('Firebase Admin loaded from Render Secret File.');
  } else if (process.env.FIREBASE_SERVICE_ACCOUNT) {
    // Render Environment Variable fallback
    credential = admin.credential.cert(JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT));
    console.log('Firebase Admin loaded from Environment Variable.');
  } else {
    // Local development fallback
    credential = admin.credential.cert(require('./firebase-service-account.json'));
    console.log('Firebase Admin loaded from local file.');
  }
  admin.initializeApp({ credential });
} catch (e) {
  console.warn('Firebase Admin init failed (Missing credentials). Mocking for development.', e.message);
}

const db = admin.firestore ? admin.firestore() : null;
const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY || 'MOCK_KEY');

// -- Auth Middleware --
const auth = async (req, res, next) => {
  const token = req.headers.authorization?.split('Bearer ')[1];
  if (!token) return res.status(401).json({ error: 'No token' });
  try {
    req.user = await admin.auth().verifyIdToken(token);
    next();
  } catch {
    // For local testing without a real token
    if (process.env.NODE_ENV !== 'production') {
      req.user = { uid: 'test_user_123' };
      return next();
    }
    res.status(401).json({ error: 'Invalid token' });
  }
};

// -- Rate Limiter --
const rateLimit = async (uid, isPro, limit = 3) => {
  if (isPro) return true;
  if (!db) return true; // Bypass in dev
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

// -- AI: Improve Bullet --
app.post('/api/ai/improve-bullet', auth, async (req, res) => {
  const { rawDuty, role } = req.body;
  if (!process.env.GEMINI_API_KEY) {
    return res.json({ bullet: `Optimised ${role} duty: Increased efficiency by 20% in ${rawDuty}` });
  }
  const model = genAI.getGenerativeModel({ model: 'gemini-2.5-flash' });
  try {
    const result = await model.generateContent(
      `You are an expert resume writer. Rewrite as strong, quantified, action-verb-led bullet. Past tense. Under 20 words. Role: ${role}. Duty: ${rawDuty}. Return ONLY the bullet.`
    );
    res.json({ bullet: result.response.text().trim() });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// -- AI: ATS Check with Rate Limiting --
app.post('/api/ai/ats-check', auth, async (req, res) => {
  const { resumeText, targetJD } = req.body;
  let isPro = false;
  if (db) {
    const userDoc = await db.collection('users').doc(req.user.uid).get();
    isPro = userDoc.data()?.plan === 'pro';
  }
  
  const allowed = await rateLimit(req.user.uid, isPro, 3);
  if (!allowed) {
    return res.status(429).json({ error: 'Daily ATS check limit reached. Upgrade to Pro for unlimited checks.' });
  }
  
  if (!process.env.GEMINI_API_KEY) {
    return res.json({
      score: 85,
      issues: ["Missing leadership keywords"],
      fixes: ["Add words like 'Managed' or 'Led'"],
      keywords: ["Flutter", "Dart"],
      missing_keywords: ["Firebase"]
    });
  }

  const model = genAI.getGenerativeModel({ model: 'gemini-2.5-flash' });
  const jdSection = targetJD ? `Target JD: ${targetJD}` : '';
  try {
    const result = await model.generateContent(
      `Analyse this resume as an ATS expert. Return ONLY valid JSON: {"score":0-100,"issues":[],"fixes":[],"keywords":[],"missing_keywords":[]}. Resume: ${resumeText} ${jdSection}`
    );
    const text = result.response.text().replace(/```json|```/g, '').trim();
    res.json(JSON.parse(text));
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// -- AI: Generate Summary --
app.post('/api/ai/summary', auth, async (req, res) => {
  const { name, targetRole, experiences, skills } = req.body;
  if (!process.env.GEMINI_API_KEY) return res.json({ summary: 'Mock summary for testing.' });
  const model = genAI.getGenerativeModel({ model: 'gemini-2.5-flash' });
  try {
    const prompt = `Write a 3-4 sentence professional resume summary for ${name} targeting role ${targetRole}. Experience: ${experiences.join(", ")}. Skills: ${skills.join(", ")}. No "I". Professional tone. Return ONLY the summary.`;
    const result = await model.generateContent(prompt);
    res.json({ summary: result.response.text().trim() });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// -- AI: Match JD --
app.post('/api/ai/match-jd', auth, async (req, res) => {
  const { resumeText, jd } = req.body;
  if (!process.env.GEMINI_API_KEY) return res.json({ required_keywords: [], matched: [], missing: [], match_percentage: 50 });
  const model = genAI.getGenerativeModel({ model: 'gemini-2.5-flash' });
  try {
    const prompt = `Extract top 15 keywords from JD, check which are in resume. Return ONLY valid JSON: {"required_keywords":[],"matched":[],"missing":[],"match_percentage":0} JD: ${jd} Resume: ${resumeText}`;
    const result = await model.generateContent(prompt);
    const text = result.response.text().replace(/```json|```/g, '').trim();
    res.json(JSON.parse(text));
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// -- AI: Cover Letter --
app.post('/api/ai/cover-letter', auth, async (req, res) => {
  const { resumeText, jd, company, name } = req.body;
  if (!process.env.GEMINI_API_KEY) return res.json({ letter: 'Mock cover letter.' });
  const model = genAI.getGenerativeModel({ model: 'gemini-2.5-flash' });
  try {
    const prompt = `Write a professional cover letter for ${name} applying to ${company}. 3 paragraphs, under 300 words, first person, match resume tone. Do not invent facts. Resume: ${resumeText} JD: ${jd}. Return ONLY the letter.`;
    const result = await model.generateContent(prompt);
    res.json({ letter: result.response.text().trim() });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// -- Share Link Generator --
app.post('/api/share-link', auth, async (req, res) => {
  const { resumeId } = req.body;
  const token = crypto.randomBytes(16).toString('hex');
  const expiry = new Date(Date.now() + 30 * 86400000); // 30 days
  if (db) {
    await db.collection('share_links').doc(token).set({
      uid: req.user.uid,
      resumeId,
      expiry: admin.firestore.Timestamp.fromDate(expiry)
    });
  }
  res.json({ link: `${process.env.BACKEND_URL || 'http://localhost:3000'}/r/${token}`, expiry });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`ATS Resume Builder backend running on port ${PORT}`));
