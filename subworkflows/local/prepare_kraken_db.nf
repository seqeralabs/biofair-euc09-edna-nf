// ============================================================================
// subworkflows/local/prepare_kraken_db.nf
// Resolve the Kraken2 / Bracken database into an extracted directory.
//
// The database may be supplied either as a ready-to-use directory or as a
// gzipped tarball (`.tar.gz` / `.tgz`). Kraken2 and Bracken both need the
// *extracted* directory, so when a tarball is given we unpack it with UNTAR.
// The choice is made here with workflow-level if/else on the path string
// (a plain param value), not inside a process.
// ============================================================================

include { UNTAR } from '../../modules/local/untar'

workflow PREPARE_KRAKEN_DB {

    take:
    kraken2_db   // value: path string to a DB directory or a .tar.gz/.tgz archive

    main:
    if ( kraken2_db.toString().endsWith('.tar.gz') || kraken2_db.toString().endsWith('.tgz') ) {
        // Tarball: stage the archive and extract it into a directory.
        ch_archive = channel.fromPath(kraken2_db, checkIfExists: true)
            .map { archive -> [ [id: 'kraken2_db'], archive ] }

        UNTAR ( ch_archive )
        ch_db = UNTAR.out.untar.map { _meta, dir -> dir }
    } else {
        // Already-extracted directory: use it as-is.
        ch_db = channel.fromPath(kraken2_db, type: 'dir', checkIfExists: true)
    }

    emit:
    // Collected so every Kraken2 / Bracken task receives the whole DB dir.
    db = ch_db.collect()
}
