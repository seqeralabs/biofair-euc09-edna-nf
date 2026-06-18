// ============================================================================
// ABRICATE -- functional / antimicrobial-resistance (AMR) gene profiling
// Placeholder slot for AMRFinderPlus / CARD-RGI in production.
// Snakemake source rule: amr_profile  (rules/functional.smk)
// ============================================================================

process ABRICATE {
    tag "$meta.id"
    label 'process_medium'

    conda "bioconda::abricate=1.0.1"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/abricate:1.0.1--ha8f3691_1' :
        'biocontainers/abricate:1.0.1--ha8f3691_1' }"

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("*.amr.tsv"), emit: report
    path  "versions.yml"              , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args ?: ''   // e.g. --db card --minid 80 --mincov 80
    def prefix = task.ext.prefix ?: "${meta.id}"
    def input  = meta.single_end ? "${reads}" : "${reads[0]}"
    """
    abricate \\
        --threads $task.cpus \\
        $args \\
        ${input} > ${prefix}.amr.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        abricate: \$( abricate --version 2>&1 | sed 's/^.*abricate //' )
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.amr.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        abricate: \$( abricate --version 2>&1 | sed 's/^.*abricate //' )
    END_VERSIONS
    """
}
