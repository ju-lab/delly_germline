# Snakefile to run Processed BAM -> germline SV calling 
# 2018.06.24 Jongsoo Yoon

configfile: 'pathConfig.yaml'
configfile: 'sampleConfig.yaml'

rule all:
    input:
        'done'

rule initial_call:
    input:
        delly = config['delly'], 
        ref = config['reference'], 
        dellymask = config['dellymask'], 
        bam = lambda wildcards: config['samples'][wildcards.sample],
    output:
        'initial_call/{sample}.bcf'
    log:
        'logs/{sample}.initial_call.log'
    threads: 1
    shell:
        "({input.delly} call -g {input.ref} -o {output} "
        "-x {input.dellymask} {input.bam}) &> {log}"

rule merge_svsites:
    input:
        delly = config['delly'], 
        initial_calls = expand("initial_call/{sample}.bcf", sample=config["samples"])
    output:
        merged_sites = 'merged_sites/sites.bcf'
    log:
        'logs/merge_svsites.log'
    shell:
        "({input.delly} merge -o {output.merged_sites} "
        "{input.initial_calls}) &> {log} "

rule genotype:
    input:
        delly = config['delly'], 
        bam = lambda wildcards: config['samples'][wildcards.sample],
        ref = config['reference'], 
        merged_sites = 'merged_sites/sites.bcf', 
        dellymask = config['dellymask']
    output:
        genotyped = 'genotyped/{sample}.geno.bcf'
    log:
        'logs/{sample}.genotype.log'
    shell:
        "({input.delly} call -g {input.ref} -v {input.merged_sites} "
        "-o {output.genotyped} -x {input.dellymask} "
        "{input.bam}) &> {log}"

rule merge_genotype:
    input:
        bcftools = config['bcftools'], 
        genotyped_bcf = expand('genotyped/{sample}.geno.bcf', sample=config['samples'])
    output:
        merged_genotype = 'merged_genotype/merged.bcf'
    log:
        'logs/merge_genotype.log'
    shell:
        "({input.bcftools} merge -m id -O b -o {output.merged_genotype} "
        "{input.genotyped_bcf}) &> {log}"

rule filter:
    input: 
        delly = config['delly'], 
        merged_genotype = 'merged_genotype/merged.bcf'
    output:
        germline_bcf = 'final/delly_germline.bcf'
    log:
        'logs/filter.log'
    shell:
        "({input.delly} filter -f germline "
        "-o {output.germline_bcf} {input.merged_genotype}) &> {log}"
        

rule finish:
    input:
        outfile = 'final/delly_germline.bcf'
    output:
        'done'
    log:
        "logs/done.log"
    shell:
        "(touch {output}) &> {log}"