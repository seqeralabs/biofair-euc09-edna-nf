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
    ch_samplesheet   // channel: [ val(meta), [ reads ] ]

    main:
    ch_versions     = Channel.empty()
    ch_multiqc_files = Channel.empty()

    //
    // MODULE: FastQC on raw reads  (Snakemake rule: fastqc_raw)
    //
    FASTQC ( ch_samplesheet )
    ch_versions      = ch_versions.mix(FASTQC.out.versions.first())
    ch_multiqc_files = ch_multiqc_files.mix(FASTQC.out.zip.map { it[1] })

    //
    // MODULE: fastp adapter / quality trimming  (Snakemake rule: fastp_trim)
    //
    ch_adapter = params.adapter_fasta ? Channel.fromPath(params.adapter_fasta) : []
    FASTP ( ch_samplesheet, ch_adapter )
    ch_versions      = ch_versions.mix(FASTP.out.versions.first())
    ch_multiqc_files = ch_multiqc_files.mix(FASTP.out.json.map { it[1] })

    //
    // MODULE: optional host / contaminant removal  (Snakemake rule: host_removal)
    // The Snakemake `classifier_input()` input function becomes a channel branch.
    //
    if ( params.host_removal ) {
        ch_host_index = Channel.fromPath(params.host_bowtie2_index, type: 'dir')
        BOWTIE2_HOSTREMOVAL ( FASTP.out.reads, ch_host_index )
        ch_versions       = ch_versions.mix(BOWTIE2_HOSTREMOVAL.out.versions.first())
        ch_classify_reads = BOWTIE2_HOSTREMOVAL.out.reads
    } else {
        ch_classify_reads = FASTP.out.reads
    }

    //
    // MODULE: Kraken2 taxonomic classification  (Snakemake rule: kraken2)
    //
    ch_kraken_db = Channel.fromPath(params.kraken2_db, type: 'dir').collect()
    KRAKEN2 ( ch_classify_reads, ch_kraken_db )
    ch_versions      = ch_versions.mix(KRAKEN2.out.versions.first())
    ch_multiqc_files = ch_multiqc_files.mix(KRAKEN2.out.report.map { it[1] })

    //
    // MODULE: Bracken abundance re-estimation  (Snakemake rule: bracken)
    //
    BRACKEN ( KRAKEN2.out.report, ch_kraken_db )
    ch_versions = ch_versions.mix(BRACKEN.out.versions.first())

    //
    // MODULE: AMR profiling  (Snakemake rule: amr_profile) -- optional
    //
    if ( params.run_amr ) {
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

    ch_multiqc_config = params.multiqc_config ? Channel.fromPath(params.multiqc_config) : []
    MULTIQC (
        ch_multiqc_files.mix(ch_collated_versions).collect(),
        ch_multiqc_config
    )

    emit:
    bracken  = BRACKEN.out.reports        // channel: [ val(meta), tsv ]
    multiqc  = MULTIQC.out.report         // channel: html
    versions = ch_versions                // channel: versions.yml
}
