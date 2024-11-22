# mitochondrial-calling
Collection of configurations for GATK mitochondrial (MT) small variant calling from short-read WGS alignments.

Currently using the [GATK Mitochondria Pipeline 4.5.0.0](https://dockstore.org/workflows/github.com/broadinstitute/gatk/MitochondriaPipeline:4.5.0.0?tab=info) WDL. 
Testing was done with [Google Terra](https://terra.bio/) and with a local instance of Cromwell with a docker backend. 

Best practices were followed in accordance with [GATK's best practice workflows](https://gatk.broadinstitute.org/hc/en-us/articles/4403870837275-Mitochondrial-short-variant-discovery-SNVs-Indels-)

The tool runs as is with Google Terra with the only required configuration being a path to the input BAM or CRAM file.

In summary, this pipeline performs the following tasks:
* Subset the mitochondrial reads from a WGS BAM/CRAM
* Realign the BAM or CRAM against to the MT and the shifted MT genome with BWA
* Carry over BQSR read tags from the WGS BAM/CRAM to the MT BAM
* Call variants with Mutect2 on the both the original mitochondrial BAM/CRAM and shifted mitochondrial BAM/CRAM
* Merge both variant calls into a consensus VCF using a liftover file for the shifted mitochondrial genome
* Apply masking using a blacklists file

# Prerequisites
* For a local runtime, a cromwell installation is required. See the [Cromwell readthedocs](https://cromwell.readthedocs.io/en/stable/Releases/)
* A backend such as Docker or Singularity is also required to use cromwell.
* The following [reference genome](ftp://ftp.ncbi.nlm.nih.gov/genomes/all/GCA/000/001/405/GCA_000001405.15_GRCh38/seqs_for_alignment_pipelines.ucsc_ids/GCA_000001405.15_GRCh38_no_alt_analysis_set.fna.gz) is also needed for the annotation step.
* A local GATK installation for running VariantAnnotator
* A samtools installation for getting MT coverage

Outside of the WDL the following annotations are performed
* [gnomAD v3.1 sites](https://gnomad.broadinstitute.org/downloads#v3-mitochondrial-dna)
* [clinvar_20240407](https://ftp.ncbi.nlm.nih.gov/pub/clinvar/vcf_GRCh38/archive_2.0/2024/clinvar_20240407.vcf.gz)
* [mitomap_disease](https://mitomap.org/cgi-bin/disease.cgi?format=vcf)
* [tAPOGEE_2024.0.1](https://mitimpact.css-mendel.it/cdn/t-APOGEE_2024.0.1.txt.zip)
Note that MITOMAP disease requires reformatting with PicardTools and tAPOGEE needs to be restructured as a VCF to work with GATK VariantAnnotator

For MITOMAP Disease, make the following edits:
* Add the following FORMAT fields to the header with your favorite text editor:

`##FORMAT=<ID=AD,Number=R,Type=Integer,Description="Allelic depths for the ref and alt alleles in the order listed">`

`##FORMAT=<ID=DP,Number=1,Type=Integer,Description="Approximate read depth (reads with MQ=255 or with bad mates are filtered)">`

`##FORMAT=<ID=FT,Number=.,Type=String,Description="Genotype-level filter">`

`##FORMAT=<ID=GQ,Number=1,Type=Integer,Description="Genotype Quality">`

`##FORMAT=<ID=GT,Number=1,Type=String,Description="Genotype">`

`##FORMAT=<ID=PL,Number=G,Type=Integer,Description="Normalized, Phred-scaled likelihoods for genotypes as defined in the VCF specification">`

For tAPOGEE, make the following edits with your favorite spreadsheet editor:

* For the INFO column, create the following excel formula to populate it accordingly. Fill the formula down.

`="Gene_symbol="&E2&";tAPOGEE_score="&F2&";tAPOGEE_unbiased_score="&G2`

* Insert new columns for "ID", "QUAL", and "FILTER" in the following order and fill them down with the '.' character.

`#CHROM  POS     ID      REF     ALT     QUAL    FILTER  INFO`

* Delete the "Gene_symbol", "t-APOGEE_score", and "t-APOGEE_unbiased_score" columns.

* Add the following VCF header:

`##fileformat=VCFv4.2`

`##FILTER=<ID=PASS,Description="All filters passed">`

`##fileDate=20240503`

`##source=https://mitimpact.css-mendel.it/cdn/tAPOGEE_2024.0.1.txt.zip`

`##reference=https://www.ncbi.nlm.nih.gov/nuccore/251831106`

`##contig=<ID=chrM,length=16569,assembly=hg38>`

`##INFO=<ID=Gene_symbol,Number=1,Type=String,Description="Gene symbol">`

`##INFO=<ID=tAPOGEE_score,Number=1,Type=Float,Description="tAPOGEE score">`

`##INFO=<ID=tAPOGEE_unbiased_score,Number=1,Type=Float,Description="tAPOGEE unbiased score">`

* Save as '.txt' file. Make sure it stays tab-delimited. 

* Rename the file extension as .vcf with your file explorer. Use a tool like dos2unix to edit the line endings.

# Running m2_anno.sh in your local cromwell instance
* Download the WDL ZIP folder from [Dockstore](https://dockstore.org/api/workflows/8801/zip/256948).
* Unzip it in your current working directory.
* Download the WDL references to a path on your local instance.
* Edit the input JSON template so the file paths match their actual locations.
* Make an input JSON folder for each sample's input JSON using the template provided in this repository.
* Edit the variables for `cromwell` and `refPath` to match your installation
* `sh m2_anno.sh intput_json` where `input_json` is the path to the input JSON folder
* When complete, this will create an `output_vcf` folder where final VCFs and annotated VCFs go.

# Running mito_report.py to create an excel report for all samples with participant phenotypes
* Download the `aligned_dna_short_read.tsv`, `analyte.tsv`, and `participant.tsv` from the latest upload set for GREGoR AnVIL (as of Oct 23, 2024 that would be U08).
* Run `samtools coverage` to get mitochondrial coverage metrics from the WGS BAMs/CRAMs
*   For CRAMs this requires the `--reference` argument with the path to the reference FASTA
*   `samtools coverage --reference GRCh38.fa -o wgs_metrics/${sample_id}.coverage.txt ${sample_id}.cram`
* Use conda to change environments to one with pandas and vcfpy installed.
* `python3 mito_report.py -p participant.tsv -a analyte.tsv -d aligned_dna_short_read.tsv -c wgs_metrics -i output_vcf -o mito.xlsx`
* This will print out an excel table with cohort information and all variant calls compiled. 
