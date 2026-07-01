# Google Drive backup

## What ships today (no setup required)

**Settings → Backup & Google Drive → "Back up to Drive"** exports all your
data (invoices, products, customers) into a single `.json` file and opens the
Android share sheet. Pick **Google Drive** (or Gmail, WhatsApp, Files, etc.)
to store it in the cloud.

To restore: download the backup file from Drive to the phone, then
**Settings → Restore** and select it.

This works on every build, needs no Google account sign‑in, and keeps the app
100% offline until you choose to share a backup.

---

## Optional: fully‑integrated one‑tap Drive sync (future upgrade)

A "Sign in with Google → one‑tap Backup/Restore to a Drive app folder"
experience is possible, but Google requires some one‑time setup that only you
can do under your own Google account. Here's exactly what it needs so we can
turn it on deliberately:

### 1. Stable app signing key
Google ties sign‑in to your app's signing certificate. The CI build currently
uses an **ephemeral debug key** (its fingerprint changes every build), which
Google Sign‑In rejects. We first need a **release keystore** committed (or
supplied via CI secrets) and wired into `android/app/build.gradle`.

Generate one:
```bash
keytool -genkey -v -keystore invoice-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias invoice
```
Get its SHA‑1:
```bash
keytool -list -v -keystore invoice-release.jks -alias invoice | grep SHA1
```

### 2. Google Cloud project + OAuth client
1. Go to <https://console.cloud.google.com/> → create a project.
2. **APIs & Services → Enable APIs** → enable **Google Drive API**.
3. **OAuth consent screen** → External → add your email as a test user.
4. **Credentials → Create Credentials → OAuth client ID → Android**.
   - Package name: `com.example.shakti_invoice`
   - SHA‑1: the fingerprint from step 1.

### 3. App code (already scoped out)
- Add packages: `google_sign_in`, `googleapis` (Drive v3),
  `extension_google_sign_in_as_googleapis_auth`.
- Add `<uses-permission android:name="android.permission.INTERNET"/>`.
- Sign in with scope `https://www.googleapis.com/auth/drive.file` (app‑created
  files only — least privilege), upload the backup JSON to a "Invoice Bills"
  Drive folder, and list/download it for restore.

Once you've done steps 1–2 and shared the SHA‑1, say the word and this gets
wired in.
