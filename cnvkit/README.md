# cnvkit-wdl
WDL implementation of the [cnvkit docker image by etal](https://hub.docker.com/r/etal/cnvkit/tags)

Workflows can be broken down as follows:
* Pooled coverage reference generation
  * Pooled male and female references are generated using cohorts of healthy samples, unlikely to have copy number alterations.
  * For every reference sample:
    * cnvkit.py autobin generates a "targets.bed" file using a [sequence accessibility reference](https://github.com/etal/cnvkit/blob/master/data/access-10kb.hg38.bed), a preset bin size (50kb), and annotates genes with a [flat file](https://github.com/etal/cnvkit/blob/master/data/refFlat_hg38.txt)
    * cnvkit.py coverage generates a bin-level coverage map (.cnn) using the targets.bed file previously generated
  * cnvkit.py reference combines all the male or female CNNs to generate a male or female pooled coverage reference. This represents normal male/female coverage for the given library type.
* Analysis of affected samples
  * cnvkit.py batch is used with the matching pooled reference sex to generate copy number region (.cnr) calls and copy number segment (.cns) calls
  * cnvkit.py call -m clonal is used to get integer copy number calls from CNS calls as well as to calculate B-allele frequencies from an SNV VCF file
  * cnvkit.py scatter generates a coverage scatter plot from the supplied CNR, CNS, and germline VCF
  * cnvkit.py export exports copy number segments to BED and VCF formats for downstream annotation
