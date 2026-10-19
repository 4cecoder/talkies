# Agent connector fixtures

Recorded tool output that drives the connector fakes, so connector tests never need the real
tool running. See
[companion devices and voice agent control](../../../docs/architecture/companion-and-agent-control.md)
for the connector contract.

## cmux

Recorded from cmux 0.65.0 (`cmux 0.65.0 (108) [dda24fbd2]`) and then sanitized: workspace and
surface titles, paths, notification bodies, and UUIDs were replaced. Every field cmux emitted is
kept, including fields Talkies ignores, so a parser that rejects unknown keys would fail here.

| File | Command |
|---|---|
| `cmux/tree-all.json` | `cmux --json --id-format uuids tree --all` |
| `cmux/input-states.json` | `cmux rpc surface.input_state '{"surface_id":"…"}'` for each surface in the tree, keyed by surface UUID |
| `cmux/list-notifications.json` | `cmux --json --id-format uuids list-notifications` |
| `cmux/cli-errors.json` | Standard error of failed calls, with the connector error each maps to |

The field set of `input_state` (`agent`, `blocks_typing`, `lifecycle`, `state`, `surface_id`,
`terminal`, `waiting_on_human`, `workspace_id`) was observed live. The live session had only
`empty` and `unknown` states, so the `draft`, `dialog`, and `needsInput` values follow cmux's
documented `input_state` contract. In `cli-errors.json`, entries with `"observed": false` use
error strings from the cmux 0.65.0 binary that were not triggered live.
