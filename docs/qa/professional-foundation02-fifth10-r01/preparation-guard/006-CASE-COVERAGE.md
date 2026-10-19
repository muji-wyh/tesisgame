# Frozen r03 guard coverage

All cases are planned and unexecuted. Two positives cover the genuine baseline and exact explicitly bound committed/prepared copies for both predecessors.

| Frozen specification | Variants | Intended rejection |
| --- | ---: | --- |
| reviewer_missing | 1 | Named reviewer type |
| reviewer_empty | 1 | Nonempty exact reviewer |
| reviewer_whitespace | 2 | Whitespace-only and padded identity |
| reviewer_current_author | 1 | Current author, with all role fields aligned |
| reviewer_inherited_author | 1 | Inherited author, with all role fields aligned |
| reviewer_dispatcher | 1 | Root is not a canonical independent agent |
| reviewer_role_mismatch | 1 | Valid reviewer differs from binding |
| review_pin_identity_mismatch | 4 | Binding/inventory path or byte length differs with retained digest |
| unrelated_committed_journal | 1 | Different genuine selected state identity |
| changed_state_hash | 1 | Correctly rehashed changed state differs from receipt |
| changed_prepared_identity | 1 | Rebound state has another prepared identity |
| changed_plan_identity | 2 | Inner plan bytes and receipt/prepared plan identities |
| partial_prepared_manifest | 1 | Rehashed smaller plan differs from full receipt manifest |
| partial_installed_targets | 1 | Durable evidence target outside five named files is omitted |
| extra_installed_target | 1 | Unrelated genuine pin is not a committed target |
| duplicate_installed_target | 2 | Exact and case-insensitive duplicates |
| wrong_installed_bytes_or_hash | 2 | Byte length and valid hash differ from manifest |
| changed_installed_file | 1 | Intentional stale current-byte pin |
| unbound_journal_copy | 1 | Exact copies without mapping rows |
| changed_journal_copy | 1 | Rebound copy reaches original/copy byte inequality |
| unused_journal_alias | 1 | Mapping without selected copy |
| wrong_bag_receipt_schema | 2 | Wrong schema identifier and invented nested result |
| wrong_bag_persisted_input | 2 | Correctly rehashed input/source differ from receipt identity |
| persisted_commit_or_state_mismatch | 2 | Rebound input names another commit path or state hash |
| persisted_target_omission | 2 | Omitted target and changed afterimage hash |
| persisted_command_failure | 4 | Exit, error, signal and rehashed changed log |
| persisted_postcheck_failure | 4 | Postcheck error and fail/cancelled/skipped counters |
| later_journal_state | 2 | Initial admission and session recheck |
| unbound_template | 2 | Untouched root-input and binding templates |

These 48 variants are separate from three additional controls: malformed root-input digest syntax, a valid digest for different root-input bytes, and malformed binding-pin digest syntax.

The runner requires all 29 frozen IDs and verifies each rejection at the exact first assertion line and the column span of the selected single assertion in frozen binding.cjs. Necessary fixture pins are rebound to isolate semantic checks. Synthetic fixture documents and acceptances are never written to disk.
