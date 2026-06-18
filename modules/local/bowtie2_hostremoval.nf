// ============================================================================
// BOWTIE2_HOSTREMOVAL -- optional host / contaminant decontamination
// Snakemake source rule: host_removal  (rules/qc.smk)
// ============================================================================

process BOWTIE2_HOSTREMOVAL {
    tag "$meta.id"
    label 'process_high'

    conda "bioconda::bowtie2=2.5.2 bioconda::samtools=1.19.2"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/mulled-v2-ac74a7f02cebcfcc07d8e8d1d750af9c83b4d45a:f70b31a2db15c023d83c4521c032c2d33ba9bba6-0' :
        'biocontainers/mulled-v2-ac74a7f02cebcfcc07d8e8d1d750af9c83b4d45a:f70b31a2db15c023d83c4521c032c2d33ba9bba6-0' }"

    input:
    tuple val(meta), path(reads)
    path  index   // directory containing the bowtie2 *.bt2 index files

    output:
    tuple val(meta), path('*.clean.fastq.gz'), emit: reads
    path  "versions.yml"                      , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    INDEX=\$(find -L ${index} -name "*.rev.1.bt2" | sed 's/\\.rev.1.bt2\$//')

    bowtie2 \\
        -p $task.cpus \\
        -x \$INDEX \\
        -1 ${reads[0]} -2 ${reads[1]} \\
        --un-conc-gz ${prefix}_%.clean.fastq.gz \\
        $args \\
        -S /dev/null

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bowtie2: \$( bowtie2 --version | head -1 | sed 's/^.*version //' )
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_1.clean.fastq.gz
    touch ${prefix}_2.clean.fastq.gz

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bowtie2: \$( bowtie2 --version | head -1 | sed 's/^.*version //' )
    END_VERSIONS
    """
}
