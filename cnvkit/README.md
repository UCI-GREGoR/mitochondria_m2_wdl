# cnvkit-wdl
WDL implementation of the [cnvkit docker image by etal](https://hub.docker.com/r/etal/cnvkit/tags)

Workflows can be broken down as follows:
* Pooled coverage reference generation
  * Pooled male and female references are generated using cohorts of healthy samples, unlikely to have copy number alterations.
  * Samples are specified in a corresponding "participants.txt" tab-separated table with the following format:

  | **Participant ID** | **BAM/CRAM File URI** | **BAI/CRAI File URI** | **VCF File URI** | **Participant Sex (f or m)** |
  | ------------------ | --------------------- | --------------------- | ---------------- | :--------------------------: |
  | PMGRC-1-1-0 | s3://pmgrc-gregor-data/wgs-short-read/../crams/PMGRC-1-1-0.cram | s3://pmgrc-gregor-data/wgs-short-read/../crams/PMGRC-1-1-0.crai | s3://pmgrc-gregor-data/wgs-short-read/../snv_vcfs/PMGRC-1-1-0.snv.vcf.gz | f |
  | PMGRC-2-1-2 | s3://pmgrc-gregor-data/wgs-short-read/../crams/PMGRC-2-1-2.cram | s3://pmgrc-gregor-data/wgs-short-read/../crams/PMGRC-2-1-2.crai | s3://pmgrc-gregor-data/wgs-short-read/../snv_vcfs/PMGRC-2-1-2.snv.vcf.gz | f |

  * Headers are not supported in the "participants.txt" file. CSV must be converted to TSV. No whitespace characters allowed in participant IDs. 
  * The participants filename must match what is provided in the corresponding "inputs.json"
  * VCF files and participant sex are not necessary when generating a reference and the columns may be left blank
  * For both reference generation and processing, each BAM/CRAM is expected to be indexed prior to processing
  * For a reference cohort:
    * cnvkit.py access generates an "access.bed" file from the reference fasta and excludes any problematic regions from the "excludes.bed" file.
      * Minimum gap size is left at the default 5000bp
      * Currently using the [ENCODE Blacklist](https://hgdownload.soe.ucsc.edu/gbdb/hg38/problematic/encBlacklist.bb) and converting to bed with [bigBedToBed](http://hgdownload.soe.ucsc.edu/admin/exe/linux.x86_64/bigBedToBed)
    * cnvkit.py autobin generates a "targets.bed" file from a CRAM file representing the median coverage in the cohort
      * cnvkit.py autobin uses a [sequence accessibility reference](https://github.com/etal/cnvkit/blob/master/data/access-10kb.hg38.bed), a preset bin size (50kb), and annotates genes with a [flat file](https://github.com/etal/cnvkit/blob/master/data/refFlat_hg38.txt)
    * cnvkit.py coverage generates a bin-level coverage map (.cnn) using the targets.bed file previously generated
  * cnvkit.py reference combines all CNNs to generate a pooled coverage reference. This represents normal coverage for the given library type.
  * Required input files include:
    * A cohort of unaffected participants (n>30), mix of males and females processed identically to the affected participants to be analyzed (same library prep, same sequencing methodology)
    * Indexed alignments from all participants (bams and bais or crams and crais)
  * Output files include:
    * access bed file of reference genome (e.g. access-5kb.mappable.hg38.bed)
    * target and antitarget bed files for the median-coverage sample (e.g. NA12878.targets.hg38.bed and NA12878.antitargets.hg38.bed)
    * targetcoverage and antitargetcoverage coverage map files for each sample in the cohort (e.g. NA12878.targetcoverage.cnn and NA12878.antitargetcoverage.cnn)
    * combined cohort reference coverage map file (e.g. GIAB.hg38.reference.cnn)

* Analysis of affected samples
  * cnvkit.py coverage is used with the cohort reference to generate coverage maps (.targetcoverage.cnn and .antitargetcoverage.cnn) for on-target and off-target regions respectively
    * For WGS, off-target regions are always empty
    * This is the only tool used in this pipeline in cnvkit.py that supports multi-threading and is also the most time consuming.
  * cnvkit.py fix is used to generate copy number region (.cnr) calls from coverage maps (.cnn) while adjusting for GC biases
  * cnvkit.py segment is used to call copy number segments (.cns)
  * cnvkit.py call -m clonal is used to get integer copy number calls from CNS calls as well as to calculate B-allele frequencies from an SNV VCF file
  * cnvkit.py export exports copy number segments to VCF formats for downstream annotation and joint calling
  * cnvkit.py scatter generates a coverage scatter plot from the supplied CNR, CNS, and VCF
  * cnvkit.py diagram generates a coverage diagram plot from the supplied CNR and CNS
  * Required inputs include:
    * 1 or many affected participants
    * indexed alignments from all participants (bams and bais or crams and crais)
    * matching SNV VCFs from all participants
    * known sex of each participant
    * a reference coverage map generated with cnvkit.py reference
    * target and antitarget bed files from reference sample
  * Output files for each affected participant include:
    * targetcoverage and antitargetcoverage coverage map files (e.g. PMGRC-1-1-0.targetcoverage.cnn and PMGRC-1-1-0.antitargetcoverage.cnn)
    * copy number region files (e.g. PMGRC-1-1-0.cnr)
    * copy number segment files (e.g. PMGRC-1-1-0.cns)
    * called copy number segment files (e.g. PMGRC-1-1-0.call.cns)
    * CNV VCF files exported from .call.cns files (e.g. PMGRC-1-1-0.cnv.vcf)
    * a scatter plot of coverage with B-allele frequencies (e.g. PMGRC-1-1-0.scatter.png)
    * a diagram plot of coverage (e.g. PMGRC-1-1-0.diagram.pdf)
