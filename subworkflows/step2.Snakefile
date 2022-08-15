import os, glob, re

configfile: 'config.yml'
CWD = os.getcwd()
OUTPUTDIR = config['OUTPUTDIR']
DATA_DIR =  config['DATADIR']

FASTQ_FILES_R1 = glob.glob(OUTPUTDIR + '/demultiplexed_data/*R1_001.fastq.gz')
FASTQ_FILES_R2 = glob.glob(OUTPUTDIR + '/demultiplexed_data/*R2_001.fastq.gz')

TRIMGALORE_OUTPUT_R1 = list(
                set(
                    [
                        OUTPUTDIR + '/QC/' +
                        os.path.basename( re.sub('_L001.*', '', file) ) + '/' +
                        os.path.basename( re.sub('001.fastq.gz', '001_val_1.fq.gz', file) ) for file in FASTQ_FILES_R1
                    ]
                )
            )

TRIMGALORE_OUTPUT_R2 = list(
                set(
                    [
                        OUTPUTDIR + '/QC/' +
                        os.path.basename( re.sub('_L001.*', '', file) ) + '/' +
                        os.path.basename( re.sub('001.fastq.gz', '001_val_2.fq.gz', file) ) for file in FASTQ_FILES_R2
                    ]
                )
            )

container: "docker://condaforge/mambaforge:4.13.0-1"

rule run_all:
    input: [TRIMGALORE_OUTPUT_R1, TRIMGALORE_OUTPUT_R2]
    output: OUTPUTDIR + '/QC/done.txt'
    shell:
        """
            touch {output}
        """

rule run_trim_galore:
    input:
        expand(OUTPUTDIR + '/demultiplexed_data/{{sample}}_L{{lane}}_R{pair}_001.fastq.gz', pair=['1','2'])
    output:
        expand(OUTPUTDIR+"/QC/{{sample}}/{{sample}}_L{{lane}}_R{pair}_001_val_{pair}.fq.gz",pair=['1','2'])
    params:
        five_prime_clip_r1 = 35, # NN + Plate_Barcode + GA + Row_Barcode + Common Sequence from PCR reaction #2
        three_prime_clip_r2 = 7,
        output_dir=OUTPUTDIR+'/QC/{sample}'
    threads: 10
    log: CWD + '/results/QC/{sample}/{sample}_L{lane}_trim_galore.log'
    conda:
        "../envs/trim_galore.yaml"
    shell:
        """
            _JAVA_OPTIONS='' trim_galore --paired \
            --quality 20 \
            --stringency 5 \
            --fastqc \
            --clip_R1 {params.five_prime_clip_r1} \
            --clip_R2 {params.three_prime_clip_r2} \
            --output_dir={params.output_dir} \
            {input[0]} {input[1]} > {log} 2>&1
        """
