// ============================================================================
// workflows/edna.nf  --  main eDNA / shotgun-metagenomics analysis workflow
// BioFAIR EUC-09 (UK Centre for Ecology & Hydrology)
//
// Port of the Snakemake `rule all` DAG: QC -> trim -> (host removal) ->
//   Kraken2 -> Bracken -> AMR -> MultiQC
// ============================================================================

include { FASTQC              } from '../modules/local/fastqc'
include { FASTP               } from '../modules/local/fastp'
include { BOWTIE2_HOSTREMOVAL } from '../modules/local/bowtie2_hostremoval'
include { KRAKEN2             } from '../modules/local/kraken2'
include { BRACKEN             } from '../modules/local/bracken'
include { ABRICATE            } from '../modules/local/abricate'
include { MULTIQC             } from '../modules/local/multiqc'

workflow EDNA {

    take:
    ch_samplesheet     // channel: [ val(meta), [ reads ] ]
    ch_adapter_fasta   // channel: optional fastp adapter FASTA (or [])
    run_host_removal   // value:   whether to run host/contaminant removal
    ch_host_index      // channel: bowtie2 host index dir (or [])
    ch_kraken_db       // channel: collected Kraken2 / Bracken database dir
    run_amr_profiling  // value:   whether to run AMR profiling
    ch_multiqc_config  // channel: optional MultiQC config (or [])

    main:
    ch_versions     = channel.empty()
    ch_multiqc_files = channel.empty()

    //
    // MODULE: FastQC on raw reads  (Snakemake rule: fastqc_raw)
    //
    FASTQC ( ch_samplesheet )
    ch_versions      = ch_versions.mix(FASTQC.out.versions.first())
    ch_multiqc_files = ch_multiqc_files.mix(FASTQC.out.zip.map { _meta, zip -> zip })

    //
    // MODULE: fastp adapter / quality trimming  (Snakemake rule: fastp_trim)
    //
    FASTP ( ch_samplesheet, ch_adapter_fasta )
    ch_versions      = ch_versions.mix(FASTP.out.versions.first())
    ch_multiqc_files = ch_multiqc_files.mix(FASTP.out.json.map { _meta, json -> json })

    //
    // MODULE: optional host / contaminant removal  (Snakemake rule: host_removal)
    // The Snakemake `classifier_input()` input function becomes a channel branch.
    //
    if ( run_host_removal ) {
        BOWTIE2_HOSTREMOVAL ( FASTP.out.reads, ch_host_index )
        ch_versions       = ch_versions.mix(BOWTIE2_HOSTREMOVAL.out.versions.first())
        ch_classify_reads = BOWTIE2_HOSTREMOVAL.out.reads
    } else {
        ch_classify_reads = FASTP.out.reads
    }

    //
    // MODULE: Kraken2 taxonomic classification  (Snakemake rule: kraken2)
    //
    KRAKEN2 ( ch_classify_reads, ch_kraken_db )
    ch_versions      = ch_versions.mix(KRAKEN2.out.versions.first())
    ch_multiqc_files = ch_multiqc_files.mix(KRAKEN2.out.report.map { _meta, report -> report })

    //
    // MODULE: Bracken abundance re-estimation  (Snakemake rule: bracken)
    //
    BRACKEN ( KRAKEN2.out.report, ch_kraken_db )
    ch_versions = ch_versions.mix(BRACKEN.out.versions.first())

    //
    // MODULE: AMR profiling  (Snakemake rule: amr_profile) -- optional
    //
    if ( run_amr_profiling ) {
        ABRICATE ( FASTP.out.reads )
        ch_versions = ch_versions.mix(ABRICATE.out.versions.first())
    }

    //
    // Collate software versions and run MultiQC  (Snakemake rule: multiqc)
    //
    ch_versions
        .unique()
        .collectFile(name: 'collated_versions.yml')
        .set { ch_collated_versions }

    MULTIQC (
        ch_multiqc_files.mix(ch_collated_versions).collect(),
        ch_multiqc_config
    )

    emit:
    bracken  = BRACKEN.out.reports        // channel: [ val(meta), tsv ]
    multiqc  = MULTIQC.out.report         // channel: html
    versions = ch_versions                // channel: versions.yml
}
