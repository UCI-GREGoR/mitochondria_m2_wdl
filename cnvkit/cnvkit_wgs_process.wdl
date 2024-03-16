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
    File participants_file
    Array[Array[String]] samples = read_tsv(participants_file)

    # Reference args
    File ref_targets_bed  # Generated from cnvkit_wgs_reference
    File ref_antitargets_bed  # Generated from cnvkit_wgs_reference
    File ref_cnn  # Generated from cnvkit_wgs_reference
    File ref_fasta  # Needed for CRAM parsing

    # Tool settings - defaults
    String call_method = "clonal"
    Float scatter_plot_width = 25.6
    Float scatter_plot_height = 19.2

    # Runtime args
    String cnvkit_docker = "docker.io/etal/cnvkit:0.9.10"
    Int processes = 32  # TBD based on cnvkit.py coverage multithreading efficiency
  }
  scatter(sample in samples) {
    call cnvkit_coverage {
      input:
        sID = sample[0],
        cram = sample[1],
        crai = sample[2],
        fasta = ref_fasta,
        targets = ref_targets_bed,
        antitargets = ref_antitargets_bed,
        docker = cnvkit_docker,
        proc = processes,
        memory_alloc = 0.5 * processes
    }
    call cnvkit_fix_segment_call_export_plot {
      input:
        sID = sample[0],
        vcf = sample[3],
        sex = sample[4],
        target_cnn = cnvkit_coverage.sample_target_cnn,
        antitarget_cnn = cnvkit_coverage.sample_antitarget_cnn,
        ref = ref_cnn,
        c_method = call_method,
        s_plot_w = scatter_plot_width,
        s_plot_h = scatter_plot_height,
        docker = cnvkit_docker,
        proc = 1,
        memory_alloc = 2.0
    }
  }
}

task cnvkit_coverage {
  input {
    File cram
    File crai
    File fasta
    File targets
    File antitargets
    String sID

    String docker
    Int proc
    Float memory_alloc
  }
  command {
    set -o pipefail
    set -e

    # cram index must be formatted as "${sID}.cram.crai" and in the same path as the cram
    cnvkit.py coverage \
    --fasta "~{fasta}" \
    --processes ~{proc} \
    --output "~{sID}.targetcoverage.cnn" \
    "~{cram}" \
    "~{targets}"

    # antitargets coverage (empty file for WGS)
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
    memory: "~{memory_alloc} GiB"
  }
  output {
    File sample_target_cnn = "~{sID}.targetcoverage.cnn"
    File sample_antitarget_cnn = "~{sID}.antitargetcoverage.cnn"
  }
}

task cnvkit_fix_segment_call_export_plot {
  input {
    String sID
    File vcf
    String sex
    File target_cnn
    File antitarget_cnn

    File ref
    String c_method

    Float s_plot_w
    Float s_plot_h

    String docker
    Int proc
    Float memory_alloc
  }
  command {
    set -o pipefail
    set -e

    cnvkit.py fix \
    "~{target_cnn}" \
    "~{antitarget_cnn}" \
    "~{ref}" \
    --output "~{sID}.cnr"

    cnvkit.py segment \
    "~{sID}.cnr" \
    --output "~{sID}.cns"

    cnvkit.py call \
    "~{sID}.cns" \
    --vcf "~{vcf}" \
    --method "~{c_method}" \
    --output "~{sID}.call.cns"

    cnvkit.py export vcf \
    "~{sID}.cns" \
    --sample-id "~{sID}" \
    --output "~{sID}.cnv.vcf"

    cnvkit.py scatter \
    --segment "~{sID}.cns" \
    "~{sID}.cnr" \
    --vcf "~{vcf}" \
    --fig-size ~{s_plot_w} ~{s_plot_h} \
    --output "~{sID}.scatter.png"

    cnvkit.py diagram \
    --segment "~{sID}.cns" \
    "~{sID}.cnr" \
    --no-gene-labels \
    --output "~{sID}.diagram.pdf"
  }
  runtime {
    docker: docker
    cpu: proc
    memory: "~{memory_alloc} GiB"
  }
  output {
    File cnr_file = "~{sID}.cnr"
    File cns_file = "~{sID}.cns"
    File call_cns_file = "~{sID}.call.cns"
    File cnv_vcf = "~{sID}.cnv.vcf"
    File scatter_png = "~{sID}.scatter.png"
    File diagram_pdf = "~{sID}.diagram.pdf"
  }
}
