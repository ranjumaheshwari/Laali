# Existing User Recognition Flow

## Overview

When an existing user restarts the app, the system automatically detects them and routes them to the correct page without requiring them to sign up again.

---

## How It Works

### **1. App Startup** (in `main.dart`)

When the app launches:

1. **Supabase initializes** with credentials
2. **`_getInitialRoute()` is called** (async function)
3. App shows a loading screen while checking

### **2. Authentication Check**

```dart
Future<String> _getInitialRoute() async {
  // Check if Supabase auth session exists
  final user = Supabase.instance.client.auth.currentUser;
  
  if (user != null) {
    // User IS authenticated (session found)
    // → Check if they're anonymous or account user
    final prefs = await SharedPreferences.getInstance();
    final isAnonymous = prefs.getBool('isAnonymous') ?? false;
    
    if (isAnonymous) {
      return '/voice';        // → Anonymous: go to Voice Interface
    } else {
      return '/dashboard';    // → Account: go to Dashboard
    }
  }
  
  // User NOT authenticated (no session)
  // → Show Welcome Page for new users
  return '/';
}
```

---

## Database lookup: Where does Supabase store the session?

Supabase stores auth sessions in **local storage** (encrypted on device):
- **Mobile:** `SharedPreferences` or native secure storage
- **When:** Session is created during `signUpTempUser()` or account signup
- **Session includes:** `auth.users.id`, JWT token, refresh token

### **Why this works:**

1. **Account User Signs Up:**
   - Creates `auth.users` row (email, password)
   - Saves session locally (encrypted)
   - Saves `isAnonymous: false` in SharedPreferences
   
2. **User Closes App & Reopens:**
   - Supabase reads encrypted session from device storage
   - If valid → `auth.currentUser` is populated
   - App detects: "user exists!" → routes to Dashboard

3. **User Logs Out (or clears app data):**
   - Session is deleted
   - `auth.currentUser` returns null
   - App routes to Welcome Page

---

## Complete User Journey

### **Scenario 1: New User (Anonymous Path)**

```
Welcome Page
  ↓ [User says "ಅನಾಮಧೇಯ"]
  ↓ _handleAnonymous() called
  ↓ Saves: userMode='anonymous', isAnonymous=true (SharedPreferences only, no DB)
  ↓ NO Supabase auth created
Voice Interface Page
  ↓ [User asks questions]
  ↓ Responses NOT saved to DB
  ↓ [User closes app]
→ Next launch:
  ↓ _getInitialRoute() checks: Supabase auth = NULL
  ↓ Returns '/'  → Welcome Page again
  ↓ User is treated as new (session expired/never created)
```

### **Scenario 2: New User (Account Path)**

```
Welcome Page
  ↓ [User says "ಖಾತೆ ರಚಿಸಿ"]
  ↓ Router → /signup (Voice Signup Page)
Voice Signup Page
  ↓ [User: name → LMP → confirm]
  ↓ _handleConfirm() called
  ↓ Calls: _supa.signUpTempUser()
  ↓   → Creates auth.users row (email: user{timestamp}{uuid}@example.com)
  ↓   → Session automatically saved locally (encrypted)
  ↓ Calls: _supa.createProfile() + _supa.createPregnancy()
  ↓   → Creates profiles + pregnancies rows in DB
  ↓ Saves: userMode='account', username=name, lmpDate=date (SharedPreferences)
  ↓ Router → /dashboard
Dashboard Page
  ↓ [Shows username, gestational age, risk, activity]
  ↓ [User closes app]
→ Next launch (EXISTING USER):
  ↓ _getInitialRoute() checks: Supabase auth = NOT NULL (session found!)
  ↓ Checks: isAnonymous = false
  ↓ Returns '/dashboard' → Dashboard Page
  ↓ Dashboard loads username + data from SharedPreferences
  ↓ Dashboard can load DB data (pregnancies, risk_scores, visit_notes)
```

### **Scenario 3: Existing Account User Reopens App**

```
[User already created account before, app was closed]
  ↓ App launches → FutureBuilder shows loading screen
  ↓ _getInitialRoute() checks:
  ↓   Step 1: Is Supabase session still valid?
  ↓     → YES (device has encrypted token, Supabase validates it)
  ↓   Step 2: Check isAnonymous flag
  ↓     → false (because they created account)
  ↓ Returns: '/dashboard'
→ Dashboard Page loads automatically
  ↓ Shows: "Welcome, [username]"
  ↓ Shows: Gestational age (from pregnancies table)
  ↓ Shows: Recent symptoms (from visit_notes table)
  ↓ User can immediately ask questions
  ↓ All new questions saved to visit_notes
```

---

## Database Schema Relevance

Your schema is perfectly set up:

```sql
-- 1. Supabase manages sessions automatically
auth.users (id, email, encrypted_password, ...)  ← Session here

-- 2. Your app queries these based on auth.uid()
profiles (id ← references auth.users.id, username, is_anonymous, ...)
pregnancies (user_id ← references profiles.id, lmp_date, ...)
visit_notes (user_id ← references profiles.id, transcript, ...)
vitals (user_id ← references profiles.id, type, value, ...)
risk_scores (user_id ← references profiles.id, score, risk_level, ...)
```

### **When user reopens app:**
- `auth.currentUser.id` is available (from cached session)
- Dashboard queries `profiles WHERE id = auth.currentUser.id` ✅
- RLS policies automatically apply (users see only their data)

---

## Important: Session Persistence

**Sessions persist because:**
1. Supabase stores encrypted token on device
2. Token is automatically refreshed when app opens
3. If token expires → User redirected to Welcome Page (sign in again)

**Session is cleared when:**
- User signs out (call `supabase.auth.signOut()`)
- App is uninstalled
- Device storage is cleared
- Token expires and can't be refreshed

---

## Code Checklist: What You Need

✅ **main.dart:**
- Import `shared_preferences`
- Implement `_getInitialRoute()` helper
- Convert `MyApp` to StatefulWidget with FutureBuilder
- Show loading screen while checking auth

✅ **welcome_page.dart:**
- Anonymous path: NO Supabase auth, store `isAnonymous: true`
- Account path: Goes to signup (which creates auth user)

✅ **voice_signup_page.dart:**
- Calls `_supa.signUpTempUser()` (creates auth.users)
- Calls `_supa.createProfile()` + `_supa.createPregnancy()`
- Saves `userMode: 'account'` to SharedPreferences

✅ **dashboard.dart:**
- Loads username + dates from SharedPreferences
- Queries `profiles`, `pregnancies`, `visit_notes` via Supabase

✅ **supabase_service.dart:**
- `currentUser` getter: returns `auth.currentUser`
- `getProfile()`: queries `profiles WHERE id = currentUser.id`
- `getPregnancy()`: queries `pregnancies WHERE user_id = currentUser.id`

---

## Testing Existing User Flow

### Test Case: Account User Reopens App

1. **First launch:** Select "ಖಾತೆ ರಚಿಸಿ" → Complete signup
2. **Verify:** Dashboard shows username, GA, recent activity
3. **Close app completely** (iOS: swipe up; Android: back button)
4. **Relaunch app**
5. **Expected:** Loading screen → Then Dashboard (NOT Welcome Page)
6. **Verify:** Same username, GA, activity still there
7. **Ask question:** New responses saved to DB

### Test Case: Anonymous User Reopens App

1. **First launch:** Select "ಅನಾಮಧೇಯ"
2. **Verify:** Goes to Voice Interface (no DB)
3. **Close app**
4. **Relaunch app**
5. **Expected:** Welcome Page (no session)
6. **Why:** Anonymous mode doesn't create Supabase auth

---

## Troubleshooting

| Issue | Cause | Fix |
|-------|-------|-----|
| Account user sees Welcome Page on reopen | Session not saved or expired | Check `signUpTempUser()` is creating auth user; check SharedPreferences saves `isAnonymous=false` |
| Dashboard shows "User" instead of username | Username not loaded from SharedPreferences | Ensure `voice_signup_page.dart` calls `prefs.setString('username', username)` |
| Loading screen appears but never goes away | `_getInitialRoute()` hangs | Check Supabase initialization didn't fail; check internet connection |
| Old account data doesn't load | Querying with wrong user ID | Ensure `currentUser` returns correct ID; check RLS policies |

---

## Summary

**How app finds existing users:**

1. **On startup** → Check if Supabase auth session exists locally
2. **If exists** → Check if `isAnonymous` flag is false
3. **If account user** → Route to `/dashboard`
4. **If no session** → Route to `/welcome` (treat as new user)

Your DB schema supports this perfectly—no changes needed! ✅

