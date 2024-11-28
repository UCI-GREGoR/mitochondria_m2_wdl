# mitochondrial-calling
Collection of configurations for GATK mitochondrial (MT) small variant calling from short-read WGS alignments.

Currently using the [GATK Mitochondria Pipeline 4.5.0.0](https://dockstore.org/workflows/github.com/broadinstitute/gatk/MitochondriaPipeline:4.5.0.0?tab=info) WDL. 
Testing was done a local instance of [Cromwell v86](https://cromwell.readthedocs.io/en/stable/Releases/) with a docker backend. 

Best practices were followed in accordance with [GATK's best practice workflows](https://gatk.broadinstitute.org/hc/en-us/articles/4403870837275-Mitochondrial-short-variant-discovery-SNVs-Indels-)

The tool runs as is with Google Terra with the only required configuration being a path to the input BAM or CRAM file.

In summary, this pipeline performs the following tasks:
* Subset the mitochondrial reads from a WGS BAM/CRAM
* Realign the BAM or CRAM against to the MT and the shifted MT genome with BWA
* Carry over GATK base quality score recalibration (BQSR) read tags from the WGS BAM/CRAM to the MT BAM
* Call variants with Mutect2 on the both the original mitochondrial BAM/CRAM and shifted mitochondrial BAM/CRAM
* Merge both variant calls into a consensus VCF using a liftover file for the shifted mitochondrial genome
* Apply masking using a blacklists file

# Prerequisites
* A UNIX-like operating system and POSIX-compliant shell. This guide will cover a typical Linux AMD64/x86_64 installation with Ubuntu 24.04 LTS.
* Minimum 4GB of RAM. 
* The following OS dependencies are needed. If not present, install them with the appropriate package manager (e.g. apt-get or dnf)
* * git
  * unzip
* Clone this repository into a directory with write permission and approximately 5 GB of free space.
* `git clone https://github.com/UCI-GREGoR/mitochondria_m2_wdl.git`
* A conda environment is required. Please install with [mamba](https://mamba.readthedocs.io/en/latest/installation/mamba-installation.html)
* A cromwell installation is required. For AMD64 Linux and Intel Mac OS, import the `environment_amd64.yaml` file with `mamba env create -f environment_amd64.yaml` to install cromwell and its dependencies.
* * For Mac OS on Apple Silicon, import the `environment_arm64.yaml` file with `mamba env create -f environment_arm64.yaml` to install cromwell and its dependencies.
* Activate the cromwell environment with `mamba activate cromwell` 
* Cromwell requires a backend such as [Docker](https://docs.docker.com/engine/install/) or [Apptainer](https://apptainer.org/docs/user/latest/quick_start.html). Docker for Linux was used in my case.
* * For Mac OS, install [Docker Desktop](https://docs.docker.com/desktop/setup/install/mac-install/)
* Install [git lfs](https://git-lfs.com/) for downloading large reference files such as the hg38 reference fasta.
* Additional annotation files not provided in this repository:
* * Download and unzip the t-APOGEE 2024.0.1 scores text file to the `ref/chrM/` path after agreeing to the [MitImpact 3D Non-commercial software license agreement](https://mitimpact.css-mendel.it/)
* * Go to the `scripts/` path and run `python3 reformat_tAPOGEE.py`
  * 
# Running m2_anno.sh in your local cromwell instance
* Edit `ExampleInputMitochondriaPipeline.json`
* Make an input JSON folder for each sample's input JSON using the template provided in this repository.
* Edit the variables for `refPath` to match your installation
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
