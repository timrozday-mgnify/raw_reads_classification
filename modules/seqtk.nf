/*
 * seqtk 1.3
*/

process SEQTK {
    publishDir "${params.outdir}/", mode: 'copy'
    label 'seqtk'
    tag "${sample_name}"
    container 'quay.io/biocontainers/seqtk:1.3--h7132678_4'

    input:
        val sample_name
        path reads
    output:
        val sample_name, emit: sample_name
        path "${sample_name}.fasta", emit: sequence

    script:
    """
    seqtk seq -a ${reads} > ${sample_name}.fasta
    """
}