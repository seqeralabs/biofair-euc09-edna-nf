# =============================================================================
# rules/qc.smk  --  raw-read QC and adapter/quality trimming
# =============================================================================


rule fastqc_raw:
    """Quality control of the raw input reads with FastQC."""
    input:
        get_raw_reads,
    output:
        html=f"{OUTDIR}/fastqc/{{sample}}_fastqc.html",
        zip=f"{OUTDIR}/fastqc/{{sample}}_fastqc.zip",
    params:
        outdir=lambda wc: f"{OUTDIR}/fastqc",
    threads: config["threads"]["fastqc"]
    conda:
        "../envs/fastqc.yaml"
    log:
        f"{OUTDIR}/logs/fastqc/{{sample}}.log",
    shell:
        r"""
        fastqc --threads {threads} --outdir {params.outdir} {input} > {log} 2>&1
        """


rule fastp_trim:
    """Adapter and quality trimming with fastp (handles SE and PE)."""
    input:
        get_raw_reads,
    output:
        r1=f"{OUTDIR}/trimmed/{{sample}}_1.trim.fastq.gz",
        r2=f"{OUTDIR}/trimmed/{{sample}}_2.trim.fastq.gz",
        json=f"{OUTDIR}/trimmed/{{sample}}.fastp.json",
        html=f"{OUTDIR}/trimmed/{{sample}}.fastp.html",
    params:
        paired=is_paired,
        min_length=config["fastp"]["min_length"],
        qual=config["fastp"]["quality_cutoff"],
        adapter=lambda wc: (
            f"--adapter_fasta {config['fastp']['adapter_fasta']}"
            if config["fastp"]["adapter_fasta"]
            else ""
        ),
        detect_pe=lambda wc: (
            "--detect_adapter_for_pe"
            if config["fastp"]["detect_adapter_for_pe"]
            else ""
        ),
    threads: config["threads"]["fastp"]
    conda:
        "../envs/fastp.yaml"
    log:
        f"{OUTDIR}/logs/fastp/{{sample}}.log",
    shell:
        r"""
        if [ "{params.paired}" = "True" ]; then
            fastp \
                --in1 {input[0]} --in2 {input[1]} \
                --out1 {output.r1} --out2 {output.r2} \
                --json {output.json} --html {output.html} \
                --length_required {params.min_length} \
                --cut_right --cut_right_mean_quality {params.qual} \
                {params.detect_pe} {params.adapter} \
                --thread {threads} > {log} 2>&1
        else
            fastp \
                --in1 {input[0]} \
                --out1 {output.r1} \
                --json {output.json} --html {output.html} \
                --length_required {params.min_length} \
                --cut_right --cut_right_mean_quality {params.qual} \
                {params.adapter} \
                --thread {threads} > {log} 2>&1
            # keep the rule's output contract stable for SE samples
            touch {output.r2}
        fi
        """


rule host_removal:
    """Optional removal of host / contaminant reads via Bowtie2.

    When config['host_removal']['enabled'] is False this rule is bypassed by
    the downstream `decontaminated_reads` input function in classify.smk.
    """
    input:
        r1=f"{OUTDIR}/trimmed/{{sample}}_1.trim.fastq.gz",
        r2=f"{OUTDIR}/trimmed/{{sample}}_2.trim.fastq.gz",
    output:
        r1=f"{OUTDIR}/decontam/{{sample}}_1.clean.fastq.gz",
        r2=f"{OUTDIR}/decontam/{{sample}}_2.clean.fastq.gz",
    params:
        index=config["host_removal"]["bowtie2_index"],
    threads: config["threads"]["host_removal"]
    conda:
        "../envs/host_removal.yaml"
    log:
        f"{OUTDIR}/logs/host_removal/{{sample}}.log",
    shell:
        r"""
        # Map against host index, keep read pairs where NEITHER mate maps
        bowtie2 -p {threads} -x {params.index} \
            -1 {input.r1} -2 {input.r2} \
            --un-conc-gz {OUTDIR}/decontam/{wildcards.sample}_%.clean.fastq.gz \
            -S /dev/null > {log} 2>&1
        mv {OUTDIR}/decontam/{wildcards.sample}_1.clean.fastq.gz {output.r1}
        mv {OUTDIR}/decontam/{wildcards.sample}_2.clean.fastq.gz {output.r2}
        """
