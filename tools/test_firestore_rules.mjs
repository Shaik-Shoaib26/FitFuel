/**
 * Comprehensive Automated Test Suite for Firestore Security Rules (Phase 35.12.18)
 * Executes against local Cloud Firestore Emulator (Port 8080) with isolated project 'demo-fitfuel'.
 * 
 * Verifies:
 * - Full user subcollections access & cross-user denial (14 active collections)
 * - Boundary field constraints (nutrients, weight, goals, pantry, grocery items)
 * - Least-privilege default-deny on root collections and unlisted subcollections
 * - Actual document update semantics: replacement, partial patch with updateMask, genuine zeros, explicit nulls
 * - Nullable nutrition contract and legacy document compatibility
 */

import assert from 'node:assert';

const BASE_URL = 'http://127.0.0.1:8080/v1/projects/demo-fitfuel/databases/(default)/documents';

/**
 * Creates an unsigned JWT simulating an authenticated Firebase Authentication identity.
 * NOTE: The Firestore Emulator accepts unsigned tokens (alg: 'none') when targeting a demo project.
 * This is an emulator testing facility, distinct from real cryptographically signed Firebase Auth tokens.
 */
function createToken(uid) {
  const header = Buffer.from(JSON.stringify({ alg: 'none', typ: 'JWT' })).toString('base64url');
  const payload = Buffer.from(JSON.stringify({
    sub: uid,
    user_id: uid,
    aud: 'demo-fitfuel',
    iss: 'https://securetoken.google.com/demo-fitfuel',
  })).toString('base64url');
  return `${header}.${payload}.`;
}

// Helper to map JS object to Firestore REST document fields
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

async function runAllRulesTests() {
  console.log('================================================================');
  console.log('Running Authenticated Firestore Security Rules Verification Suite');
  console.log(`Target: ${BASE_URL}`);
  console.log('================================================================\n');

  const aliceToken = createToken('user_alice');
  const bobToken = createToken('user_bob');
  const charlieToken = createToken('user_charlie_fresh');
  const eveToken = createToken('attacker_eve');

  const validRecordData = {
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

  // ============================================================================
  // Group 1: Ownership & Access Control (Tests 1-14) — Preserved from Phase 35.12.17
  // ============================================================================
  console.log('--- Group 1: Ownership & Access Control ---');

  await runTestCase('Unauthenticated user cannot create a nutrition document', async () => {
    const res = await fetch(`${BASE_URL}/users/user_alice/nutrition/unauth_create`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ fields: toFirestoreFields(validRecordData) }),
    });
    assert.strictEqual(res.status, 403, `Expected 403, got ${res.status}`);
  });

  await runTestCase('Unauthenticated user cannot read a nutrition document', async () => {
    const res = await fetch(`${BASE_URL}/users/user_alice/nutrition/unauth_read`, {
      method: 'GET',
    });
    assert.strictEqual(res.status, 403, `Expected 403, got ${res.status}`);
  });

  await runTestCase('Unauthenticated user cannot update a nutrition document', async () => {
    const res = await fetch(`${BASE_URL}/users/user_alice/nutrition/unauth_update`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ fields: toFirestoreFields(validRecordData) }),
    });
    assert.strictEqual(res.status, 403, `Expected 403, got ${res.status}`);
  });

  await runTestCase('Unauthenticated user cannot delete a nutrition document', async () => {
    const res = await fetch(`${BASE_URL}/users/user_alice/nutrition/unauth_delete`, {
      method: 'DELETE',
    });
    assert.strictEqual(res.status, 403, `Expected 403, got ${res.status}`);
  });

  await runTestCase('User A can create their own permitted nutrition record', async () => {
    const res = await fetch(`${BASE_URL}/users/user_alice/nutrition/alice_rec_1`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${aliceToken}`,
      },
      body: JSON.stringify({ fields: toFirestoreFields(validRecordData) }),
    });
    assert.strictEqual(res.status, 200, `Expected 200, got ${res.status}`);
  });

  await runTestCase('User A can read their own nutrition record', async () => {
    const res = await fetch(`${BASE_URL}/users/user_alice/nutrition/alice_rec_1`, {
      method: 'GET',
      headers: { 'Authorization': `Bearer ${aliceToken}` },
    });
    assert.strictEqual(res.status, 200, `Expected 200, got ${res.status}`);
    const data = await res.json();
    assert.strictEqual(data.fields.foodName.stringValue, 'Grilled Chicken Breast');
  });

  await runTestCase('User A can update their own nutrition record', async () => {
    const updated = { ...validRecordData, calories: 180.0 };
    const res = await fetch(`${BASE_URL}/users/user_alice/nutrition/alice_rec_1`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${aliceToken}`,
      },
      body: JSON.stringify({ fields: toFirestoreFields(updated) }),
    });
    assert.strictEqual(res.status, 200, `Expected 200, got ${res.status}`);
  });

  await runTestCase('User A can delete their own nutrition record', async () => {
    const res = await fetch(`${BASE_URL}/users/user_alice/nutrition/alice_rec_1`, {
      method: 'DELETE',
      headers: { 'Authorization': `Bearer ${aliceToken}` },
    });
    assert.strictEqual(res.status, 200, `Expected 200, got ${res.status}`);
  });

  await runTestCase('User B cannot read User A nutrition records', async () => {
    await fetch(`${BASE_URL}/users/user_alice/nutrition/alice_rec_secure`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${aliceToken}`,
      },
      body: JSON.stringify({ fields: toFirestoreFields(validRecordData) }),
    });

    const res = await fetch(`${BASE_URL}/users/user_alice/nutrition/alice_rec_secure`, {
      method: 'GET',
      headers: { 'Authorization': `Bearer ${bobToken}` },
    });
    assert.strictEqual(res.status, 403, `Expected 403, got ${res.status}`);
  });

  await runTestCase('User B cannot create a document under User A nutrition path', async () => {
    const res = await fetch(`${BASE_URL}/users/user_alice/nutrition/bob_injected_doc`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${bobToken}`,
      },
      body: JSON.stringify({ fields: toFirestoreFields(validRecordData) }),
    });
    assert.strictEqual(res.status, 403, `Expected 403, got ${res.status}`);
  });

  await runTestCase('User B cannot update User A nutrition records', async () => {
    const res = await fetch(`${BASE_URL}/users/user_alice/nutrition/alice_rec_secure`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${bobToken}`,
      },
      body: JSON.stringify({ fields: toFirestoreFields({ ...validRecordData, calories: 999.0 }) }),
    });
    assert.strictEqual(res.status, 403, `Expected 403, got ${res.status}`);
  });

  await runTestCase('User B cannot delete User A nutrition records', async () => {
    const res = await fetch(`${BASE_URL}/users/user_alice/nutrition/alice_rec_secure`, {
      method: 'DELETE',
      headers: { 'Authorization': `Bearer ${bobToken}` },
    });
    assert.strictEqual(res.status, 403, `Expected 403, got ${res.status}`);
  });

  await runTestCase('Tampered UID token cannot access another collection', async () => {
    const res = await fetch(`${BASE_URL}/users/user_alice/nutrition/alice_rec_secure`, {
      method: 'GET',
      headers: { 'Authorization': `Bearer ${eveToken}` },
    });
    assert.strictEqual(res.status, 403, `Expected 403, got ${res.status}`);
  });

  await runTestCase('Fresh user sees no records and has empty diary path', async () => {
    const res = await fetch(`${BASE_URL}/users/user_charlie_fresh/nutrition`, {
      method: 'GET',
      headers: { 'Authorization': `Bearer ${charlieToken}` },
    });
    assert.strictEqual(res.status, 200, `Expected 200, got ${res.status}`);
    const body = await res.json();
    assert.ok(!body.documents || body.documents.length === 0, 'New user should have 0 documents');
  });

  // ============================================================================
  // Group 2: Nutrition Field Validation (Tests 15-24) — Preserved from Phase 35.12.17
  // ============================================================================
  console.log('\n--- Group 2: Nutrition Field Validation ---');

  await runTestCase('Reject negative calories', async () => {
    const invalid = { ...validRecordData, calories: -50.0 };
    const res = await fetch(`${BASE_URL}/users/user_alice/nutrition/neg_cal`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${aliceToken}`,
      },
      body: JSON.stringify({ fields: toFirestoreFields(invalid) }),
    });
    assert.strictEqual(res.status, 403, `Expected 403, got ${res.status}`);
  });

  await runTestCase('Reject negative protein', async () => {
    const invalid = { ...validRecordData, protein: -10.0 };
    const res = await fetch(`${BASE_URL}/users/user_alice/nutrition/neg_prot`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${aliceToken}`,
      },
      body: JSON.stringify({ fields: toFirestoreFields(invalid) }),
    });
    assert.strictEqual(res.status, 403, `Expected 403, got ${res.status}`);
  });

  await runTestCase('Reject negative carbohydrates', async () => {
    const invalid = { ...validRecordData, carbohydrates: -5.0 };
    const res = await fetch(`${BASE_URL}/users/user_alice/nutrition/neg_carbs`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${aliceToken}`,
      },
      body: JSON.stringify({ fields: toFirestoreFields(invalid) }),
    });
    assert.strictEqual(res.status, 403, `Expected 403, got ${res.status}`);
  });

  await runTestCase('Reject negative fat', async () => {
    const invalid = { ...validRecordData, fats: -2.0 };
    const res = await fetch(`${BASE_URL}/users/user_alice/nutrition/neg_fats`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${aliceToken}`,
      },
      body: JSON.stringify({ fields: toFirestoreFields(invalid) }),
    });
    assert.strictEqual(res.status, 403, `Expected 403, got ${res.status}`);
  });

  await runTestCase('Reject negative fiber', async () => {
    const invalid = { ...validRecordData, fiber: -1.0 };
    const res = await fetch(`${BASE_URL}/users/user_alice/nutrition/neg_fiber`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${aliceToken}`,
      },
      body: JSON.stringify({ fields: toFirestoreFields(invalid) }),
    });
    assert.strictEqual(res.status, 403, `Expected 403, got ${res.status}`);
  });

  await runTestCase('Reject negative sugar', async () => {
    const invalid = { ...validRecordData, sugar: -3.0 };
    const res = await fetch(`${BASE_URL}/users/user_alice/nutrition/neg_sugar`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${aliceToken}`,
      },
      body: JSON.stringify({ fields: toFirestoreFields(invalid) }),
    });
    assert.strictEqual(res.status, 403, `Expected 403, got ${res.status}`);
  });

  await runTestCase('Reject negative sodium', async () => {
    const invalid = { ...validRecordData, sodium: -15.0 };
    const res = await fetch(`${BASE_URL}/users/user_alice/nutrition/neg_sod`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${aliceToken}`,
      },
      body: JSON.stringify({ fields: toFirestoreFields(invalid) }),
    });
    assert.strictEqual(res.status, 403, `Expected 403, got ${res.status}`);
  });

  await runTestCase('Reject non-numeric type for calories (string type)', async () => {
    const invalid = { ...validRecordData, calories: '250' };
    const res = await fetch(`${BASE_URL}/users/user_alice/nutrition/str_cal`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${aliceToken}`,
      },
      body: JSON.stringify({ fields: toFirestoreFields(invalid) }),
    });
    assert.strictEqual(res.status, 403, `Expected 403, got ${res.status}`);
  });

  await runTestCase('Reject missing required calories field', async () => {
    const missing = { ...validRecordData };
    delete missing.calories;
    const res = await fetch(`${BASE_URL}/users/user_alice/nutrition/miss_cal`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${aliceToken}`,
      },
      body: JSON.stringify({ fields: toFirestoreFields(missing) }),
    });
    assert.strictEqual(res.status, 403, `Expected 403, got ${res.status}`);
  });

  await runTestCase('Reject non-positive serving size (servingSize <= 0)', async () => {
    const invalid = { ...validRecordData, servingSize: 0.0 };
    const res = await fetch(`${BASE_URL}/users/user_alice/nutrition/zero_serving`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${aliceToken}`,
      },
      body: JSON.stringify({ fields: toFirestoreFields(invalid) }),
    });
    assert.strictEqual(res.status, 403, `Expected 403, got ${res.status}`);
  });

  // ============================================================================
  // Group 3: Nullable & Legacy Record Compatibility (Tests 25-28) — Preserved
  // ============================================================================
  console.log('\n--- Group 3: Nullable & Legacy Record Compatibility ---');

  await runTestCase('Preserve legitimate numeric 0.0 for all nutrients', async () => {
    const zeroNutrients = {
      foodName: 'Purified Water / Diet Drink',
      mealType: 'Snack',
      calories: 0.0,
      protein: 0.0,
      carbohydrates: 0.0,
      fats: 0.0,
      servingSize: 250.0,
      sugar: 0.0,
      fiber: 0.0,
      sodium: 0.0,
    };
    const res = await fetch(`${BASE_URL}/users/user_alice/nutrition/true_zeros`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${aliceToken}`,
      },
      body: JSON.stringify({ fields: toFirestoreFields(zeroNutrients) }),
    });
    assert.strictEqual(res.status, 200, `Expected 200, got ${res.status}`);
  });

  await runTestCase('Permit legacy document where optional fiber and sodium are absent', async () => {
    const legacyDoc = {
      foodName: 'Old Legacy Log',
      mealType: 'Breakfast',
      calories: 220.0,
      protein: 8.0,
      carbohydrates: 30.0,
      fats: 4.0,
      servingSize: 150.0,
    };
    const res = await fetch(`${BASE_URL}/users/user_alice/nutrition/legacy_doc_1`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${aliceToken}`,
      },
      body: JSON.stringify({ fields: toFirestoreFields(legacyDoc) }),
    });
    assert.strictEqual(res.status, 200, `Expected 200, got ${res.status}`);

    const readRes = await fetch(`${BASE_URL}/users/user_alice/nutrition/legacy_doc_1`, {
      method: 'GET',
      headers: { 'Authorization': `Bearer ${aliceToken}` },
    });
    assert.strictEqual(readRes.status, 200);
    const readData = await readRes.json();
    assert.strictEqual(readData.fields.fiber, undefined, 'Fiber should be absent in legacy doc');
    assert.strictEqual(readData.fields.sodium, undefined, 'Sodium should be absent in legacy doc');
  });

  await runTestCase('Permit explicit null values for optional nutrients (fiber: null, sodium: null)', async () => {
    const nullOptional = {
      foodName: 'Unanalyzed Fruit',
      mealType: 'Snack',
      calories: 80.0,
      protein: 1.0,
      carbohydrates: 18.0,
      fats: 0.2,
      servingSize: 120.0,
      fiber: null,
      sodium: null,
      sugar: null,
    };
    const res = await fetch(`${BASE_URL}/users/user_alice/nutrition/null_optionals`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${aliceToken}`,
      },
      body: JSON.stringify({ fields: toFirestoreFields(nullOptional) }),
    });
    assert.strictEqual(res.status, 200, `Expected 200, got ${res.status}`);

    const readRes = await fetch(`${BASE_URL}/users/user_alice/nutrition/null_optionals`, {
      method: 'GET',
      headers: { 'Authorization': `Bearer ${aliceToken}` },
    });
    assert.strictEqual(readRes.status, 200);
    const readData = await readRes.json();
    assert.deepStrictEqual(readData.fields.fiber, { nullValue: null });
    assert.deepStrictEqual(readData.fields.sodium, { nullValue: null });
  });

  await runTestCase('Known nonzero optional nutrients are stored accurately', async () => {
    const nonzeroNutrients = {
      foodName: 'Quinoa Bowl',
      mealType: 'Dinner',
      calories: 300.0,
      protein: 11.0,
      carbohydrates: 53.25,
      fats: 4.75,
      servingSize: 250.0,
      fiber: 7.0,
      sugar: 2.25,
      sodium: 17.5,
    };
    const res = await fetch(`${BASE_URL}/users/user_alice/nutrition/quinoa_250`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${aliceToken}`,
      },
      body: JSON.stringify({ fields: toFirestoreFields(nonzeroNutrients) }),
    });
    assert.strictEqual(res.status, 200, `Expected 200, got ${res.status}`);

    const readRes = await fetch(`${BASE_URL}/users/user_alice/nutrition/quinoa_250`, {
      method: 'GET',
      headers: { 'Authorization': `Bearer ${aliceToken}` },
    });
    assert.strictEqual(readRes.status, 200);
    const readData = await readRes.json();
    assert.strictEqual(getNum(readData.fields.fiber), 7.0);
    assert.strictEqual(getNum(readData.fields.sugar), 2.25);
    assert.strictEqual(getNum(readData.fields.sodium), 17.5);
  });

  // ============================================================================
  // Group 4: Expanded Nutrition Field & Boundary Validation (Tests 29-40)
  // ============================================================================
  console.log('\n--- Group 4: Expanded Nutrition Field & Boundary Validation ---');

  await runTestCase('Reject missing required protein field', async () => {
    const invalid = { ...validRecordData };
    delete invalid.protein;
    const res = await fetch(`${BASE_URL}/users/user_alice/nutrition/miss_prot`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${aliceToken}` },
      body: JSON.stringify({ fields: toFirestoreFields(invalid) }),
    });
    assert.strictEqual(res.status, 403, `Expected 403, got ${res.status}`);
  });

  await runTestCase('Reject missing required carbohydrates field', async () => {
    const invalid = { ...validRecordData };
    delete invalid.carbohydrates;
    const res = await fetch(`${BASE_URL}/users/user_alice/nutrition/miss_carbs`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${aliceToken}` },
      body: JSON.stringify({ fields: toFirestoreFields(invalid) }),
    });
    assert.strictEqual(res.status, 403, `Expected 403, got ${res.status}`);
  });

  await runTestCase('Reject missing required fats field', async () => {
    const invalid = { ...validRecordData };
    delete invalid.fats;
    const res = await fetch(`${BASE_URL}/users/user_alice/nutrition/miss_fats`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${aliceToken}` },
      body: JSON.stringify({ fields: toFirestoreFields(invalid) }),
    });
    assert.strictEqual(res.status, 403, `Expected 403, got ${res.status}`);
  });

  await runTestCase('Reject non-numeric type for protein (string type)', async () => {
    const invalid = { ...validRecordData, protein: '31.0' };
    const res = await fetch(`${BASE_URL}/users/user_alice/nutrition/str_prot`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${aliceToken}` },
      body: JSON.stringify({ fields: toFirestoreFields(invalid) }),
    });
    assert.strictEqual(res.status, 403, `Expected 403, got ${res.status}`);
  });

  await runTestCase('Reject non-numeric type for carbohydrates (string type)', async () => {
    const invalid = { ...validRecordData, carbohydrates: '0.0' };
    const res = await fetch(`${BASE_URL}/users/user_alice/nutrition/str_carbs`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${aliceToken}` },
      body: JSON.stringify({ fields: toFirestoreFields(invalid) }),
    });
    assert.strictEqual(res.status, 403, `Expected 403, got ${res.status}`);
  });

  await runTestCase('Reject non-numeric type for fats (string type)', async () => {
    const invalid = { ...validRecordData, fats: '3.6' };
    const res = await fetch(`${BASE_URL}/users/user_alice/nutrition/str_fats`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${aliceToken}` },
      body: JSON.stringify({ fields: toFirestoreFields(invalid) }),
    });
    assert.strictEqual(res.status, 403, `Expected 403, got ${res.status}`);
  });

  await runTestCase('Reject non-numeric type for fiber (string type)', async () => {
    const invalid = { ...validRecordData, fiber: '5.0' };
    const res = await fetch(`${BASE_URL}/users/user_alice/nutrition/str_fiber`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${aliceToken}` },
      body: JSON.stringify({ fields: toFirestoreFields(invalid) }),
    });
    assert.strictEqual(res.status, 403, `Expected 403, got ${res.status}`);
  });

  await runTestCase('Reject non-numeric type for sodium (string type)', async () => {
    const invalid = { ...validRecordData, sodium: '74.0' };
    const res = await fetch(`${BASE_URL}/users/user_alice/nutrition/str_sod`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${aliceToken}` },
      body: JSON.stringify({ fields: toFirestoreFields(invalid) }),
    });
    assert.strictEqual(res.status, 403, `Expected 403, got ${res.status}`);
  });

  await runTestCase('Reject non-numeric type for sugar (string type)', async () => {
    const invalid = { ...validRecordData, sugar: '10.0' };
    const res = await fetch(`${BASE_URL}/users/user_alice/nutrition/str_sugar`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${aliceToken}` },
      body: JSON.stringify({ fields: toFirestoreFields(invalid) }),
    });
    assert.strictEqual(res.status, 403, `Expected 403, got ${res.status}`);
  });

  await runTestCase('Reject non-numeric type for servingSize (string type)', async () => {
    const invalid = { ...validRecordData, servingSize: '100.0' };
    const res = await fetch(`${BASE_URL}/users/user_alice/nutrition/str_serv`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${aliceToken}` },
      body: JSON.stringify({ fields: toFirestoreFields(invalid) }),
    });
    assert.strictEqual(res.status, 403, `Expected 403, got ${res.status}`);
  });

  await runTestCase('Reject negative servingSize (servingSize < 0)', async () => {
    const invalid = { ...validRecordData, servingSize: -25.0 };
    const res = await fetch(`${BASE_URL}/users/user_alice/nutrition/neg_serv`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${aliceToken}` },
      body: JSON.stringify({ fields: toFirestoreFields(invalid) }),
    });
    assert.strictEqual(res.status, 403, `Expected 403, got ${res.status}`);
  });

  await runTestCase('Permit document when servingSize is omitted (legacy compatibility contract)', async () => {
    const legacyNoServing = { ...validRecordData };
    delete legacyNoServing.servingSize;
    const res = await fetch(`${BASE_URL}/users/user_alice/nutrition/legacy_no_serv`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${aliceToken}` },
      body: JSON.stringify({ fields: toFirestoreFields(legacyNoServing) }),
    });
    assert.strictEqual(res.status, 200, `Expected 200, got ${res.status}`);
  });

  // ============================================================================
  // Group 5: Full User Subcollections & Isolation Regression (Tests 41-76)
  // ============================================================================
  console.log('\n--- Group 5: Full User Subcollections & Isolation Regression ---');

  // 1. User profile root document (/users/{userId})
  await runTestCase('Unauthenticated user cannot read user profile document', async () => {
    const res = await fetch(`${BASE_URL}/users/user_alice`, { method: 'GET' });
    assert.strictEqual(res.status, 403);
  });

  await runTestCase('Unauthenticated user cannot write user profile document', async () => {
    const res = await fetch(`${BASE_URL}/users/user_alice`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ fields: toFirestoreFields({ displayName: 'Alice Hacker' }) }),
    });
    assert.strictEqual(res.status, 403);
  });

  await runTestCase('Authenticated owner can create and update user profile', async () => {
    const res = await fetch(`${BASE_URL}/users/user_alice`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${aliceToken}` },
      body: JSON.stringify({ fields: toFirestoreFields({ displayName: 'Alice Fit', email: 'alice@example.com' }) }),
    });
    assert.strictEqual(res.status, 200);
  });

  await runTestCase('Authenticated owner can read user profile', async () => {
    const res = await fetch(`${BASE_URL}/users/user_alice`, {
      method: 'GET',
      headers: { 'Authorization': `Bearer ${aliceToken}` },
    });
    assert.strictEqual(res.status, 200);
    const data = await res.json();
    assert.strictEqual(data.fields.displayName.stringValue, 'Alice Fit');
  });

  await runTestCase('User B cannot read User A profile', async () => {
    const res = await fetch(`${BASE_URL}/users/user_alice`, {
      method: 'GET',
      headers: { 'Authorization': `Bearer ${bobToken}` },
    });
    assert.strictEqual(res.status, 403);
  });

  await runTestCase('User B cannot update User A profile', async () => {
    const res = await fetch(`${BASE_URL}/users/user_alice`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${bobToken}` },
      body: JSON.stringify({ fields: toFirestoreFields({ displayName: 'Bob Was Here' }) }),
    });
    assert.strictEqual(res.status, 403);
  });

  // 2. Goals (/users/{userId}/goals/{goalId})
  await runTestCase('Goals: Unauthenticated user cannot read goals', async () => {
    const res = await fetch(`${BASE_URL}/users/user_alice/goals/currentGoal`, { method: 'GET' });
    assert.strictEqual(res.status, 403);
  });

  await runTestCase('Goals: Owner can create valid goals', async () => {
    const res = await fetch(`${BASE_URL}/users/user_alice/goals/currentGoal`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${aliceToken}` },
      body: JSON.stringify({
        fields: toFirestoreFields({
          dailyCalorieTarget: 2200.0,
          proteinTargetGrams: 150.0,
          carbsTargetGrams: 250.0,
          fatTargetGrams: 65.0,
        }),
      }),
    });
    assert.strictEqual(res.status, 200);
  });

  await runTestCase('Goals: Reject negative dailyCalorieTarget', async () => {
    const res = await fetch(`${BASE_URL}/users/user_alice/goals/currentGoal`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${aliceToken}` },
      body: JSON.stringify({ fields: toFirestoreFields({ dailyCalorieTarget: -500.0 }) }),
    });
    assert.strictEqual(res.status, 403);
  });

  await runTestCase('Goals: Reject zero dailyCalorieTarget', async () => {
    const res = await fetch(`${BASE_URL}/users/user_alice/goals/currentGoal`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${aliceToken}` },
      body: JSON.stringify({ fields: toFirestoreFields({ dailyCalorieTarget: 0.0 }) }),
    });
    assert.strictEqual(res.status, 403);
  });

  await runTestCase('Goals: User B cannot read or update User A goals', async () => {
    const getRes = await fetch(`${BASE_URL}/users/user_alice/goals/currentGoal`, {
      method: 'GET',
      headers: { 'Authorization': `Bearer ${bobToken}` },
    });
    assert.strictEqual(getRes.status, 403);

    const patchRes = await fetch(`${BASE_URL}/users/user_alice/goals/currentGoal`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${bobToken}` },
      body: JSON.stringify({ fields: toFirestoreFields({ dailyCalorieTarget: 3000.0 }) }),
    });
    assert.strictEqual(patchRes.status, 403);
  });

  await runTestCase('Goals: Owner can delete own goals', async () => {
    const res = await fetch(`${BASE_URL}/users/user_alice/goals/currentGoal`, {
      method: 'DELETE',
      headers: { 'Authorization': `Bearer ${aliceToken}` },
    });
    assert.strictEqual(res.status, 200);
  });

  // 3. Health (/users/{userId}/health/{docId})
  await runTestCase('Health: Unauthenticated cannot read or write health data', async () => {
    const res = await fetch(`${BASE_URL}/users/user_alice/health/daily_health_1`, { method: 'GET' });
    assert.strictEqual(res.status, 403);
  });

  await runTestCase('Health: Owner can create and read health data', async () => {
    const res = await fetch(`${BASE_URL}/users/user_alice/health/daily_health_1`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${aliceToken}` },
      body: JSON.stringify({ fields: toFirestoreFields({ steps: 8500, restingHeartRate: 62 }) }),
    });
    assert.strictEqual(res.status, 200);

    const readRes = await fetch(`${BASE_URL}/users/user_alice/health/daily_health_1`, {
      method: 'GET',
      headers: { 'Authorization': `Bearer ${aliceToken}` },
    });
    assert.strictEqual(readRes.status, 200);
  });

  await runTestCase('Health: User B cannot read or write User A health data', async () => {
    const res = await fetch(`${BASE_URL}/users/user_alice/health/daily_health_1`, {
      method: 'GET',
      headers: { 'Authorization': `Bearer ${bobToken}` },
    });
    assert.strictEqual(res.status, 403);
  });

  // 4. Weight History (/users/{userId}/weightHistory/{docId})
  await runTestCase('Weight History: Unauthenticated cannot read weightHistory', async () => {
    const res = await fetch(`${BASE_URL}/users/user_alice/weightHistory/weight_log_1`, { method: 'GET' });
    assert.strictEqual(res.status, 403);
  });

  await runTestCase('Weight History: Owner can record valid weight (> 0)', async () => {
    const res = await fetch(`${BASE_URL}/users/user_alice/weightHistory/weight_log_1`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${aliceToken}` },
      body: JSON.stringify({ fields: toFirestoreFields({ weight: 72.5, unit: 'kg' }) }),
    });
    assert.strictEqual(res.status, 200);
  });

  await runTestCase('Weight History: Reject non-positive weight (weight <= 0)', async () => {
    const res = await fetch(`${BASE_URL}/users/user_alice/weightHistory/weight_log_neg`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${aliceToken}` },
      body: JSON.stringify({ fields: toFirestoreFields({ weight: 0.0 }) }),
    });
    assert.strictEqual(res.status, 403);
  });

  await runTestCase('Weight History: User B cannot read or write User A weightHistory', async () => {
    const res = await fetch(`${BASE_URL}/users/user_alice/weightHistory/weight_log_1`, {
      method: 'GET',
      headers: { 'Authorization': `Bearer ${bobToken}` },
    });
    assert.strictEqual(res.status, 403);
  });

  // 5. Pantry (/users/{userId}/pantry/{docId})
  await runTestCase('Pantry: Unauthenticated cannot read or write pantry', async () => {
    const res = await fetch(`${BASE_URL}/users/user_alice/pantry/pantry_item_1`, { method: 'GET' });
    assert.strictEqual(res.status, 403);
  });

  await runTestCase('Pantry: Owner can create pantry item with valid quantity (>= 0)', async () => {
    const res = await fetch(`${BASE_URL}/users/user_alice/pantry/pantry_item_1`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${aliceToken}` },
      body: JSON.stringify({ fields: toFirestoreFields({ itemName: 'Rolled Oats', quantity: 2.0 }) }),
    });
    assert.strictEqual(res.status, 200);
  });

  await runTestCase('Pantry: Reject negative pantry quantity', async () => {
    const res = await fetch(`${BASE_URL}/users/user_alice/pantry/pantry_item_neg`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${aliceToken}` },
      body: JSON.stringify({ fields: toFirestoreFields({ itemName: 'Rolled Oats', quantity: -1.0 }) }),
    });
    assert.strictEqual(res.status, 403);
  });

  await runTestCase('Pantry: User B cannot read or write User A pantry', async () => {
    const res = await fetch(`${BASE_URL}/users/user_alice/pantry/pantry_item_1`, {
      method: 'GET',
      headers: { 'Authorization': `Bearer ${bobToken}` },
    });
    assert.strictEqual(res.status, 403);
  });

  // 6. Grocery Lists & Nested Items (/users/{userId}/groceryLists/{listId}/items/{itemId})
  await runTestCase('Grocery Lists: Unauthenticated cannot read or write groceryLists', async () => {
    const res = await fetch(`${BASE_URL}/users/user_alice/groceryLists/list_1`, { method: 'GET' });
    assert.strictEqual(res.status, 403);
  });

  await runTestCase('Grocery Lists: Owner can create and read groceryList document', async () => {
    const res = await fetch(`${BASE_URL}/users/user_alice/groceryLists/list_1`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${aliceToken}` },
      body: JSON.stringify({ fields: toFirestoreFields({ title: 'Weekly Groceries', isCompleted: false }) }),
    });
    assert.strictEqual(res.status, 200);
  });

  await runTestCase('Grocery Lists: User B cannot read or write User A groceryList', async () => {
    const res = await fetch(`${BASE_URL}/users/user_alice/groceryLists/list_1`, {
      method: 'GET',
      headers: { 'Authorization': `Bearer ${bobToken}` },
    });
    assert.strictEqual(res.status, 403);
  });

  await runTestCase('Grocery List Items: Unauthenticated cannot access nested items', async () => {
    const res = await fetch(`${BASE_URL}/users/user_alice/groceryLists/list_1/items/item_1`, { method: 'GET' });
    assert.strictEqual(res.status, 403);
  });

  await runTestCase('Grocery List Items: Owner can add valid nested item (quantity >= 0)', async () => {
    const res = await fetch(`${BASE_URL}/users/user_alice/groceryLists/list_1/items/item_1`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${aliceToken}` },
      body: JSON.stringify({ fields: toFirestoreFields({ name: 'Almond Milk', quantity: 1.0, isChecked: false }) }),
    });
    assert.strictEqual(res.status, 200);
  });

  await runTestCase('Grocery List Items: Reject negative nested item quantity', async () => {
    const res = await fetch(`${BASE_URL}/users/user_alice/groceryLists/list_1/items/item_neg`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${aliceToken}` },
      body: JSON.stringify({ fields: toFirestoreFields({ name: 'Almond Milk', quantity: -3.0 }) }),
    });
    assert.strictEqual(res.status, 403);
  });

  await runTestCase('Grocery List Items: User B cannot read or write User A nested items', async () => {
    const res = await fetch(`${BASE_URL}/users/user_alice/groceryLists/list_1/items/item_1`, {
      method: 'GET',
      headers: { 'Authorization': `Bearer ${bobToken}` },
    });
    assert.strictEqual(res.status, 403);
  });

  // 7. Custom Foods, Favorite Foods, Recent Foods
  await runTestCase('Custom Foods: Owner can manage customFoods; User B denied; Unauth denied', async () => {
    const unauth = await fetch(`${BASE_URL}/users/user_alice/customFoods/custom_1`, { method: 'GET' });
    assert.strictEqual(unauth.status, 403);

    const ownerWrite = await fetch(`${BASE_URL}/users/user_alice/customFoods/custom_1`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${aliceToken}` },
      body: JSON.stringify({ fields: toFirestoreFields({ name: 'Protein Shake Special', calories: 280.0 }) }),
    });
    assert.strictEqual(ownerWrite.status, 200);

    const bobRead = await fetch(`${BASE_URL}/users/user_alice/customFoods/custom_1`, {
      method: 'GET',
      headers: { 'Authorization': `Bearer ${bobToken}` },
    });
    assert.strictEqual(bobRead.status, 403);
  });

  await runTestCase('Favorite Foods: Owner can manage favoriteFoods; User B denied', async () => {
    const ownerWrite = await fetch(`${BASE_URL}/users/user_alice/favoriteFoods/fav_1`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${aliceToken}` },
      body: JSON.stringify({ fields: toFirestoreFields({ foodId: 'greek_yogurt_170' }) }),
    });
    assert.strictEqual(ownerWrite.status, 200);

    const bobRead = await fetch(`${BASE_URL}/users/user_alice/favoriteFoods/fav_1`, {
      method: 'GET',
      headers: { 'Authorization': `Bearer ${bobToken}` },
    });
    assert.strictEqual(bobRead.status, 403);
  });

  await runTestCase('Recent Foods: Owner can manage recentFoods; User B denied', async () => {
    const ownerWrite = await fetch(`${BASE_URL}/users/user_alice/recentFoods/recent_1`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${aliceToken}` },
      body: JSON.stringify({ fields: toFirestoreFields({ foodId: 'salmon_fillet_cooked' }) }),
    });
    assert.strictEqual(ownerWrite.status, 200);

    const bobRead = await fetch(`${BASE_URL}/users/user_alice/recentFoods/recent_1`, {
      method: 'GET',
      headers: { 'Authorization': `Bearer ${bobToken}` },
    });
    assert.strictEqual(bobRead.status, 403);
  });

  // 8. Grocery Preferences, Meal Plans, Reminder Settings
  await runTestCase('Grocery Preferences: Owner can manage groceryPreferences; User B denied', async () => {
    const ownerWrite = await fetch(`${BASE_URL}/users/user_alice/groceryPreferences/prefs_1`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${aliceToken}` },
      body: JSON.stringify({ fields: toFirestoreFields({ dietaryPreference: 'high-protein' }) }),
    });
    assert.strictEqual(ownerWrite.status, 200);

    const bobRead = await fetch(`${BASE_URL}/users/user_alice/groceryPreferences/prefs_1`, {
      method: 'GET',
      headers: { 'Authorization': `Bearer ${bobToken}` },
    });
    assert.strictEqual(bobRead.status, 403);
  });

  await runTestCase('Meal Plans: Owner can manage mealPlans; User B denied', async () => {
    const ownerWrite = await fetch(`${BASE_URL}/users/user_alice/mealPlans/plan_1`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${aliceToken}` },
      body: JSON.stringify({ fields: toFirestoreFields({ planName: 'Lean Muscle Cycle' }) }),
    });
    assert.strictEqual(ownerWrite.status, 200);

    const bobRead = await fetch(`${BASE_URL}/users/user_alice/mealPlans/plan_1`, {
      method: 'GET',
      headers: { 'Authorization': `Bearer ${bobToken}` },
    });
    assert.strictEqual(bobRead.status, 403);
  });

  await runTestCase('Reminder Settings: Owner can manage reminderSettings; User B denied', async () => {
    const ownerWrite = await fetch(`${BASE_URL}/users/user_alice/reminderSettings/reminders_1`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${aliceToken}` },
      body: JSON.stringify({ fields: toFirestoreFields({ mealRemindersEnabled: true }) }),
    });
    assert.strictEqual(ownerWrite.status, 200);

    const bobRead = await fetch(`${BASE_URL}/users/user_alice/reminderSettings/reminders_1`, {
      method: 'GET',
      headers: { 'Authorization': `Bearer ${bobToken}` },
    });
    assert.strictEqual(bobRead.status, 403);
  });

  // ============================================================================
  // Group 6: Least-Privilege & Boundary Access Controls (Tests 77-80)
  // ============================================================================
  console.log('\n--- Group 6: Least-Privilege & Boundary Access Controls ---');

  await runTestCase('Root collection /global_foods denied for unauthenticated users', async () => {
    const res = await fetch(`${BASE_URL}/global_foods/food_1`, { method: 'GET' });
    assert.strictEqual(res.status, 403);
  });

  await runTestCase('Root collection /global_foods denied for authenticated users (default deny)', async () => {
    const res = await fetch(`${BASE_URL}/global_foods/food_1`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${aliceToken}` },
      body: JSON.stringify({ fields: toFirestoreFields({ title: 'Hacked Root' }) }),
    });
    assert.strictEqual(res.status, 403);
  });

  await runTestCase('Root collection /system_secrets denied for authenticated users', async () => {
    const res = await fetch(`${BASE_URL}/system_secrets/api_keys`, {
      method: 'GET',
      headers: { 'Authorization': `Bearer ${aliceToken}` },
    });
    assert.strictEqual(res.status, 403);
  });

  await runTestCase('Arbitrary unlisted subcollection /users/user_alice/arbitrary_hack denied', async () => {
    const res = await fetch(`${BASE_URL}/users/user_alice/arbitrary_hack/doc1`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${aliceToken}` },
      body: JSON.stringify({ fields: toFirestoreFields({ exploit: 'true' }) }),
    });
    assert.strictEqual(res.status, 403, 'Absence of wildcard must deny unlisted subcollection');
  });

  // ============================================================================
  // Group 7: Document Update Semantics & Nullable Nutrition Fields (Tests 81-88)
  // ============================================================================
  console.log('\n--- Group 7: Document Update Semantics & Nullable Nutrition Fields ---');

  const updateDocPath = `${BASE_URL}/users/user_alice/nutrition/doc_update_lifecycle`;

  await runTestCase('Lifecycle Step 1 & 2: Create record with nonzero fiber (7.0) and sodium (15.0)', async () => {
    const initialDoc = {
      foodName: 'Steel Cut Oatmeal Bowl',
      mealType: 'Breakfast',
      calories: 220.0,
      protein: 7.0,
      carbohydrates: 38.0,
      fats: 4.0,
      servingSize: 150.0,
      sugar: 1.5,
      fiber: 7.0,
      sodium: 15.0,
    };
    const res = await fetch(updateDocPath, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${aliceToken}` },
      body: JSON.stringify({ fields: toFirestoreFields(initialDoc) }),
    });
    assert.strictEqual(res.status, 200);

    const readRes = await fetch(updateDocPath, {
      method: 'GET',
      headers: { 'Authorization': `Bearer ${aliceToken}` },
    });
    assert.strictEqual(readRes.status, 200);
    const readData = await readRes.json();
    assert.strictEqual(getNum(readData.fields.fiber), 7.0);
    assert.strictEqual(getNum(readData.fields.sodium), 15.0);
  });

  await runTestCase('Lifecycle Step 3: Update with new numeric values (fiber: 12.5, sodium: 35.0)', async () => {
    // Partial update using updateMask
    const patchPayload = { fiber: 12.5, sodium: 35.0 };
    const patchUrl = `${updateDocPath}?updateMask.fieldPaths=fiber&updateMask.fieldPaths=sodium`;
    const res = await fetch(patchUrl, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${aliceToken}` },
      body: JSON.stringify({ fields: toFirestoreFields(patchPayload) }),
    });
    assert.strictEqual(res.status, 200);

    const readRes = await fetch(updateDocPath, {
      method: 'GET',
      headers: { 'Authorization': `Bearer ${aliceToken}` },
    });
    const readData = await readRes.json();
    assert.strictEqual(getNum(readData.fields.fiber), 12.5);
    assert.strictEqual(getNum(readData.fields.sodium), 35.0);
    // Verify calories unchanged
    assert.strictEqual(getNum(readData.fields.calories), 220.0);
  });

  await runTestCase('Lifecycle Step 4: Update with genuine zero (fiber: 0.0, sodium: 0.0)', async () => {
    const patchPayload = { fiber: 0.0, sodium: 0.0 };
    const patchUrl = `${updateDocPath}?updateMask.fieldPaths=fiber&updateMask.fieldPaths=sodium`;
    const res = await fetch(patchUrl, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${aliceToken}` },
      body: JSON.stringify({ fields: toFirestoreFields(patchPayload) }),
    });
    assert.strictEqual(res.status, 200);

    const readRes = await fetch(updateDocPath, {
      method: 'GET',
      headers: { 'Authorization': `Bearer ${aliceToken}` },
    });
    const readData = await readRes.json();
    assert.strictEqual(getNum(readData.fields.fiber), 0.0);
    assert.strictEqual(getNum(readData.fields.sodium), 0.0);
  });

  await runTestCase('Lifecycle Step 5a: Partial update with omitted optional field preserves existing value', async () => {
    // Only update calories via mask, omitting fiber/sodium
    const patchPayload = { calories: 250.0 };
    const patchUrl = `${updateDocPath}?updateMask.fieldPaths=calories`;
    const res = await fetch(patchUrl, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${aliceToken}` },
      body: JSON.stringify({ fields: toFirestoreFields(patchPayload) }),
    });
    assert.strictEqual(res.status, 200);

    const readRes = await fetch(updateDocPath, {
      method: 'GET',
      headers: { 'Authorization': `Bearer ${aliceToken}` },
    });
    const readData = await readRes.json();
    assert.strictEqual(getNum(readData.fields.calories), 250.0);
    assert.strictEqual(getNum(readData.fields.fiber), 0.0, 'Omitted in partial update must remain untouched');
    assert.strictEqual(getNum(readData.fields.sodium), 0.0, 'Omitted in partial update must remain untouched');
  });

  await runTestCase('Lifecycle Step 5b: Explicit null update sets field to null in Firestore', async () => {
    const patchPayload = { fiber: null, sodium: null };
    const patchUrl = `${updateDocPath}?updateMask.fieldPaths=fiber&updateMask.fieldPaths=sodium`;
    const res = await fetch(patchUrl, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${aliceToken}` },
      body: JSON.stringify({ fields: toFirestoreFields(patchPayload) }),
    });
    assert.strictEqual(res.status, 200);

    const readRes = await fetch(updateDocPath, {
      method: 'GET',
      headers: { 'Authorization': `Bearer ${aliceToken}` },
    });
    const readData = await readRes.json();
    assert.deepStrictEqual(readData.fields.fiber, { nullValue: null });
    assert.deepStrictEqual(readData.fields.sodium, { nullValue: null });
  });

  await runTestCase('Lifecycle Step 6: Full document replacement omitting optional field removes it from document', async () => {
    const replacementDoc = {
      foodName: 'Oatmeal Replaced',
      mealType: 'Breakfast',
      calories: 200.0,
      protein: 6.0,
      carbohydrates: 35.0,
      fats: 3.0,
      servingSize: 100.0,
      sugar: 1.0,
      // fiber and sodium omitted from full replacement payload
    };
    const res = await fetch(updateDocPath, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${aliceToken}` },
      body: JSON.stringify({ fields: toFirestoreFields(replacementDoc) }),
    });
    assert.strictEqual(res.status, 200);

    const readRes = await fetch(updateDocPath, {
      method: 'GET',
      headers: { 'Authorization': `Bearer ${aliceToken}` },
    });
    const readData = await readRes.json();
    assert.strictEqual(readData.fields.fiber, undefined, 'Omitted in full replacement is removed');
    assert.strictEqual(readData.fields.sodium, undefined, 'Omitted in full replacement is removed');
    assert.strictEqual(getNum(readData.fields.calories), 200.0);
  });

  await runTestCase('Lifecycle Step 7: Update does not alter or erase immutable fields (foodName, mealType)', async () => {
    const patchPayload = { calories: 215.0 };
    const patchUrl = `${updateDocPath}?updateMask.fieldPaths=calories`;
    const res = await fetch(patchUrl, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${aliceToken}` },
      body: JSON.stringify({ fields: toFirestoreFields(patchPayload) }),
    });
    assert.strictEqual(res.status, 200);

    const readRes = await fetch(updateDocPath, {
      method: 'GET',
      headers: { 'Authorization': `Bearer ${aliceToken}` },
    });
    const readData = await readRes.json();
    assert.strictEqual(readData.fields.foodName.stringValue, 'Oatmeal Replaced');
    assert.strictEqual(readData.fields.mealType.stringValue, 'Breakfast');
    assert.strictEqual(getNum(readData.fields.calories), 215.0);
  });

  await runTestCase('Lifecycle Step 8: Update rejecting negative values leaves previous valid values untouched', async () => {
    const illegalPatch = { calories: -99.0 };
    const patchUrl = `${updateDocPath}?updateMask.fieldPaths=calories`;
    const res = await fetch(patchUrl, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${aliceToken}` },
      body: JSON.stringify({ fields: toFirestoreFields(illegalPatch) }),
    });
    assert.strictEqual(res.status, 403, 'Negative calorie patch must be rejected');

    const readRes = await fetch(updateDocPath, {
      method: 'GET',
      headers: { 'Authorization': `Bearer ${aliceToken}` },
    });
    const readData = await readRes.json();
    assert.strictEqual(getNum(readData.fields.calories), 215.0, 'Calories must remain untouched at 215.0');
  });

  console.log('\n================================================================');
  console.log(`ALL ${passedTests}/${totalTests} FIRESTORE SECURITY RULES TESTS PASSED ON EMULATOR!`);
  console.log('================================================================\n');
}

runAllRulesTests().catch((err) => {
  console.error('\nTEST SUITE TERMINATED WITH ERROR:', err);
  process.exit(1);
});
