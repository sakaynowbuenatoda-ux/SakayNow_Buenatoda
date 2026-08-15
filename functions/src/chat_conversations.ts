import {createHash} from "node:crypto";

export type RideConversationCandidate = {
  id: string;
  activityAtMillis: number;
};

export function canonicalRideConversationId(
  passengerId: string,
  driverId: string,
) {
  const participantIds = [passengerId, driverId].sort();
  const digest = createHash("sha256")
    .update(JSON.stringify(participantIds))
    .digest("hex")
    .slice(0, 40);
  return `ride_pair_${digest}`;
}

export function selectMostRecentRideConversation<
  T extends RideConversationCandidate,
>(candidates: T[]) {
  if (candidates.length === 0) {
    return undefined;
  }

  return [...candidates].sort((left, right) => {
    const activityComparison =
      right.activityAtMillis - left.activityAtMillis;
    if (activityComparison !== 0) {
      return activityComparison;
    }

    return left.id.localeCompare(right.id);
  })[0];
}
