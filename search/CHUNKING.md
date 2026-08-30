# Chunking: default vs tuned

Compared on `dev` against the same corpus blobs and the same probe query after AZP-6 ingest.

| | **Default** (`corpus-default`) | **Tuned** (`corpus-tuned`) |
|--|-------------------------------|----------------------------|
| Split | `maximumPageLength` 2000, overlap 500 | 800 / 150 |
| Skillset | `corpus-skillset-default` | `corpus-skillset-tuned` |
| Chunk count (this corpus) | 79 | ~189–191 |
| Intent | Coarse pages | Smaller bites for nested sections / control-like structure |

## Probe

`What does the Well-Architected Framework say about reliability zones?`

Both indexes return top hits from:

- **Framework:** Azure Well-Architected Framework  
- **Section:** Reliability - Availability zones  
- **Source:** `waf/reliability-availability-zones.md`

So hybrid retrieval + citations work on both.

## Qualitative difference

- **Default** yields fewer, longer chunks. Ranked hits still cite the right WAF page; mid-document chunks are larger and mix more surrounding Learn UI/nav noise from HTML stripping.
- **Tuned** yields more chunks. Overlap and smaller size keep section-sized passages tighter; more chunks mean more candidates that share the same framework/section but different offsets (some fall back to path-derived section labels when the markdown header is not in that chunk).

For this standards-style corpus, **tuned is the better default going forward** when the goal is cited section-level answers. Keep **default** as the A/B baseline.

## Citation note

**Root cause (confirmed):** custom blob Metadata keys (e.g. `citeframework`) are visible to the indexer as `/document/citeframework`, **not** `/document/metadata_citeframework`. Built-in storage properties still use the `metadata_` prefix (`metadata_storage_path`, `metadata_storage_name`).

Our first skillsets mapped `/document/metadata_citeframework` (and earlier `metadata_framework`). Those paths were empty → index projections skipped every chunk → empty indexes despite indexer “success.”

**Fix:** skillset projections use `/document/citeframework`, `/document/citesection`, `/document/citetitle` so citations land in one indexer pass.
