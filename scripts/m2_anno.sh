#!/bin/sh

# GATK Mitochondrial WDL and annotation

# See: https://gatk.broadinstitute.org/hc/en-us/articles/4403870837275-Mitochondrial-short-variant-discovery-SNVs-Indels-

set -e

# Please change paths for cromwell and refPath which has reference files
work_path="../"
ref_path="${work_path}/ref/"
input_json="${work_path}/input_json"

# Run cromwell locally
# * Activate cromwell conda environment before running
for json in ${input_json}/*.json ; do
    cromwell run "./MitochondriaPipeline.wdl" -i $json
# This will create new folders 'cromwell-executions' and 'cromwell-workflow-logs'
# Copy results to a new folder in the current working directory
output_vcf=${work_path}/output_vcf
mkdir $output_vcf
cp ${work_path}/cromwell-executions/MitochondriaPipeline/*/call-SplitMultiAllelicSites/execution/*.final.split.vcf* \
    ${output_vcf}/

# Annotation with GATK VariantAnnotator
gnomad_vcf="${refPath}/chrM/gnomad.genomes.v3.1.sites.chrM.vcf.bgz"
clinvar_vcf="${refPath}/chrM/clinvar_20240407.chrM.vcf.gz"
mitomap_vcf="${refPath}/chrM/mitomap_disease.vcf.gz"
tApogee_vcf="${refPath}/chrM/t-APOGEE_2024.0.1.vcf"
hg38_fa="${refPATH}/Homo_sapiens_assembly38.fasta"
for vcf in ${output_vcf}/*.final.split.vcf ; do
    sample_id=$(basename ${vcf%%.*})
    gatk VariantAnnotator \
        --reference $hg38_fa \
        --variant $vcf \
        --output "${output_vcf}/${sample_id}.anno.vcf" \
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
