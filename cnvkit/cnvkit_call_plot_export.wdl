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
    String proband_id  # PMGRC ID
    String proband_sex  # f, m, male, female, x, y, case-insensitive
    File proband_cnr
    File proband_cns
    File proband_vcf
    String call_method  # threshold, clonal, none

    # Runtime args
    Int preemptible_tries = 3
    String cnvkit_docker = "docker.io/etal/cnvkit:0.9.10"
    Float mem = 0.5
  }
  call cnvkit_call_cns {
    input:
      s_id = proband_id,
      cns = proband_cns,
      sex = proband_sex,
      vcf = proband_vcf,
      method = call_method,
      tries = preemptible_tries,
      docker = cnvkit_docker,
      mem_size_gb = mem
  }
  call cnvkit_scatter_plot {
    input:
      s_id = proband_id,
      cnr = proband_cnr,
      cns = proband_cns,
      vcf = proband_vcf,
      x_scatter_size = "12.8",
      y_scatter_size = "9.6",
      y_cn_max = "4",
      y_cn_min = "-4",
      tries = preemptible_tries,
      docker = cnvkit_docker,
      mem_size_gb = mem
  }
  call cnvkit_diagram_plot {
    input:
      s_id = proband_id,
      cns = proband_cns,
      tries = preemptible_tries,
      docker = cnvkit_docker,
      mem_size_gb = mem
  }
  call cnvkit_export_vcf {
    input:
      s_id = proband_id,
      cns = cnvkit_call_cns.clonal_cns,
      sex = proband_sex,
      tries = preemptible_tries,
      docker = cnvkit_docker,
      mem_size_gb = mem
  }
}

task cnvkit_call_cns {
  input {
    File cns
    File vcf

    String sex
    String s_id
    String method

    Int tries
    String docker
    Float mem_size_gb
  }
  output {
    File clonal_cns = s_id + ".clonal.cns"
  }
  runtime {
    preemptible: tries
    docker: docker
    memory: "~{mem_size_gb} GiB"
  }
  command {
    set -o pipefail
    set -e

    cnvkit.py call \
    ~{cns} \
    --sample-sex ~{sex} \
    --sample-id ~{s_id} \
    --vcf ~{vcf}\
    --method ~{method} \
    --output ~{clonal_cns}
  }
}
task cnvkit_scatter_plot {
  input {
    File cnr
    File cns
    File vcf
    String s_id

    String x_scatter_size = "12.8"
    String y_scatter_size = "9.6"
    String y_cn_max = "4"
    String y_cn_min = "-4"

    Int tries
    String docker
    Float mem_size_gb
  }
  output {
    File scatter_pdf = s_id + ".scatter.pdf"
  }
  runtime {
    preemptible: tries
    docker: docker
    memory: "~{mem_size_gb} GiB"
  }
  command {
    set -o pipefail
    set -e

    cnvkit.py scatter \
    ~{cnr} \
    --segment ~{cns} \
    --sample-id ~{s_id} \
    --vcf ~{vcf} \
    --output ~{scatter_pdf}
    --fig-size ~{x_scatter_size} ~{y_scatter_size} \
    --y-max ~{y_cn_max} \
    --y-min ~{y_cn_min}
  }
}
task cnvkit_diagram_plot {
  input {
    File cns
    String s_id

    Int tries
    String docker
    Float mem_size_gb
  }
  output {
    File diagram_pdf = s_id + ".diagram.pdf"
  }
  runtime {
    preemptible: tries
    docker: docker
    memory: "~{mem_size_gb} GiB"
  }
  command {
    set -o pipefail
    set -e

    cnvkit.py diagram \
    --segment ~{cns} \
    --sample-id ~{s_id} \
    --output ~{diagram_pdf}
  }
}
task cnvkit_export_vcf {
  input {
    File cns
    String s_id
    String sex

    Int tries
    String docker
    Float mem_size_gb
  }
  output {
    File cnv_vcf = s_id + ".cnv.vcf"
  }
  runtime {
    preemptible: tries
    docker: docker
    memory: "~{mem_size_gb} GiB"
  }
  command {
    set -o pipefail
    set -e

    cnvkit.py export vcf \
    ~{cns} \
    --sample-id ~{s_id} \
    --sample-sex ~{sex} \
    --output ~{cnv_vcf}
  }
}
