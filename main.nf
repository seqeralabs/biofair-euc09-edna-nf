#!/usr/bin/env nextflow
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    biofair/edna  --  EUC-09 eDNA & shotgun-metagenomics pipeline
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    BioFAIR EUC-09 (UK Centre for Ecology & Hydrology)
    Nextflow DSL2 port of the original Snakemake pipeline (see ../snakemake-source)
    Github : https://github.com/biofair/euc-09-edna   (placeholder)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

nextflow.enable.dsl = 2

include { INPUT_CHECK        } from './subworkflows/local/input_check'
include { PREPARE_KRAKEN_DB  } from './subworkflows/local/prepare_kraken_db'
include { EDNA               } from './workflows/edna'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow {

    // ----------------------------
    // Parameter setup
    // ----------------------------
    // Validate the required launch inputs, then resolve every `params.*` value
    // the pipeline uses into an explicitly named channel or value here, so the
    // run section below reads as a clean stage-by-stage story and downstream
    // workflows never reach back into `params.*`.
    if (!params.input) {
        error "ERROR: please provide an input samplesheet with --input <path/to/samplesheet.csv>"
    }
    if (!params.kraken2_db) {
        error "ERROR: please provide a Kraken2 database directory with --kraken2_db <path>"
    }

    input_samplesheet  = params.input
    kraken2_database   = params.kraken2_db
    run_host_removal   = params.host_removal
    run_amr_profiling  = params.run_amr

    ch_adapter_fasta   = params.adapter_fasta ? channel.fromPath(params.adapter_fasta) : []
    ch_host_index      = params.host_removal && params.host_bowtie2_index ? channel.fromPath(params.host_bowtie2_index, type: 'dir') : []
    ch_multiqc_config  = params.multiqc_config ? channel.fromPath(params.multiqc_config) : []

    /*
    Resolve the Kraken2 / Bracken database into a single collected directory
    channel. Handles both a ready-made DB directory and a `.tar.gz`/`.tgz`
    archive (which is extracted first); the branching lives in the subworkflow.
    */
    PREPARE_KRAKEN_DB ( kraken2_database )
    ch_kraken_db = PREPARE_KRAKEN_DB.out.db

    // ----------------------------
    // Pipeline run
    // ----------------------------

    /*
    Parse the input samplesheet (CSV) into a [ meta, [reads] ] channel so every
    downstream stage runs once per sample.
    */
    INPUT_CHECK ( input_samplesheet )

    /*
    Run the full eDNA / shotgun-metagenomics analysis on the parsed read pairs:
    FastQC -> fastp trimming -> optional host removal -> Kraken2 classification
    -> Bracken re-estimation -> optional AMR profiling -> MultiQC aggregation.
    All param-derived inputs are passed in explicitly.
    */
    EDNA (
        INPUT_CHECK.out.reads,
        ch_adapter_fasta,
        run_host_removal,
        ch_host_index,
        ch_kraken_db,
        run_amr_profiling,
        ch_multiqc_config,
    )

    // ----------------------------
    // Completion handler
    // ----------------------------
    workflow.onComplete {
        log.info "Pipeline completed at: ${workflow.complete}"
        log.info "Execution status: ${ workflow.success ? 'OK' : 'FAILED' }"
        log.info "Results published to: ${params.outdir}"
    }
}
