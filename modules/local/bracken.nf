// ============================================================================
// BRACKEN -- re-estimate taxonomic abundance from a Kraken2 report
// Modelled on nf-core/modules bracken/bracken (Midnighter)
// Snakemake source rule: bracken  (rules/classify.smk)
// ============================================================================

process BRACKEN {
    tag "$meta.id"
    label 'process_low'

    conda "bioconda::bracken=2.9"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/bracken:2.9--py39h1f90b4d_0' :
        'biocontainers/bracken:2.9--py39h1f90b4d_0' }"

    input:
    tuple val(meta), path(kraken_report)
    path  database

    output:
    tuple val(meta), path("*.bracken.tsv")       , emit: reports
    tuple val(meta), path("*.bracken.report.txt"), emit: kraken_style_report
    path  "versions.yml"                          , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    bracken \\
        -d ${database} \\
        -i ${kraken_report} \\
        -o ${prefix}.bracken.tsv \\
        -w ${prefix}.bracken.report.txt \\
        $args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bracken: \$( bracken -v | cut -f2 -d'v' )
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.bracken.tsv
    touch ${prefix}.bracken.report.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bracken: \$( bracken -v | cut -f2 -d'v' )
    END_VERSIONS
    """
}
