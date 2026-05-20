/**
 * Firestore security rules tests for Manhunt catch + presence paths.
 *
 * Run from repo root:
 *   cd rules-tests && npm install && npm test
 */

const { readFileSync } = require("node:fs");
const { resolve } = require("node:path");
const { before, after, describe, it } = require("node:test");
const assert = require("node:assert/strict");

const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require("@firebase/rules-unit-testing");

const RULES_PATH = resolve(__dirname, "../firestore.rules");
const PROJECT_ID = "touch-grass-rules-test";

let testEnv;

function sessionBase(overrides = {}) {
  return {
    id: "session-1",
    hostId: "host-auth",
    hostAuthUid: "host-auth",
    hostPlayerId: "host-player",
    gameState: "active",
    gameType: "manhunt",
    joinCode: "123456",
    catchDistance: 10,
    hunterCount: 1,
    gameNumber: 1,
    players: [],
    playerIds: [],
    memberAuthUids: [],
    playerAuthByPlayerId: {},
    ...overrides,
  };
}

function player(id, authUserId, role, isAlive = true) {
  return {
    id,
    authUserId,
    displayName: id,
    latitude: 37.77,
    longitude: -122.42,
    role,
    isAlive,
    lastUpdated: Date.now() / 1000,
  };
}

function roster(players) {
  const playerIds = players.map((p) => p.id);
  const memberAuthUids = [...new Set(players.map((p) => p.authUserId))];
  const playerAuthByPlayerId = Object.fromEntries(
    players.map((p) => [p.id, p.authUserId])
  );
  return { players, playerIds, memberAuthUids, playerAuthByPlayerId };
}

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: readFileSync(RULES_PATH, "utf8"),
      host: "127.0.0.1",
      port: 8080,
    },
  });
});

after(async () => {
  await testEnv?.cleanup();
});

describe("Manhunt member catch updates", () => {
  const hostPlayer = player("host-player", "host-auth", "hider");
  const hunterPlayer = player("hunter-player", "hunter-auth", "hunter");
  const hiderTarget = player("hider-target", "hider-auth", "hider");
  const players = [hostPlayer, hunterPlayer, hiderTarget];
  const rosterFields = roster(players);

  before(async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().doc("sessions/session-1").set(
        sessionBase({
          ...rosterFields,
          firstTaggedPlayerId: null,
        })
      );
    });
  });

  it("allows non-host hunter first catch when host is a hider", async () => {
    const db = testEnv.authenticatedContext("hunter-auth").firestore();
    const deadHider = { ...hiderTarget, isAlive: false };
    const ref = db.doc("sessions/session-1");

    await assertSucceeds(
      ref.update({
        players: [hostPlayer, hunterPlayer, deadHider],
        firstTaggedPlayerId: "hider-target",
      })
    );

    const snap = await ref.get();
    assert.equal(snap.data().firstTaggedPlayerId, "hider-target");
    assert.equal(
      snap.data().players.find((p) => p.id === "hider-target").isAlive,
      false
    );
  });

  it("allows second catch by another hunter", async () => {
    const secondHider = player("hider-two", "hider-two-auth", "hider");
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const snap = await context.firestore().doc("sessions/session-1").get();
      const data = snap.data();
      data.players.push(secondHider);
      data.playerIds.push(secondHider.id);
      data.memberAuthUids.push(secondHider.authUserId);
      data.playerAuthByPlayerId[secondHider.id] = secondHider.authUserId;
      await context.firestore().doc("sessions/session-1").set(data);
    });

    const db = testEnv.authenticatedContext("hunter-auth").firestore();
    const dead = { ...secondHider, isAlive: false };
    const snap = await db.doc("sessions/session-1").get();
    const data = snap.data();
    const updatedPlayers = data.players.map((p) =>
      p.id === secondHider.id ? dead : p
    );

    await assertSucceeds(
      db.doc("sessions/session-1").update({
        players: updatedPlayers,
        firstTaggedPlayerId: data.firstTaggedPlayerId,
      })
    );
  });

  it("allows hider honor first tag (self only)", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().doc("sessions/session-1").set(
        sessionBase({
          ...roster([
            hostPlayer,
            hunterPlayer,
            player("solo-hider", "solo-hider-auth", "hider"),
          ]),
          firstTaggedPlayerId: null,
        })
      );
    });

    const solo = player("solo-hider", "solo-hider-auth", "hider");
    const db = testEnv.authenticatedContext("solo-hider-auth").firestore();
    const dead = { ...solo, isAlive: false };

    await assertSucceeds(
      db.doc("sessions/session-1").update({
        players: [hostPlayer, hunterPlayer, dead],
        firstTaggedPlayerId: "solo-hider",
      })
    );
  });

  it("denies hider marking another hider dead", async () => {
    const db = testEnv.authenticatedContext("solo-hider-auth").firestore();
    const snap = await db.doc("sessions/session-1").get();
    const data = snap.data();
    const victim = data.players.find((p) => p.id === "hider-target") || hiderTarget;
    const deadOther = { ...victim, isAlive: false };

    await assertFails(
      db.doc("sessions/session-1").update({
        players: data.players.map((p) =>
          p.id === victim.id ? deadOther : p
        ),
        firstTaggedPlayerId: victim.id,
      })
    );
  });

  it("denies non-member catch write", async () => {
    const db = testEnv.authenticatedContext("outsider-auth").firestore();
    const deadHider = { ...hiderTarget, isAlive: false };

    await assertFails(
      db.doc("sessions/session-1").update({
        players: [hostPlayer, hunterPlayer, deadHider],
        firstTaggedPlayerId: "hider-target",
      })
    );
  });
});

describe("Member presence updates", () => {
  it("allows member to update players heartbeat fields", async () => {
    const p = player("p1", "member-auth", "hider");
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().doc("sessions/presence-1").set(
        sessionBase({
          gameState: "active",
          ...roster([p]),
        })
      );
    });

    const db = testEnv.authenticatedContext("member-auth").firestore();
    const bumped = {
      ...p,
      lastUpdated: Date.now() / 1000 + 60,
    };

    await assertSucceeds(
      db.doc("sessions/presence-1").update({
        players: [bumped],
        playerIds: ["p1"],
        memberAuthUids: ["member-auth"],
        playerAuthByPlayerId: { p1: "member-auth" },
      })
    );
  });
});
