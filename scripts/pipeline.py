#!/usr/bin/env python3

import docker
import glob
import multiprocessing as mp
import os
import subprocess as sp
import mito_report.py


def run_cromwell(input_json):
    exit_code = sb.call([
        'cromwell',
        'run',
        'MitochondriaPipeline.wdl',
        '-i',
        input_json
        ])
    if exit_code != 0:
        print(f"{json_input} failed with code {exit_code}")


def annotate_vcf(vcf):
    anno_vcf = vcf.split('.')[0] + '.anno.vcf'
    hg38_fasta = 'ref/Homo_sapiens_assembly38.fasta'
    gnomad_vcf = 'ref/chrM/gnomad.genomes.v3.1.sites.chrM.vcf.bgz'
    clinvar_vcf = 'ref/chrM/clinvar_20240407.chrM.vcf.gz'
    mitomap_vcf = 'ref/chrM/mitomap_disease.vcf.gz'
    tApogee_vcf = 'ref/chrM/t-APOGEE_2024.0.1.vcf'
    gatk_cmd = [
            'gatk','VariantAnnotator',
            '--reference',hg38_fasta,
            '--variant',vcf,
            '--output',anno_vcf,
            '--resource:gnomad',gnomad_vcf,
            '--resource:clinvar',clinvar_vcf,
            '--resource:mitomap',mitoamp_vcf,
            '--resource:tApogee',tApogee_vcf,
            '--expression','gnomad.vep',
            '--expression','gnomad.AF_hom',
            '--expression','gnomad_AF_het',
            '--expression','gnomad.max_hl',
            '--expression','clinvar.ID',
            '--expression','clinvar.CLNSIG',
            '--expression','clinvar.CLNREVSTAT',
            '--expression','mitomap.Disease',
            '--expression','tApogee.tAPOGEE_score'
            ]

    client = docker.from_env()
    container = client.create_container(
            image='broadinstitute/gatk:4.5.0.0',
            volumes=['./'],
            host_config=host_config
            )


if __name__ == '__main__':
    os.chdir('../')  # Change working directory to root of project
    cromwell_path = 'cromwell-executions/MitochondriaPipeline/*/'
            + 'call-SplitMultiAllelicSites/execution/'
    vcf_extension = 'alignedHg38.duplicateMarked.baseRealigned.final.split.vcf'
    output_vcfs = 'output_vcfs/'
    cores = multiprocessing.cpu_count()
    for input_json in glob.glob('input_jsons/*.json'):
        sample_id = os.path.basename(json_input.split('.')[0])
        run_cromwell(input_json)
        #q = mp.Queue()
        #p = mp.Process(target=run_cromwell, args=(input_json))
        #p.start()
        #print(q.get())
        #p.join()
        cromwell_vcf = glob.glob(f"{cromwell_path}/{sample_id}.{vcf_extension}")
        cromwell_vcf_idx = glob.glob(f"{cromwell_path}/{sample_id}.{vcf_extension}.idx")
        os.system(f"cp {cromwell_vcf} {output_vcfs}")
        os.system(f"cp {cromwell_vcf_idx} {output_vcfs}")
