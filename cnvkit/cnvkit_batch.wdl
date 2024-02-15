version 1.0

## Copyright (c) 2024 UCI-GREGoR
##
## References https://github.com/etal/cnvkit
##
## This WDL pipeline implements germline CNV calling using cnvkit.py batch
##
## Requirements/expectations :
## - Samples and references in pair-end short-read mapped BAM/CRAM format
## - Reference samples to call CNVs against (unaffected relatives of probands)
## - Matching reference genome for bams/crams (e.g. hg38-no-alt)
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
workflow cnvkit_germline {
  input {
    # Reference args
    File ref_fasta
    File ref_flat
    File access_bed
    String ref_cnn  # For now, generate a new reference every time

    Array[File] proband_bams
    Array[File] unaffected_bams
    String output_path

    # Runtime args
    Int processes  # TBD
    Float memory_gb  # Memory per thread
    Int agg_small_disk = 200
    Int agg_medium_disk = 300
    Int agg_large_disk = 400
    String cnvkit_docker
    Int preemptible_tries = 3
  }
  call cnvkit_batch {
    input:
      fasta = ref_fasta,
      flat = ref_flat,
      access = access_bed,
      ref= ref_cnn,
      bams = proband_bams,
      ref_bams = unaffected_bams,
      out = output_path,
      ref_out = ref_cnn,
      docker = cnvkit_docker,
      proc = processes,
      memory_alloc = memory_gb * processes,
      disk_size = agg_large_disk,
      tries = preemptible_tries
  }
}

task cnvkit_batch {
  input {
    File fasta
    File flat
    File access
    File ref

    Array[File] bams
    Array[File] ref_bams

    String out
    String ref_out

    String docker
    Int proc
    Float memory_alloc
    Int disk_size
    Int tries
  }
  command {
    set -o pipefail
    set -e

    cnvkit.py batch \
    --method wgs \
    ~{bams} \
    --normals ~{ref_bams} \
    --output-reference ~{ref} \
    --fasta ~{fasta} \
    --annotate ~{flat} \
    --access ~{access} \
    --output-dir ~{out} \
    --process ~{proc}
  }
  runtime {
    preemptible: tries
    docker: docker
    memory: "~{memory_alloc} GiB"
    cpu: proc
    disks: "local-disk " + disk_size + " HDD"
  }
}
