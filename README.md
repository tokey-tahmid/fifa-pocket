# fifa-pocket

## Test Plan

### Deck Builder
- Verify card library filters update card list when search text, position, or rarity changes.
- Confirm dragging cards into deck slots fills the squad, prevents duplicates, and updates squad overview metrics.
- Ensure save and clear actions persist the selected deck via `DeckManager` and reset the UI state without errors.

### Match Flow
- Start a match and observe automatic phase transitions (draw, tactic selection, resolution, cleanup) occur on timer completion.
- Validate player and opponent selections adjust energy pools, trigger tactic summaries, and update score/round counters.
- Check match completion displays the end dialog, awards coins/packs appropriately, and resets celebrations for a new match.

### Progression
- Confirm player profile initialization creates default decks and owned cards when none exist.
- Simulate match rewards to verify coins and card packs increment the profile and unlock new cards in the collection dialog.
- Test tutorial flags to ensure first-run guidance for deck builder and match flow only appears once per profile.
