// ============================================================================
// KRAKEN2 -- taxonomic classification of reads
// Modelled on nf-core/modules kraken2/kraken2 (joseespinosa, drpatelh)
// Snakemake source rule: kraken2  (rules/classify.smk)
// ============================================================================

process KRAKEN2 {
    tag "$meta.id"
    label 'process_high'

    conda "bioconda::kraken2=2.1.3 conda-forge::pigz=2.8"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/mulled-v2-5799ab18b5fc681e75923b2450abaa969907ec98:87fc08d11968d081f3e8a37131c1f1f6715b6542-0' :
        'biocontainers/mulled-v2-5799ab18b5fc681e75923b2450abaa969907ec98:87fc08d11968d081f3e8a37131c1f1f6715b6542-0' }"

    input:
    tuple val(meta), path(reads)
    path  db

    output:
    tuple val(meta), path('*.kraken2.report.txt'), emit: report
    tuple val(meta), path('*.kraken2.output.txt'), emit: output
    path  "versions.yml"                          , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args      = task.ext.args ?: ''
    def prefix    = task.ext.prefix ?: "${meta.id}"
    def paired    = meta.single_end ? "${reads}" : "--paired ${reads[0]} ${reads[1]}"
    """
    kraken2 \\
        --db $db \\
        --threads $task.cpus \\
        --report ${prefix}.kraken2.report.txt \\
        --output ${prefix}.kraken2.output.txt \\
        $args \\
        $paired

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        kraken2: \$( kraken2 --version 2>&1 | head -1 | sed "s/^.*Kraken version //; s/ .*//" )
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.kraken2.report.txt
    touch ${prefix}.kraken2.output.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        kraken2: \$( kraken2 --version 2>&1 | head -1 | sed "s/^.*Kraken version //; s/ .*//" )
    END_VERSIONS
    """
}
