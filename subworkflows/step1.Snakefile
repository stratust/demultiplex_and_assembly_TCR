import os, glob, re

configfile: 'config.yml'
CWD = os.getcwd()
OUTPUTDIR = config['OUTPUTDIR']
DATA_DIR =  config['DATADIR']

FASTQ_FILES = glob.glob(DATA_DIR + '/*.fastq.gz')

FILTERED_FASTQ = list(
                set(
                    [
                        OUTPUTDIR + '/PhiX_Removal/' +
                        os.path.basename( re.sub('L001_R[12]','filtered_L001_R12', file) ) for file in FASTQ_FILES
                    ]
                )
            )


container: "docker://condaforge/mambaforge:4.13.0-1"

rule demultiplex_samples_using_plate_and_wells_barcodes:
    input: FILTERED_FASTQ
    output: OUTPUTDIR + '/PhiX_Removal/done.txt'
    params:
        plate_barcode = config['PLATE_BARCODES'],
        row_barcode = config['ROW_BARCODES'],
        column_barcode = config['COLUMN_BARCODES'],
        output_folder = CWD + '/' + OUTPUTDIR + '/demultiplexed_data/'
    threads: 256
    conda:
        "../envs/perl.yaml"
    shell:
        """
            rm -rf {params.output_folder}
            mkdir {params.output_folder}
            gunzip -c {input} >  {params.output_folder}/interleaved.fastq
            parallel -j {threads}  \
                --pipepart \
                -a {params.output_folder}/interleaved.fastq \
                --block -1 \
                --regexp \
                --recend '\n' \
                --recstart '@.*(/1| 1:.*)\n[A-Za-z\n\.~]' \
                    "perl scripts/demultiplex.pl foo \
                        --plate_barcode_file {params.plate_barcode} \
                        --row_barcode_file {params.row_barcode} \
                        --column_barcode_file {params.column_barcode} \
                        --output_folder {params.output_folder} \
                        --fastq_file -"
            rm -rf {params.output_folder}/interleaved.fastq 
            find {params.output_folder} -iname "*.fastq" | parallel -j {threads} --bar "gzip {{}}"

            touch {output}
        """

rule remove_phix:
    input: expand(DATA_DIR + '/{{sample}}_L001_R{pair}_001.fastq.gz', pair=['1','2'])
    output:
        OUTPUTDIR + '/PhiX_Removal/{sample}_filtered_L001_R12_001.fastq.gz',
    params:
        phix_ref = config['PHIX_GENOME_REF']
    threads: 10
    resources:
        mem_mb=8000
    conda:
        "../envs/bbmap.yaml"
    shell:
        """
            _JAVA_OPTIONS="-XX:ParallelGCThreads=1 -XX:+UseParallelGC" bbduk.sh -Xmx{resources.mem_mb}M \
            in1={input[0]} in2={input[1]} \
            out={output[0]} \
            ref={params.phix_ref} \
            threads={threads}
            k=31 \
        """
