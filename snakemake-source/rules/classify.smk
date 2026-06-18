# =============================================================================
# rules/classify.smk  --  taxonomic classification (Kraken2 + Bracken)
# =============================================================================


def classifier_input(wildcards):
    """Feed Kraken2 either the decontaminated or the trimmed reads,
    depending on whether host removal is enabled in the config."""
    if config["host_removal"]["enabled"]:
        return {
            "r1": f"{OUTDIR}/decontam/{wildcards.sample}_1.clean.fastq.gz",
            "r2": f"{OUTDIR}/decontam/{wildcards.sample}_2.clean.fastq.gz",
        }
    return {
        "r1": f"{OUTDIR}/trimmed/{wildcards.sample}_1.trim.fastq.gz",
        "r2": f"{OUTDIR}/trimmed/{wildcards.sample}_2.trim.fastq.gz",
    }


rule kraken2:
    """Assign a taxon to every read against the Kraken2 database."""
    input:
        unpack(classifier_input),
    output:
        report=f"{OUTDIR}/kraken2/{{sample}}.kraken2.report.txt",
        out=f"{OUTDIR}/kraken2/{{sample}}.kraken2.output.txt",
    params:
        db=config["kraken2"]["db"],
        confidence=config["kraken2"]["confidence"],
        paired=is_paired,
    threads: config["threads"]["kraken2"]
    conda:
        "../envs/kraken2.yaml"
    log:
        f"{OUTDIR}/logs/kraken2/{{sample}}.log",
    shell:
        r"""
        if [ "{params.paired}" = "True" ]; then
            kraken2 --db {params.db} --threads {threads} \
                --confidence {params.confidence} \
                --paired {input.r1} {input.r2} \
                --report {output.report} --output {output.out} > {log} 2>&1
        else
            kraken2 --db {params.db} --threads {threads} \
                --confidence {params.confidence} \
                {input.r1} \
                --report {output.report} --output {output.out} > {log} 2>&1
        fi
        """


rule bracken:
    """Re-estimate abundance at a given taxonomic level from the Kraken2 report."""
    input:
        report=f"{OUTDIR}/kraken2/{{sample}}.kraken2.report.txt",
    output:
        tsv=f"{OUTDIR}/bracken/{{sample}}.bracken.tsv",
        report=f"{OUTDIR}/bracken/{{sample}}.bracken.report.txt",
    params:
        db=config["kraken2"]["db"],
        read_length=config["bracken"]["read_length"],
        level=config["bracken"]["level"],
        threshold=config["bracken"]["threshold"],
    threads: config["threads"]["bracken"]
    conda:
        "../envs/bracken.yaml"
    log:
        f"{OUTDIR}/logs/bracken/{{sample}}.log",
    shell:
        r"""
        bracken -d {params.db} -i {input.report} \
            -o {output.tsv} -w {output.report} \
            -r {params.read_length} -l {params.level} -t {params.threshold} \
            > {log} 2>&1
        """
