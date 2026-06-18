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

include { INPUT_CHECK } from './subworkflows/local/input_check'
include { EDNA        } from './workflows/edna'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow {

    // Minimal parameter validation (a full port would use nf-schema/plugin)
    if (!params.input) {
        error "ERROR: please provide an input samplesheet with --input <path/to/samplesheet.csv>"
    }
    if (!params.kraken2_db) {
        error "ERROR: please provide a Kraken2 database directory with --kraken2_db <path>"
    }

    INPUT_CHECK ( params.input )

    EDNA ( INPUT_CHECK.out.reads )
}

workflow.onComplete {
    log.info "Pipeline completed at: ${workflow.complete}"
    log.info "Execution status: ${ workflow.success ? 'OK' : 'FAILED' }"
    log.info "Results published to: ${params.outdir}"
}
