// ============================================================================
// UNTAR -- extract a (optionally gzipped) tar archive into a directory
// Modelled on nf-core/modules untar (joseespinosa, drpatelh, matthdsm, jfy133)
// Used to unpack a `.tar.gz` Kraken2 / Bracken database into the directory
// that kraken2 / bracken expect at runtime.
// ============================================================================

process UNTAR {
    tag "$archive"
    label 'process_single'

    conda "conda-forge::grep=3.11 conda-forge::sed=4.8 conda-forge::tar=1.34"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/ubuntu:22.04' :
        'nf-core/ubuntu:22.04' }"

    input:
    tuple val(meta), path(archive)

    output:
    tuple val(meta), path("$prefix"), emit: untar
    path  "versions.yml"            , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args  = task.ext.args ?: ''
    def args2 = task.ext.args2 ?: ''
    prefix    = task.ext.prefix ?: ( meta.id ? "${meta.id}" : archive.baseName.toString().replaceFirst(/\.tar$/, "") )
    """
    mkdir $prefix

    ## Compute the number of leading path components shared by every entry.
    ## If the archive wraps everything in a single top-level directory we strip
    ## it (--strip-components 1); if files sit at the archive root (as the
    ## Kraken2/Bracken test DB does) we strip nothing. This mirrors the
    ## canonical nf-core/untar behaviour and keeps the emitted dir self-contained.
    if tar -tf ${archive} | head -1 | grep -q -E "^[^/]+\\/\$"; then
        STRIP=1
    else
        STRIP=0
    fi

    tar \\
        -C $prefix --strip-components \$STRIP \\
        -xavf \\
        $args \\
        $archive \\
        $args2

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        untar: \$(echo \$(tar --version 2>&1) | sed 's/^.*(GNU tar) //; s/ Copyright.*\$//')
    END_VERSIONS
    """
}
