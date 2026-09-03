# OncoRepurpose

A Flutter research tool for browsing gene-drug interactions recorded in public
databases, aimed at cancer transcriptomics.

**Research use only.** The app reports what source databases have recorded. It
does not predict drug efficacy and must not be used to guide patient care.

---

## What it does

1. **Look up a drug by name** - returns every gene the drug is recorded against,
   how many independent databases report it, and its approval status.
2. **Find candidate drugs for a gene set** - takes a gene list, either typed in
   or from a signature, and returns one candidate per drug with a directional
   verdict for each gene it hits.
3. **Analyse your own study file** - parses a CSV/TSV differential-expression
   table, applies Benjamini-Hochberg FDR correction, filters on significance and
   effect size, and saves the result as a reusable signature.

### The directional check

DGIdb's `interaction` column records whether a drug suppresses or activates its
target. The app classifies those terms and compares each drug's direction against
the direction the gene moved in the study:

| Verdict | Meaning |
| --- | --- |
| **Opposes** | Suppresses an over-expressed gene, or activates an under-expressed one. |
| **Reinforces** | Pushes further in the direction already observed. Shown with a warning, not hidden - it is a real counter-indication for a reversal hypothesis. |
| **Conflicting** | Sources disagree on the drug's direction. Real for 275 gene-drug pairs. |
| **Undetermined** | No mechanism was reported, or the term names a modality ("antibody", "vaccine") rather than a direction. |

Candidates are ranked by **opposing target count first**, then corroboration,
then target count, then documentation score. A drug acting against four
dysregulated genes is a stronger hypothesis than one with a single
well-documented interaction, and the previous score-only ordering could not
express that.

Measured against the bundled TCGA signature (30 genes, 101 candidates): 40
oppose at least one gene, 23 only reinforce, 38 are undetermined. The old ranking
put `SOTEVTAMAB` first on a score of 52.5 with **zero** established direction;
the new ranking leads with `AMATUXIMAB`, an MSLN inhibitor opposing an
over-expressed gene, corroborated by three databases.

This is a **consistency check, not a prediction.** Three limits apply:

1. mRNA abundance is not protein activity.
2. A dysregulated gene may be a driver, a passenger, or a compensatory response.
   Reversing a passenger achieves nothing; reversing a compensatory response can
   be harmful.
3. Each gene is treated in isolation - no pathways, no feedback loops, and none
   of the drug's targets outside the queried set.

## What it does not do

These limits are stated in the app itself, on the About screen.

| Not implemented | Detail |
| --- | --- |
| Machine learning | Results come from SQL queries plus the directional check above. No model, no training, no inference. |
| Connectivity scoring | There is no LINCS/L1000 expression-reversal score. The directional check is per gene, not a whole-signature similarity measure. |
| Pathway or network analysis | No enrichment, no protein-interaction neighbours, no off-target modelling. |
| Molecular docking | No binding affinities are computed or stored. |

## Data sources

### Gene-drug interactions

`assets/db/master_drugs.db` (12 MB) is a flattened import of DGIdb interaction
claims: **98,239 rows, 5,012 genes, 18,854 drugs**, in a single table.

```sql
CREATE TABLE drug_interactions (
  gene TEXT, drug TEXT, interaction TEXT, target_category TEXT,
  is_novel INTEGER, score REAL, source TEXT, docking_score REAL
);
```

Measured properties of this data, all of which shape the UI:

| Column | Reality |
| --- | --- |
| `docking_score` | Constant `-5.0` across all 98,239 rows. Not read by the app. |
| `target_category` | Constant `'TARGET'` across all rows. Not read by the app. |
| `interaction` | The literal string `'NULL'` in 63,336 rows (64%). Rendered as "Mechanism not reported". |
| `drug` | The string `'NULL'` in 10,572 rows; 6,218 rows carry a bare `CHEMBL:CHEMBLxxxxx` accession with no common name. Placeholder rows are excluded from every query. |
| `gene` | The string `'NULL'` in 8,177 rows. Excluded. |
| `is_novel` | Inverse of DGIdb's `approved` flag, so it means **"not FDA-approved"**, not "novel repurposing candidate". Exposed as `isApproved`. 98 drugs carry conflicting flags across sources and are resolved per drug, not per row. |
| `score` | DGIdb interaction score: how well *documented* a claim is, weighted by gene and drug promiscuity. Not efficacy or potency. Range 0.0004-157.5, median 0.15. |
| `source` | Provenance: DTC, ChEMBL, GuideToPharmacology, TTD, NCI, PharmGKB, and others. |

**Corroboration is the strongest real signal in this dataset** and drives the
default ranking. Over the 69,018 non-placeholder (gene, drug) pairs: 90.8% come
from a single database, 9.2% from two or more, 3.8% from three or more.

Score percentiles over the same 69,018 pairs, used for the UI's documentation
labels and filter hints:

| p25 | p50 | p75 | p90 | p95 | p99 |
| --- | --- | --- | --- | --- | --- |
| 0.04 | 0.15 | 0.73 | 2.63 | 5.25 | 26.25 |

### Reference signatures

Four bundled signatures in `assets/data/`: TCGA Breast Invasive Carcinoma
(PanCancer Atlas) and three TNBC subtype comparisons, 30 genes each.

**Coverage caveat.** Only 13 of the 30 genes in the TCGA signature have any
interaction record, because differential-expression outliers (HORMAD1, PRAME,
CT83) and druggable targets are largely disjoint sets. Empty results are normal
and the UI explains why rather than reporting "no results found".

## Architecture

```
lib/
├── main.dart                          App setup, theme engine, provider wiring
├── theme/
│   ├── app_theme.dart                 Light & OLED Midnight Slate palettes, EvidenceThemeColors extension
│   └── theme_provider.dart            Theme mode state manager with disk persistence
├── models/
│   ├── cancer_signature.dart          Signature, gene, analysis provenance
│   ├── drug_interaction.dart          One (gene, drug) record + evidence class
│   ├── drug_candidate.dart            Per-drug grouping, directional ranking
│   ├── pharmacology.dart              Direction inference and matching
│   ├── target_evidence.dart           Open Targets association, tractability, candidates
│   ├── connectivity_evidence.dart     LINCS L1000FWD reversal scores & perturbations
│   └── disease_option.dart            MONDO ontology options & defaults
├── providers/
│   ├── data_provider.dart             Signature selection, filters, SQLite query state
│   ├── evidence_provider.dart         Open Targets state, cache passthrough, disease context
│   └── connectivity_provider.dart     LINCS L1000 connectivity score caching & loading
├── services/
│   ├── database_service.dart          SQLite access over bundled DGIdb database
│   ├── lab_storage_service.dart       Saved studies as JSON on disk
│   ├── study_analysis_service.dart    CSV/TSV parsing, FDR, filtering
│   ├── open_targets_service.dart      Open Targets GraphQL client (reverse queries, batching)
│   ├── lincs_service.dart             NIH LINCS L1000FWD signature connectivity client
│   └── network/
│       ├── api_client.dart            HTTP with caching, retries, offline path
│       ├── api_result.dart            Success/failure + data freshness
│       ├── network_consent.dart       Opt-in gate, denied by default
│       └── response_cache.dart        On-disk response cache
├── screens/                           9 screens (workstation dashboard, results grid, profile, settings)
└── widgets/
    ├── adaptive_layout.dart           Breakpoints, AdaptiveContainer, AdaptiveCardGrid
    ├── animated_entrance.dart         AnimatedEntrance, InteractiveHoverCard
    └── evidence_widgets.dart          Shared components, colour tokens, OT chips, LINCS card
```

Every asynchronous operation reports `LoadStatus.loading` / `ready` / `failed`
with an error message, so a failure is never rendered as an empty result.

### Statistics

`StudyAnalysisService` is the only genuine statistical code. Benjamini-Hochberg
correction is verified against `R p.adjust(method="BH")` in the test suite.
Parsing runs on a background isolate. Rows missing a gene symbol, fold change,
or p-value are skipped and counted in the provenance record rather than being
coerced to `log2fc = 0, p = 1`.

### External Target Evidence: Open Targets Platform (Phase 2b)

The app integrates with the Open Targets Platform GraphQL API (Release 26.06,
API v26.6.3, CC0 license) to corroborate whether candidate drug targets are
biologically relevant to the tumor phenotype.

#### Architectural Query Fix: Reverse vs. Broken Forward Query

Open Targets API v26.6.3 contains a critical defect in its forward query:
`target(ensemblId).associatedDiseases(Bs: [diseaseId])` ignores the disease
filter and returns fabricated association scores (e.g., assigning housekeeping
control gene `ACTB` a score of 0.9323, higher than proven breast cancer driver
`ESR1` at 0.8179).

OncoApp uses the verified reverse query:
```graphql
disease(efoId: $diseaseId) {
  associatedTargets(Bs: $ensemblIds, enableIndirect: true) {
    rows { score datatypeScores { id score } target { id approvedSymbol } }
  }
}
```
Setting `enableIndirect: true` is mandatory; without it, evidence from child
ontologies is omitted (e.g. `TP53` drops from 0.8606 to 0.6626). A guard test
asserts that queries never invoke the broken forward query.

#### Calibrated Association Score Scale

Open Targets scores are empirical harmonic sums, not linear probabilities.
The app calibrates them into discrete, evidence-backed tiers:
- **Strong** ($\ge 0.30$): Extensive genetic, somatic, or clinical precedence.
- **Moderate** ($\ge 0.10$): Clear corroborated publication evidence.
- **Weak** ($0.01 - 0.09$): Limited or solitary literature citations.
- **Negligible** ($< 0.01$): Negligible indirect linkage.
- **Not reported** (`null`): No published link found in Open Targets.

#### Driver vs. Passenger Target Hypothesis

Reversing the expression of a gene that changed as a passive consequence of
tumorigenesis (passenger) provides no therapeutic benefit. When a target has
negligible or absent disease association (< 0.10), zero clinical trial candidates,
and lacks clinical tractability, the app surfaces a probabilistic passenger
warning:
> "No published evidence links this gene to the selected disease. The observed
> expression change may be a consequence of tumourigenesis rather than a cause."

#### Scientific Limitations of Target Evidence

1. **Publication Bias**: Well-funded and heavily researched genes receive higher
   scores simply because more papers exist.
2. **Indirect Term Inheritance**: Scores with `enableIndirect: true` aggregate
   findings across descendant disease ontology branches.
3. **No Directionality**: Open Targets measures the strength of association, not
   whether up- or downregulation is protective. It complements the directional check
   rather than replacing it.
4. **Disease Context Sensitivity**: Association scores depend strictly on the
   selected MONDO disease ontology context.

### Transcriptomic Connectivity Scoring (NIH LINCS L1000)

In Phase 2c, OncoRepurpose connects with the **NIH LINCS L1000FWD API**
(`https://maayanlab.cloud/l1000fwd/`, Ma'ayan Laboratory) to evaluate real
whole-genome transcriptomic signature reversal.

Rather than relying on single-gene annotations alone, the app queries over 16,000
drug perturbation profiles measured across human cancer cell lines (e.g. MCF7,
HCC515, PC3):

1. **`POST /sig_search`**: Submits active signature up- and down-regulated gene sets.
2. **`GET /result/topn/<result_id>`**: Retrieves top opposing (signature reversal)
   and similar (mimic) perturbagens with standardized scores, p-values, FDR
   q-values, and z-scores.
3. **`GET /sig/<sig_id>`**: Resolves pert_id / Broad IDs to generic drug descriptions,
   incubation times, and micro-molar doses.

#### Scientific Tiers of Transcriptomic Reversal

| Tier | Criteria | Biological Interpretation |
| --- | --- | --- |
| **Strong Reversal** | FDR $q \le 0.05$ and score $\le -0.30$ | Highly statistically significant reversal across the global cancer transcriptome. |
| **Moderate Reversal** | FDR $q \le 0.10$ and score $< 0.0$ | Significant anti-correlated expression profile. |
| **Nominal Reversal** | $p \le 0.05$ or score $< 0.0$ | Suggestive reversal trend in vitro. |
| **Mimic** | Score $> 0.0$ | **Caution**: Perturbation mimics the disease expression signature (potential adverse or pro-tumorigenic effect). |

### Network layer

**Consent is opt-in and denied by default.** A gene list from an unpublished
study reveals what a researcher is working on, so `NetworkConsent` gates every
outbound request and fails closed on any read error. Every existing feature runs
against the bundled database, so the app is fully functional with lookups off.

**Every result states its own freshness.** `ApiResult` distinguishes three
successful cases:

| Freshness | Meaning |
| --- | --- |
| `network` | Fetched from the server during this call. |
| `freshCache` | Served from cache within the 12-hour freshness window. |
| `staleCache` | Served from expired cache because the server was unreachable. Surfaced as an "Offline copy from N days ago" banner. |

Presenting month-old evidence as current would be the same class of error as the
placeholder docking scores this app used to display, so the stale case is a
distinct state rather than a silent fallback.

Failures are classified by cause (`offline`, `timeout`, `tlsFailure`,
`serverError`, `rateLimited`, `badRequest`, `invalidResponse`,
`responseTooLarge`, `consentNotGranted`), because the UI's response differs: a
transient failure gets a retry affordance, a consent gate gets a settings link,
and a malformed response gets neither.

## Development

```bash
flutter pub get
flutter test                            # 318 tests passing
flutter analyze                         # 0 issues
dart run tool/verify_open_targets.dart  # live Open Targets API verification
dart run tool/verify_lincs.dart         # live LINCS L1000 API verification
flutter build windows --release
```

Platforms: Windows, Android, macOS, Linux, iOS. **Web cannot work** - the app
depends on `dart:io`, local SQLite, and `path_provider`.

Network permissions are declared on Android (`INTERNET`) and macOS
(`com.apple.security.network.client`). They are only exercised when the user
turns external lookups on.

### Android release signing

Copy `android/key.properties.example` to `android/key.properties` and fill in
your keystore details. Without it, release builds fall back to the debug key and
log a warning; such an artifact cannot be published.

## Rebuilding the drug database

`build_master_db.py` regenerates `master_drugs.db` from a DGIdb
`interactions.tsv` export. Note that the committed script hardcodes absolute
paths that do not exist on a fresh checkout, and writes `target_category` and
`docking_score` as the constants documented above. It needs rewriting before the
pipeline is reproducible.
