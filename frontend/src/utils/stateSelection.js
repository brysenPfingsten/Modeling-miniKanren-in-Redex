export const hasStateSelection = stateId => stateId !== null && stateId !== undefined;

export const deriveStateSelectionUpdate = ({ substitutionData, trailData, sId, hasStateId }) => {
  if (!hasStateId) return null;

  return {
    substitutionData,
    trailData,
    stateId: sId,
  };
};
