# mitochondrial-calling
Collection of configurations for GATK mitochondrial small variant calling from short-read WGS alignments.

Currently using the [GATK Mitochondria Pipeline 4.5.0.0](https://dockstore.org/workflows/github.com/broadinstitute/gatk/MitochondriaPipeline:4.5.0.0?tab=info) WDL. 
Testing was done with [Google Terra](https://terra.bio/). 

Best practices were followed in accordance with [GATK's best practice workflows](https://gatk.broadinstitute.org/hc/en-us/articles/4403870837275-Mitochondrial-short-variant-discovery-SNVs-Indels-)

In summary, this pipeline performs the following tasks:
* Subset the mitochondrial reads from a BAM or CRAM
* Realign the BAM or CRAM against a shifted mitochondrial genome with Burrows-Wheeler Aligner
* Call variants with Mutect2 on the both the original mitochondrial BAM/CRAM and shifted mitochondrial BAM/CRAM
* Merge both variant calls into a consensus VCF using a liftover file for the shifted mitochondrial genome
