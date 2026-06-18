# Snakemake → Nextflow DSL2 conversion notes

**BioFAIR EUC-09** — eDNA & shotgun-metagenomics pipeline (UK Centre for Ecology
& Hydrology), the *native-execution* exemplar use case.

This document maps the original Snakemake pipeline
([`snakemake-source/`](snakemake-source)) onto the idiomatic Nextflow DSL2 /
nf-core-style port ([`nextflow/`](nextflow)).

---

## 1. Rule → Process mapping

| Snakemake rule | File | Nextflow process | File | Tool |
|----------------|------|------------------|------|------|
| `fastqc_raw`   | `rules/qc.smk`         | `FASTQC`              | `modules/local/fastqc.nf`              | FastQC |
| `fastp_trim`   | `rules/qc.smk`         | `FASTP`               | `modules/local/fastp.nf`               | fastp |
| `host_removal` | `rules/qc.smk`         | `BOWTIE2_HOSTREMOVAL` | `modules/local/bowtie2_hostremoval.nf` | Bowtie2 |
| `kraken2`      | `rules/classify.smk`   | `KRAKEN2`             | `modules/local/kraken2.nf`             | Kraken2 |
| `bracken`      | `rules/classify.smk`   | `BRACKEN`             | `modules/local/bracken.nf`             | Bracken |
| `amr_profile`  | `rules/functional.smk` | `ABRICATE`            | `modules/local/abricate.nf`            | abricate (→ AMRFinderPlus in prod) |
| `multiqc`      | `rules/functional.smk` | `MULTIQC`             | `modules/local/multiqc.nf`             | MultiQC |
| `rule all` (targets) | `Snakefile`      | `workflow EDNA`       | `workflows/edna.nf`                    | — |
| pandas sample-sheet parsing | `Snakefile` | `INPUT_CHECK`     | `subworkflows/local/input_check.nf`    | — |

Module interfaces (inputs/outputs/version-capture/command templates) were
grounded against the real nf-core modules for fastqc, fastp, kraken2/kraken2,
bracken/bracken and multiqc via the nf-core MCP `describe_nfcore_module` tool, so
the `local/` processes follow nf-core emit names and `versions.yml` conventions.

---

## 2. Key idiom differences

### Wildcards → channels + `meta` maps
Snakemake threads the `{sample}` wildcard through filename patterns and resolves
the DAG by pattern-matching `input:`/`output:` paths. Nextflow instead carries an
explicit `meta` map (`[ id, single_end, platform ]`) alongside the files in a
channel tuple `[ meta, reads ]`. Dependencies are wired by passing one process's
output channel into the next, not by matching paths.

### `config.yaml` → `params` + samplesheet
- The Snakemake `config/config.yaml` scalars become `params.*` in
  `nextflow.config`, validated by `nextflow_schema.json`.
- `config/samples.tsv` (tab-separated, pandas-parsed in the `Snakefile`) becomes
  `assets/samplesheet.csv`, parsed by `INPUT_CHECK` with `splitCsv`. The
  `is_paired()` helper (checks the `fq2` column) becomes `meta.single_end`,
  derived from an empty `fastq_2` field.

### `conda:` envs → container directives
Each rule's `envs/*.yaml` Conda spec becomes a `conda` directive **and** a
`container` directive (biocontainers / Galaxy depot) on the process, selected by
`workflow.containerEngine`. Same pinned versions (e.g. fastp 0.23.4, kraken2
2.1.3, bracken 2.9). The `conda` profile preserves the original Conda path.

### `expand()` → channel operators
`expand(".../{sample}...", sample=SAMPLES)` in `rule all` and in
`multiqc_inputs()` becomes channel composition: per-sample outputs flow as
channels and are gathered for MultiQC with
`.mix(...).collect()` (and `.map { it[1] }` to drop the meta before
aggregation). `ch_versions.unique().collectFile()` replaces manual version
bookkeeping.

### Optional stages: input functions → `if` + `ext.when`
The Snakemake `classifier_input()` input function (route trimmed *or*
decontaminated reads into Kraken2 depending on `host_removal.enabled`) becomes a
Groovy `if (params.host_removal)` branch in `workflows/edna.nf` that swaps the
channel feeding `KRAKEN2`. The `amr.enabled` toggle becomes `ext.when = {
params.run_amr }` in `conf/modules.config` plus an `if (params.run_amr)` guard.

### `params:`/`shell:` flags → `ext.args`
Per-rule tool flags built inline in Snakemake `params:`/`shell:` (e.g.
`--confidence`, `-r/-l/-t`, `--minid/--mincov`) move to `ext.args` closures in
`conf/modules.config`, keeping the process bodies generic and reusable.

### `output:` paths → `publishDir`
Snakemake encodes the publish location directly in `output:` paths
(`results/bracken/{sample}.bracken.tsv`). Nextflow processes write to the work
dir and `publishDir` (in `conf/modules.config`) copies named outputs to
`results/<stage>/`.

### `threads:` → resource labels
The `config["threads"]` map maps onto nf-core resource **labels**
(`process_low/medium/high/single`) defined in `conf/base.config`, with
`check_max()` ceilings and a retry `errorStrategy` — capabilities Snakemake
expresses per-rule rather than via reusable classes.

---

## 3. Layout of the port

```
nextflow/
├── main.nf                         entry workflow + param guards
├── nextflow.config                 params (mirror config.yaml) + profiles + manifest
├── nextflow_schema.json            parameter schema/validation
├── modules.json                    provenance of ported nf-core modules
├── conf/
│   ├── base.config                 resource labels (threads: → labels)
│   ├── modules.config              ext.args + publishDir (params:/output: → here)
│   └── test.config                 tiny-input / -stub CI profile
├── subworkflows/local/input_check.nf   samplesheet → [meta, reads]
├── workflows/edna.nf               the DAG (rule all → channel wiring)
├── modules/local/*.nf              one process per rule
└── assets/
    ├── samplesheet.csv             samples.tsv → CSV
    ├── multiqc_config.yml
    ├── test_data/*.fastq.gz        tiny stub reads
    └── test_db/                    placeholder Kraken2/Bracken DB
```

Validate / dry-run with:

```bash
cd nextflow
nextflow run . -profile test,docker -stub
```

---

## 4. What a production port would still need

- **Real reference databases.** `--kraken2_db` must point at a genuine built
  Kraken2 + Bracken DB (the `database<readlen>mers.kmer_distrib` files must match
  `--bracken_read_length`); the `assets/test_db` files are empty placeholders for
  the `-stub` DAG only. Likewise a real host Bowtie2 index for `--host_removal`.
- **AMR tool swap.** `ABRICATE` is a lightweight stand-in. Production should run
  **AMRFinderPlus** (or CARD-RGI) — typically on assembled contigs, which would
  add an assembly module (e.g. MEGAHIT/metaSPAdes) upstream rather than screening
  raw reads.
- **Real nf-core modules + `nf-core modules install`.** Replace the hand-ported
  `modules/local/*` with pinned, lint-passing `modules/nf-core/*` (the
  `modules.json` `git_sha` fields are placeholders) and adopt the
  `nf-validation`/`nf-schema` plugin for `--input` and param validation instead
  of the manual `error` guards in `main.nf`.
- **CI tests.** Add `nf-test` per-process snapshot tests and a GitHub Actions
  matrix (`-profile test,docker` / `test,singularity`, multiple NF versions),
  plus `nf-core lint`.
- **Reference staging / igenomes-style config**, institutional `conf/` profiles
  (e.g. via nf-core/configs) for HPC/cloud, and a `CITATIONS.md` / tool version
  reporting subworkflow.
- **Resource tuning** with empirical metagenomics figures (Kraken2 RAM ≈ DB
  size; the `process_high` 72 GB default assumes a standard DB and must scale for
  larger ones).
```
