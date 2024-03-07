version 1.0

## Copyright (c) 2024 UCI-GREGoR
##
## References https://github.com/etal/cnvkit
##
## This WDL pipeline implements germline CNV calling using cnvkit.py batch
##
## Requirements/expectations :
## - Samples and references in pair-end short-read mapped cram/CRAM format
## - Reference samples to call CNVs against (unaffected relatives of probands)
## - Matching reference genome for crams/crams (e.g. hg38-no-alt)
##
## Output :
## - CNR and CNS coverage files, scatter and diagram plots
##
## Software version requirements
## - cnvkit == 0.9.10
## - python >= 3.7
## - biopython >= 1.79
## - matplotlib >= 3.5.1
## - numpy >= 1.21.6
## - pandas >= 1.3.5
## - pomegranate == 0.14.9
## - pyfaidx >= 0.6.4
## - pysam >= 0.17.0
## - reportlab >= 3.6.8
## - scikit-learn >= 1.0.2
## - scipy >= 1.7.3
##
## Cromwell version support
## - Tested on v59
##
## Runtime parameters are optimized for *TBD* Cloud Platform implementation
##
## Memory requirements: 300MB per process
##
## LICENSING :
## This script is released under the MIT License (see LICENSE in
## https://github.com/UCI-GREGoR/WDLs). Note however that the programs it
## calls may be subject to different licenses. Users are responsible for
## checking that they are authorized to run all programs before running this
## script. Please see the dockers for detailed licensing information pertaining
## to the included programs.

# WORKFLOW DEFINITION
workflow cnvkit_wgs_reference {
  input {
    # Reference args
    File ref_cram  # Median coverage cram/CRAM file or GIAB
    File ref_fasta
    File ref_flat
    String access_bed = "cnvkit_access." + basename(ref_fasta, ".fa") + ".bed"
    Int bin_size = 50000  # Default 50000bp for 30X genome

    Array[File] crams  # List of crams/crams for creating reference

    String ref_cnn  # Typically a cohort name

    # Runtime args
    String cnvkit_docker = "docker.io/etal/cnvkit:0.9.10"
    Int processes = 32
  }
  call cnvkit_access_autobin {
    input:
      cram = ref_cram,
      sID = basename(ref_cram, ".cram"),
      fasta = ref_fasta,
      flat = ref_flat,
      access = access_bed,
      bins = bin_size,
      docker = cnvkit_docker,
      proc = 1,  #  AWS and GCS options
      mem_gb = 1
  }
  scatter (in_cram in crams) {
    call cnvkit_coverage {
      input:
        fasta = ref_fasta,
        cram = in_cram,
        sID = basename(in_cram, ".cram"),
        targets = cnvkit_access_autobin.ref_targets_bed,
        antitargets = cnvkit_access_autobin.ref_antitargets_bed,
        docker = cnvkit_docker,
        proc = processes,  # AWS and GCS options
        mem_gb = processes
    }
  }
  call cnvkit_reference {
    input:
      cnn_targets = cnvkit_coverage.ref_target_cnn,
      cnn_antitargets = cnvkit_coverage.ref_antitarget_cnn,
      fasta = ref_fasta,
      ref = ref_cnn,
      docker = cnvkit_docker,
      proc = 1,
      mem_gb = 1
  }
}

task cnvkit_access_autobin {
  input {
    File cram
    File fasta
    File flat
    String access
    Int bins
    String sID

    String docker
    Int proc
    Int mem_gb
  }
  command {
    set -o pipefail
    set -e

    cnvkit.py access \
    "~{fasta}" \
    --output "~{access}"

    cnvkit.py autobin \
    ~{cram} \
    --method wgs \
    --bp-per-bin ~{bins} \
    --fasta "~{fasta}" \
    --annotate "~{flat}" \
    --access "~{access}" \
    --target-output-bed "~{sID}.targets.bed" \
    --antitarget-output-bed "~{sID}.antitargets.bed"
  }
  runtime {
    docker: docker
    cpu: proc
    memory: "~{mem_gb} GB"
  }
  output {
    File access_bed = access
    File ref_targets_bed = "~{sID}.targets.bed"
    File ref_antitargets_bed = "~{sID}.antitargets.bed"
  }
}

task cnvkit_coverage {
  input {
    File cram
    File fasta
    File targets
    File antitargets
    String sID

    String docker
    Int proc
    Int mem_gb
  }
  command {
    set -o pipefail
    set -e

    cnvkit.py coverage \
    --fasta "~{fasta}" \
    --processes ~{proc} \
    --output "~{sID}.targetcoverage.cnn" \
    "~{cram}" \
    "~{targets}"

    cnvkit.py coverage \
    --fasta "~{fasta}" \
    --processes ~{proc} \
    --output "~{sID}.antitargetcoverage.cnn" \
    "~{cram}" \
    "~{antitargets}"
  }
  runtime {
    docker: docker
    cpu: proc
    memory: "~{mem_gb} GB"
  }
  output {
    File ref_target_cnn = "~{sID}.targetcoverage.cnn"
    File ref_antitarget_cnn = "~{sID}.antitargetcoverage.cnn"
  }
}

task cnvkit_reference {
  input {
    Array[File] cnn_targets
    Array[File] cnn_antitargets
    String fasta
    String ref

    String docker
    Int proc
    Int mem_gb
  }
  command {
    set -o pipefail
    set -e

    cnvkit.py reference \
    --fasta "~{fasta}" \
    --output "~{ref}" \
    "~{cnn_targets}" \
    "~{cnn_antitargets}"
  }
  runtime {
    docker: docker
    cpu: proc
    memory: "~{mem_gb} GB"
  }
  output {
    File ref_cnn = ref
  }
}
