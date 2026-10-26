/**
 * Phase 35.12.19 — Firebase Auth Emulator Integration & Firestore Identity Contract Test Suite
 * 
 * Verifies end-to-end token-backed identity authorization:
 * - Real token issuance from local Firebase Auth Emulator (port 9099)
 * - Token-backed rules enforcement on Cloud Firestore Emulator (port 8080)
 * - Active user scoping, cross-user denial across subcollections
 * - Session invalidation upon sign-out
 * - Document update semantics (partial mask, explicit nulls, full replacement)
 * - Field immutability & legitimate editability audit (foodName, mealType)
 */

import assert from 'node:assert';

const AUTH_BASE_URL = 'http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1';
const FIRESTORE_BASE_URL = 'http://127.0.0.1:8080/v1/projects/demo-fitfuel/databases/(default)/documents';

let passedTests = 0;
let totalTests = 0;

async function runTestCase(name, fn) {
  totalTests++;
  try {
    await fn();
    console.log(`  [PASS] Test ${totalTests}: ${name}`);
    passedTests++;
  } catch (err) {
    console.error(`  [FAIL] Test ${totalTests}: ${name}`);
    console.error(`         ${err.message}`);
    throw err;
  }
}

/**
 * Obtains an Auth Emulator-issued ID token via the Auth Emulator REST API.
 * Uses accounts:signUp or accounts:signInWithPassword to get a real emulator token.
 */
async function authenticateWithAuthEmulator(email, password) {
  // Try sign-in first
  let res = await fetch(`${AUTH_BASE_URL}/accounts:signInWithPassword?key=demo-fitfuel`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password, returnSecureToken: true }),
  });
  if (res.ok) {
    const data = await res.json();
    return { token: data.idToken, uid: data.localId, email: data.email };
  }

  // If sign-in failed, create account via sign-up
  res = await fetch(`${AUTH_BASE_URL}/accounts:signUp?key=demo-fitfuel`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password, returnSecureToken: true }),
  });
  if (res.ok) {
    const data = await res.json();
    return { token: data.idToken, uid: data.localId, email: data.email };
  }

  const errBody = await res.text();
  throw new Error(`Auth Emulator authentication failed: ${errBody}`);
}

function toFirestoreFields(obj) {
  const fields = {};
  for (const [key, val] of Object.entries(obj)) {
    if (val === null || val === undefined) {
      fields[key] = { nullValue: null };
    } else if (typeof val === 'number') {
      fields[key] = Number.isInteger(val) ? { integerValue: val.toString() } : { doubleValue: val };
    } else if (typeof val === 'string') {
      fields[key] = { stringValue: val };
    } else if (typeof val === 'boolean') {
      fields[key] = { booleanValue: val };
    }
  }
  return fields;
}

function getNum(field) {
  if (!field) return undefined;
  if (field.integerValue !== undefined) return Number(field.integerValue);
  if (field.doubleValue !== undefined) return Number(field.doubleValue);
  return undefined;
}

async function runAuthIntegrationSuite() {
  console.log('================================================================');
  console.log('Running Firebase Auth Emulator to Firestore Identity Integration Suite');
  console.log(`Auth Emulator: ${AUTH_BASE_URL}`);
  console.log(`Firestore Emulator: ${FIRESTORE_BASE_URL}`);
  console.log('================================================================\n');

  // ============================================================================
  // Group 1: Auth Emulator Token Issuance & User Creation
  // ============================================================================
  console.log('--- Group 1: Auth Emulator Token Issuance & User Creation ---');

  let userA, userB, userC;

  await runTestCase('Auth Emulator issues valid identity token for User A', async () => {
    userA = await authenticateWithAuthEmulator('user_a_alice@fitfuel.test', 'Password123!');
    assert.ok(userA.token, 'Token must be returned by Auth Emulator');
    assert.ok(userA.uid, 'UID (localId) must be returned by Auth Emulator');
    assert.strictEqual(userA.email, 'user_a_alice@fitfuel.test');
  });

  await runTestCase('Auth Emulator issues valid identity token for User B', async () => {
    userB = await authenticateWithAuthEmulator('user_b_bob@fitfuel.test', 'Password123!');
    assert.ok(userB.token, 'Token must be returned by Auth Emulator');
    assert.ok(userB.uid, 'UID must be returned by Auth Emulator');
    assert.notStrictEqual(userB.uid, userA.uid, 'User B must have distinct UID from User A');
  });

  await runTestCase('Auth Emulator creates a fresh User C with unique UID', async () => {
    const timestamp = Date.now();
    userC = await authenticateWithAuthEmulator(`fresh_charlie_${timestamp}@fitfuel.test`, 'Password123!');
    assert.ok(userC.token);
    assert.ok(userC.uid);
    assert.notStrictEqual(userC.uid, userA.uid);
    assert.notStrictEqual(userC.uid, userB.uid);
  });

  const validRecordA = {
    foodName: 'Grilled Chicken Breast',
    mealType: 'Lunch',
    calories: 165.0,
    protein: 31.0,
    carbohydrates: 0.0,
    fats: 3.6,
    servingSize: 100.0,
    sugar: 0.0,
    fiber: 0.0,
    sodium: 74.0,
  };

  const validRecordB = {
    foodName: 'Bob Protein Shake',
    mealType: 'Breakfast',
    calories: 250.0,
    protein: 30.0,
    carbohydrates: 15.0,
    fats: 2.5,
    servingSize: 300.0,
    sugar: 1.0,
    fiber: 2.0,
    sodium: 100.0,
  };

  // ============================================================================
  // Group 2: Token-Backed Document Operations & Ownership
  // ============================================================================
  console.log('\n--- Group 2: Token-Backed Document Operations & Ownership ---');

  await runTestCase('User A can create a nutrition record using Auth Emulator token', async () => {
    const res = await fetch(`${FIRESTORE_BASE_URL}/users/${userA.uid}/nutrition/rec_a1`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${userA.token}`,
      },
      body: JSON.stringify({ fields: toFirestoreFields(validRecordA) }),
    });
    assert.strictEqual(res.status, 200, `Expected 200, got ${res.status}`);
  });

  await runTestCase('User A can read back their own nutrition record', async () => {
    const res = await fetch(`${FIRESTORE_BASE_URL}/users/${userA.uid}/nutrition/rec_a1`, {
      method: 'GET',
      headers: { 'Authorization': `Bearer ${userA.token}` },
    });
    assert.strictEqual(res.status, 200);
    const data = await res.json();
    assert.strictEqual(data.fields.foodName.stringValue, 'Grilled Chicken Breast');
    assert.strictEqual(getNum(data.fields.calories), 165.0);
  });

  await runTestCase('User B can create and read their own nutrition record', async () => {
    const writeRes = await fetch(`${FIRESTORE_BASE_URL}/users/${userB.uid}/nutrition/rec_b1`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${userB.token}`,
      },
      body: JSON.stringify({ fields: toFirestoreFields(validRecordB) }),
    });
    assert.strictEqual(writeRes.status, 200);

    const readRes = await fetch(`${FIRESTORE_BASE_URL}/users/${userB.uid}/nutrition/rec_b1`, {
      method: 'GET',
      headers: { 'Authorization': `Bearer ${userB.token}` },
    });
    assert.strictEqual(readRes.status, 200);
    const data = await readRes.json();
    assert.strictEqual(data.fields.foodName.stringValue, 'Bob Protein Shake');
  });

  await runTestCase('Newly created User C has empty diary collection', async () => {
    const res = await fetch(`${FIRESTORE_BASE_URL}/users/${userC.uid}/nutrition`, {
      method: 'GET',
      headers: { 'Authorization': `Bearer ${userC.token}` },
    });
    assert.strictEqual(res.status, 200);
    const body = await res.json();
    assert.ok(!body.documents || body.documents.length === 0, 'User C diary must be empty');
  });

  // ============================================================================
  // Group 3: Cross-User Denial Across Active Subcollections
  // ============================================================================
  console.log('\n--- Group 3: Cross-User Denial Across Active Subcollections ---');

  await runTestCase('Cross-User: User B cannot read User A nutrition records', async () => {
    const res = await fetch(`${FIRESTORE_BASE_URL}/users/${userA.uid}/nutrition/rec_a1`, {
      method: 'GET',
      headers: { 'Authorization': `Bearer ${userB.token}` },
    });
    assert.strictEqual(res.status, 403, 'Cross-user read must return 403');
  });

  await runTestCase('Cross-User: User B cannot create document under User A nutrition path', async () => {
    const res = await fetch(`${FIRESTORE_BASE_URL}/users/${userA.uid}/nutrition/bob_injected`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${userB.token}`,
      },
      body: JSON.stringify({ fields: toFirestoreFields(validRecordB) }),
    });
    assert.strictEqual(res.status, 403, 'Cross-user write must return 403');
  });

  await runTestCase('Cross-User: User B cannot update User A nutrition records', async () => {
    const res = await fetch(`${FIRESTORE_BASE_URL}/users/${userA.uid}/nutrition/rec_a1`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${userB.token}`,
      },
      body: JSON.stringify({ fields: toFirestoreFields({ ...validRecordA, calories: 999.0 }) }),
    });
    assert.strictEqual(res.status, 403, 'Cross-user update must return 403');
  });

  await runTestCase('Cross-User: User B cannot delete User A nutrition records', async () => {
    const res = await fetch(`${FIRESTORE_BASE_URL}/users/${userA.uid}/nutrition/rec_a1`, {
      method: 'DELETE',
      headers: { 'Authorization': `Bearer ${userB.token}` },
    });
    assert.strictEqual(res.status, 403, 'Cross-user delete must return 403');
  });

  await runTestCase('Cross-User: User A cannot read User B nutrition records', async () => {
    const res = await fetch(`${FIRESTORE_BASE_URL}/users/${userB.uid}/nutrition/rec_b1`, {
      method: 'GET',
      headers: { 'Authorization': `Bearer ${userA.token}` },
    });
    assert.strictEqual(res.status, 403, 'User A accessing User B must return 403');
  });

  // Cross-subcollection representative checks:
  await runTestCase('Cross-User: User B cannot access User A goals', async () => {
    // User A sets goals
    await fetch(`${FIRESTORE_BASE_URL}/users/${userA.uid}/goals/currentGoal`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${userA.token}` },
      body: JSON.stringify({ fields: toFirestoreFields({ dailyCalorieTarget: 2200.0, proteinTargetGrams: 150.0 }) }),
    });

    const getRes = await fetch(`${FIRESTORE_BASE_URL}/users/${userA.uid}/goals/currentGoal`, {
      method: 'GET',
      headers: { 'Authorization': `Bearer ${userB.token}` },
    });
    assert.strictEqual(getRes.status, 403);

    const patchRes = await fetch(`${FIRESTORE_BASE_URL}/users/${userA.uid}/goals/currentGoal`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${userB.token}` },
      body: JSON.stringify({ fields: toFirestoreFields({ dailyCalorieTarget: 3500.0 }) }),
    });
    assert.strictEqual(patchRes.status, 403);
  });

  await runTestCase('Cross-User: User B cannot access User A pantry', async () => {
    await fetch(`${FIRESTORE_BASE_URL}/users/${userA.uid}/pantry/oats`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${userA.token}` },
      body: JSON.stringify({ fields: toFirestoreFields({ itemName: 'Organic Oats', quantity: 2.0 }) }),
    });

    const res = await fetch(`${FIRESTORE_BASE_URL}/users/${userA.uid}/pantry/oats`, {
      method: 'GET',
      headers: { 'Authorization': `Bearer ${userB.token}` },
    });
    assert.strictEqual(res.status, 403);
  });

  await runTestCase('Cross-User: User B cannot access User A custom foods', async () => {
    await fetch(`${FIRESTORE_BASE_URL}/users/${userA.uid}/customFoods/smoothie`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${userA.token}` },
      body: JSON.stringify({ fields: toFirestoreFields({ name: 'Green Smoothie', calories: 180.0 }) }),
    });

    const res = await fetch(`${FIRESTORE_BASE_URL}/users/${userA.uid}/customFoods/smoothie`, {
      method: 'GET',
      headers: { 'Authorization': `Bearer ${userB.token}` },
    });
    assert.strictEqual(res.status, 403);
  });

  await runTestCase('Cross-User: User B cannot access User A grocery lists', async () => {
    await fetch(`${FIRESTORE_BASE_URL}/users/${userA.uid}/groceryLists/weekly`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${userA.token}` },
      body: JSON.stringify({ fields: toFirestoreFields({ title: 'Weekly Needs' }) }),
    });

    const res = await fetch(`${FIRESTORE_BASE_URL}/users/${userA.uid}/groceryLists/weekly`, {
      method: 'GET',
      headers: { 'Authorization': `Bearer ${userB.token}` },
    });
    assert.strictEqual(res.status, 403);
  });

  await runTestCase('Cross-User: User B cannot access User A health logs', async () => {
    await fetch(`${FIRESTORE_BASE_URL}/users/${userA.uid}/health/today`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${userA.token}` },
      body: JSON.stringify({ fields: toFirestoreFields({ steps: 9500 }) }),
    });

    const res = await fetch(`${FIRESTORE_BASE_URL}/users/${userA.uid}/health/today`, {
      method: 'GET',
      headers: { 'Authorization': `Bearer ${userB.token}` },
    });
    assert.strictEqual(res.status, 403);
  });

  await runTestCase('Cross-User: User B cannot access User A weight history', async () => {
    await fetch(`${FIRESTORE_BASE_URL}/users/${userA.uid}/weightHistory/log1`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${userA.token}` },
      body: JSON.stringify({ fields: toFirestoreFields({ weight: 70.0 }) }),
    });

    const res = await fetch(`${FIRESTORE_BASE_URL}/users/${userA.uid}/weightHistory/log1`, {
      method: 'GET',
      headers: { 'Authorization': `Bearer ${userB.token}` },
    });
    assert.strictEqual(res.status, 403);
  });

  // ============================================================================
  // Group 4: Unauthenticated & Session Invalidation Controls
  // ============================================================================
  console.log('\n--- Group 4: Unauthenticated & Session Invalidation Controls ---');

  await runTestCase('Request without authorization header is rejected with 403', async () => {
    const res = await fetch(`${FIRESTORE_BASE_URL}/users/${userA.uid}/nutrition/rec_a1`, {
      method: 'GET',
    });
    assert.strictEqual(res.status, 403);
  });

  await runTestCase('Request with malformed token is rejected', async () => {
    const res = await fetch(`${FIRESTORE_BASE_URL}/users/${userA.uid}/nutrition/rec_a1`, {
      method: 'GET',
      headers: { 'Authorization': 'Bearer malformed.invalid.token' },
    });
    assert.ok([400, 401, 403].includes(res.status), `Expected rejection status 400/401/403, got ${res.status}`);
  });

  await runTestCase('Session Sign-Out: dropped token prevents any subsequent access', async () => {
    // Simulating sign out by discarding session token
    let sessionToken = userA.token;
    sessionToken = null; // sign out in client state

    const headers = {};
    if (sessionToken) headers['Authorization'] = `Bearer ${sessionToken}`;

    const res = await fetch(`${FIRESTORE_BASE_URL}/users/${userA.uid}/nutrition/rec_a1`, {
      method: 'GET',
      headers,
    });
    assert.strictEqual(res.status, 403, 'Unauthenticated request after sign out must return 403');
  });

  // ============================================================================
  // Group 5: Nutrition Schema & Boundary Validation via Auth Emulator
  // ============================================================================
  console.log('\n--- Group 5: Nutrition Schema & Boundary Validation via Auth Emulator ---');

  await runTestCase('Reject negative macro fields (calories: -20)', async () => {
    const res = await fetch(`${FIRESTORE_BASE_URL}/users/${userA.uid}/nutrition/neg_cal_auth`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${userA.token}` },
      body: JSON.stringify({ fields: toFirestoreFields({ ...validRecordA, calories: -20.0 }) }),
    });
    assert.strictEqual(res.status, 403);
  });

  await runTestCase('Reject non-numeric macro types (calories string)', async () => {
    const res = await fetch(`${FIRESTORE_BASE_URL}/users/${userA.uid}/nutrition/str_cal_auth`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${userA.token}` },
      body: JSON.stringify({ fields: toFirestoreFields({ ...validRecordA, calories: '165' }) }),
    });
    assert.strictEqual(res.status, 403);
  });

  await runTestCase('Reject missing required macro field (carbohydrates missing)', async () => {
    const missing = { ...validRecordA };
    delete missing.carbohydrates;
    const res = await fetch(`${FIRESTORE_BASE_URL}/users/${userA.uid}/nutrition/miss_carbs_auth`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${userA.token}` },
      body: JSON.stringify({ fields: toFirestoreFields(missing) }),
    });
    assert.strictEqual(res.status, 403);
  });

  await runTestCase('Reject non-positive servingSize (servingSize <= 0)', async () => {
    const res = await fetch(`${FIRESTORE_BASE_URL}/users/${userA.uid}/nutrition/zero_serv_auth`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${userA.token}` },
      body: JSON.stringify({ fields: toFirestoreFields({ ...validRecordA, servingSize: 0.0 }) }),
    });
    assert.strictEqual(res.status, 403);
  });

  await runTestCase('Permit omitted servingSize for legacy document compatibility', async () => {
    const legacy = { ...validRecordA };
    delete legacy.servingSize;
    const res = await fetch(`${FIRESTORE_BASE_URL}/users/${userA.uid}/nutrition/legacy_serv_auth`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${userA.token}` },
      body: JSON.stringify({ fields: toFirestoreFields(legacy) }),
    });
    assert.strictEqual(res.status, 200);
  });

  await runTestCase('Preserve legitimate numeric zero 0.0 without treating as missing', async () => {
    const dietRecord = {
      foodName: 'Diet Soda',
      mealType: 'Snack',
      calories: 0.0,
      protein: 0.0,
      carbohydrates: 0.0,
      fats: 0.0,
      sugar: 0.0,
      fiber: 0.0,
      sodium: 0.0,
      servingSize: 355.0,
    };
    const res = await fetch(`${FIRESTORE_BASE_URL}/users/${userA.uid}/nutrition/zero_nutrients_auth`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${userA.token}` },
      body: JSON.stringify({ fields: toFirestoreFields(dietRecord) }),
    });
    assert.strictEqual(res.status, 200);

    const readRes = await fetch(`${FIRESTORE_BASE_URL}/users/${userA.uid}/nutrition/zero_nutrients_auth`, {
      method: 'GET',
      headers: { 'Authorization': `Bearer ${userA.token}` },
    });
    assert.strictEqual(readRes.status, 200);
    const data = await readRes.json();
    assert.strictEqual(getNum(data.fields.calories), 0.0);
    assert.strictEqual(getNum(data.fields.protein), 0.0);
    assert.strictEqual(getNum(data.fields.fiber), 0.0);
  });

  // ============================================================================
  // Group 6: Document Update Semantics & Field Preservation
  // ============================================================================
  console.log('\n--- Group 6: Document Update Semantics & Field Preservation ---');

  const lifecycleDocPath = `${FIRESTORE_BASE_URL}/users/${userA.uid}/nutrition/lifecycle_auth_doc`;

  await runTestCase('Lifecycle Step 1: Create initial document with nonzero fiber and sodium', async () => {
    const docData = {
      foodName: 'Almond Granola',
      mealType: 'Breakfast',
      calories: 210.0,
      protein: 6.0,
      carbohydrates: 28.0,
      fats: 8.0,
      servingSize: 50.0,
      sugar: 5.0,
      fiber: 4.5,
      sodium: 85.0,
    };
    const res = await fetch(lifecycleDocPath, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${userA.token}` },
      body: JSON.stringify({ fields: toFirestoreFields(docData) }),
    });
    assert.strictEqual(res.status, 200);
  });

  await runTestCase('Lifecycle Step 2: Partial update with updateMask preserves unmasked fields', async () => {
    // Only update calories via mask
    const patchPayload = { calories: 230.0 };
    const patchUrl = `${lifecycleDocPath}?updateMask.fieldPaths=calories`;
    const res = await fetch(patchUrl, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${userA.token}` },
      body: JSON.stringify({ fields: toFirestoreFields(patchPayload) }),
    });
    assert.strictEqual(res.status, 200);

    const readRes = await fetch(lifecycleDocPath, {
      method: 'GET',
      headers: { 'Authorization': `Bearer ${userA.token}` },
    });
    const data = await readRes.json();
    assert.strictEqual(getNum(data.fields.calories), 230.0);
    assert.strictEqual(getNum(data.fields.fiber), 4.5, 'Unmasked fiber must be preserved');
    assert.strictEqual(getNum(data.fields.sodium), 85.0, 'Unmasked sodium must be preserved');
    assert.strictEqual(data.fields.foodName.stringValue, 'Almond Granola', 'Unmasked foodName preserved');
  });

  await runTestCase('Lifecycle Step 3: Explicit null update sets field to null in Firestore', async () => {
    const patchPayload = { fiber: null };
    const patchUrl = `${lifecycleDocPath}?updateMask.fieldPaths=fiber`;
    const res = await fetch(patchUrl, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${userA.token}` },
      body: JSON.stringify({ fields: toFirestoreFields(patchPayload) }),
    });
    assert.strictEqual(res.status, 200);

    const readRes = await fetch(lifecycleDocPath, {
      method: 'GET',
      headers: { 'Authorization': `Bearer ${userA.token}` },
    });
    const data = await readRes.json();
    assert.deepStrictEqual(data.fields.fiber, { nullValue: null }, 'Explicit null stored as nullValue');
  });

  await runTestCase('Lifecycle Step 4: Full replacement omitting optional field removes it from document', async () => {
    const replacement = {
      foodName: 'Almond Granola Simple',
      mealType: 'Breakfast',
      calories: 200.0,
      protein: 5.0,
      carbohydrates: 25.0,
      fats: 7.0,
      servingSize: 45.0,
      sugar: 4.0,
      // fiber and sodium omitted from full replacement
    };
    const res = await fetch(lifecycleDocPath, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${userA.token}` },
      body: JSON.stringify({ fields: toFirestoreFields(replacement) }),
    });
    assert.strictEqual(res.status, 200);

    const readRes = await fetch(lifecycleDocPath, {
      method: 'GET',
      headers: { 'Authorization': `Bearer ${userA.token}` },
    });
    const data = await readRes.json();
    assert.strictEqual(data.fields.fiber, undefined, 'Omitted field in full replacement must be removed');
    assert.strictEqual(data.fields.sodium, undefined, 'Omitted field in full replacement must be removed');
    assert.strictEqual(data.fields.foodName.stringValue, 'Almond Granola Simple');
  });

  await runTestCase('Lifecycle Step 5: Invalid update (negative calories) is rejected and document is unchanged', async () => {
    const invalidPatch = { calories: -50.0 };
    const patchUrl = `${lifecycleDocPath}?updateMask.fieldPaths=calories`;
    const res = await fetch(patchUrl, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${userA.token}` },
      body: JSON.stringify({ fields: toFirestoreFields(invalidPatch) }),
    });
    assert.strictEqual(res.status, 403, 'Invalid update must return 403');

    // Confirm document still has calories 200.0
    const readRes = await fetch(lifecycleDocPath, {
      method: 'GET',
      headers: { 'Authorization': `Bearer ${userA.token}` },
    });
    const data = await readRes.json();
    assert.strictEqual(getNum(data.fields.calories), 200.0, 'Calories must remain untouched');
  });

  await runTestCase('Legitimate Editability Audit: foodName and mealType can be updated by owner', async () => {
    // In FitFuel, users can correct food name typos or change meal type in FoodFormSheet
    const editPatch = { foodName: 'Almond Granola with Berries', mealType: 'Snack' };
    const patchUrl = `${lifecycleDocPath}?updateMask.fieldPaths=foodName&updateMask.fieldPaths=mealType`;
    const res = await fetch(patchUrl, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${userA.token}` },
      body: JSON.stringify({ fields: toFirestoreFields(editPatch) }),
    });
    assert.strictEqual(res.status, 200, 'Legitimate editing of foodName and mealType must be allowed');

    const readRes = await fetch(lifecycleDocPath, {
      method: 'GET',
      headers: { 'Authorization': `Bearer ${userA.token}` },
    });
    const data = await readRes.json();
    assert.strictEqual(data.fields.foodName.stringValue, 'Almond Granola with Berries');
    assert.strictEqual(data.fields.mealType.stringValue, 'Snack');
  });

  // ============================================================================
  // Group 7: Least-Privilege & Default-Deny Boundaries
  // ============================================================================
  console.log('\n--- Group 7: Least-Privilege & Default-Deny Boundaries ---');

  await runTestCase('Root collection /global_foods is rejected for Auth Emulator-authenticated user', async () => {
    const res = await fetch(`${FIRESTORE_BASE_URL}/global_foods/food_1`, {
      method: 'GET',
      headers: { 'Authorization': `Bearer ${userA.token}` },
    });
    assert.strictEqual(res.status, 403, 'Root collection outside /users must be denied by default');
  });

  await runTestCase('Root collection /admin_config is rejected for Auth Emulator-authenticated user', async () => {
    const res = await fetch(`${FIRESTORE_BASE_URL}/admin_config/settings`, {
      method: 'GET',
      headers: { 'Authorization': `Bearer ${userA.token}` },
    });
    assert.strictEqual(res.status, 403);
  });

  console.log('\n================================================================');
  console.log(`ALL ${passedTests}/${totalTests} AUTH EMULATOR INTEGRATION TESTS PASSED!`);
  console.log('================================================================\n');
}

runAuthIntegrationSuite().catch((err) => {
  console.error('\nTEST SUITE TERMINATED WITH ERROR:', err);
  process.exit(1);
});
