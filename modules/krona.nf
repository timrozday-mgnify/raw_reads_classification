/*
 * Krona 2.7.1
*/

process KRONA {

    label 'krona'
    tag "${sample_name}"
    
    publishDir(
        "${params.outdir}/taxonomy/${sample_name}/${otu_label}",
        mode: 'copy',
        pattern: "*krona.html"
    )

    container 'quay.io/biocontainers/krona:2.7.1--pl5321hdfd78af_7'

    input:
    val sample_name
    val otu_label
    path otu_counts

    output:
    val sample_name, emit: sample_name
    path "*krona.html", emit: krona_html

    script:
    """
    ktImportText -o "${sample_name}_${otu_label}_krona.html" $otu_counts
    """
}
