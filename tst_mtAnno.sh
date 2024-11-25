#!/bin/sh

refPath="/Users/hadleyking/GitHub/UCI-GREGoR/mitochondria_m2_wdl/home"
# Annotation with GATK VariantAnnotator
gnomad_vcf="${refPath}/gnomad.genomes.v3.1.sites.chrM.vcf.bgz"
clinvar_vcf="${refPath}/clinvar_20240407.vcf.gz"
mitomap_vcf="${refPath}/disease.vcf"
tApogee_vcf="${refPath}/t-APOGEE_2024.0.1.vcf"

        # --reference "${refPath}/hg38.chrM.fa" \
for vcf in home/output_vcf/*.final.split.vcf ; do
    echo "My tst ${gnomad_vcf}" 
    /opt/gatk-4.5.0.0/gatk VariantAnnotator \
        --reference "${refPath}/reference_files/Homo_sapiens_assembly38.chrM.fasta" \
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
done