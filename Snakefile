import os

configfile: 'config.yml'
CWD = os.getcwd()
OUTPUTDIR = config['OUTPUTDIR']

subworkflow step_one:
    snakefile: 'subworkflows/step1.Snakefile'

subworkflow step_two:
    snakefile: 'subworkflows/step2.Snakefile'

subworkflow step_three:
    snakefile: 'subworkflows/step3.Snakefile'

subworkflow step_four:
    snakefile: 'subworkflows/step4.Snakefile'



rule all_subworkflows:
    input:
        step_one('results/PhiX_Removal/done.txt'),
        step_two('results/QC/done.txt'),
        step_three('results/bbmerge/done.txt'),
        step_four('results/TRUST/done.txt')
