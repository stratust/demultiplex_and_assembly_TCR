import os, glob, re

configfile: 'config.yml'
CWD = os.getcwd()
OUTPUTDIR = config['OUTPUTDIR']
DATA_DIR =  config['DATADIR']

FASTQ_FILES = glob.glob(OUTPUTDIR + '/demultiplexed_data/*R1_001.fastq.gz')

TRUST_REPORT = list(
                set(
                    [
                        OUTPUTDIR + '/TRUST/' +
                        os.path.basename( re.sub('_L001.*', '', file) ) + '/' +
                        os.path.basename( re.sub('_L001.*', '_report.tsv', file) ) for file in FASTQ_FILES
                    ]
                )
            )

TRUST_REPORT_R2 = list(
                set(
                    [
                        OUTPUTDIR + '/TRUST_R2_ONLY/' +
                        os.path.basename( re.sub('_L001.*', '', file) ) + '/' +
                        os.path.basename( re.sub('_L001.*', '_report.tsv', file) ) for file in FASTQ_FILES
                    ]
                )
            )

container: "docker://condaforge/mambaforge:4.13.0-1"

rule run_all:
    input: [ TRUST_REPORT ]
    output: OUTPUTDIR + '/TRUST/done.txt'
    shell:
        """
            touch {output}
        """


rule run_trust:
    input:
        OUTPUTDIR+"/bbmerge/{sample}/{sample}_L001_merged.fastq.gz",
    output:
        OUTPUTDIR + '/TRUST/{sample}/{sample}_report.tsv'
    params:
        human_imgt_plus_c = CWD + '/database/TRUST4/human_IMGT+C.fa',
        results_path = CWD + '/results/TRUST/{sample}/{sample}'
    threads: 10
    log: CWD + '/results/TRUST/{sample}/{sample}_trust.log'
    conda:
        "../envs/trust4.yaml"
    shell:
        """
            if [[ $(gunzip -c {input} | wc -l) -eq 0  ]];then
                echo "#count\tfrequency\tCDR3nt\tCDR3aa\tV\tD\tJ\tC\tcid" > {output}
            else
                run-trust4 -f {params.human_imgt_plus_c} \
                --ref {params.human_imgt_plus_c} \
                -t {threads} \
                -u {input[0]} \
                -o {params.results_path} > {log} 2>&1
            fi
        """


rule run_trust_r2:
    input:
        OUTPUTDIR+"/QC/{sample}/{sample}_L001_R2_001_val_2.fq.gz",
    output:
        OUTPUTDIR + '/TRUST_R2_ONLY/{sample}/{sample}_report.tsv'
    params:
        human_imgt_plus_c = CWD + '/database/TRUST4/human_IMGT+C.fa',
        results_path = CWD + '/results/TRUST_R2_ONLY/{sample}/{sample}'
    threads: 10
    log: CWD + '/results/TRUST_R2_ONLY/{sample}/{sample}_trust.log'
    conda:
        "../envs/trust4.yaml"
    shell:
        """
            run-trust4 -f {params.human_imgt_plus_c} \
            --ref {params.human_imgt_plus_c} \
            -t {threads} \
            -u {input[0]} \
            -o {params.results_path} > {log} 2>&1
        """
