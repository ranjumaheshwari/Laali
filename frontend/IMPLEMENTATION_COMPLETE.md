# ✅ Existing User Recognition - Complete Implementation

## Summary of Changes

### **What was added to recognize returning users:**

#### **1. `main.dart` - Updated**
- Added import: `import 'package:shared_preferences/shared_preferences.dart';`
- Added helper function: `_getInitialRoute()` 
  - Checks if Supabase session exists
  - Checks if user is anonymous or account type
  - Returns appropriate route ('/', '/voice', or '/dashboard')
  
- Changed `MyApp` from `StatelessWidget` to `StatefulWidget`
- Wrapped MaterialApp in `FutureBuilder`
- Shows loading screen while checking auth status
- Dynamically sets `initialRoute` based on user type

#### **2. `supabase_service.dart` - Email domain improved**
- Changed temp email from `@local.test` to `@example.com`
- Added try/catch logging for signup failures

#### **3. `welcome_page.dart` - Anonymous path fixed**
- Removed Supabase auth call for anonymous users
- Only stores local preferences (no DB)
- Sets `isAnonymous: true` flag

#### **4. `voice_signup_page.dart` - Already working**
- Creates Supabase auth user (temp email)
- Creates profile + pregnancy in DB
- Saves preferences (userMode, username, lmpDate, isAnonymous=false)

---

## Your Database Schema - NO CHANGES NEEDED ✅

Your schema is perfectly designed for this flow:

```sql
auth.users
  id (UUID primary key) ← Supabase manages this
  email, password, ...
  
profiles
  id (UUID refs auth.users.id)  ← User identified here
  username, is_anonymous
  RLS: Users see only their own row
  
pregnancies
  user_id (refs profiles.id)    ← Linked to user
  lmp_date, estimated_due
  RLS: Users see only their own rows
  
visit_notes
  user_id (refs profiles.id)    ← Linked to user
  transcript, created_at
  RLS: Users see only their own rows
  
vitals, risk_scores
  [Same pattern - user_id identifies owner]
  [RLS policies protect data]
```

**Why this works:**
- Supabase `auth.users` is the source of truth
- `profiles.id` references `auth.users.id` 
- All other tables reference `user_id` 
- RLS policies use `auth.uid()` to isolate data
- When session is restored, `auth.uid()` is automatically set

---

## How Existing Users are Recognized

### **Account Users (with DB data)**

```
App Restarts
    ↓
_getInitialRoute() checks:
    ↓
1. Supabase.instance.client.auth.currentUser != null?
   → YES (session cached on device, validated with server)
    ↓
2. prefs.getBool('isAnonymous') == false?
   → YES (set during signup)
    ↓
Return '/dashboard'
    ↓
Dashboard loads immediately with:
  - username from SharedPreferences
  - GA from pregnancies table (queried via auth.uid())
  - Risk from risk_scores table (queried via auth.uid())
  - Activity from visit_notes table (queried via auth.uid())
```

### **Anonymous Users (no DB)**

```
App Restarts
    ↓
_getInitialRoute() checks:
    ↓
1. Supabase.instance.client.auth.currentUser == null?
   → YES (anonymous never creates auth user)
    ↓
Return '/'
    ↓
Welcome Page shown again
(Anonymous sessions don't persist)
```

---

## Testing Checklist

### **Test 1: First-time account user returns**
- [ ] Complete signup on first launch
- [ ] Dashboard shows username, GA, recent activity
- [ ] Close app completely
- [ ] Reopen app
- [ ] **Expected:** Loading screen → Dashboard (auto-logged in)
- [ ] Ask new question
- [ ] Check Supabase `visit_notes` table → new entry exists

### **Test 2: First-time anonymous user returns**
- [ ] Select "ಅನಾಮಧೇಯ" on first launch
- [ ] Go to Voice Interface
- [ ] Close app
- [ ] Reopen app
- [ ] **Expected:** Loading screen → Welcome Page (treated as new)
- [ ] Why: Anonymous mode doesn't create auth session

### **Test 3: Check session persistence**
- [ ] Create account, close app
- [ ] Reopen app after 1 hour
- [ ] **Expected:** Dashboard still visible
- [ ] Check: `Supabase.instance.client.auth.currentUser` is populated

### **Test 4: Force logout and re-authenticate**
- [ ] On Dashboard, add manual "Sign Out" button (optional feature)
- [ ] Call `Supabase.instance.client.auth.signOut()`
- [ ] Reopen app
- [ ] **Expected:** Welcome Page
- [ ] Why: Session was explicitly cleared

---

## File Locations (for reference)

```
c:\MCP-testing\
├── lib\
│   ├── main.dart                          ← UPDATED (session check)
│   ├── welcome_page.dart                  ← FIXED (no auth for anonymous)
│   ├── voice_signup_page.dart             ← OK (creates auth user)
│   ├── voice_interface_page.dart          ← OK (conditionally saves)
│   ├── dashboard.dart                     ← OK (loads user data)
│   ├── services\
│   │   └── supabase_service.dart          ← UPDATED (email domain)
│   └── ...
├── EXISTING_USER_RECOGNITION.md           ← NEW (detailed doc)
├── FLOW_DIAGRAMS.md                       ← NEW (visual flows)
└── README.md                              ← (original)
```

---

## Session Storage Details

**Where is the session stored?**
- Supabase Flutter SDK stores it in **platform-specific secure storage:**
  - **iOS:** Keychain
  - **Android:** Encrypted SharedPreferences
  - **Web:** localStorage (not applicable for your mobile app)

**How long does it last?**
- Default: ~1 hour for access token
- Refresh token: ~7 days (auto-refreshed on app reopen)
- If token expires and refresh fails: `auth.currentUser` = null → show Welcome Page

**Can user stay logged in forever?**
- No. Refresh token expires after ~7 days
- After 7 days without using app: User must sign in again
- If user opens app weekly: Session refreshed automatically

---

## Troubleshooting Guide

### Issue: Account user sees Welcome Page on reopen

**Cause:** Session not created or saved

**Debug:**
```dart
// Add to main.dart _getInitialRoute():
debugPrint('Auth user: ${Supabase.instance.client.auth.currentUser}');
debugPrint('Is Anonymous: ${prefs.getBool('isAnonymous')}');
```

**Fix:**
- Check `signUpTempUser()` completes without error
- Check `prefs.setBool('isAnonymous', false)` is called in signup
- Check device has internet (session validation requires server)

---

### Issue: Dashboard shows "User" instead of username

**Cause:** Username not saved to SharedPreferences during signup

**Debug:**
```dart
// In voice_signup_page.dart, line ~250 in _handleConfirm():
debugPrint('Saving username: $username');
```

**Fix:**
- Ensure `prefs.setString('username', username)` is called
- Check SharedPreferences write doesn't fail
- Manually test: `prefs.getString('username')` returns value

---

### Issue: Loading screen appears forever

**Cause:** `_getInitialRoute()` hangs or throws uncaught error

**Debug:**
```dart
// In main.dart _getInitialRoute():
debugPrint('Starting route check...');
try {
  // ... code ...
  debugPrint('Route determined: $route');
} catch (e) {
  debugPrint('ERROR in _getInitialRoute: $e');
  return '/';
}
```

**Fix:**
- Check Supabase initialization in main() completes
- Check internet connection available
- Wrap in try/catch (already done)
- Check no infinite loops in dashboard initState

---

### Issue: Old account data not loading on Dashboard

**Cause:** Dashboard queries wrong user ID or RLS policy blocked

**Debug:**
```dart
// In dashboard.dart _loadSupabaseData():
final currentUserId = _supa.currentUser?.id;
debugPrint('Current user ID: $currentUserId');
```

**Fix:**
- Check `_supa.currentUser?.id` is not null
- Check Supabase RLS policies (should work with auth.uid())
- Manually query in Supabase console: `SELECT * FROM profiles`

---

## Summary: What Changed?

| Component | Before | After | Status |
|-----------|--------|-------|--------|
| App startup | Always show Welcome Page | Check auth session first | ✅ NEW |
| Anonymous user | Might create DB row (bug) | No DB, local only | ✅ FIXED |
| Account user session | Not persisted (bug) | Cached encrypted on device | ✅ NEW |
| Returning account user | Requires signup again (bug) | Auto-routed to Dashboard | ✅ NEW |
| Email domain | @local.test (rejected) | @example.com (accepted) | ✅ FIXED |

---

## No Database Changes Needed ✅

Your schema is perfect as-is. It already supports:
- User identification via `auth.users.id`
- Data isolation via RLS policies with `auth.uid()`
- User profile storage
- Pregnancy tracking
- Visit history
- Vitals tracking
- Risk assessment

The new code just leverages what's already there!

---

## Next Steps

1. **Build & Test:**
   ```bash
   cd c:\MCP-testing
   flutter clean && flutter pub get && flutter run
   ```

2. **Test all scenarios:**
   - New anonymous user
   - New account user
   - Returning account user
   - Returning after many days
   - Force logout

3. **Monitor logs:**
   - Check debug print statements
   - Look for "Auth user:" and "Route determined:" messages
   - Watch for "ERROR in _getInitialRoute:"

4. **Optional enhancements:**
   - Add manual "Sign Out" button on Dashboard
   - Add "Edit Profile" feature
   - Add session timeout warnings
   - Add data sync when network restored

---

## Questions?

- ✅ How are existing users recognized? → Via Supabase auth session + isAnonymous flag
- ✅ Where is session stored? → Device secure storage (Keychain/encrypted SharedPreferences)
- ✅ How long does session last? → 7 days (auto-refresh if app opened weekly)
- ✅ Do I need to change the database? → NO! Schema is already perfect
- ✅ What happens if token expires? → User sees Welcome Page, must sign in again
- ✅ Can users stay logged in forever? → No, max 7 days without activity

All set! Ready to test? 🚀

