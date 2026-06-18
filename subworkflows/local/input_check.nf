// ============================================================================
// subworkflows/local/input_check.nf
// Parse the input samplesheet (CSV) into a [ meta, reads ] channel.
// This replaces the Snakemake pandas sample-sheet parsing in the Snakefile.
// ============================================================================

workflow INPUT_CHECK {

    take:
    samplesheet   // path: assets/samplesheet.csv

    main:
    ch_reads = Channel
        .fromPath(samplesheet, checkIfExists: true)
        .splitCsv(header: true, sep: ',')
        .map { row -> create_fastq_channel(row) }

    emit:
    reads = ch_reads   // channel: [ val(meta), [ reads ] ]
}

// Build a [ meta, [reads] ] tuple from one CSV row.
// Columns: sample,fastq_1,fastq_2,platform
def create_fastq_channel(LinkedHashMap row) {
    def meta      = [:]
    meta.id       = row.sample
    meta.platform = row.platform ?: 'illumina'

    def fastq_1 = file(row.fastq_1, checkIfExists: true)
    if (!row.fastq_2?.trim()) {
        meta.single_end = true
        return [ meta, [ fastq_1 ] ]
    }
    meta.single_end = false
    def fastq_2 = file(row.fastq_2, checkIfExists: true)
    return [ meta, [ fastq_1, fastq_2 ] ]
}
