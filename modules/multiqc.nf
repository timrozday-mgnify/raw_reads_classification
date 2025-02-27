process MULTIQC {

    publishDir "${params.outdir}/qc/multiqc", mode: 'copy'
    tag "${sample_name}"
    container 'quay.io/biocontainers/multiqc:1.14--pyhdfd78af_0'

    input:
    tuple val(sample_name), path(fastp_json)
    path motus_log, name: "motus.log"

    output:
    path "multiqc_report.html", emit: multiqc_report
    path "multiqc_data", emit: multiqc_data

    script:
    """
    multiqc --module fastp --module motus .
    """
}
