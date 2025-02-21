/*
 * Infernal cmsearch 1.1.4
*/

process CMSEARCH {

    label 'cmsearch'
    tag "${sample_name}"
    container 'quay.io/biocontainers/infernal:1.1.4--pl5321hec16e2b_1'

    input:
    val sample_name
    path sequences
    each covariance_model_database

    output:
    val sample_name, emit: sample_name
    path "${sequences.baseName}*.cmsearch_matches.tbl", emit: cmsearch

    script:
    """
    cmsearch \
    --cpu ${task.cpus} \
    --cut_ga \
    --noali \
    --hmmonly \
    -Z 1000 \
    -o /dev/null \
    --tblout ${sequences.baseName}.cmsearch_matches.tbl \
    ${covariance_model_database} \
    ${sequences}
    """
}
