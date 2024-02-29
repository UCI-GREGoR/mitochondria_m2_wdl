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
    String access_bed = "cnvkit_access." + basename(ref_fasta) + ".bed"
    Int bin_size = 50000  # Default 50000bp for 30X genome

    Array[File] crams  # List of crams/crams for creating reference

    String ref_cnn  # Typically a cohort name

    # Runtime args
    Int processes = 16  # TBD
    String cnvkit_docker = "docker.io/etal/cnvkit:0.9.10"
  }
  call cnvkit_access_autobin {
    input:
      cram = ref_cram,
      fasta = ref_fasta,
      flat = ref_flat,
      access = access_bed,
      bins = bin_size,
      docker = cnvkit_docker,
      proc = 1,
      memory_alloc = 0.5
  }
  scatter (cram in crams) {
    call cnvkit_coverage {
      input:
        fasta = ref_fasta,
        cram = cram,
        targets = cnvkit_access_autobin.ref_targets_bed,
        antitargets = cnvkit_access_autobin.ref_antitargets_bed,
        docker = cnvkit_docker,
        proc = processes,
        memory_alloc = 0.5 * processes
    }
  }
  call cnvkit_reference {
    input:
      cnn_targets = cnvkit_coverage.ref_target_cnn,
      cnn_antitargets = cnvkit_coverage.ref_antitarget_cnn,
      ref = ref_cnn,
      docker = cnvkit_docker,
      proc = 1,
      memory_alloc = 0.5 * length(crams)
  }
}

task cnvkit_access_autobin {
  input {
    File cram
    File fasta
    File flat
    String access
    Int bins
    String sID = basename(cram, ".cram")
    String out_targets = sID + ".targets.bed"
    String out_antitargets = sID + ".antitargets.bed"

    String docker
    Int proc
    Float memory_alloc
  }
  command {
    set -o pipefail
    set -e

    cnvkit.py access \
    ~{fasta} \
    --output ~{access}

    cnvkit.py autobin \
    ~{cram} \
    --method wgs \
    --bp-per-bin ~{bins} \
    --fasta ~{fasta} \
    --annotate ~{flat} \
    --access ~{access} \
    --target-output-bed ~{out_targets} \
    --antitarget-output-bed ~{out_antitargets}
  }
  runtime {
    docker: docker
    memory: "~{memory_alloc} GiB"
    cpu: proc
  }
  output {
    File access_bed = access
    File ref_targets_bed = out_targets
    File ref_antitargets_bed = out_antitargets
  }
}

task cnvkit_coverage {
  input {
    File cram
    File fasta
    File targets
    File antitargets
    String sID = basename(cram)  # accepts .cram and .cram
    String out_file_1 = sID + ".targetcoverage.cnn"
    String out_file_2 = sID + ".antitargetcoverage.cnn"

    String docker
    Int proc
    Float memory_alloc
  }
  command {
    set -o pipefail
    set -e

    cnvkit.py coverage \
    --fasta ~{fasta} \
    --processes ~{proc} \
    --output ~{out_file_1} \
    ~{cram} \
    ~{targets}
    
    cnvkit.py coverage \
    --fasta ~{fasta} \
    --processes ~{proc} \
    --output ~{out_file_2} \
    ~{cram} \
    ~{antitargets}
  }
  runtime {
    docker: docker
    memory: "~{memory_alloc} GiB"
    cpu: proc
  }
  output {
    File ref_target_cnn = out_file_1
    File ref_antitarget_cnn = out_file_2
  }
}

task cnvkit_reference {
  input {
    Array[File] cnn_targets
    Array[File] cnn_antitargets
    String ref

    String docker
    Int proc
    Float memory_alloc
  }
  command {
    set -o pipefail
    set -e

    cnvkit.py reference \
    cnn_targets \
    cnn_antitargets \
    --output ~{ref}
  }
  runtime {
    docker: docker
    memory: "~{memory_alloc} GiB"
    cpu: proc
  }
  output {
    File ref_cnn = ref
  }
}
