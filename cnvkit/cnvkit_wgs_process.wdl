version 1.0

## Copyright (c) 2024 UCI-GREGoR
##
## References https://github.com/etal/cnvkit
##
## This WDL pipeline implements germline CNV calling using cnvkit.py batch
##
## Requirements/expectations :
## - Samples and references in pair-end short-read mapped CRAM format
## - Reference samples to call CNVs against (unaffected relatives of probands)
## - Matching reference genome for crams (e.g. hg38-no-alt)
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
workflow cnvkit_wgs_process {
  input {
    # Sample args
    File sample_cram
    File sample_vcf

    # Reference args
    File ref_targets_bed  # Generated from cnvkit_wgs_reference
    File ref_antitargets_bed  # Generated from cnvkit_wgs_reference
    File ref_cnn  # Generated from cnvkit_wgs_reference
    File ref_fasta

    # Runtime args
    Int processes = 16  # TBD
    String cnvkit_docker = "docker.io/etal/cnvkit:0.9.10"
  }
  call cnvkit_coverage {
    input:
      fasta = ref_fasta,
      cram = sample_cram,
      targets = ref_targets_bed,
      antitargets = ref_antitargets_bed,
      docker = cnvkit_docker,
      proc = processes,
      memory_alloc = 0.5 * processes,
  }
  call cnvkit_fix_segment_call_export_plot {
    input:
      target_cnn = cnvkit_coverage.sample_target_cnn,
      antitarget_cnn = cnvkit_coverage.sample_antitarget_cnn,
      ref = ref_cnn,
      call_method = "clonal",
      vcf = sample_vcf,
      scatter_plot_width = 25.6,
      scatter_plot_height = 19.2,
      docker = cnvkit_docker,
      proc = 1,
      memory_alloc = 2.0,
  }
}

task cnvkit_coverage {
  input {
    File cram
    File fasta
    File targets
    File antitargets
    String sID = basename(cram, ".cram")  # accepts .cram
    String targets_filename = sID + ".targetcoverage.cnn"
    String antitargets_filename = sID + ".antitargetcoverage.cnn"

    String docker
    Int proc
    Float memory_alloc
  }
  command {
    set -o pipefail
    set -e

    # cram index must be formatted as "${sID}.cram.crai" and in the same path as the cram
    cnvkit.py coverage \
    --fasta ~{fasta} \
    --processes ~{proc} \
    --output ~{targets_filename} \
    ~{cram} \
    ~{targets}
    
    cnvkit.py coverage \
    --fasta ~{fasta} \
    --processes ~{proc} \
    --output ~{antitargets_filename} \
    ~{cram} \
    ~{antitargets}
  }
  runtime {
    docker: docker
    memory: "~{memory_alloc} GiB"
    cpu: proc
  }
  output {
    File sample_target_cnn = targets_filename
    File sample_antitarget_cnn = antitargets_filename
  }
}

task cnvkit_fix_segment_call_export_plot {
  input {
    File target_cnn
    File antitarget_cnn
    File ref
    File vcf
    String call_method

    String sID = basename(target_cnn, ".targetcoverage.cnn")
    String cnr_filename = sID + ".cnr"
    String cns_filename = sID + ".cns"
    String call_cns_filename = sID + ".call.cns"
    String scatter_png_name = sID + ".scatter.png"
    String diagram_pdf_name = sID + ".diagram.pdf"
    String cnv_vcf_name = sID + ".cnv.vcf"

    Float scatter_plot_width
    Float scatter_plot_height

    String docker
    Int proc
    Float memory_alloc
  }
  command {
    set -o pipefail
    set -e

    cnvkit.py fix \
    ~{target_cnn} \
    ~{antitarget_cnn} \
    ~{ref} \
    --output ~{cnr_filename}

    cnvkit.py segment \
    ~{cnr_filename} \
    --output ~{cns_filename}

    cnvkit.py call \
    ~{cns_filename} \
    --vcf ~{vcf} \
    --method ~{call_method} \
    --output ~{call_cns_filename}

    cnvkit.py export vcf \
    ~{cns_filename} \
    --sample-id ~{sID} \
    --output ~{cnv_vcf_name}

    cnvkit.py scatter \
    --segment ~{cns_filename} \
    ~{cnr_filename} \
    --vcf ~{vcf} \
    --fig-size ~{scatter_plot_width} ~{scatter_plot_height} \
    --output ~{scatter_png_name}

    cnvkit.py diagram \
    --segment ~{cns_filename} \
    ~{cnr_filename} \
    --no-gene-labels \
    --output ~{diagram_pdf_name}
  }
  runtime {
    docker: docker
    memory: "~{memory_alloc} GiB"
    cpu: proc
  }
  output {
    File cnr_file = cnr_filename
    File cns_file = cns_filename
    File call_cns_file = call_cns_filename
    File cnv_vcf = cnv_vcf_name
    File scatter_png = scatter_png_name
    File diagram_pdf = diagram_pdf_name
  }
}
