# Six held Foundation02 entries: source ledger

Status: research only, unaccepted. Researcher: AI language-delivery agent. Consultation date: October 17, 2026, Asia/Shanghai (fresh HTTP timestamps are October 16 UTC). No human, independent linguistic, specialist, visual or listening acceptance is recorded here.

## Retrieval and reuse boundaries

- `fresh-http-retrieval.json` records eight new successful HTTP requests, raw response byte counts/hashes and selected metadata/CSV rows. Full remote documents were held transiently for inspection and were not saved. Matching an older hash does not make the new retrieval historical.
- The dictionary bodies below were inspected through fresh web retrieval. Selected Oxford raw sense tags were also freshly fetched. The `cefr` and `fkcefr` attributes are distinguished exactly. Footer word-of-the-day levels are unrelated and excluded.
- `retained-reviews/` contains exact copies of the three earlier local hold reviews. Those are historical decisions, not fresh source retrieval or superseded acceptance. `input-pins.json` maps their original paths and hashes.
- Dictionary and lesson publishers retain their content rights. Only short factual metadata and original summaries are retained; no artwork, recording, worksheet, or right to redistribute publisher content was acquired. Links are reference consultations, not production media licenses.
- Cambridge Dictionary requests listed under failures did not produce an inspected entry. Search snippets are leads only. Lesson level, headword/POS level and selected-sense level are different kinds of evidence.

## Fresh dictionary consultations

| ID | Source and selected scope | Fresh observation | Limit |
| --- | --- | --- | --- |
| O-collect | [Oxford: collect](https://www.oxfordlearnersdictionaries.com/definition/english/collect_1), senses 1 and 4 | Gathering from multiple people/places is separate from fetching/taking away. Fresh tags: `collect_sng_2`, `cefr=a2`; `collect_sng_6`, `cefr=b1`. Reception pickup occurs in sense 4. Person-pickup examples specifically carry British labels. | Neither sense merges the current mixed definition. The A2 hobby sense is separate. Object pickup is not assigned a British-only label in the inspected Oxford section. |
| C-collect | [Collins: collect](https://www.collinsdictionary.com/dictionary/english/collect), COBUILD senses 1 and 3 | Gathering is B1. Fetching a person/item is A2, marked British, with an American preference for pick up. American dictionary sections on the same page also include fetching. | Preserve the cross-source regional nuance. Do not conclude pickup is impossible in American English, or transfer the hobby level to gathering. |
| O-notify | [Oxford: notify](https://www.oxfordlearnersdictionaries.com/definition/english/notify), formal communication | Official/formal communication to a person; patterns include person + of + information and person + that clause. Fresh `notify_sng_1` has `fkcefr=c1`. | No inspected A2-B2 selected-sense level. |
| C-notify | [Collins: notify](https://www.collinsdictionary.com/dictionary/english/notify), COBUILD formal communication | Official informing sense and person + of/about patterns support the present meaning. | No level printed beside this selected COBUILD sense. Meaning support does not establish B2 placement. |
| O-postpone | [Oxford: postpone](https://www.oxfordlearnersdictionaries.com/definition/english/postpone), rescheduling | Moving an arranged activity to a later time; noun and -ing complements, with until/to patterns. Fresh `postpone_sng_1` has `fkcefr=c1`; the Working life topic also shows C1. | C1 remains source evidence even if another source supports a lower editorial placement. |
| C-postpone | [Collins: postpone](https://www.collinsdictionary.com/dictionary/english/postpone), COBUILD planned-event sense | Explicit literal label B1+ beside the selected planned-event sense. | B1+ is retained verbatim as a source label; it is not automatically rounded or rewritten as B1/B2. |
| O-verify | [Oxford: verify](https://www.oxfordlearnersdictionaries.com/definition/english/verify), sense 1 | Accuracy/truth established by checking. Fresh `verify_sng_1` has `cefr=c1`. Separate confirming/stating sense `verify_sng_2` also has `cefr=c1`. | Do not use confirming as a substitute for evidence checking or borrow an unrelated footer B2. |
| C-verify | [Collins: verify](https://www.collinsdictionary.com/dictionary/english/verify), COBUILD senses 1 and 2 | Examination-based checking is separate from declaring/confirming truth. A clerical matching example supports the current order-record context. | Neither selected sense displays a level. |
| O-unsafe | [Oxford: unsafe](https://www.oxfordlearnersdictionaries.com/definition/english/unsafe), sense 1 | A thing/place/activity can present danger. The sense for a person in danger and the British legal sense are separate. | Fresh `unsafe_sng_1` has neither `cefr` nor `fkcefr`. No level is inferred from the footer or transparent morphology. |
| C-unsafe | [Collins: unsafe](https://www.collinsdictionary.com/dictionary/english/unsafe), COBUILD sense 1 | The selected sense includes buildings, machines, activities and areas that present danger. | No selected level. Personal vulnerability and legal-evidence senses remain excluded. |
| O-hazard | [Oxford: hazard](https://www.oxfordlearnersdictionaries.com/definition/english/hazard_1), noun | A potential cause of danger/damage; safety and health collocations support the broad noun meaning. Fresh `hazard_sng_1` has `fkcefr=c1`; Danger topic C1. | This is `fkcefr`, not `cefr`. It is language evidence, not safety approval. |
| C-hazard | [Collins: hazard](https://www.collinsdictionary.com/dictionary/english/hazard), COBUILD count noun | Potential danger to health/safety is within the noun meaning. | No selected level; the noun must not be confused with the guessing verb. |
| O-inform | [Oxford: inform](https://www.oxfordlearnersdictionaries.com/definition/english/inform), sense 1 | Giving information, particularly officially, supports an alternative to notify in a workplace change message. The selected sense is associated with a B2 topic. | Fresh rendered page inspected; no fresh raw tag was acquired for inform. The other senses (influence; learn for oneself; inform on) are excluded. |
| C-inform | [Collins: inform](https://www.collinsdictionary.com/dictionary/english/inform), COBUILD sense 1 | Telling someone information; literal B1+ label, and person + of/that patterns. | B1+ remains literal. Inform is a possible new headword, not an accepted alias or silent renaming of notify. |

## Fresh profile evidence

P-CSV: [CEFR-J Vocabulary Profile v1.5 CSV](https://raw.githubusercontent.com/openlanguageprofiles/olp-en-cefrj/master/cefrj-vocabulary-profile-1.5.csv), provided by Open Language Profiles from the CEFR-J project. Fresh HTTP 200; 233,214 bytes; SHA256 `b0dd3c635f1c9a4fdf1490c7e5b7c48e8bbe55b652ad0c9860a95f98e10ae498`. Exact selected rows are retained in `fresh-http-retrieval.json` with one-based physical line numbers:

| Headword | POS | Profile label | Physical line |
| --- | --- | --- | ---: |
| collect | verb | A1 | 1258 |
| postpone | verb | B2 | 5160 |
| unsafe | adjective | B2 | 7341 |
| hazard | noun | B1 | 3155 |
| inform | verb | B1 | 3499 |

Exact headword searches for notify, verify and double-check returned no row in this file. This does not prove absence from other lists or establish an above-B2 level. Other exploratory rows are retained as leads only. Rows supply headword/POS placement, without sense IDs or a productive-mastery guarantee. The collect A1 row does not resolve its sense mismatch.

P-TERMS: [Open Language Profiles README](https://raw.githubusercontent.com/openlanguageprofiles/olp-en-cefrj/master/README.md). Fresh HTTP 200; 1,956 bytes; SHA256 `8b69f7366fa3c7be328cb9ba02ceb7b3725697f36125bb75b85131d664b5e359`. Copyright is held by Tono Laboratory at Tokyo University of Foreign Studies. Its stated terms permit research and commercial use without charge with proper citation. The README's CC BY-SA 4.0 license belongs to the separate Octanove C1/C2 dataset; it must not be assigned to this CEFR-J file.

Citation for the actual rows: *The CEFR-J Wordlist Version 1.5. Compiled by Yukio Tono, Tokyo University of Foreign Studies. Accessed October 17, 2026 via the Open Language Profiles v1.5 CSV.* This is not a v1.6 citation.

P-METHOD: [CEFR-J official download/methodology page](https://www.cefr-j.org/download.html), freshly inspected. The method uses regional textbook corpora grouped approximately by CEFR, with English Vocabulary Profile supplementation. Entries are headword/POS pairs, and the stated scope includes recognition vocabulary through B2. The page advertises v1.6 dated March 24, 2020. **The v1.6 workbook was not acquired or inspected.** No claim that a selected v1.5 row is unchanged in v1.6 is made. The source notice and license were summarized in English; the non-English page was not copied into this packet.

## Fresh lesson and context consultations

L-HAZARD: [British Council: Joining the British Army in the First World War](https://www.teachingenglish.org.uk/teaching-resources/teaching-secondary/uk-history-and-literature/first-world-war/joining-british). The editorial-team page labels this lesson B2 for ages 13 to adult. Task 2B explicitly teaches hazard as a potential cause of accidents, in a mining-risk reading context. This is concrete evidence of teaching the selected broad noun sense within a B2 lesson. It is not a universal per-word B2 certification or an occupational safety review. No war text, poster, worksheet, or illustration is proposed for the game or downloaded.

L-NOTIFY: [British Council: How to prepare for a job interview in English](https://learnenglish.britishcouncil.org/level/improve-your-english-level/how-prepare-job-interview-english). The author provides a question asking when candidates will be notified about interview results. The page's Language level section includes A2, B1, B2 **and C1**. It demonstrates authentic workplace usage, but this wide article-level tagging cannot resolve notify's selected C1 label or justify a B2 gate by itself. Reader comments are excluded.

L-SAFETY: [The English Flows: Workplace health and safety](https://theenglishflows.com/lesson-plans/workplace-health-and-safety/). The public outline labels the lesson A2/B1 and describes it as suitable for B1. It mentions discussing occupational hazards and identifying hazards after listening. Its stated vocabulary target is protective equipment. The complete worksheets require a subscription and were not obtained. The outline does not show an explicit learner target for unsafe or a term-level level for hazard. Teacher-facing use of verify understanding is not evidence that verify is taught at B1.

L-DANGER: [Cambridge English: Word families: danger](https://www.cambridgeenglish.org/learning-english/activities-for-learners/b2v008-word-families-danger). The accessible landing page marks the activity B1-B2, but the inspected page text contains neither unsafe nor hazard. The interactive exercise was not inspected. No term-level evidence is claimed.

## Failed or excluded leads

- Fresh Cambridge Dictionary opens for [collect](https://dictionary.cambridge.org/dictionary/english/collect), [postpone](https://dictionary.cambridge.org/dictionary/english/postpone), [unsafe](https://dictionary.cambridge.org/dictionary/english/unsafe), [hazard](https://dictionary.cambridge.org/dictionary/english/hazard), [notify](https://dictionary.cambridge.org/us/dictionary/english/notify), and [verify](https://dictionary.cambridge.org/us/dictionary/english/verify) returned Internal Error in the web tool. Their search snippets were not promoted to inspected selected-sense evidence.
- Searches for verify at B1/B2 mostly found exam-certificate verification pages, navigation level labels, user comments, or teacher-facing lesson descriptions. These do not establish the learner's target-word level. No suitable lower-level selected-sense source was established in this pass.
- The British Council C1 inversion lesson using notify is C1 evidence, not a lower-level exception. A past-perfect lesson comment and the proofreading comment search result are learner comments, not editorial target-vocabulary evidence.
- No publisher audio was played or licensed; no source images were acquired; no professional safety procedures were researched or approved in this language-only pass.
