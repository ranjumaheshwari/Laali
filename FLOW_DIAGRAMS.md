# Existing User Recognition - Flow Diagram

## App Startup Flow

```
┌─────────────────────────────────────────┐
│  App Launches                           │
│  (Supabase initialized in main())       │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│  _getInitialRoute() called               │
│  (FutureBuilder shows loading screen)   │
└──────────────┬──────────────────────────┘
               │
               ▼
        ┌──────────────┐
        │ Check:       │
        │ Is Supabase  │
        │ auth session │
        │ active?      │
        └──┬────────┬──┘
           │        │
       YES │        │ NO
           ▼        ▼
    ┌──────────┐  ┌──────────────┐
    │ Session  │  │ No session   │
    │ found!   │  │ (new user)   │
    └────┬─────┘  └──────┬───────┘
         │               │
         ▼               ▼
    ┌──────────┐   ┌──────────────┐
    │ Check:   │   │ Return '/'   │
    │ is       │   │              │
    │Anonymous?│   │ Welcome Page │
    └─┬────┬───┘   └──────────────┘
      │    │
   YES│    │ NO
      ▼    ▼
   ┌─────────────┐  ┌──────────────┐
   │ Return      │  │ Return       │
   │ '/voice'    │  │ '/dashboard' │
   │             │  │              │
   │ Voice       │  │ Dashboard    │
   │Interface    │  │ Page         │
   │Page         │  │              │
   └─────────────┘  └──────────────┘
```

---

## Complete User Registration & Return Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                         FIRST TIME USER                             │
└─────────────────────────────────────────────────────────────────────┘

WELCOME PAGE
│
├─ [User says "ಅನಾಮಧೇಯ"] ──────────────────────────────────────┐
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ _handleAnonymous()                                       │  │
│  │ • NO Supabase auth created                              │  │
│  │ • Save: userMode='anonymous'                            │  │
│  │ • Save: isAnonymous=true (SharedPreferences)            │  │
│  │ • No DB entries                                         │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ↓                                                              │
│  VOICE INTERFACE PAGE (no DB save)                             │
│  • Ask questions ← N8N processes                              │
│  • [User closes app]                                          │
│                                                                 │
│  ↓ [App reopens]                                              │
│  _getInitialRoute() check:                                    │
│  • Supabase auth = NULL (no session created)                 │
│  • Return '/'                                                │
│  ↓                                                             │
│  WELCOME PAGE again (treated as new user)                     │
│                                                                 │
└──────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                                                                     │
├─ [User says "ಖಾತೆ ರಚಿಸಿ"] ──────────────────────────────────────┐
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │ Router → VOICE SIGNUP PAGE                                 │  │
│  │                                                              │  │
│  │ Step 1: [Tap mic] → Name extraction                        │  │
│  │ Step 2: [Tap mic] → LMP date parsing                       │  │
│  │ Step 3: [Confirm with "ಹೌದು"]                             │  │
│  │                                                              │  │
│  │ _handleConfirm():                                          │  │
│  │   ├─ _supa.signUpTempUser()                               │  │
│  │   │   ├─ Email: user{timestamp}{uuid}@example.com         │  │
│  │   │   ├─ Create: auth.users row ✅                         │  │
│  │   │   └─ Save session locally (encrypted) ✅              │  │
│  │   │                                                         │  │
│  │   ├─ _supa.createProfile(username, is_anonymous=false)    │  │
│  │   │   └─ Create: profiles row ✅                          │  │
│  │   │                                                         │  │
│  │   ├─ _supa.createPregnancy(lmpDate)                        │  │
│  │   │   └─ Create: pregnancies row ✅                       │  │
│  │   │                                                         │  │
│  │   └─ Save to SharedPreferences:                            │  │
│  │       ├─ userMode='account'                                │  │
│  │       ├─ username=extracted_name                           │  │
│  │       ├─ lmpDate=parsed_date                               │  │
│  │       └─ isAnonymous=false ✅                              │  │
│  │                                                              │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                     │
│  ↓ [TTS: Account created successfully]                             │
│  DASHBOARD PAGE                                                    │
│  • Show: username, GA, risk, activity                              │
│  • Mic button (read summary)                                       │
│  • Ask questions button → /voice                                   │
│  • Report symptoms button → /voice                                 │
│                                                                     │
│  ↓ [User asks questions]                                          │
│  VOICE INTERFACE PAGE                                              │
│  • Questions saved to visit_notes table ✅                         │
│  • [User closes app]                                               │
│                                                                     │
│  ↓ [App reopens - RETURNING USER] ⭐                              │
│  _getInitialRoute() check:                                        │
│  • Supabase.instance.client.auth.currentUser ≠ NULL ✅           │
│    (encrypted session found on device)                            │
│  • Check isAnonymous = false ✅                                   │
│  • Return '/dashboard'                                            │
│                                                                     │
│  ↓ [Loading screen disappears]                                    │
│  DASHBOARD PAGE (AUTOMATIC - NO SIGN UP NEEDED!)                  │
│  • Shows: [username], GA, risk, recent questions                  │
│  • Session valid                                                   │
│  • User can immediately ask more questions                         │
│  • All new data saved to DB                                       │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Data Flow: Where Everything is Stored

```
┌──────────────────────────────────────────────────────────────────────┐
│                         DEVICE STORAGE                               │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  SharedPreferences (LOCAL, NOT encrypted by default)                │
│  ├─ userMode: 'account' or 'anonymous'                             │
│  ├─ username: 'ರಮ್ಯಾ'                                             │
│  ├─ lmpDate: '2024-08-01T00:00:00.000Z'                            │
│  └─ isAnonymous: true/false                                         │
│                                                                      │
│  Supabase Local Session (ENCRYPTED)                                │
│  ├─ JWT token (auth_token)                                         │
│  ├─ Refresh token                                                   │
│  └─ User ID (UUID)                                                 │
│      [Automatically cached by supabase_flutter]                    │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
                              ↓
                    [On App Restart]
                              ↓
         Supabase reads cached JWT token ✅
         Validates with server
         Sets: auth.currentUser (if token valid)
                              ↓
┌──────────────────────────────────────────────────────────────────────┐
│                      SUPABASE CLOUD (DB)                            │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌─ auth.users (managed by Supabase)                               │
│  │  └─ id: "a1b2c3d4-...", email: "user...@example.com", ...      │
│  │                                                                  │
│  ├─ public.profiles                                                 │
│  │  └─ id: "a1b2c3d4-...", username: "ರಮ್ಯಾ", is_anonymous: false │
│  │                                                                  │
│  ├─ public.pregnancies                                              │
│  │  └─ user_id: "a1b2c3d4-...", lmp_date: "2024-08-01", ...       │
│  │                                                                  │
│  ├─ public.visit_notes                                              │
│  │  └─ user_id: "a1b2c3d4-...", transcript: "...", created_at: ... │
│  │                                                                  │
│  ├─ public.vitals                                                   │
│  │  └─ user_id: "a1b2c3d4-...", type: "...", value: ..., ...      │
│  │                                                                  │
│  └─ public.risk_scores                                              │
│     └─ user_id: "a1b2c3d4-...", risk_level: "low", ...            │
│                                                                      │
│  [Protected by RLS policies - users see only their own data]       │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

---

## Session Lifecycle

```
┌────────────────────────────────────────────────────────────────┐
│ NEW ACCOUNT USER SIGNS UP                                      │
└────────────────────┬───────────────────────────────────────────┘
                     │
                     ▼
        signUpTempUser() called
        • Email generated
        • Create auth.users row
        • Supabase returns JWT token
                     │
                     ▼
    ✅ SESSION CREATED (cached on device)
    • Device stores: encrypted JWT token
    • Device stores: userId, email, refresh_token
    • app.currentUser = user object


┌────────────────────────────────────────────────────────────────┐
│ USER CLOSES APP                                                │
└────────────────────┬───────────────────────────────────────────┘
                     │
                     ▼
    Session persists in device storage (encrypted)


┌────────────────────────────────────────────────────────────────┐
│ USER REOPENS APP (Next day / Same week / Any time)             │
└────────────────────┬───────────────────────────────────────────┘
                     │
                     ▼
    1. Supabase library reads cached token from device
    2. Validates token with Supabase server
    3. If valid: Sets auth.currentUser (session restored!)
       If invalid/expired: Clears session, auth.currentUser = null
                     │
                     ▼
    ✅ SESSION RESTORED (or expired if too old)
    • _getInitialRoute() can check auth.currentUser
    • Route to /dashboard if user is account type
    • Route to /voice if user is anonymous type
    • Route to / if user is new


┌────────────────────────────────────────────────────────────────┐
│ USER SIGNS OUT (or token expires)                              │
└────────────────────┬───────────────────────────────────────────┘
                     │
                     ▼
    • supabase.auth.signOut()
    • Device clears cached token
    • auth.currentUser = null
                     │
                     ▼
    ❌ SESSION DESTROYED
    • Next app launch routes to /welcome (new user flow)
    • User must sign in or sign up again
```

---

## Key Takeaways

1. **Session is managed by Supabase** — Once created, it persists automatically
2. **Device stores encrypted JWT** — No password stored locally
3. **`auth.currentUser` is your check** — If not null → user is authenticated
4. **`isAnonymous` flag matters** — Determines which page to route to
5. **No changes to your DB schema needed** — It's already perfect! ✅
6. **RLS policies handle data isolation** — Users automatically see only their own data

