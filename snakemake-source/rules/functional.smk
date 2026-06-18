# =============================================================================
# rules/functional.smk  --  functional / AMR-gene profiling + MultiQC
# =============================================================================


rule amr_profile:
    """Screen trimmed reads/contigs for antimicrobial-resistance genes.

    Placeholder using `abricate`; in production this is the slot for
    AMRFinderPlus (or a CARD/RGI run on assembled contigs).
    """
    input:
        r1=f"{OUTDIR}/trimmed/{{sample}}_1.trim.fastq.gz",
    output:
        tsv=f"{OUTDIR}/amr/{{sample}}.amr.tsv",
    params:
        db=config["amr"]["database"],
        min_id=config["amr"]["min_identity"],
        min_cov=config["amr"]["min_coverage"],
    threads: config["threads"]["amr"]
    conda:
        "../envs/amr.yaml"
    log:
        f"{OUTDIR}/logs/amr/{{sample}}.log",
    shell:
        r"""
        abricate --db {params.db} \
            --minid {params.min_id} --mincov {params.min_cov} \
            --threads {threads} \
            {input.r1} > {output.tsv} 2> {log}
        """


def multiqc_inputs(_):
    """Gather every per-sample report MultiQC understands."""
    inputs = []
    inputs += expand(f"{OUTDIR}/fastqc/{{sample}}_fastqc.zip", sample=SAMPLES)
    inputs += expand(f"{OUTDIR}/trimmed/{{sample}}.fastp.json", sample=SAMPLES)
    inputs += expand(
        f"{OUTDIR}/kraken2/{{sample}}.kraken2.report.txt", sample=SAMPLES
    )
    return inputs


rule multiqc:
    """Aggregate FastQC, fastp and Kraken2 reports into one HTML summary."""
    input:
        multiqc_inputs,
    output:
        html=f"{OUTDIR}/multiqc/multiqc_report.html",
    params:
        indir=OUTDIR,
        outdir=f"{OUTDIR}/multiqc",
    conda:
        "../envs/multiqc.yaml"
    log:
        f"{OUTDIR}/logs/multiqc/multiqc.log",
    shell:
        r"""
        multiqc --force \
            --outdir {params.outdir} \
            --filename multiqc_report.html \
            {params.indir}/fastqc {params.indir}/trimmed {params.indir}/kraken2 \
            > {log} 2>&1
        """
