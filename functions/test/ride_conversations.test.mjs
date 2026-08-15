import assert from "node:assert/strict";
import test from "node:test";

import {
  canonicalRideConversationId,
  selectMostRecentRideConversation,
} from "../lib/chat_conversations.js";

test("ride pair IDs are stable regardless of caller order", () => {
  const first = canonicalRideConversationId("passenger-1", "driver-1");
  const reverse = canonicalRideConversationId("driver-1", "passenger-1");
  const different = canonicalRideConversationId("passenger-1", "driver-2");

  assert.equal(first, reverse);
  assert.match(first, /^ride_pair_[a-f0-9]{40}$/);
  assert.notEqual(first, different);
});

test("the most recently active existing ride conversation is selected", () => {
  const selected = selectMostRecentRideConversation([
    {id: "ride_old", activityAtMillis: 100},
    {id: "ride_latest", activityAtMillis: 300},
    {id: "ride_middle", activityAtMillis: 200},
  ]);

  assert.equal(selected?.id, "ride_latest");
});

test("conversation ID provides a deterministic activity tie-breaker", () => {
  const selected = selectMostRecentRideConversation([
    {id: "ride_b", activityAtMillis: 300},
    {id: "ride_a", activityAtMillis: 300},
  ]);

  assert.equal(selected?.id, "ride_a");
  assert.equal(selectMostRecentRideConversation([]), undefined);
});
