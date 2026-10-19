# Shopping-bag persisted r01 parser failure

The audit and all 255 Node tests exited successfully. The Node spec reporter emitted information-symbol summary lines, while the root wrapper recognized only TAP comment lines. Its counter parser produced NaN values, so the wrapper correctly retained an unsuccessful overall receipt. The original output and failure are unchanged.

Root independently checked both logs, all 308 journal states and transitions, 153 installed/staged targets, four backups and the absent transaction lock. This does not relabel the wrapper as successful. A separate r02 source corrects only summary parsing and requires fresh independent review before dispatch. No native probe or historical entrypoint was replayed.

Original receipt SHA256: `8680e417f593aa1e04225e258b9390e1cb944c7d91cf378288ff19011de2204d`. Exact 11-file copy receipt SHA256: `12ab287773dca29de5c0372ac538e688939a35df51c6cfc984db55b2267282fb`.
