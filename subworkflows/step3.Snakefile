import os, glob, re

configfile: 'config.yml'
CWD = os.getcwd()
OUTPUTDIR = config['OUTPUTDIR']
DATA_DIR =  config['DATADIR']

FASTQ_FILES_R1 = glob.glob(OUTPUTDIR + '/demultiplexed_data/*R1_001.fastq.gz')

BBMERGE_OUTPUT = list(
                set(
                    [
                        OUTPUTDIR + '/bbmerge/' +
                        os.path.basename( re.sub('_L001.*', '', file) ) + '/' +
                        os.path.basename( re.sub('_R1_001.fastq.gz', '_merged.fastq.gz', file) ) for file in FASTQ_FILES_R1
                    ]
                )
            )

container: "docker://condaforge/mambaforge:4.13.0-1"

rule run_all:
    input: BBMERGE_OUTPUT
    output: OUTPUTDIR + '/bbmerge/done.txt'
    shell:
        """
            touch {output}
        """

rule run_bbmerge:
    input:
        expand(OUTPUTDIR+"/QC/{{sample}}/{{sample}}_L{{lane}}_R{pair}_001_val_{pair}.fq.gz",pair=['1','2'])
    output:
        merged = OUTPUTDIR+"/bbmerge/{sample}/{sample}_L{lane}_merged.fastq.gz",
    threads: 10
    resources:
        mem_mb=8000
    log: CWD + '/results/bbmerge/{sample}/{sample}_L{lane}_bbmerge.log'
    params:
        unmerged_r1 = OUTPUTDIR+"/bbmerge/{sample}/{sample}_L{lane}_R1_unmerged.fastq",
        unmerged_r2 = OUTPUTDIR+"/bbmerge/{sample}/{sample}_L{lane}_R2_unmerged.fastq",
        merged_unsorted=OUTPUTDIR+"/bbmerge/{sample}/{sample}_L{lane}_merged_unsorted.fastq.gz",
        merged_unzipped=OUTPUTDIR+"/bbmerge/{sample}/{sample}_L{lane}_merged.fastq"
    conda:
        "../envs/bbmap.yaml"
    shell:
        """
            _JAVA_OPTIONS="-XX:ParallelGCThreads=1 -XX:+UseParallelGC"  bbmerge-auto.sh -Xmx{resources.mem_mb}M \
            in1={input[0]} \
            in2={input[1]} \
            out={params.merged_unsorted} \
            outu1={params.unmerged_r1} \
            outu2={params.unmerged_r2} \
            threads={threads} pfilter=1 rem k=62 vstrict > {log} 2>&1

            gunzip -c {params.merged_unsorted} | fastq-sort --id > {params.merged_unzipped}

            gzip {params.merged_unzipped}
        """
