#!/bin/sh

# GATK Mitochondrial WDL and annotation

# See: https://gatk.broadinstitute.org/hc/en-us/articles/4403870837275-Mitochondrial-short-variant-discovery-SNVs-Indels-

# Tools used:
# * GATK v4.5.0.0
# * * HTSJDK Version: 4.1.0
# * * Picard Version: 3.1.1
# * Haplocheck 1.3.2
# * bwa-mem2 2.2.1 in AVX512 mode

set -e

# Please change paths for cromwell and refPath which has reference files
cromwell="/home/vlab/miniconda3/envs/cromwell/bin/cromwell"
refPath="/mnt/data1/ref/hg38/mt"
input_json=$1

# Run cromwell locally
# * Will need to edit this for batching with cromwell server
for json in ${input_json}/*.json ; do
    $cromwell run "MitochondriaPipeline.wdl" -i $json
# This will create new folders 'cromwell-executions' and 'cromwell-workflow-logs'
# Copy results to a new folder in the current working directory
mkdir output_vcf/
cp cromwell-executions/MitochondriaPipeline/*/call-SplitMultiAllelicSites/execution/*.final.split.vcf* output_vcf/

# Annotation with GATK VariantAnnotator
gnomad_vcf="${refPath}/gnomad.genomes.v3.1.sites.chrM.vcf.bgz"
clinvar_vcf="${refPath}/clinvar_20240407.chrM.vcf.gz"
mitomap_vcf="${refPath}/mitomap_disease_reheader.vcf.gz"
tApogee_vcf="${refPath}/tAPOGEE_2024.0.1.vcf.gz"
for vcf in output_vcf/*.final.split.vcf ; do
    gatk VariantAnnotator \
        --reference "${refPath}/hg38.chrM.fa" \
        --variant $vcf \
        --output "output_vcf/${basename}.anno.vcf" \
        --resource:gnomad $gnomad_vcf \
        --resource:clinvar $clinvar_vcf \
        --resource:mitomap $mitomap_vcf \
        --resource:tApogee $tApogee_vcf \
        --expression "gnomad.vep" \
        --expression "gnomad.AF_hom" \
        --expression "gnomad.AF_het" \
        --expression "gnomad.max_hl" \
        --expression "clinvar.ID" \
        --expression "clinvar.CLNSIG" \
        --expression "clinvar.CLNREVSTAT" \
        --expression "mitomap.Disease" \
        --expression "tApogee.tAPOGEE_score"
