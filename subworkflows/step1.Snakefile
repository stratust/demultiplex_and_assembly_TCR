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
                        os.path.basename( re.sub('L001', 'filtered_L001', file) ) for file in FASTQ_FILES
                    ]
                )
            )


print(FILTERED_FASTQ)

rule run_all:
    input: FILTERED_FASTQ
    output: OUTPUTDIR + '/PhiX_Removal/done.txt'
    params:
        plate_barcode = config['PLATE_BARCODES'],
        row_barcode = config['ROW_BARCODES'],
        column_barcode = config['COLUMN_BARCODES'],
        samplesheet_file = config['SAMPLESHEET'],
        output_folder = CWD + '/' + OUTPUTDIR + '/demultiplexed_data/'
    shell:
        """
            perl scripts/demultiplex.pl foo \
            --plate_barcode_file {params.plate_barcode} \
            --row_barcode_file {params.row_barcode} \
            --column_barcode_file {params.column_barcode} \
            --samplesheet_file {params.samplesheet_file}\
            --fastq_file_r1 {input[0]} \
            --fastq_file_r2 {input[1]} \
            --output_folder {params.output_folder}

            find {params.output_folder} -iname "*.fastq" | parallel -j 70 --bar "gzip {{}}"

            touch {output}

        """

rule remove_phix:
    input: expand(DATA_DIR + '/{{sample}}_L001_R{pair}_001.fastq.gz', pair=['1','2'])
    output:
        expand(OUTPUTDIR + '/PhiX_Removal/{{sample}}_filtered_L001_R{pair}_001.fastq.gz', pair=['1','2'])
    params:
        phix_ref = config['PHIX_GENOME_REF']
    threads: 10
    resources:
        mem_mb=8000
    shell:
        """
            _JAVA_OPTIONS="-XX:ParallelGCThreads=1 -XX:+UseParallelGC" bbduk.sh -Xmx{resources.mem_mb}M \
            in1={input[0]} in2={input[1]} \
            out1={output[0]} out2={output[1]} \
            ref={params.phix_ref} \
            threads={threads}
            k=31 \
        """
