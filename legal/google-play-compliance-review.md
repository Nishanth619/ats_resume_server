# Google Play Compliance Review

Review date: May 10, 2026

This is a practical review for Google Play readiness based on the current repository. It is not legal advice, but it is written to help avoid obvious Google Play policy mismatches.

## High Priority Before Submission

1. Verify the account deletion path.

The app now includes a Settings option to initiate account deletion, and a public account deletion page has been drafted. Before submission, verify the in-app flow works against production Firebase rules and host the account deletion page publicly.

2. Verify in-app AI output reporting.

The app now includes "Report AI Output" actions on reviewed AI result surfaces and stores reports in Firestore. Before submission, verify production Firestore rules allow authenticated users to create AI reports while preventing unauthorized reads/edits.

3. Host the privacy policy on a public non-PDF URL.

The app links to `https://ats-resume-builder.app/privacy`. Google Play requires the policy to be publicly accessible, active, non-geofenced, non-editable by users, and not a PDF. Publish `legal/privacy-policy.md` as an HTML page at that URL before production submission.

4. Confirm exact developer legal name.

The Privacy Policy and Terms currently use "ATS Resume Builder" as the operator name because no separate legal entity was found in the codebase. Replace or supplement it with the exact Google Play developer/company name before publishing.

## Medium Priority Before Submission

1. Declare ads accurately.

The app integrates Google Mobile Ads and includes rewarded, banner, and interstitial ad units. In Play Console, answer "Yes" for ads and make sure interstitial timing is not disruptive.

2. Review photo/media permission messaging.

The Android manifest requests `READ_MEDIA_IMAGES`, `READ_EXTERNAL_STORAGE`, and `WRITE_EXTERNAL_STORAGE` for image/file features. Use these only when the user initiates profile photo/import/export actions, and make the in-app prompt clear before requesting permission.

3. Confirm subscription implementation.

`purchases_flutter` is present and RevenueCat keys are configured, but Play Billing/RevenueCat is not fully implemented. The fake local Pro grant path has been disabled. Do not submit paid/subscription claims until Play Billing/RevenueCat is fully implemented and tested.

4. Align Data safety with SDK provider disclosures.

Review Firebase, AdMob, Google Sign-In, RevenueCat, LinkedIn, Google Gemini, Groq, and hosting provider disclosures before final Data safety submission.

5. Keep privacy disclosures consistent with app behavior.

If you remove LinkedIn import, ads, analytics, subscriptions, AI providers, or profile photo upload, update the Privacy Policy and Play Console Data safety form. If you add new SDKs, update both again.

## Lower Priority / Good Practice

1. Keep a visible support/report link in AI screens and Settings.

2. Add a short AI disclaimer near generated outputs: users should verify all AI-generated career content before submitting it.

3. Add a privacy/terms acceptance checkbox during sign-up if you want stronger evidence that users accepted them.

4. Avoid collecting unnecessary sensitive details in resume templates. Let users choose what to include.

5. Add backend deletion tooling so account deletion can also remove Firebase Storage files, share links, and cached records where technically possible.

## Current In-App Legal Links

Settings currently links to:

- Privacy Policy: `https://ats-resume-builder.app/privacy`
- Terms of Service: `https://ats-resume-builder.app/terms`
- Support: `support@ats-resume-builder.app`

Host the prepared policies at those URLs or update the app links before release.
