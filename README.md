# biofair/edna

**eDNA & shotgun-metagenomics pipeline — Nextflow DSL2 port**
BioFAIR EUC-09 · UK Centre for Ecology & Hydrology

[![Nextflow](https://img.shields.io/badge/nextflow%20DSL2-%E2%89%A523.04.0-23aa62.svg)](https://www.nextflow.io/)
[![run with docker](https://img.shields.io/badge/run%20with-docker-0db7ed.svg)](https://www.docker.com/)

## Introduction

**biofair/edna** is a bioinformatics pipeline for high-throughput environmental
DNA (eDNA) and microbiome analysis in support of national biodiversity
monitoring. It takes raw sequencing reads through quality control, trimming,
optional host decontamination, taxonomic classification, and functional /
antimicrobial-resistance (AMR) profiling, summarised in a single MultiQC report.

This is a DSL2 / nf-core-style port of the original Snakemake pipeline kept
under [`../snakemake-source/`](../snakemake-source). The rule-by-rule mapping is
documented in [`../CONVERSION.md`](../CONVERSION.md).

## Pipeline summary

```
samplesheet.csv
      │  INPUT_CHECK  (splitCsv -> [meta, reads])
      ▼
  ┌─ FASTQC ───────────────────────────────┐
  │                                          │
  └─ FASTP  (adapter/quality trim)           │ (zip / json -> MultiQC)
        │                                     │
        ├─ [optional] BOWTIE2_HOSTREMOVAL     │
        │        │                            │
        ▼        ▼                            │
       KRAKEN2  (taxonomic classification) ───┤ (report -> MultiQC)
        │
        ├─ BRACKEN  (abundance re-estimation)  → results/bracken
        │
        └─ ABRICATE (AMR genes, optional)      → results/amr
                                               │
                                          MULTIQC → results/multiqc
```

| Step | Process | Tool | Container |
|------|---------|------|-----------|
| Raw QC                | `FASTQC`              | FastQC 0.12.1  | biocontainers/fastqc |
| Trimming              | `FASTP`               | fastp 0.23.4   | biocontainers/fastp |
| Host removal (opt.)   | `BOWTIE2_HOSTREMOVAL` | Bowtie2 2.5.2  | biocontainers (mulled) |
| Classification        | `KRAKEN2`             | Kraken2 2.1.3  | biocontainers (mulled) |
| Abundance             | `BRACKEN`             | Bracken 2.9    | biocontainers/bracken |
| AMR profiling (opt.)  | `ABRICATE`            | abricate 1.0.1 | biocontainers/abricate |
| Aggregate report      | `MULTIQC`             | MultiQC 1.21   | biocontainers/multiqc |

## Quick start

1. Install [Nextflow](https://www.nextflow.io/) (`>=23.04.0`) and Docker (or
   Singularity / Conda).

2. Run the bundled stub test (no real databases or reads required):

   ```bash
   nextflow run . -profile test,docker -stub
   ```

3. Run on your own data:

   ```bash
   nextflow run . \
       -profile docker \
       --input assets/samplesheet.csv \
       --kraken2_db /path/to/kraken2_db \
       --outdir results
   ```

### Samplesheet

```csv
sample,fastq_1,fastq_2,platform
CEH_pond_01,/data/CEH_pond_01_R1.fastq.gz,/data/CEH_pond_01_R2.fastq.gz,illumina
CEH_soil_22,/data/CEH_soil_22_R1.fastq.gz,,illumina
```

Leave `fastq_2` empty for single-end samples — `meta.single_end` is set
automatically and every process branches on it.

## Key parameters

All parameters mirror the original Snakemake `config/config.yaml`. See
`nextflow_schema.json` for the full list and validation.

| Parameter | Default | Description |
|-----------|---------|-------------|
| `--input`                | – (required) | Samplesheet CSV |
| `--outdir`               | `results`    | Output directory |
| `--fastp_min_length`     | `50`         | Min length after trimming |
| `--fastp_quality_cutoff` | `20`         | Sliding-window Phred cutoff |
| `--host_removal`         | `false`      | Enable Bowtie2 decontamination |
| `--host_bowtie2_index`   | –            | Host Bowtie2 index dir |
| `--kraken2_db`           | – (required) | Kraken2/Bracken DB dir |
| `--kraken2_confidence`   | `0.1`        | Kraken2 confidence threshold |
| `--bracken_read_length`  | `100`        | Bracken DB read length |
| `--bracken_level`        | `S`          | Bracken taxonomic level |
| `--bracken_threshold`    | `10`         | Min reads per classification |
| `--run_amr`              | `true`       | Enable AMR profiling |
| `--amr_database`         | `card`       | abricate DB |

## Profiles

`docker`, `singularity`, `conda`, `wave`, `test`. Combine container engine with
the test profile, e.g. `-profile test,singularity`.

## Outputs

```
results/
├── fastqc/          FastQC html + zip
├── trimmed/         fastp json/html/log
├── decontam/        host-removed reads (if --host_removal)
├── kraken2/         per-sample report + output
├── bracken/         per-sample abundance tsv  ← primary deliverable
├── amr/             per-sample AMR tsv (if --run_amr)
├── multiqc/         aggregated multiqc_report.html
└── pipeline_info/   execution timeline/report/trace/DAG
```

## Credits

Ported from the UK CEH Snakemake pipeline for BioFAIR EUC-09. Module interfaces
are modelled on the corresponding [nf-core/modules](https://github.com/nf-core/modules).
