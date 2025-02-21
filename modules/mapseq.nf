/*
 * MAPseq 2.1.1
*/
process MAPSEQ {

    publishDir(
        "${params.outdir}/taxonomy/${sample_name}/${otu_label}",
        mode: 'copy',
        pattern: "*.mseq*"
    )

    container 'quay.io/biocontainers/mapseq:2.1.1--ha34dc8c_0'

    label 'mapseq'
    tag "${sample_name}"
    
    input:
    val sample_name
    path sequence
    path db_fasta
    path db_mscluster
    path db_tax
    val otu_label

    output:
    val sample_name, emit: sample_name
    path "${sequence.baseName}.mseq", emit: mapseq_result

    script:
    """
    mapseq \
        ${sequence} \
        ${db_fasta} \
        ${db_tax} \
        -nthreads ${task.cpus} \
        -tophits 80 \
        -topotus 40 \
        -outfmt 'simple' > ${sequence.baseName}.mseq
    """
}


