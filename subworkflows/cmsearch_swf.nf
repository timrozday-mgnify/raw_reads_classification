/*
 * Cmsearch and deoverlap-cmsearch
 */

include { CMSEARCH } from '../modules/cmsearch'
include { CMSEARCH_DEOVERLAP } from '../modules/cmsearch_deoverlap'
include { EASEL_EXTRACT_BY_COORD } from '../modules/easel'
include { EXTRACT_MODELS } from '../modules/extract_coords'

/* FIXME: rename this - the current name doesn't reflect the modue functionatily */
process RETURN_FILES {

    publishDir(
        "${params.outdir}/cmsearch/",
        mode: 'copy'
    )

    container 'quay.io/biocontainers/infernal:1.1.4--pl5321hec16e2b_1'
    tag "${name}"
    label 'process_single'

    stageInMode 'copy'

    input:
    val name
    file cmsearch
    file deoverlap

    output:
    file "${name}_matched_seqs_with_coords.tbl"
    file "${name}_matched_seqs_with_coords_deoverlap.tbl"

    script:
    """
    head -n 1 ${cmsearch} > "${name}_matched_seqs_with_coords.tbl"
    grep -v '^#' ${cmsearch} | grep . >> "${name}_matched_seqs_with_coords.tbl"

    head -n 1 ${cmsearch} > "${name}_matched_seqs_with_coords_deoverlap.tbl"
    cat ${deoverlap} >> "${name}_matched_seqs_with_coords_deoverlap.tbl"
    """
}

workflow CMSEARCH_SUBWF {
    take:
        sample_name
        sequences
        covariance_model_database
        clan_information
    main:
        // cat models
        
        CMSEARCH(sample_name, sequences, covariance_model_database)

        CMSEARCH_DEOVERLAP(CMSEARCH.out.sample_name, clan_information, CMSEARCH.out.cmsearch)

        // cat cmsearch
        cmsearch_result = CMSEARCH.out.sample_name.merge(CMSEARCH.out.cmsearch)
        cmsearch_result.collectFile(name: "cmsearch.tbl", newLine: true)

        // cat deoverlapped
        cmsearch_result_deoverlapped = CMSEARCH_DEOVERLAP.out.sample_name.merge(CMSEARCH_DEOVERLAP.out.cmsearch_deoverlap)
        cmsearch_result_deoverlapped.collectFile(name: "deoverlapped.tbl")

        easel_ch = sample_name.merge(sequences).join(cmsearch_result_deoverlapped)
        EASEL_EXTRACT_BY_COORD(easel_ch.map{ it[0] }, easel_ch.map{ it[1] }, easel_ch.map{ it[2] })

        extract_ch = EASEL_EXTRACT_BY_COORD.out.sample_name.merge(EASEL_EXTRACT_BY_COORD.out.models_fasta)
        EXTRACT_MODELS(extract_ch.map{ it[0] }, extract_ch.map{ it[1] })

        output_ch = cmsearch_result.join(cmsearch_result_deoverlapped) 

        RETURN_FILES(output_ch.map{ it[0] }, output_ch.map{ it[1] }, output_ch.map{ it[2] })
    emit:
        sample_name = EXTRACT_MODELS.out.sample_name
        cmsearch_lsu_fasta = EXTRACT_MODELS.out.lsu_fasta
        cmsearch_ssu_fasta = EXTRACT_MODELS.out.ssu_fasta
        seq_cat = EXTRACT_MODELS.out.seq_cat_folder
}
