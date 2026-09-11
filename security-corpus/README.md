# MoonMIME synthetic security corpus

This repository-authored corpus makes the security claims reproducible without
redistributing private mail or third-party payloads. Every message uses reserved
`.test` domains and contains no executable body. `manifest.tsv` records the
expected minimum finding for six adversarial patterns and four benign controls.

Run `bash scripts/evaluate-security-corpus.sh`. A passing run must report
`TP=6 TN=4 FP=0 FN=0`. These figures measure this labelled synthetic corpus only;
they are not a claim about all email traffic or malware detection.

