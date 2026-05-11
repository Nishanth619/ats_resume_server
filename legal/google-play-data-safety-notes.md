# Google Play Data Safety Notes

Effective review date: May 10, 2026

These notes are based on the current code review of this project and should be used to complete the Play Console Data safety form. Re-check before every production release because SDKs, features, and backend behavior can change.

## App Summary

Package: `com.atsai.resume`

App name: ATS Resume Builder

Core features:

- Email/password and Google Sign-In account creation
- Resume builder, editor, templates, PDF/DOCX export, and share features
- Profile photo upload
- ATS scoring, keyword matching, bullet improvement, summary generation, resume tailoring, and cover letter generation through backend AI APIs
- LinkedIn ZIP import and LinkedIn OAuth import
- Job application tracker
- Firebase sync/storage
- Firebase Analytics and Crashlytics
- Google Mobile Ads / AdMob rewarded, banner, and interstitial ads
- RevenueCat dependency for subscription support, although the current subscription service still uses Firestore as source of truth

## Data Types Likely Collected

Mark "collected" for these categories if the production build includes the reviewed features:

- Personal info: name, email address, user IDs, phone number, address/location text entered in resume, profile links, and other user-entered resume contact information
- Photos and videos: profile photo selected by the user
- Files and docs: LinkedIn ZIP exports, generated PDFs/DOCX files, resumes, cover letters, job descriptions, and other user-created career documents
- App activity: app interactions, feature usage, usage limits, generated content actions, ads watched, and subscriptions/plan status
- App info and performance: crash logs, diagnostics, performance data, and other Firebase Crashlytics/Analytics signals
- Device or other IDs: Firebase installation identifiers, advertising ID/device identifiers used by ads/analytics SDKs where applicable
- Financial info: purchase history/subscription status if paid features are enabled through Google Play/RevenueCat. Do not declare raw payment card collection unless you directly collect it; the app code does not.

## Data Sharing Likely Required

Mark "shared" where the data is sent to third-party providers outside your developer organization:

- Firebase/Google services for auth, database, storage, analytics, and crash reporting
- AdMob/Google Mobile Ads for advertising and ad measurement
- Backend hosting provider for API processing
- Google Gemini and/or Groq for AI feature processing when users submit AI requests
- LinkedIn when users choose LinkedIn OAuth/import features
- RevenueCat/Google Play Billing if paid subscription handling is enabled
- User-selected share targets when users export/share files or links

## Purposes to Select

Common purposes that fit this app:

- App functionality
- Analytics
- Developer communications
- Advertising or marketing, for AdMob and ad identifiers
- Fraud prevention, security, and compliance
- Account management

For AI feature inputs and resume content, use app functionality. For Crashlytics, use analytics and app functionality/performance. For AdMob, use advertising or marketing, analytics, fraud prevention/security as applicable to the SDK provider's guidance.

## Security Practices

Declare that data is encrypted in transit if the production app only uses HTTPS/TLS endpoints and Firebase secure transport. Do not claim independent security review unless you have completed one through an eligible third-party process.

## Deletion

Because the app allows account creation, Play Console requires an account deletion URL. Use a public, non-PDF web page such as:

https://ats-resume-builder.app/account-deletion

The app should also add an in-app account deletion request/control in Settings before production review.

