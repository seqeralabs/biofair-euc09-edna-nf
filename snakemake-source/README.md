# eDNA / shotgun-metagenomics pipeline (Snakemake source)

> **Status:** pre-conversion source. This is the original Snakemake / Python / R
> *native-execution* pipeline for **BioFAIR EUC-09** (UK Centre for Ecology &
> Hydrology). It is preserved here as the reference implementation that the
> Nextflow DSL2 port (`../nextflow/`) was translated from. See
> [`../CONVERSION.md`](../CONVERSION.md) for the rule-by-rule mapping.

## What it does

High-throughput environmental-DNA (eDNA) and microbiome analysis for national
biodiversity monitoring. Raw sequencing reads are taken through quality control,
trimming, optional host/contaminant removal, taxonomic classification, and
functional / antimicrobial-resistance (AMR) profiling, with a single aggregated
QC report.

```
raw reads
   │
   ├─ FastQC ─────────────────────────────┐
   │                                       │
   └─ fastp (adapter/quality trim)         │
          │                                │
          ├─ [optional] Bowtie2 host removal
          │                                │
          ├─ Kraken2 (taxonomic classification)
          │      └─ Bracken (abundance re-estimation)
          │                                │
          └─ abricate / AMRFinderPlus (AMR genes)
                                           │
                                      MultiQC summary
```

## Layout

| Path | Purpose |
|------|---------|
| `Snakefile`              | Entry point; sample-sheet parsing + `rule all` targets |
| `config/config.yaml`     | All tunable parameters (DB paths, thresholds, toggles) |
| `config/samples.tsv`     | Sample sheet (`sample`, `fq1`, `fq2`, `platform`) |
| `rules/qc.smk`           | `fastqc_raw`, `fastp_trim`, `host_removal` |
| `rules/classify.smk`     | `kraken2`, `bracken` |
| `rules/functional.smk`   | `amr_profile`, `multiqc` |
| `envs/*.yaml`            | One Conda environment per tool |
| `resources/`             | Reference DBs and input reads (not committed) |

## Running

```bash
# dry run to see the DAG
snakemake -n

# full run with per-rule Conda environments
snakemake --use-conda --cores 16
```

## Notes

- Paired-end vs single-end is decided per sample from the `fq2` column.
- `host_removal.enabled` and `amr.enabled` toggle optional stages; downstream
  input functions (`classifier_input`) re-route reads accordingly.
- Reference databases (Kraken2/Bracken, abricate) must be built/downloaded
  separately into `resources/`.
