// ============================================================================
// MULTIQC -- aggregate QC reports across all samples into one HTML report
// Modelled on nf-core/modules multiqc (abhi18av, bunop, drpatelh, jfy133)
// Snakemake source rule: multiqc  (rules/functional.smk)
// ============================================================================

process MULTIQC {
    label 'process_single'

    conda "bioconda::multiqc=1.21"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/multiqc:1.21--pyhdfd78af_0' :
        'biocontainers/multiqc:1.21--pyhdfd78af_0' }"

    input:
    path multiqc_files, stageAs: "?/*"
    path multiqc_config

    output:
    path "*multiqc_report.html", emit: report
    path "*_data"              , emit: data
    path "*_plots"             , optional: true, emit: plots
    path "versions.yml"        , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args ?: ''
    def config = multiqc_config ? "--config $multiqc_config" : ''
    """
    multiqc \\
        --force \\
        $config \\
        $args \\
        .

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        multiqc: \$( multiqc --version | sed 's/.* //g' )
    END_VERSIONS
    """

    stub:
    """
    mkdir multiqc_data
    touch multiqc_report.html

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        multiqc: \$( multiqc --version | sed 's/.* //g' )
    END_VERSIONS
    """
}
